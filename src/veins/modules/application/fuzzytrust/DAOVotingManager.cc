#include "DAOVotingManager.h"
#include <algorithm>
#include <numeric>
#include <cmath>
#include <random>
#include <sstream>
#include <iomanip>
#include <fstream>

using json = nlohmann::json;

DAOVotingManager::DAOVotingManager() {
    // 初始化默认配置
    consensus_config_.approval_threshold = 0.6;
    consensus_config_.quorum_threshold = 0.4;
    consensus_config_.super_majority_threshold = 0.75;
    consensus_config_.min_voting_period_hours = 24;
    consensus_config_.max_voting_period_hours = 168; // 7天
    consensus_config_.reputation_weight = 0.4;
    consensus_config_.stake_weight = 0.4;
    consensus_config_.participation_weight = 0.2;
    consensus_config_.enable_quadratic_voting = false;
    consensus_config_.enable_delegation = true;
    
    current_block_height_ = 0;
    latest_block_hash_ = "";
    
    // 初始化规则权重（7个规则）
    current_rule_weights_ = {0.25, 0.20, 0.18, 0.15, 0.12, 0.08, 0.02};
    target_rule_weights_ = current_rule_weights_;
    
    // 初始化治理指标
    governance_metrics_.system_performance_score = 0.8;
    governance_metrics_.network_stability_index = 0.85;
    governance_metrics_.trust_consensus_level = 0.75;
    governance_metrics_.resource_utilization_efficiency = 0.7;
    governance_metrics_.decision_quality_score = 0.8;
    governance_metrics_.last_updated = std::chrono::system_clock::now();
}

DAOVotingManager::DAOVotingManager(const json& config) : DAOVotingManager() {
    loadConfig(config);
}

void DAOVotingManager::loadConfig(const json& config) {
    config_ = config;
    
    if (config.contains("dao_voting")) {
        const auto& dao_config = config["dao_voting"];
        
        // 加载共识配置
        if (dao_config.contains("consensus")) {
            const auto& consensus = dao_config["consensus"];
            consensus_config_.approval_threshold = consensus.value("approval_threshold", 0.6);
            consensus_config_.quorum_threshold = consensus.value("quorum_threshold", 0.4);
            consensus_config_.super_majority_threshold = consensus.value("super_majority_threshold", 0.75);
            consensus_config_.min_voting_period_hours = consensus.value("min_voting_period_hours", 24);
            consensus_config_.max_voting_period_hours = consensus.value("max_voting_period_hours", 168);
            consensus_config_.reputation_weight = consensus.value("reputation_weight", 0.4);
            consensus_config_.stake_weight = consensus.value("stake_weight", 0.4);
            consensus_config_.participation_weight = consensus.value("participation_weight", 0.2);
            consensus_config_.enable_quadratic_voting = consensus.value("enable_quadratic_voting", false);
            consensus_config_.enable_delegation = consensus.value("enable_delegation", true);
        }
        
        // 加载初始规则权重
        if (dao_config.contains("initial_rule_weights")) {
            current_rule_weights_ = dao_config["initial_rule_weights"].get<std::vector<double>>();
            target_rule_weights_ = current_rule_weights_;
        }
    }
}

json DAOVotingManager::getConfig() const {
    return config_;
}

void DAOVotingManager::updateConsensusConfig(const ConsensusConfig& new_config) {
    consensus_config_ = new_config;
    
    // 记录配置更新日志
    json log_data;
    log_data["action"] = "consensus_config_updated";
    log_data["timestamp"] = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    logVotingActivity("CONFIG_UPDATE", log_data);
}

bool DAOVotingManager::registerVoter(const Voter& voter) {
    if (voters_.find(voter.node_id) != voters_.end()) {
        return false; // 投票者已存在
    }
    
    Voter new_voter = voter;
    new_voter.voting_power = calculateVotingPower(new_voter);
    new_voter.is_active = true;
    new_voter.last_active = std::chrono::system_clock::now();
    
    voters_[voter.node_id] = new_voter;
    
    // 记录注册日志
    json log_data;
    log_data["action"] = "voter_registered";
    log_data["voter_id"] = voter.node_id;
    log_data["voting_power"] = new_voter.voting_power;
    logVotingActivity("VOTER_REGISTRATION", log_data);
    
    return true;
}

bool DAOVotingManager::updateVoterReputation(const std::string& voter_id, double new_reputation) {
    auto it = voters_.find(voter_id);
    if (it == voters_.end()) {
        return false;
    }
    
    it->second.reputation_score = new_reputation;
    updateVotingPower(voter_id);
    
    return true;
}

bool DAOVotingManager::updateVoterStake(const std::string& voter_id, double new_stake) {
    auto it = voters_.find(voter_id);
    if (it == voters_.end()) {
        return false;
    }
    
    it->second.stake_amount = new_stake;
    updateVotingPower(voter_id);
    
    return true;
}

void DAOVotingManager::updateVotingPower(const std::string& voter_id) {
    auto it = voters_.find(voter_id);
    if (it != voters_.end()) {
        it->second.voting_power = calculateVotingPower(it->second);
    }
}

void DAOVotingManager::updateAllVotingPowers() {
    for (auto& [voter_id, voter] : voters_) {
        voter.voting_power = calculateVotingPower(voter);
    }
}

std::vector<DAOVotingManager::Voter> DAOVotingManager::getActiveVoters() const {
    std::vector<Voter> active_voters;
    for (const auto& [voter_id, voter] : voters_) {
        if (voter.is_active) {
            active_voters.push_back(voter);
        }
    }
    return active_voters;
}

DAOVotingManager::Voter DAOVotingManager::getVoter(const std::string& voter_id) const {
    auto it = voters_.find(voter_id);
    if (it != voters_.end()) {
        return it->second;
    }
    return Voter{}; // 返回空的投票者
}

std::string DAOVotingManager::createProposal(ProposalType type, const std::string& title,
                                           const std::string& description, const json& proposal_data,
                                           const std::string& proposer_id,
                                           std::function<bool(const json&)> execution_callback) {
    
    // 验证提案数据
    if (!validateProposalData(type, proposal_data)) {
        return ""; // 无效的提案数据
    }
    
    Proposal proposal;
    proposal.proposal_id = generateProposalId();
    proposal.type = type;
    proposal.title = title;
    proposal.description = description;
    proposal.proposal_data = proposal_data;
    proposal.proposer_id = proposer_id;
    proposal.created_time = std::chrono::system_clock::now();
    
    // 根据提案类型设置投票期限
    int voting_hours = consensus_config_.min_voting_period_hours;
    if (type == ProposalType::EMERGENCY_ACTION) {
        voting_hours = 12; // 紧急提案12小时
    } else if (type == ProposalType::GOVERNANCE_CHANGE || type == ProposalType::SYSTEM_UPGRADE) {
        voting_hours = consensus_config_.max_voting_period_hours; // 重要提案7天
    }
    
    proposal.voting_deadline = proposal.created_time + std::chrono::hours(voting_hours);
    proposal.status = ProposalStatus::ACTIVE;
    proposal.yes_votes = 0.0;
    proposal.no_votes = 0.0;
    proposal.abstain_votes = 0.0;
    proposal.total_voters = 0;
    proposal.execution_callback = execution_callback;
    
    proposals_[proposal.proposal_id] = proposal;
    
    // 触发提案创建回调
    if (proposal_created_callback_) {
        proposal_created_callback_(proposal);
    }
    
    // 记录提案创建日志
    json log_data;
    log_data["action"] = "proposal_created";
    log_data["proposal_id"] = proposal.proposal_id;
    log_data["type"] = static_cast<int>(type);
    log_data["proposer_id"] = proposer_id;
    logVotingActivity("PROPOSAL_CREATION", log_data);
    
    return proposal.proposal_id;
}

bool DAOVotingManager::castVote(const std::string& proposal_id, const std::string& voter_id,
                                VoteOption option, double voting_power) {
    // 检查提案是否存在且处于活跃状态
    auto proposal_it = proposals_.find(proposal_id);
    if (proposal_it == proposals_.end() || proposal_it->second.status != ProposalStatus::ACTIVE) {
        return false;
    }
    
    // 检查投票者是否有资格投票
    if (!isVoterEligible(voter_id, proposal_id)) {
        return false;
    }
    
    // 检查是否已经投票
    for (const auto& vote : vote_history_) {
        if (vote.proposal_id == proposal_id && vote.voter_id == voter_id) {
            return false; // 已经投票
        }
    }
    
    auto voter_it = voters_.find(voter_id);
    if (voter_it == voters_.end()) {
        return false;
    }
    
    // 创建投票记录
    VoteRecord vote_record;
    vote_record.voter_id = voter_id;
    vote_record.proposal_id = proposal_id;
    vote_record.option = option;
    vote_record.voting_power = voting_power; // 使用传入的投票权重
    vote_record.vote_time = std::chrono::system_clock::now();
    vote_record.reason = "";
    
    // 添加到投票历史
    vote_history_.push_back(vote_record);
    
    // 更新提案的投票统计
    Proposal& proposal = proposal_it->second;
    switch (option) {
        case VoteOption::YES:
            proposal.yes_votes += voting_power;
            break;
        case VoteOption::NO:
            proposal.no_votes += voting_power;
            break;
        case VoteOption::ABSTAIN:
            proposal.abstain_votes += voting_power;
            break;
    }
    
    // 更新投票者的参与历史
    voter_it->second.participation_count++;
    voter_it->second.last_active = std::chrono::system_clock::now();
    
    return true;
}

bool DAOVotingManager::submitVote(const std::string& proposal_id, const std::string& voter_id,
                                VoteOption option, const std::string& reason) {
    
    // 检查提案是否存在且处于活跃状态
    auto proposal_it = proposals_.find(proposal_id);
    if (proposal_it == proposals_.end() || proposal_it->second.status != ProposalStatus::ACTIVE) {
        return false;
    }
    
    // 检查投票者是否有资格投票
    if (!isVoterEligible(voter_id, proposal_id)) {
        return false;
    }
    
    // 检查是否已经投票
    for (const auto& vote : vote_history_) {
        if (vote.proposal_id == proposal_id && vote.voter_id == voter_id) {
            return false; // 已经投票
        }
    }
    
    auto voter_it = voters_.find(voter_id);
    if (voter_it == voters_.end()) {
        return false;
    }
    
    // 创建投票记录
    VoteRecord vote_record;
    vote_record.voter_id = voter_id;
    vote_record.proposal_id = proposal_id;
    vote_record.option = option;
    vote_record.voting_power = voter_it->second.voting_power;
    vote_record.vote_time = std::chrono::system_clock::now();
    vote_record.reason = reason;
    
    // 处理二次投票（如果启用）
    if (consensus_config_.enable_quadratic_voting) {
        vote_record.voting_power = calculateQuadraticVotingPower(
            vote_record.voting_power, voter_it->second.stake_amount);
    }
    
    vote_history_.push_back(vote_record);
    
    // 更新提案投票统计
    switch (option) {
        case VoteOption::YES:
            proposal_it->second.yes_votes += vote_record.voting_power;
            break;
        case VoteOption::NO:
            proposal_it->second.no_votes += vote_record.voting_power;
            break;
        case VoteOption::ABSTAIN:
            proposal_it->second.abstain_votes += vote_record.voting_power;
            break;
    }
    proposal_it->second.total_voters++;
    
    // 更新投票者参与统计
    updateVoterParticipationStats(voter_id);
    
    // 触发投票回调
    if (vote_cast_callback_) {
        vote_cast_callback_(vote_record);
    }
    
    // 记录投票日志
    json log_data;
    log_data["action"] = "vote_cast";
    log_data["proposal_id"] = proposal_id;
    log_data["voter_id"] = voter_id;
    log_data["option"] = static_cast<int>(option);
    log_data["voting_power"] = vote_record.voting_power;
    logVotingActivity("VOTE_CAST", log_data);
    
    return true;
}

bool DAOVotingManager::executeProposal(const std::string& proposal_id) {
    auto it = proposals_.find(proposal_id);
    if (it == proposals_.end()) {
        return false;
    }
    
    Proposal& proposal = it->second;
    
    // 检查提案是否已通过
    if (proposal.status != ProposalStatus::PASSED) {
        return false;
    }
    
    bool execution_success = true;
    
    // 执行提案
    if (proposal.execution_callback) {
        execution_success = proposal.execution_callback(proposal.proposal_data);
    } else {
        // 默认执行逻辑
        switch (proposal.type) {
            case ProposalType::RULE_WEIGHT_ADJUSTMENT:
                if (proposal.proposal_data.contains("new_weights")) {
                    auto new_weights = proposal.proposal_data["new_weights"].get<std::vector<double>>();
                    updateRuleWeights(new_weights);
                }
                break;
            case ProposalType::PARAMETER_UPDATE:
                // 参数更新逻辑
                break;
            default:
                execution_success = false;
                break;
        }
    }
    
    if (execution_success) {
        proposal.status = ProposalStatus::EXECUTED;
        
        // 触发执行回调
        if (proposal_executed_callback_) {
            proposal_executed_callback_(proposal);
        }
        
        // 记录执行日志
        json log_data;
        log_data["action"] = "proposal_executed";
        log_data["proposal_id"] = proposal_id;
        log_data["execution_success"] = true;
        logVotingActivity("PROPOSAL_EXECUTION", log_data);
    }
    
    return execution_success;
}

void DAOVotingManager::updateProposalStatus() {
    auto now = std::chrono::system_clock::now();
    
    for (auto& proposal_pair : proposals_) {
        if (proposal_pair.second.status == ProposalStatus::ACTIVE) {
            // 检查是否过期
            if (now > proposal_pair.second.voting_deadline) {
                proposal_pair.second.status = determineProposalOutcome(proposal_pair.first);
            }
        }
    }
    
    // 清理过期提案
    cleanupExpiredProposals();
}

std::vector<DAOVotingManager::Proposal> DAOVotingManager::getActiveProposals() const {
    std::vector<Proposal> active_proposals;
    for (const auto& proposal_pair : proposals_) {
        if (proposal_pair.second.status == ProposalStatus::ACTIVE) {
            active_proposals.push_back(proposal_pair.second);
        }
    }
    return active_proposals;
}

std::vector<DAOVotingManager::Proposal> DAOVotingManager::getProposalsByType(ProposalType type) const {
    std::vector<Proposal> filtered_proposals;
    for (const auto& proposal_pair : proposals_) {
        if (proposal_pair.second.type == type) {
            filtered_proposals.push_back(proposal_pair.second);
        }
    }
    return filtered_proposals;
}

DAOVotingManager::Proposal DAOVotingManager::getProposal(const std::string& proposal_id) const {
    auto it = proposals_.find(proposal_id);
    if (it != proposals_.end()) {
        return it->second;
    }
    return Proposal{}; // 返回空提案
}

std::vector<DAOVotingManager::VoteRecord> DAOVotingManager::getVoteHistory(const std::string& voter_id) const {
    std::vector<VoteRecord> voter_history;
    for (const auto& vote : vote_history_) {
        if (vote.voter_id == voter_id) {
            voter_history.push_back(vote);
        }
    }
    return voter_history;
}

std::vector<DAOVotingManager::VoteRecord> DAOVotingManager::getProposalVotes(const std::string& proposal_id) const {
    std::vector<VoteRecord> proposal_votes;
    for (const auto& vote : vote_history_) {
        if (vote.proposal_id == proposal_id) {
            proposal_votes.push_back(vote);
        }
    }
    return proposal_votes;
}

bool DAOVotingManager::checkQuorum(const std::string& proposal_id) const {
    auto it = proposals_.find(proposal_id);
    if (it == proposals_.end()) {
        return false;
    }
    
    const Proposal& proposal = it->second;
    double total_voting_power = 0.0;
    for (const auto& voter_pair : voters_) {
        if (voter_pair.second.is_active) {
            total_voting_power += voter_pair.second.voting_power;
        }
    }
    
    double participated_power = proposal.yes_votes + proposal.no_votes + proposal.abstain_votes;
    double participation_rate = (total_voting_power > 0) ? participated_power / total_voting_power : 0.0;
    
    return participation_rate >= consensus_config_.quorum_threshold;
}

bool DAOVotingManager::checkApprovalThreshold(const std::string& proposal_id) const {
    auto it = proposals_.find(proposal_id);
    if (it == proposals_.end()) {
        return false;
    }
    
    const Proposal& proposal = it->second;
    double total_decisive_votes = proposal.yes_votes + proposal.no_votes;
    
    if (total_decisive_votes == 0) {
        return false;
    }
    
    double approval_rate = proposal.yes_votes / total_decisive_votes;
    
    // 根据提案类型选择阈值
    double required_threshold = consensus_config_.approval_threshold;
    if (proposal.type == ProposalType::GOVERNANCE_CHANGE || 
        proposal.type == ProposalType::SYSTEM_UPGRADE) {
        required_threshold = consensus_config_.super_majority_threshold;
    }
    
    return approval_rate >= required_threshold;
}

double DAOVotingManager::calculateConsensusScore(const std::string& proposal_id) const {
    auto it = proposals_.find(proposal_id);
    if (it == proposals_.end()) {
        return 0.0;
    }
    
    const Proposal& proposal = it->second;
    double total_votes = proposal.yes_votes + proposal.no_votes + proposal.abstain_votes;
    
    if (total_votes == 0) {
        return 0.0;
    }
    
    // 计算共识强度（考虑投票分布的均匀性）
    double yes_ratio = proposal.yes_votes / total_votes;
    double no_ratio = proposal.no_votes / total_votes;
    double abstain_ratio = proposal.abstain_votes / total_votes;
    
    // 使用熵来衡量共识强度（熵越低，共识越强）
    double entropy = 0.0;
    if (yes_ratio > 0) entropy -= yes_ratio * std::log2(yes_ratio);
    if (no_ratio > 0) entropy -= no_ratio * std::log2(no_ratio);
    if (abstain_ratio > 0) entropy -= abstain_ratio * std::log2(abstain_ratio);
    
    // 将熵转换为共识分数（0-1范围）
    double max_entropy = std::log2(3.0); // 三个选项的最大熵
    double consensus_score = 1.0 - (entropy / max_entropy);
    
    return std::max(0.0, std::min(1.0, consensus_score));
}

DAOVotingManager::ProposalStatus DAOVotingManager::determineProposalOutcome(const std::string& proposal_id) const {
    if (!checkQuorum(proposal_id)) {
        return ProposalStatus::EXPIRED; // 未达到法定人数
    }
    
    if (checkApprovalThreshold(proposal_id)) {
        return ProposalStatus::PASSED;
    } else {
        return ProposalStatus::REJECTED;
    }
}

void DAOVotingManager::performWeightAdaptation(const std::vector<double>& performance_gains) {
    if (performance_gains.size() != current_rule_weights_.size()) {
        return; // 尺寸不匹配
    }
    
    // 创建权重调整提案
    std::vector<double> new_weights = current_rule_weights_;
    double learning_rate = 0.05; // 学习率
    
    for (size_t i = 0; i < new_weights.size(); ++i) {
        // 使用Sigmoid映射性能增益
        double sigma_delta = 1.0 / (1.0 + std::exp(-performance_gains[i]));
        new_weights[i] = (1.0 - learning_rate) * new_weights[i] + learning_rate * sigma_delta;
        
        // 确保权重在合理范围内
        new_weights[i] = std::max(0.01, std::min(1.0, new_weights[i]));
    }
    
    // 归一化权重
    double sum = std::accumulate(new_weights.begin(), new_weights.end(), 0.0);
    if (sum > 0) {
        for (auto& w : new_weights) {
            w /= sum;
        }
    }
    
    // 创建自动权重调整提案
    json proposal_data;
    proposal_data["new_weights"] = new_weights;
    proposal_data["performance_gains"] = performance_gains;
    proposal_data["adaptation_reason"] = "automatic_performance_based_adjustment";
    
    std::string proposal_id = createProposal(
        ProposalType::RULE_WEIGHT_ADJUSTMENT,
        "Automatic Rule Weight Adjustment",
        "System-generated proposal for rule weight adaptation based on performance metrics",
        proposal_data,
        "system",
        [this](const json& data) -> bool {
            if (data.contains("new_weights")) {
                auto weights = data["new_weights"].get<std::vector<double>>();
                this->updateRuleWeights(weights);
                return true;
            }
            return false;
        }
    );
    
    // 记录权重适应日志
    json log_data;
    log_data["action"] = "weight_adaptation_proposal_created";
    log_data["proposal_id"] = proposal_id;
    log_data["performance_gains"] = performance_gains;
    logVotingActivity("WEIGHT_ADAPTATION", log_data);
}

void DAOVotingManager::updateRuleWeights(const std::vector<double>& new_weights) {
    if (new_weights.size() == current_rule_weights_.size()) {
        current_rule_weights_ = new_weights;
        
        // 记录权重更新日志
        json log_data;
        log_data["action"] = "rule_weights_updated";
        log_data["new_weights"] = new_weights;
        log_data["timestamp"] = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
        logVotingActivity("WEIGHT_UPDATE", log_data);
    }
}

std::vector<double> DAOVotingManager::getCurrentRuleWeights() const {
    return current_rule_weights_;
}

void DAOVotingManager::updateGovernanceMetrics(const GovernanceMetrics& metrics) {
    governance_metrics_ = metrics;
    governance_metrics_.last_updated = std::chrono::system_clock::now();
}

DAOVotingManager::GovernanceMetrics DAOVotingManager::getGovernanceMetrics() const {
    return governance_metrics_;
}

double DAOVotingManager::calculateSystemHealthScore() const {
    // 综合系统健康评分
    double health_score = 0.0;
    health_score += governance_metrics_.system_performance_score * 0.3;
    health_score += governance_metrics_.network_stability_index * 0.25;
    health_score += governance_metrics_.trust_consensus_level * 0.2;
    health_score += governance_metrics_.resource_utilization_efficiency * 0.15;
    health_score += governance_metrics_.decision_quality_score * 0.1;
    
    return std::max(0.0, std::min(1.0, health_score));
}

void DAOVotingManager::onBlockCreated(int block_height, const std::string& block_hash) {
    current_block_height_ = block_height;
    latest_block_hash_ = block_hash;
    
    // 每100个区块执行一次治理更新
    if (block_height % 100 == 0) {
        updateProposalStatus();
        
        // 触发权重自适应检查
        if (block_height % 500 == 0) { // 每500个区块进行一次权重适应
            // 模拟性能增益计算
            std::vector<double> performance_gains(current_rule_weights_.size());
            std::random_device rd;
            std::mt19937 gen(rd());
            std::normal_distribution<> dis(0.0, 0.1);
            
            for (auto& gain : performance_gains) {
                gain = dis(gen);
            }
            
            performWeightAdaptation(performance_gains);
        }
    }
}

void DAOVotingManager::syncWithBlockchain() {
    // 区块链同步逻辑
    // 这里可以实现与实际区块链的同步
}

json DAOVotingManager::exportProposalToBlockchain(const std::string& proposal_id) const {
    auto it = proposals_.find(proposal_id);
    if (it == proposals_.end()) {
        return json{};
    }
    
    const Proposal& proposal = it->second;
    json blockchain_data;
    blockchain_data["proposal_id"] = proposal.proposal_id;
    blockchain_data["type"] = static_cast<int>(proposal.type);
    blockchain_data["title"] = proposal.title;
    blockchain_data["description"] = proposal.description;
    blockchain_data["proposal_data"] = proposal.proposal_data;
    blockchain_data["proposer_id"] = proposal.proposer_id;
    blockchain_data["created_time"] = std::chrono::duration_cast<std::chrono::seconds>(
        proposal.created_time.time_since_epoch()).count();
    blockchain_data["voting_deadline"] = std::chrono::duration_cast<std::chrono::seconds>(
        proposal.voting_deadline.time_since_epoch()).count();
    blockchain_data["status"] = static_cast<int>(proposal.status);
    blockchain_data["yes_votes"] = proposal.yes_votes;
    blockchain_data["no_votes"] = proposal.no_votes;
    blockchain_data["abstain_votes"] = proposal.abstain_votes;
    blockchain_data["total_voters"] = proposal.total_voters;
    
    return blockchain_data;
}

bool DAOVotingManager::importProposalFromBlockchain(const json& blockchain_data) {
    try {
        Proposal proposal;
        proposal.proposal_id = blockchain_data["proposal_id"];
        proposal.type = static_cast<ProposalType>(blockchain_data["type"].get<int>());
        proposal.title = blockchain_data["title"];
        proposal.description = blockchain_data["description"];
        proposal.proposal_data = blockchain_data["proposal_data"];
        proposal.proposer_id = blockchain_data["proposer_id"];
        
        auto created_seconds = blockchain_data["created_time"].get<int64_t>();
        proposal.created_time = std::chrono::system_clock::from_time_t(created_seconds);
        
        auto deadline_seconds = blockchain_data["voting_deadline"].get<int64_t>();
        proposal.voting_deadline = std::chrono::system_clock::from_time_t(deadline_seconds);
        
        proposal.status = static_cast<ProposalStatus>(blockchain_data["status"].get<int>());
        proposal.yes_votes = blockchain_data["yes_votes"];
        proposal.no_votes = blockchain_data["no_votes"];
        proposal.abstain_votes = blockchain_data["abstain_votes"];
        proposal.total_voters = blockchain_data["total_voters"];
        
        proposals_[proposal.proposal_id] = proposal;
        return true;
    } catch (const std::exception& e) {
        return false;
    }
}

json DAOVotingManager::getVotingStatistics() const {
    json stats;
    
    // 基本统计
    stats["total_voters"] = voters_.size();
    stats["active_voters"] = getActiveVoters().size();
    stats["total_proposals"] = proposals_.size();
    stats["active_proposals"] = getActiveProposals().size();
    stats["total_votes"] = vote_history_.size();
    
    // 提案类型统计
    std::map<ProposalType, int> type_counts;
    for (const auto& proposal_pair : proposals_) {
        type_counts[proposal_pair.second.type]++;
    }
    
    json type_stats;
    for (const auto& type_pair : type_counts) {
        type_stats[std::to_string(static_cast<int>(type_pair.first))] = type_pair.second;
    }
    stats["proposal_types"] = type_stats;
    
    // 投票参与率
    if (!voters_.empty()) {
        int total_participations = 0;
        for (const auto& voter_pair : voters_) {
            total_participations += voter_pair.second.participation_count;
        }
        stats["average_participation_rate"] = static_cast<double>(total_participations) / voters_.size();
    }
    
    return stats;
}

json DAOVotingManager::getParticipationAnalysis() const {
    json analysis;
    
    // 投票者活跃度分析
    std::vector<double> participation_rates;
    for (const auto& voter_pair : voters_) {
        if (voter_pair.second.is_active) {
            participation_rates.push_back(static_cast<double>(voter_pair.second.participation_count));
        }
    }
    
    if (!participation_rates.empty()) {
        double sum = std::accumulate(participation_rates.begin(), participation_rates.end(), 0.0);
        analysis["average_participation"] = sum / participation_rates.size();
        
        auto minmax = std::minmax_element(participation_rates.begin(), participation_rates.end());
        analysis["min_participation"] = *minmax.first;
        analysis["max_participation"] = *minmax.second;
    }
    
    return analysis;
}

json DAOVotingManager::getDecisionQualityMetrics() const {
    json metrics;
    
    // 决策质量指标
    metrics["system_health_score"] = calculateSystemHealthScore();
    metrics["governance_metrics"] = {
        {"system_performance_score", governance_metrics_.system_performance_score},
        {"network_stability_index", governance_metrics_.network_stability_index},
        {"trust_consensus_level", governance_metrics_.trust_consensus_level},
        {"resource_utilization_efficiency", governance_metrics_.resource_utilization_efficiency},
        {"decision_quality_score", governance_metrics_.decision_quality_score}
    };
    
    return metrics;
}

void DAOVotingManager::setProposalCreatedCallback(std::function<void(const Proposal&)> callback) {
    proposal_created_callback_ = callback;
}

void DAOVotingManager::setVoteCastCallback(std::function<void(const VoteRecord&)> callback) {
    vote_cast_callback_ = callback;
}

void DAOVotingManager::setProposalExecutedCallback(std::function<void(const Proposal&)> callback) {
    proposal_executed_callback_ = callback;
}

// 私有方法实现

double DAOVotingManager::calculateVotingPower(const Voter& voter) const {
    // 综合计算投票权重：信誉 + 质押 + 参与度
    double reputation_component = voter.reputation_score * consensus_config_.reputation_weight;
    double stake_component = std::sqrt(voter.stake_amount) * consensus_config_.stake_weight; // 平方根避免过度集中
    double participation_component = std::min(1.0, voter.historical_accuracy) * consensus_config_.participation_weight;
    
    double total_power = reputation_component + stake_component + participation_component;
    return std::max(0.1, std::min(10.0, total_power)); // 限制在合理范围内
}

bool DAOVotingManager::isVoterEligible(const std::string& voter_id, const std::string& proposal_id) const {
    auto voter_it = voters_.find(voter_id);
    if (voter_it == voters_.end() || !voter_it->second.is_active) {
        return false;
    }
    
    // 检查最低信誉要求
    if (voter_it->second.reputation_score < 0.1) {
        return false;
    }
    
    return true;
}

void DAOVotingManager::cleanupExpiredProposals() {
    auto now = std::chrono::system_clock::now();
    auto it = proposals_.begin();
    
    while (it != proposals_.end()) {
        // 删除超过30天的已完成提案
        if ((it->second.status == ProposalStatus::EXECUTED || 
             it->second.status == ProposalStatus::REJECTED ||
             it->second.status == ProposalStatus::EXPIRED) &&
            (now - it->second.created_time) > std::chrono::hours(24 * 30)) {
            it = proposals_.erase(it);
        } else {
            ++it;
        }
    }
}

void DAOVotingManager::updateVoterParticipationStats(const std::string& voter_id) {
    auto it = voters_.find(voter_id);
    if (it != voters_.end()) {
        it->second.participation_count++;
        it->second.last_active = std::chrono::system_clock::now();
        
        // 更新历史准确率（简化实现）
        // 这里可以根据实际的投票结果来计算准确率
        it->second.historical_accuracy = std::min(1.0, it->second.historical_accuracy + 0.01);
    }
}

std::string DAOVotingManager::generateProposalId() const {
    auto now = std::chrono::system_clock::now();
    auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
    
    std::stringstream ss;
    ss << "proposal_" << timestamp << "_" << (proposals_.size() + 1);
    return ss.str();
}

void DAOVotingManager::logVotingActivity(const std::string& activity, const json& details) {
    // 简化的日志记录实现
    // 在实际应用中，这里可以写入文件或数据库
    json log_entry;
    log_entry["timestamp"] = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    log_entry["activity"] = activity;
    log_entry["details"] = details;
    log_entry["block_height"] = current_block_height_;
    
    // 这里可以添加实际的日志存储逻辑
}

double DAOVotingManager::calculateQuadraticVotingPower(double base_power, double stake) const {
    // 二次投票：投票权重与质押金额的平方根成正比
    return base_power * std::sqrt(stake + 1.0);
}

void DAOVotingManager::processDelegatedVotes(const std::string& proposal_id) {
    // 处理委托投票逻辑
    if (!consensus_config_.enable_delegation) {
        return;
    }
    
    // 简化实现：这里可以添加委托投票的具体逻辑
    for (const auto& delegation_pair : delegations_) {
        const std::string& delegator = delegation_pair.first;
        const std::string& delegate = delegation_pair.second;
        // 检查委托者是否已经投票
        bool delegator_voted = false;
        for (const auto& vote : vote_history_) {
            if (vote.proposal_id == proposal_id && vote.voter_id == delegator) {
                delegator_voted = true;
                break;
            }
        }
        
        // 如果委托者没有投票，使用委托人的投票
        if (!delegator_voted) {
            // 查找委托人的投票
            for (const auto& vote : vote_history_) {
                if (vote.proposal_id == proposal_id && vote.voter_id == delegate) {
                    // 创建委托投票记录
                    // 这里可以添加具体的委托投票逻辑
                    break;
                }
            }
        }
    }
}

bool DAOVotingManager::validateProposalData(ProposalType type, const json& data) const {
    switch (type) {
        case ProposalType::RULE_WEIGHT_ADJUSTMENT:
            return data.contains("new_weights") && data["new_weights"].is_array();
        case ProposalType::PARAMETER_UPDATE:
            return data.contains("parameters") && data["parameters"].is_object();
        case ProposalType::GOVERNANCE_CHANGE:
            return data.contains("governance_changes") && data["governance_changes"].is_object();
        case ProposalType::EMERGENCY_ACTION:
            return data.contains("emergency_action") && data["emergency_action"].is_object();
        case ProposalType::SYSTEM_UPGRADE:
            return data.contains("upgrade_details") && data["upgrade_details"].is_object();
        default:
            return false;
    }
}

void DAOVotingManager::saveState() const {
    // 状态持久化实现
    json state;
    state["voters"] = json::object();
    state["proposals"] = json::object();
    state["vote_history"] = json::array();
    state["current_rule_weights"] = current_rule_weights_;
    state["governance_metrics"] = {
        {"system_performance_score", governance_metrics_.system_performance_score},
        {"network_stability_index", governance_metrics_.network_stability_index},
        {"trust_consensus_level", governance_metrics_.trust_consensus_level},
        {"resource_utilization_efficiency", governance_metrics_.resource_utilization_efficiency},
        {"decision_quality_score", governance_metrics_.decision_quality_score}
    };
    
    // 这里可以将state保存到文件
}

void DAOVotingManager::loadState() {
    // 状态加载实现
    // 这里可以从文件加载state
}
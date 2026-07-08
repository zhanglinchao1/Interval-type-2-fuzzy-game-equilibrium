#include "BlockchainGovernanceContract.h"
#include <algorithm>
#include <random>
#include <sstream>
#include <iomanip>
#include <fstream>
#include <openssl/sha.h>
#include <openssl/evp.h>

BlockchainGovernanceContract::BlockchainGovernanceContract() 
    : is_initialized_(false), contract_address_("0x" + generateTransactionId()) {
    // 初始化默认共识参数
    consensus_params_.block_time_seconds = 10;
    consensus_params_.confirmation_blocks = 6;
    consensus_params_.min_stake_amount = 1000.0;
    consensus_params_.validator_reward = 10.0;
    consensus_params_.governance_fee_rate = 0.01;
    consensus_params_.max_transactions_per_block = 100;
    consensus_params_.slashing_penalty_rate = 0.1;
}

BlockchainGovernanceContract::BlockchainGovernanceContract(const json& config) 
    : BlockchainGovernanceContract() {
    loadConfig(config);
}

void BlockchainGovernanceContract::initialize(const json& genesis_config) {
    if (is_initialized_) {
        return;
    }
    
    // 加载创世配置
    if (genesis_config.contains("consensus_parameters")) {
        auto& params = genesis_config["consensus_parameters"];
        consensus_params_.block_time_seconds = params.value("block_time_seconds", 10);
        consensus_params_.confirmation_blocks = params.value("confirmation_blocks", 6);
        consensus_params_.min_stake_amount = params.value("min_stake_amount", 1000.0);
        consensus_params_.validator_reward = params.value("validator_reward", 10.0);
        consensus_params_.governance_fee_rate = params.value("governance_fee_rate", 0.01);
        consensus_params_.max_transactions_per_block = params.value("max_transactions_per_block", 100);
        consensus_params_.slashing_penalty_rate = params.value("slashing_penalty_rate", 0.1);
    }
    
    // 创建创世区块
    createGenesisBlock();
    
    // 初始化治理状态
    governance_state_.total_staked = 0.0;
    governance_state_.total_validators = 0;
    governance_state_.last_update = std::chrono::system_clock::now();
    
    // 创建初始验证者账户
    if (genesis_config.contains("initial_validators")) {
        for (const auto& validator : genesis_config["initial_validators"]) {
            std::string address = validator["address"];
            double initial_balance = validator.value("balance", 10000.0);
            double stake_amount = validator.value("stake", 1000.0);
            
            createAccount(address, initial_balance);
            stakeTokens(address, stake_amount);
            active_validators_.push_back(address);
        }
    }
    
    is_initialized_ = true;
    
    // 发出初始化事件
    emitEvent("ContractInitialized", {
        {"contract_address", contract_address_},
        {"genesis_block_hash", blockchain_[0].hash},
        {"initial_validators", active_validators_.size()}
    });
}

void BlockchainGovernanceContract::loadConfig(const json& config) {
    config_ = config;
    
    if (config.contains("blockchain_governance")) {
        auto& gov_config = config["blockchain_governance"];
        
        // 加载共识参数
        if (gov_config.contains("consensus")) {
            auto& consensus = gov_config["consensus"];
            consensus_params_.block_time_seconds = consensus.value("block_time_seconds", 10);
            consensus_params_.confirmation_blocks = consensus.value("confirmation_blocks", 6);
            consensus_params_.min_stake_amount = consensus.value("min_stake_amount", 1000.0);
            consensus_params_.validator_reward = consensus.value("validator_reward", 10.0);
            consensus_params_.governance_fee_rate = consensus.value("governance_fee_rate", 0.01);
            consensus_params_.max_transactions_per_block = consensus.value("max_transactions_per_block", 100);
            consensus_params_.slashing_penalty_rate = consensus.value("slashing_penalty_rate", 0.1);
        }
        
        // 加载对等节点
        if (gov_config.contains("peer_nodes")) {
            peer_nodes_ = gov_config["peer_nodes"].get<std::vector<std::string>>();
        }
    }
}

json BlockchainGovernanceContract::getConfig() const {
    return config_;
}

bool BlockchainGovernanceContract::createGenesisBlock() {
    Block genesis_block;
    genesis_block.height = 0;
    genesis_block.previous_hash = "0x0000000000000000000000000000000000000000000000000000000000000000";
    genesis_block.timestamp = std::chrono::system_clock::now();
    genesis_block.nonce = 0;
    
    // 创世区块治理数据
    genesis_block.governance_data = {
        {"type", "genesis"},
        {"contract_address", contract_address_},
        {"initial_supply", 1000000.0},
        {"governance_enabled", true}
    };
    
    genesis_block.merkle_root = calculateMerkleRoot(genesis_block.transactions);
    genesis_block.hash = calculateBlockHash(genesis_block);
    
    blockchain_.push_back(genesis_block);
    
    return true;
}

std::string BlockchainGovernanceContract::mineBlock(const std::vector<Transaction>& transactions) {
    if (transactions.size() > static_cast<size_t>(consensus_params_.max_transactions_per_block)) {
        return "";
    }
    
    Block new_block;
    new_block.height = blockchain_.size();
    new_block.previous_hash = getLatestBlock().hash;
    new_block.timestamp = std::chrono::system_clock::now();
    
    // 添加交易
    for (const auto& tx : transactions) {
        new_block.transactions.push_back(tx.tx_id);
    }
    
    // 计算默克尔根
    new_block.merkle_root = calculateMerkleRoot(new_block.transactions);
    
    // 简化的工作量证明（实际应该是权益证明）
    new_block.nonce = 0;
    std::string target = "0000"; // 简化的难度目标
    
    do {
        new_block.nonce++;
        new_block.hash = calculateBlockHash(new_block);
    } while (new_block.hash.substr(0, 4) != target && new_block.nonce < 1000000);
    
    // 验证区块
    if (validateBlock(new_block)) {
        blockchain_.push_back(new_block);
        
        // 处理区块中的治理交易
        for (const auto& tx : transactions) {
            processGovernanceTransaction(tx);
        }
        
        // 分发奖励
        distributeRewards(new_block.height);
        
        // 发出区块挖掘事件
        emitEvent("BlockMined", {
            {"block_height", new_block.height},
            {"block_hash", new_block.hash},
            {"transaction_count", new_block.transactions.size()},
            {"miner", selectBlockProducer()}
        });
        
        return new_block.hash;
    }
    
    return "";
}

bool BlockchainGovernanceContract::addBlock(const Block& block) {
    if (!validateBlock(block)) {
        return false;
    }
    
    blockchain_.push_back(block);
    
    // 更新治理状态
    if (block.governance_data.contains("rule_weights")) {
        governance_state_.rule_weights = block.governance_data["rule_weights"].get<std::vector<double>>();
        governance_state_.last_update = block.timestamp;
    }
    
    return true;
}

BlockchainGovernanceContract::Block BlockchainGovernanceContract::getBlock(int height) const {
    if (height >= 0 && height < static_cast<int>(blockchain_.size())) {
        return blockchain_[height];
    }
    return Block{};
}

BlockchainGovernanceContract::Block BlockchainGovernanceContract::getLatestBlock() const {
    if (!blockchain_.empty()) {
        return blockchain_.back();
    }
    return Block{};
}

std::vector<BlockchainGovernanceContract::Block> BlockchainGovernanceContract::getBlockRange(
    int start_height, int end_height) const {
    std::vector<Block> blocks;
    
    int start = std::max(0, start_height);
    int end = std::min(static_cast<int>(blockchain_.size()) - 1, end_height);
    
    for (int i = start; i <= end; ++i) {
        blocks.push_back(blockchain_[i]);
    }
    
    return blocks;
}

std::string BlockchainGovernanceContract::submitTransaction(const Transaction& tx) {
    if (!validateTransaction(tx)) {
        return "";
    }
    
    // 添加到交易池
    transaction_pool_[tx.tx_id] = tx;
    pending_transactions_.push(tx);
    
    // 更新统计
    transaction_counts_["total"]++;
    gas_usage_["total"] += tx.gas_fee;
    
    // 发出交易提交事件
    emitEvent("TransactionSubmitted", {
        {"tx_id", tx.tx_id},
        {"type", static_cast<int>(tx.type)},
        {"from", tx.from_address},
        {"gas_fee", tx.gas_fee}
    });
    
    return tx.tx_id;
}

bool BlockchainGovernanceContract::validateTransaction(const Transaction& tx) const {
    // 基本验证
    if (tx.tx_id.empty() || tx.from_address.empty()) {
        return false;
    }
    
    // 检查账户是否存在
    if (accounts_.find(tx.from_address) == accounts_.end()) {
        return false;
    }
    
    // 检查余额是否足够支付Gas费
    const auto& account = accounts_.at(tx.from_address);
    if (account.balance < tx.gas_fee) {
        return false;
    }
    
    // 检查重放攻击
    if (checkReplayAttack(tx)) {
        return false;
    }
    
    // 检查双花
    if (checkDoubleSpending(tx)) {
        return false;
    }
    
    return true;
}

std::vector<BlockchainGovernanceContract::Transaction> 
BlockchainGovernanceContract::getPendingTransactions() const {
    std::vector<Transaction> pending;
    std::queue<Transaction> temp_queue = pending_transactions_;
    
    while (!temp_queue.empty()) {
        pending.push_back(temp_queue.front());
        temp_queue.pop();
    }
    
    return pending;
}

BlockchainGovernanceContract::Transaction 
BlockchainGovernanceContract::getTransaction(const std::string& tx_id) const {
    auto it = transaction_pool_.find(tx_id);
    if (it != transaction_pool_.end()) {
        return it->second;
    }
    return Transaction{};
}

bool BlockchainGovernanceContract::confirmTransaction(const std::string& tx_id) {
    auto it = transaction_pool_.find(tx_id);
    if (it != transaction_pool_.end()) {
        it->second.is_confirmed = true;
        
        // 发出交易确认事件
        emitEvent("TransactionConfirmed", {
            {"tx_id", tx_id},
            {"confirmation_time", std::chrono::duration_cast<std::chrono::seconds>(
                std::chrono::system_clock::now().time_since_epoch()).count()}
        });
        
        return true;
    }
    return false;
}

bool BlockchainGovernanceContract::createAccount(const std::string& address, double initial_balance) {
    if (accounts_.find(address) != accounts_.end()) {
        return false; // 账户已存在
    }
    
    AccountState new_account;
    new_account.address = address;
    new_account.balance = initial_balance;
    new_account.staked_amount = 0.0;
    new_account.reputation_score = 100.0; // 默认信誉分数
    new_account.nonce = 0;
    
    accounts_[address] = new_account;
    
    // 发出账户创建事件
    emitEvent("AccountCreated", {
        {"address", address},
        {"initial_balance", initial_balance}
    });
    
    return true;
}

BlockchainGovernanceContract::AccountState 
BlockchainGovernanceContract::getAccountState(const std::string& address) const {
    auto it = accounts_.find(address);
    if (it != accounts_.end()) {
        return it->second;
    }
    return AccountState{};
}

bool BlockchainGovernanceContract::updateAccountBalance(const std::string& address, double amount) {
    auto it = accounts_.find(address);
    if (it != accounts_.end()) {
        it->second.balance += amount;
        return true;
    }
    return false;
}

bool BlockchainGovernanceContract::stakeTokens(const std::string& address, double amount) {
    auto it = accounts_.find(address);
    if (it != accounts_.end() && it->second.balance >= amount && amount >= consensus_params_.min_stake_amount) {
        it->second.balance -= amount;
        it->second.staked_amount += amount;
        
        validator_stakes_[address] += amount;
        governance_state_.total_staked += amount;
        
        // 如果质押足够，添加为验证者
        if (it->second.staked_amount >= consensus_params_.min_stake_amount) {
            if (std::find(active_validators_.begin(), active_validators_.end(), address) == active_validators_.end()) {
                active_validators_.push_back(address);
                governance_state_.total_validators++;
            }
        }
        
        // 发出质押事件
        emitEvent("TokensStaked", {
            {"address", address},
            {"amount", amount},
            {"total_staked", it->second.staked_amount}
        });
        
        return true;
    }
    return false;
}

bool BlockchainGovernanceContract::unstakeTokens(const std::string& address, double amount) {
    auto it = accounts_.find(address);
    if (it != accounts_.end() && it->second.staked_amount >= amount) {
        it->second.staked_amount -= amount;
        it->second.balance += amount;
        
        validator_stakes_[address] -= amount;
        governance_state_.total_staked -= amount;
        
        // 如果质押不足，移除验证者身份
        if (it->second.staked_amount < consensus_params_.min_stake_amount) {
            auto validator_it = std::find(active_validators_.begin(), active_validators_.end(), address);
            if (validator_it != active_validators_.end()) {
                active_validators_.erase(validator_it);
                governance_state_.total_validators--;
            }
        }
        
        // 发出解质押事件
        emitEvent("TokensUnstaked", {
            {"address", address},
            {"amount", amount},
            {"remaining_staked", it->second.staked_amount}
        });
        
        return true;
    }
    return false;
}

bool BlockchainGovernanceContract::updateReputation(const std::string& address, double new_reputation) {
    auto it = accounts_.find(address);
    if (it != accounts_.end()) {
        double old_reputation = it->second.reputation_score;
        it->second.reputation_score = std::max(0.0, std::min(1000.0, new_reputation));
        
        // 发出信誉更新事件
        emitEvent("ReputationUpdated", {
            {"address", address},
            {"old_reputation", old_reputation},
            {"new_reputation", it->second.reputation_score}
        });
        
        return true;
    }
    return false;
}

std::string BlockchainGovernanceContract::createProposalOnChain(const json& proposal_data, 
                                                               const std::string& proposer) {
    std::string proposal_id = "prop_" + generateTransactionId();
    
    // 创建提案交易
    Transaction proposal_tx;
    proposal_tx.tx_id = "tx_" + generateTransactionId();
    proposal_tx.type = TransactionType::PROPOSAL_CREATION;
    proposal_tx.from_address = proposer;
    proposal_tx.to_address = contract_address_;
    proposal_tx.data = {
        {"proposal_id", proposal_id},
        {"proposal_data", proposal_data},
        {"creation_time", std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count()}
    };
    proposal_tx.gas_fee = 100.0; // 提案创建费用
    proposal_tx.timestamp = std::chrono::system_clock::now();
    proposal_tx.is_confirmed = false;
    
    // 提交交易
    if (submitTransaction(proposal_tx).empty()) {
        return "";
    }
    
    // 添加到活跃提案
    governance_state_.active_proposals[proposal_id] = {
        {"id", proposal_id},
        {"proposer", proposer},
        {"data", proposal_data},
        {"votes_for", 0.0},
        {"votes_against", 0.0},
        {"votes_abstain", 0.0},
        {"status", "active"},
        {"creation_time", std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count()},
        {"voting_deadline", std::chrono::duration_cast<std::chrono::seconds>(
            (std::chrono::system_clock::now() + std::chrono::hours(24)).time_since_epoch()).count()}
    };
    
    // 发出提案创建事件
    emitEvent("ProposalCreated", {
        {"proposal_id", proposal_id},
        {"proposer", proposer},
        {"proposal_type", proposal_data.value("type", "general")}
    });
    
    return proposal_id;
}

bool BlockchainGovernanceContract::castVoteOnChain(const std::string& proposal_id, 
                                                  const std::string& voter, 
                                                  int vote_option, 
                                                  double voting_power) {
    // 检查提案是否存在
    if (governance_state_.active_proposals.find(proposal_id) == governance_state_.active_proposals.end()) {
        return false;
    }
    
    // 检查投票者是否有效
    if (!isValidValidator(voter)) {
        return false;
    }
    
    // 计算投票权重
    double actual_voting_power = std::min(voting_power, calculateVotingPower(voter));
    
    // 创建投票交易
    Transaction vote_tx;
    vote_tx.tx_id = "tx_" + generateTransactionId();
    vote_tx.type = TransactionType::VOTE_CAST;
    vote_tx.from_address = voter;
    vote_tx.to_address = contract_address_;
    vote_tx.data = {
        {"proposal_id", proposal_id},
        {"vote_option", vote_option}, // 0: 反对, 1: 赞成, 2: 弃权
        {"voting_power", actual_voting_power},
        {"vote_time", std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count()}
    };
    vote_tx.gas_fee = 10.0; // 投票费用
    vote_tx.timestamp = std::chrono::system_clock::now();
    vote_tx.is_confirmed = false;
    
    // 提交交易
    if (submitTransaction(vote_tx).empty()) {
        return false;
    }
    
    // 更新提案投票统计
    auto& proposal = governance_state_.active_proposals[proposal_id];
    switch (vote_option) {
        case 0: // 反对
            proposal["votes_against"] = proposal["votes_against"].get<double>() + actual_voting_power;
            break;
        case 1: // 赞成
            proposal["votes_for"] = proposal["votes_for"].get<double>() + actual_voting_power;
            break;
        case 2: // 弃权
            proposal["votes_abstain"] = proposal["votes_abstain"].get<double>() + actual_voting_power;
            break;
        default:
            return false;
    }
    
    // 发出投票事件
    emitEvent("VoteCast", {
        {"proposal_id", proposal_id},
        {"voter", voter},
        {"vote_option", vote_option},
        {"voting_power", actual_voting_power}
    });
    
    // 检查是否达成共识
    if (reachConsensus(proposal_id)) {
        executeProposalOnChain(proposal_id);
    }
    
    return true;
}

bool BlockchainGovernanceContract::executeProposalOnChain(const std::string& proposal_id) {
    auto it = governance_state_.active_proposals.find(proposal_id);
    if (it == governance_state_.active_proposals.end()) {
        return false;
    }
    
    auto& proposal = it->second;
    
    // 检查是否达成共识
    if (!reachConsensus(proposal_id)) {
        return false;
    }
    
    // 创建执行交易
    Transaction execution_tx;
    execution_tx.tx_id = "tx_" + generateTransactionId();
    execution_tx.type = TransactionType::PROPOSAL_EXECUTION;
    execution_tx.from_address = contract_address_;
    execution_tx.to_address = contract_address_;
    execution_tx.data = {
        {"proposal_id", proposal_id},
        {"execution_time", std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count()}
    };
    execution_tx.gas_fee = 0.0; // 系统执行，无需费用
    execution_tx.timestamp = std::chrono::system_clock::now();
    execution_tx.is_confirmed = true;
    
    // 执行提案内容
    if (proposal["data"].contains("rule_weights")) {
        governance_state_.rule_weights = proposal["data"]["rule_weights"].get<std::vector<double>>();
    }
    
    if (proposal["data"].contains("system_parameters")) {
        governance_state_.system_parameters.update(proposal["data"]["system_parameters"]);
    }
    
    // 更新提案状态
    proposal["status"] = "executed";
    proposal["execution_time"] = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    
    // 移动到已执行提案
    governance_state_.executed_proposals[proposal_id] = proposal;
    governance_state_.active_proposals.erase(it);
    
    // 更新治理状态时间戳
    governance_state_.last_update = std::chrono::system_clock::now();
    
    // 提交执行交易
    submitTransaction(execution_tx);
    
    // 发出提案执行事件
    emitEvent("ProposalExecuted", {
        {"proposal_id", proposal_id},
        {"execution_result", "success"}
    });
    
    return true;
}

json BlockchainGovernanceContract::getProposalState(const std::string& proposal_id) const {
    // 先检查活跃提案
    auto active_it = governance_state_.active_proposals.find(proposal_id);
    if (active_it != governance_state_.active_proposals.end()) {
        return active_it->second;
    }
    
    // 再检查已执行提案
    auto executed_it = governance_state_.executed_proposals.find(proposal_id);
    if (executed_it != governance_state_.executed_proposals.end()) {
        return executed_it->second;
    }
    
    return json{};
}

std::vector<json> BlockchainGovernanceContract::getActiveProposalsOnChain() const {
    std::vector<json> proposals;
    for (const auto& pair : governance_state_.active_proposals) {
        proposals.push_back(pair.second);
    }
    return proposals;
}

bool BlockchainGovernanceContract::validateBlock(const Block& block) const {
    // 基本验证
    if (block.height != static_cast<int>(blockchain_.size())) {
        return false;
    }
    
    if (!blockchain_.empty() && block.previous_hash != getLatestBlock().hash) {
        return false;
    }
    
    // 验证默克尔根
    if (block.merkle_root != calculateMerkleRoot(block.transactions)) {
        return false;
    }
    
    // 验证区块哈希
    if (block.hash != calculateBlockHash(block)) {
        return false;
    }
    
    // 验证权益证明
    if (!validateProofOfStake(block)) {
        return false;
    }
    
    return true;
}

bool BlockchainGovernanceContract::reachConsensus(const std::string& proposal_id) const {
    auto it = governance_state_.active_proposals.find(proposal_id);
    if (it == governance_state_.active_proposals.end()) {
        return false;
    }
    
    const auto& proposal = it->second;
    double votes_for = proposal["votes_for"].get<double>();
    double votes_against = proposal["votes_against"].get<double>();
    double votes_abstain = proposal["votes_abstain"].get<double>();
    
    double total_votes = votes_for + votes_against + votes_abstain;
    double total_stake = governance_state_.total_staked;
    
    // 检查参与率（至少50%的质押参与投票）
    if (total_votes < total_stake * 0.5) {
        return false;
    }
    
    // 检查赞成票是否超过2/3
    if (votes_for > total_votes * 0.67) {
        return true;
    }
    
    return false;
}

double BlockchainGovernanceContract::calculateVotingPower(const std::string& address) const {
    auto account_it = accounts_.find(address);
    if (account_it == accounts_.end()) {
        return 0.0;
    }
    
    const auto& account = account_it->second;
    
    // 基于质押金额和信誉分数计算投票权重
    double stake_weight = account.staked_amount;
    double reputation_weight = account.reputation_score / 100.0; // 归一化到0-10
    
    return stake_weight * reputation_weight;
}

bool BlockchainGovernanceContract::isValidValidator(const std::string& address) const {
    return std::find(active_validators_.begin(), active_validators_.end(), address) != active_validators_.end();
}

std::vector<std::string> BlockchainGovernanceContract::selectValidators() const {
    return active_validators_;
}

void BlockchainGovernanceContract::distributeRewards(int block_height) {
    if (active_validators_.empty()) {
        return;
    }
    
    double total_reward = consensus_params_.validator_reward;
    double reward_per_validator = total_reward / active_validators_.size();
    
    for (const auto& validator : active_validators_) {
        pending_rewards_[validator] += reward_per_validator;
        updateAccountBalance(validator, reward_per_validator);
    }
    
    // 发出奖励分发事件
    emitEvent("RewardsDistributed", {
        {"block_height", block_height},
        {"total_reward", total_reward},
        {"validator_count", active_validators_.size()}
    });
}

void BlockchainGovernanceContract::applySlashing(const std::string& address, const std::string& reason) {
    auto it = accounts_.find(address);
    if (it != accounts_.end()) {
        double penalty = it->second.staked_amount * consensus_params_.slashing_penalty_rate;
        
        it->second.staked_amount -= penalty;
        governance_state_.total_staked -= penalty;
        
        // 降低信誉分数
        it->second.reputation_score *= 0.9;
        
        // 记录恶意行为
        malicious_behavior_count_[address]++;
        
        // 如果恶意行为过多，加入黑名单
        if (malicious_behavior_count_[address] >= 3) {
            blacklisted_addresses_.push_back(address);
            
            // 移除验证者身份
            auto validator_it = std::find(active_validators_.begin(), active_validators_.end(), address);
            if (validator_it != active_validators_.end()) {
                active_validators_.erase(validator_it);
                governance_state_.total_validators--;
            }
        }
        
        // 发出惩罚事件
        emitEvent("SlashingApplied", {
            {"address", address},
            {"reason", reason},
            {"penalty_amount", penalty},
            {"remaining_stake", it->second.staked_amount}
        });
    }
}

double BlockchainGovernanceContract::calculateReward(const std::string& address, int block_height) const {
    auto it = pending_rewards_.find(address);
    if (it != pending_rewards_.end()) {
        return it->second;
    }
    return 0.0;
}

void BlockchainGovernanceContract::updateValidatorSet() {
    // 重新评估验证者集合
    active_validators_.clear();
    governance_state_.total_validators = 0;
    
    for (const auto& pair : accounts_) {
        const std::string& address = pair.first;
        const auto& account = pair.second;
        if (account.staked_amount >= consensus_params_.min_stake_amount && 
            account.reputation_score >= 50.0 && // 最低信誉要求
            std::find(blacklisted_addresses_.begin(), blacklisted_addresses_.end(), address) == blacklisted_addresses_.end()) {
            active_validators_.push_back(address);
            governance_state_.total_validators++;
        }
    }
    
    // 发出验证者集合更新事件
    emitEvent("ValidatorSetUpdated", {
        {"new_validator_count", governance_state_.total_validators},
        {"active_validators", active_validators_}
    });
}

BlockchainGovernanceContract::GovernanceState BlockchainGovernanceContract::getGovernanceState() const {
    return governance_state_;
}

json BlockchainGovernanceContract::getSystemMetrics() const {
    return {
        {"blockchain_height", blockchain_.size()},
        {"total_transactions", transaction_counts_.at("total")},
        {"total_gas_used", gas_usage_.at("total")},
        {"active_validators", governance_state_.total_validators},
        {"total_staked", governance_state_.total_staked},
        {"active_proposals", governance_state_.active_proposals.size()},
        {"executed_proposals", governance_state_.executed_proposals.size()},
        {"contract_address", contract_address_}
    };
}

std::vector<BlockchainGovernanceContract::ContractEvent> 
BlockchainGovernanceContract::getEvents(int from_block, int to_block) const {
    std::vector<ContractEvent> filtered_events;
    
    for (const auto& event : event_log_) {
        if (event.block_height >= from_block && event.block_height <= to_block) {
            filtered_events.push_back(event);
        }
    }
    
    return filtered_events;
}

json BlockchainGovernanceContract::getValidatorInfo(const std::string& address) const {
    auto account_it = accounts_.find(address);
    if (account_it == accounts_.end()) {
        return json{};
    }
    
    const auto& account = account_it->second;
    bool is_validator = isValidValidator(address);
    
    return {
        {"address", address},
        {"balance", account.balance},
        {"staked_amount", account.staked_amount},
        {"reputation_score", account.reputation_score},
        {"is_active_validator", is_validator},
        {"voting_power", calculateVotingPower(address)},
        {"pending_rewards", calculateReward(address, blockchain_.size())},
        {"malicious_count", malicious_behavior_count_.count(address) ? malicious_behavior_count_.at(address) : 0}
    };
}

void BlockchainGovernanceContract::emitEvent(const std::string& event_name, const json& event_data) {
    ContractEvent event;
    event.event_name = event_name;
    event.contract_address = contract_address_;
    event.event_data = event_data;
    event.timestamp = std::chrono::system_clock::now();
    event.block_height = blockchain_.size();
    
    event_log_.push_back(event);
    
    // 通知订阅者
    auto subscribers_it = event_subscribers_.find(event_name);
    if (subscribers_it != event_subscribers_.end()) {
        for (const auto& callback : subscribers_it->second) {
            callback(event);
        }
    }
}

void BlockchainGovernanceContract::subscribeToEvent(const std::string& event_name, 
                                                   std::function<void(const ContractEvent&)> callback) {
    event_subscribers_[event_name].push_back(callback);
}

// 私有方法实现
std::string BlockchainGovernanceContract::generateTransactionId() const {
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::uniform_int_distribution<> dis(0, 15);
    
    std::stringstream ss;
    for (int i = 0; i < 64; ++i) {
        ss << std::hex << dis(gen);
    }
    return ss.str();
}

std::string BlockchainGovernanceContract::calculateMerkleRoot(const std::vector<std::string>& transactions) const {
    if (transactions.empty()) {
        return "0x0000000000000000000000000000000000000000000000000000000000000000";
    }
    
    // 简化的默克尔根计算
    std::string combined;
    for (const auto& tx : transactions) {
        combined += tx;
    }
    
    // 使用SHA256计算哈希
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256(reinterpret_cast<const unsigned char*>(combined.c_str()), combined.length(), hash);
    
    std::stringstream ss;
    ss << "0x";
    for (int i = 0; i < SHA256_DIGEST_LENGTH; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hash[i]);
    }
    
    return ss.str();
}

std::string BlockchainGovernanceContract::calculateBlockHash(const Block& block) const {
    std::stringstream ss;
    ss << block.height << block.previous_hash << block.merkle_root << block.nonce;
    ss << std::chrono::duration_cast<std::chrono::seconds>(block.timestamp.time_since_epoch()).count();
    
    std::string block_string = ss.str();
    
    // 使用SHA256计算哈希
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256(reinterpret_cast<const unsigned char*>(block_string.c_str()), block_string.length(), hash);
    
    std::stringstream hash_ss;
    hash_ss << "0x";
    for (int i = 0; i < SHA256_DIGEST_LENGTH; ++i) {
        hash_ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hash[i]);
    }
    
    return hash_ss.str();
}

void BlockchainGovernanceContract::processGovernanceTransaction(const Transaction& tx) {
    switch (tx.type) {
        case TransactionType::PROPOSAL_CREATION:
            // 提案创建已在createProposalOnChain中处理
            break;
            
        case TransactionType::VOTE_CAST:
            // 投票已在castVoteOnChain中处理
            break;
            
        case TransactionType::PROPOSAL_EXECUTION:
            // 提案执行已在executeProposalOnChain中处理
            break;
            
        case TransactionType::STAKE_DEPOSIT:
            if (tx.data.contains("amount")) {
                stakeTokens(tx.from_address, tx.data["amount"].get<double>());
            }
            break;
            
        case TransactionType::STAKE_WITHDRAWAL:
            if (tx.data.contains("amount")) {
                unstakeTokens(tx.from_address, tx.data["amount"].get<double>());
            }
            break;
            
        case TransactionType::REPUTATION_UPDATE:
            if (tx.data.contains("new_reputation")) {
                updateReputation(tx.from_address, tx.data["new_reputation"].get<double>());
            }
            break;
            
        case TransactionType::REWARD_DISTRIBUTION:
            // 奖励分发在distributeRewards中处理
            break;
    }
}

bool BlockchainGovernanceContract::validateProofOfStake(const Block& block) const {
    // 简化的权益证明验证
    // 在实际实现中，这里应该验证区块生产者的质押权重
    return true;
}

std::string BlockchainGovernanceContract::selectBlockProducer() const {
    if (active_validators_.empty()) {
        return "";
    }
    
    // 基于质押权重随机选择区块生产者
    std::vector<double> weights;
    for (const auto& validator : active_validators_) {
        weights.push_back(calculateStakeWeight(validator));
    }
    
    std::random_device rd;
    std::mt19937 gen(rd());
    std::discrete_distribution<> dis(weights.begin(), weights.end());
    
    int selected_index = dis(gen);
    return active_validators_[selected_index];
}

double BlockchainGovernanceContract::calculateStakeWeight(const std::string& address) const {
    auto it = validator_stakes_.find(address);
    if (it != validator_stakes_.end()) {
        return it->second;
    }
    return 0.0;
}

bool BlockchainGovernanceContract::checkDoubleSpending(const Transaction& tx) const {
    // 简化的双花检测
    // 在实际实现中，需要检查UTXO或账户状态
    return false;
}

bool BlockchainGovernanceContract::checkReplayAttack(const Transaction& tx) const {
    // 简化的重放攻击检测
    // 检查交易是否已经存在
    return transaction_pool_.find(tx.tx_id) != transaction_pool_.end();
}

void BlockchainGovernanceContract::detectMaliciousBehavior() {
    // 检测恶意行为的逻辑
    // 例如：双重投票、无效提案等
    for (const auto& pair : malicious_behavior_count_) {
        const std::string& address = pair.first;
        int count = pair.second;
        if (count >= 3) {
            applySlashing(address, "Repeated malicious behavior");
        }
    }
}
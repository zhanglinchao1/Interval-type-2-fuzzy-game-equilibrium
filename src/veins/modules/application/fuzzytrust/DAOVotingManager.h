#ifndef DAO_VOTING_MANAGER_H
#define DAO_VOTING_MANAGER_H

#include <vector>
#include <map>
#include <string>
#include <memory>
#include <chrono>
#include <functional>

#include "json.hpp"

using json = nlohmann::json;

/**
 * @brief 完整的DAO投票机制管理器
 * 
 * 实现去中心化自治组织的投票治理机制，包括：
 * - 提案创建与管理
 * - 投票权重计算
 * - 共识达成机制
 * - 权重自适应更新
 * - 区块链集成接口
 */
class DAOVotingManager {
public:
    // 投票者信息结构
    struct Voter {
        std::string node_id;           // 节点ID
        double reputation_score;       // 信誉分数
        double stake_amount;           // 质押金额
        double voting_power;           // 投票权重
        int participation_count;       // 参与投票次数
        double historical_accuracy;    // 历史投票准确率
        std::chrono::system_clock::time_point last_active; // 最后活跃时间
        bool is_active;               // 是否活跃
    };
    
    // 提案类型枚举
    enum class ProposalType {
        RULE_WEIGHT_ADJUSTMENT,    // 规则权重调整
        PARAMETER_UPDATE,          // 参数更新
        GOVERNANCE_CHANGE,         // 治理规则变更
        EMERGENCY_ACTION,          // 紧急行动
        SYSTEM_UPGRADE            // 系统升级
    };
    
    // 提案状态枚举
    enum class ProposalStatus {
        PENDING,      // 待投票
        ACTIVE,       // 投票中
        PASSED,       // 通过
        REJECTED,     // 拒绝
        EXPIRED,      // 过期
        EXECUTED      // 已执行
    };
    
    // 投票选项枚举
    enum class VoteOption {
        YES,          // 赞成
        NO,           // 反对
        ABSTAIN       // 弃权
    };
    
    // 提案结构
    struct Proposal {
        std::string proposal_id;                    // 提案ID
        ProposalType type;                         // 提案类型
        std::string title;                         // 提案标题
        std::string description;                   // 提案描述
        json proposal_data;                        // 提案具体数据
        std::string proposer_id;                   // 提案者ID
        std::chrono::system_clock::time_point created_time;  // 创建时间
        std::chrono::system_clock::time_point voting_deadline; // 投票截止时间
        ProposalStatus status;                     // 提案状态
        
        // 投票统计
        double yes_votes;                          // 赞成票权重
        double no_votes;                           // 反对票权重
        double abstain_votes;                      // 弃权票权重
        int total_voters;                          // 总投票人数
        
        // 执行回调
        std::function<bool(const json&)> execution_callback; // 执行回调函数
    };
    
    // 投票记录结构
    struct VoteRecord {
        std::string voter_id;                      // 投票者ID
        std::string proposal_id;                   // 提案ID
        VoteOption option;                         // 投票选项
        double voting_power;                       // 投票权重
        std::chrono::system_clock::time_point vote_time; // 投票时间
        std::string reason;                        // 投票理由（可选）
    };
    
    // 共识配置结构
    struct ConsensusConfig {
        double approval_threshold;                 // 通过阈值（0.0-1.0）
        double quorum_threshold;                   // 法定人数阈值（0.0-1.0）
        double super_majority_threshold;           // 超级多数阈值（0.0-1.0）
        int min_voting_period_hours;              // 最小投票期（小时）
        int max_voting_period_hours;              // 最大投票期（小时）
        double reputation_weight;                  // 信誉权重系数
        double stake_weight;                       // 质押权重系数
        double participation_weight;               // 参与度权重系数
        bool enable_quadratic_voting;             // 启用二次投票
        bool enable_delegation;                   // 启用委托投票
    };
    
    // 治理指标结构
    struct GovernanceMetrics {
        double system_performance_score;           // 系统性能分数
        double network_stability_index;           // 网络稳定性指数
        double trust_consensus_level;             // 信任共识水平
        double resource_utilization_efficiency;   // 资源利用效率
        double decision_quality_score;            // 决策质量分数
        std::chrono::system_clock::time_point last_updated; // 最后更新时间
    };

public:
    DAOVotingManager();
    explicit DAOVotingManager(const json& config);
    ~DAOVotingManager() = default;
    
    // 配置管理
    void loadConfig(const json& config);
    json getConfig() const;
    void updateConsensusConfig(const ConsensusConfig& new_config);
    
    // 投票者管理
    bool registerVoter(const Voter& voter);
    bool updateVoterReputation(const std::string& voter_id, double new_reputation);
    bool updateVoterStake(const std::string& voter_id, double new_stake);
    void updateVotingPower(const std::string& voter_id);
    void updateAllVotingPowers();
    std::vector<Voter> getActiveVoters() const;
    Voter getVoter(const std::string& voter_id) const;
    
    // 提案管理
    std::string createProposal(ProposalType type, const std::string& title, 
                              const std::string& description, const json& proposal_data,
                              const std::string& proposer_id,
                              std::function<bool(const json&)> execution_callback = nullptr);
    bool submitVote(const std::string& proposal_id, const std::string& voter_id, 
                   VoteOption option, const std::string& reason = "");
    bool castVote(const std::string& proposal_id, const std::string& voter_id,
                 VoteOption option, double voting_power);
    bool executeProposal(const std::string& proposal_id);
    void updateProposalStatus();
    
    // 查询接口
    std::vector<Proposal> getActiveProposals() const;
    std::vector<Proposal> getProposalsByType(ProposalType type) const;
    Proposal getProposal(const std::string& proposal_id) const;
    std::vector<VoteRecord> getVoteHistory(const std::string& voter_id) const;
    std::vector<VoteRecord> getProposalVotes(const std::string& proposal_id) const;
    
    // 共识机制
    bool checkQuorum(const std::string& proposal_id) const;
    bool checkApprovalThreshold(const std::string& proposal_id) const;
    double calculateConsensusScore(const std::string& proposal_id) const;
    ProposalStatus determineProposalOutcome(const std::string& proposal_id) const;
    
    // 权重自适应更新
    void performWeightAdaptation(const std::vector<double>& performance_gains);
    void updateRuleWeights(const std::vector<double>& new_weights);
    std::vector<double> getCurrentRuleWeights() const;
    
    // 治理指标管理
    void updateGovernanceMetrics(const GovernanceMetrics& metrics);
    GovernanceMetrics getGovernanceMetrics() const;
    double calculateSystemHealthScore() const;
    
    // 区块链集成接口
    void onBlockCreated(int block_height, const std::string& block_hash);
    void syncWithBlockchain();
    json exportProposalToBlockchain(const std::string& proposal_id) const;
    bool importProposalFromBlockchain(const json& blockchain_data);
    
    // 统计与分析
    json getVotingStatistics() const;
    json getParticipationAnalysis() const;
    json getDecisionQualityMetrics() const;
    
    // 事件回调
    void setProposalCreatedCallback(std::function<void(const Proposal&)> callback);
    void setVoteCastCallback(std::function<void(const VoteRecord&)> callback);
    void setProposalExecutedCallback(std::function<void(const Proposal&)> callback);
    
private:
    // 内部辅助方法
    double calculateVotingPower(const Voter& voter) const;
    bool isVoterEligible(const std::string& voter_id, const std::string& proposal_id) const;
    void cleanupExpiredProposals();
    void updateVoterParticipationStats(const std::string& voter_id);
    std::string generateProposalId() const;
    void logVotingActivity(const std::string& activity, const json& details);
    
    // 共识算法实现
    double calculateQuadraticVotingPower(double base_power, double stake) const;
    void processDelegatedVotes(const std::string& proposal_id);
    bool validateProposalData(ProposalType type, const json& data) const;
    
    // 数据持久化
    void saveState() const;
    void loadState();
    
private:
    // 核心数据
    std::map<std::string, Voter> voters_;                    // 投票者映射
    std::map<std::string, Proposal> proposals_;              // 提案映射
    std::vector<VoteRecord> vote_history_;                   // 投票历史
    std::map<std::string, std::string> delegations_;         // 委托关系
    
    // 配置参数
    ConsensusConfig consensus_config_;                       // 共识配置
    GovernanceMetrics governance_metrics_;                   // 治理指标
    json config_;                                           // 完整配置
    
    // 规则权重管理
    std::vector<double> current_rule_weights_;              // 当前规则权重
    std::vector<double> target_rule_weights_;               // 目标规则权重
    
    // 区块链集成
    int current_block_height_;                              // 当前区块高度
    std::string latest_block_hash_;                         // 最新区块哈希
    
    // 事件回调
    std::function<void(const Proposal&)> proposal_created_callback_;
    std::function<void(const VoteRecord&)> vote_cast_callback_;
    std::function<void(const Proposal&)> proposal_executed_callback_;
    
    // 统计数据
    mutable std::map<std::string, int> proposal_type_counts_; // 提案类型统计
    mutable std::map<std::string, double> voter_accuracy_history_; // 投票者准确率历史
};

#endif // DAO_VOTING_MANAGER_H
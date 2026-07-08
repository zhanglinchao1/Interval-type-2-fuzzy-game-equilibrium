//
// Copyright (C) 2024 FuzzyTrust Project
//
// Documentation for these modules is at http://veins.car2x.org/
//
// SPDX-License-Identifier: GPL-2.0-or-later
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#pragma once

#include "veins/modules/application/ieee80211p/DemoBaseApplLayer.h"
#include "veins/modules/mobility/traci/TraCIMobility.h"
#include "veins/modules/mobility/traci/TraCICommandInterface.h"

// 包含模糊信任相关的头文件
#include "veins/modules/application/fuzzytrust/FuzzyTrust.h"
#include "veins/modules/application/fuzzytrust/ChannelQuality.h"
#include "veins/modules/application/fuzzytrust/ResourceManager.h"
#include "veins/modules/application/fuzzytrust/GameManager.h"
#include "veins/modules/application/fuzzytrust/OWAL-RL/core/OWARLAgent.h"
#include "veins/modules/application/fuzzytrust/FuzzyInferenceEngine.h"
#include "veins/modules/application/fuzzytrust/DynamicParameterOptimizer.h"
#include "veins/modules/application/fuzzytrust/DAOVotingManager.h"
#include "veins/modules/application/fuzzytrust/BlockchainGovernanceContract.h"
#include "veins/modules/application/fuzzytrust/ARIMAPredictor.h"

// Chapter 5.2 ITGameEngine + MembershipExtractor + MetricsLogger + RSUGovernanceAggregator
#include "veins/modules/application/fuzzytrust/Chapter52/ITGameEngine.h"
#include "veins/modules/application/fuzzytrust/Chapter52/MembershipExtractor.h"
#include "veins/modules/application/fuzzytrust/Chapter52/Chapter52MetricsLogger.h"
#include "veins/modules/application/fuzzytrust/Chapter52/RSUGovernanceAggregator.h"
#include "veins/modules/application/fuzzytrust/Chapter52/GovernanceWeightMessage_m.h"
#include "veins/modules/application/fuzzytrust/Chapter52/StrategyReportMessage_m.h"

// Choquet-OWA数据收集组件
#include "veins/modules/application/fuzzytrust/Choquet-OWA/ChoquetOWADataCollector.h"
#include "veins/modules/application/fuzzytrust/Choquet-OWA/ResourcePerformanceMonitor.h"
#include "veins/modules/application/fuzzytrust/Choquet-OWA/CSVOutputManager.h"
#include "veins/modules/application/fuzzytrust/Choquet-OWA/TimestampManager.h"

// OWA-RL权重演化数据收集
#include "veins/modules/application/fuzzytrust/OWAL-RL/collector/OWARLWeightCollector.h"

// 车辆混合策略数据收集
#include "veins/modules/application/fuzzytrust/VehicleMixingStrategy/VehicleMixingStrategyCollector.h"

// 消融对照测试数据收集
#include "veins/modules/application/fuzzytrust/Ablation/AblationDataCollector.h"

// JSON库支持
#include "json.hpp"
#include <map>
#include <vector>
#include <string>
#include <functional>
#include <numeric>
#include <set>
#include <cmath>

namespace veins {

/**
 * @brief FuzzyTrustApp - A comprehensive trust evaluation application for vehicular networks
 * 
 * This class implements a multi-faceted trust evaluation system that integrates:
 * - IT2-Sigmoid fuzzy trust evaluation
 * - Quality of Service (QoS) assessment
 * - Resource management and allocation
 * - Game theory-based strategic decision making
 * - OWARL (Optimistic Weighted Average Reward Learning) agent
 * 
 * The module extends DemoBaseApplLayer to provide seamless integration with
 * the Veins framework and standard WAVE/IEEE 802.11p communication protocols.
 * 
 * @author FuzzyTrust Project Team
 * @version 1.0
 */
class FuzzyTrustApp : public DemoBaseApplLayer {
private:
    // 数据收集相关成员变量
    struct CollectedData {
        // 移动性数据
        Coord currentPosition;
        double currentSpeed;
        double currentHeading;
        
        // 通信质量数据
        double measuredRTT;
        double measuredJitter;
        double measuredPacketLoss;
        double signalStrength;
        
        // 资源状态数据
        double cpuUtilization;
        double bandwidthUsage;
        double remainingEnergy;
        double powerConsumption;
        
        // 信誉数据
        std::vector<double> reputationVector; // 7维信誉向量
        
        // 时间戳
        simtime_t timestamp;
        
        // 节点信息
        std::string nodeType;                  // 节点类型 ("RSU" 或 "Vehicle")
        std::string nodeName;                  // 节点完整名称
    };
    
    // 策略选择历史数据结构
    struct StrategySelectionRecord {
        simtime_t timestamp;                    // 选择时间戳
        std::string selectedStrategy;           // 选择的策略类型 (SC/SP/DC/DP)
        std::vector<double> strategyProbabilities; // 各策略的选择概率 [SC, SP, DC, DP]
        double expectedPayoff;                  // 预期收益
        double actualPayoff;                    // 实际收益
        std::string decisionContext;             // 决策上下文 ("normal", "emergency", "congested"等)
        double trustLevel;                      // 当时的信任水平
        double qosLevel;                        // 当时的QoS水平
        double resourceLevel;                   // 当时的资源水平
        std::string nodeType;                  // 节点类型 ("Vehicle" 或 "RSU")
        std::string nodeName;                   // 节点名称
    };
    
    CollectedData currentData;
    std::vector<CollectedData> dataHistory;
    
    // 策略选择历史相关成员变量
    std::vector<StrategySelectionRecord> strategyHistory;
    StrategySelectionRecord currentStrategyRecord;
    
    // 策略统计信息
    struct StrategyStatistics {
        std::map<std::string, int> selectionCount;      // 各策略选择次数
        std::map<std::string, double> totalPayoffMap;   // 各策略累计收益
        std::map<std::string, double> averagePayoffMap; // 各策略平均收益
        int totalDecisions;                             // 总决策次数
        double totalPayoff;                             // 总收益
        double averagePayoff;                           // 平均收益
        
        StrategyStatistics() : totalDecisions(0), totalPayoff(0.0), averagePayoff(0.0) {
            // 初始化四种策略的统计信息
            selectionCount["SC"] = 0; selectionCount["SP"] = 0;
            selectionCount["DC"] = 0; selectionCount["DP"] = 0;
            totalPayoffMap["SC"] = 0.0; totalPayoffMap["SP"] = 0.0;
            totalPayoffMap["DC"] = 0.0; totalPayoffMap["DP"] = 0.0;
            averagePayoffMap["SC"] = 0.0; averagePayoffMap["SP"] = 0.0;
            averagePayoffMap["DC"] = 0.0; averagePayoffMap["DP"] = 0.0;
        }
    };
    
    StrategyStatistics strategyStats;
    
    // 数据收集方法声明
    void collectMobilityData();
    void collectCommunicationData();
    void collectResourceData();
    void collectReputationData();
    void updateDataHistory();
    
    // 策略选择历史记录方法声明（移动到public部分）
    void updateStrategyPayoff(double actualPayoff);
    void updateStrategyStatistics();
    void exportStrategyHistoryToCSV();
    std::string getStrategyFromProbabilities(const std::vector<double>& probabilities);
    std::string getCurrentDecisionContext();
    
    // 信誉计算方法声明
    double calculateDirectReputation();
    double calculateTimeReputation();
    double calculateFrequencyReputation();
    double calculatePositionReputation();
    double calculateServiceReputation();
    double calculateCommunicationReputation();
    double calculateNetworkReputation();
    
    // MAE性能数据收集方法声明
    void collectMAEPerformanceData();
    double calculateIT2SigmoidTrust(const std::vector<double>& reputationVector);
    double calculateType1SigmoidTrust(const std::vector<double>& reputationVector);
    double calculateThresholdTrust(const std::vector<double>& reputationVector);
    double calculateNoDefenseTrust(const std::vector<double>& reputationVector);
    double calculateGroundTruthTrust(const std::string& nodeId);
    bool checkIfNodeIsMalicious(const std::string& nodeId);
    void calculateMAEStatistics();
    double calculateMean(const std::vector<double>& values);
    double calculateStdDev(const std::vector<double>& values, double mean);
    void exportMAEPerformanceData();
    void exportMAERawData();
    void exportMAEStatistics();
    
    // 数据收集配置参数
    bool enableDataCollection = true;
    bool exportDataToCSV = true;
    int dataHistorySize = 1000;
    bool enableResourceMonitoring = true;
    simtime_t energyUpdateInterval = 1.0;
    
    // 策略选择历史配置参数
    bool enableStrategyHistoryCollection = true;
    bool exportStrategyHistoryToCSVFlag = true;
    int strategyHistorySize = 1000;
    bool enableStrategyStatistics = true;
    
    // MAE性能数据收集相关结构体和变量
    struct MAEPerformanceData {
        double maliciousRatio;              // 恶意节点比例
        double estimatedTrust;              // 估计信任值
        double groundTruthTrust;            // 真实信任值
        double absoluteError;               // 绝对误差
        std::string evaluationMethod;      // 评估方法 ("IT2", "Type1", "Threshold", "None")
        std::string nodeId;                 // 节点ID
        simtime_t timestamp;                // 时间戳
        bool isMaliciousNode;               // 是否为恶意节点
    };
    
    struct MAEStatistics {
        double maliciousRatio;
        double mae_it2, std_it2;
        double mae_t1, std_t1;
        double mae_threshold, std_threshold;
        double mae_none, std_none;
        int sampleCount;
    };
    
    // MAE数据收集相关成员变量
    std::vector<MAEPerformanceData> maeDataHistory;
    std::vector<MAEStatistics> maeStatistics;
    bool enableMAECollection = true;
    bool exportMAEToCSV = true;
    double currentMaliciousRatio = 0.0;
    // 威胁模型实现（chapter5.2 场景层）：本决策周期是否为协作动作 / 是否因异常伙伴失败
    bool lastItGameCoopAction = false;
    bool lastItGameCoopFailed = false;
    int maeExperimentRuns = 10;
    int currentExperimentRun = 0;
    
    // Choquet-OWA性能数据收集相关成员变量
    std::unique_ptr<ChoquetOWADataCollector> choquetDataCollector;
    std::unique_ptr<ResourcePerformanceMonitor> resourceMonitor;
    std::unique_ptr<CSVOutputManager> csvOutputManager;
    std::unique_ptr<TimestampManager> timestampManager;
    
    // Choquet-OWA数据收集配置
    bool enableChoquetOWACollection = true;
    bool exportChoquetOWAToCSV = true;
    double choquetSamplingInterval = 1.0;
    std::string currentTaskType = "compute_intensive";
    std::string choquetOutputDirectory = "results/choquet_owa/data/";
    
    // OWA-RL权重演化数据收集相关成员变量
    std::shared_ptr<OWARLWeightCollector> owarlWeightCollector;
    
    // OWA-RL数据收集配置
    bool enableOWARLWeightCollection = true;
    bool exportOWARLWeightsToCSV = true;
    double owarlSamplingInterval = 1.0;
    std::string owarlOutputDirectory = "results/OWAL-RL/data/";
    std::string currentScenario = "unknown";
    
    // 车辆混合策略数据收集相关成员变量
    std::shared_ptr<VehicleMixingStrategyCollector> mixingStrategyCollector;
    
    // 消融对照测试数据收集相关成员变量
    std::shared_ptr<AblationDataCollector> ablationDataCollector;
    
    // 车辆混合策略数据收集配置
    bool enableMixingStrategyCollection = true;
    bool exportMixingStrategyToCSV = true;
    double mixingStrategySamplingInterval = 1.0;
    std::string mixingStrategyOutputDirectory = "results/Vehicle Mixing Strategy/data/";
    
    // 消融对照测试数据收集配置
    bool enableAblationCollection = true;
    bool exportAblationToCSV = true;
    double ablationSamplingInterval = 1.0;
    std::string ablationOutputDirectory = "results/Ablation/data/";
    
    // 位置-策略联动相关变量
    Coord lastKnownPosition;                        // 上次已知位置
    double positionUpdateThreshold;                 // 位置变化阈值（米）
    simtime_t lastPositionUpdateTime;               // 上次位置更新时间
    std::set<std::string> currentNeighborSet;       // 当前邻居集合
    bool enablePositionBasedStrategyUpdate;         // 启用基于位置的策略更新
    
    // 能源建模相关变量
    double currentBatterySOC;                       // 当前电池SOC (0-1)
    double initialBatteryCapacity;                  // 初始电池容量 (Wh)
    double blockchainPowerConsumption;              // 区块链验证功耗 (W)
    double communicationPowerConsumption;           // 通信功耗 (W)
    double basePowerConsumption;                    // 基础功耗 (W)
    simtime_t lastEnergyUpdateTime;                 // 上次能源更新时间
    bool enableDetailedEnergyModeling;              // 启用详细能源建模
    
    // 消融对照测试模块启用状态
    bool enableIT2Module = true;                    // 启用IT2-Sigmoid模块
    bool enableChoquetOWAModule = true;             // 启用Choquet-OWA模块  
    bool enableOWARLModule = true;                  // 启用OWA-RL模块

public:
    void initialize(int stage) override;
    void finish() override;
    
    // 策略选择历史记录方法（供GameManager调用）
    void recordStrategySelection(const std::string& strategy,
                                const std::vector<double>& probabilities,
                                double expectedPayoff,
                                double muTrust = -1.0,
                                double muDelay = -1.0,
                                double muResource = -1.0);
    
    // Choquet-OWA性能数据收集方法
    void collectChoquetOWAPerformanceData();
    void updateTaskTypeBasedOnContext();
    void initializeChoquetOWAComponents();
    
    // OWA-RL权重演化数据收集方法
    void collectOWARLWeightData();
    void updateCurrentScenario();
    void initializeOWARLWeightCollector();
    std::string detectCongestionScenario() const;
    
    // 车辆混合策略数据收集方法
    void collectMixingStrategyData();
    void initializeMixingStrategyCollector();
    void updateStrategyDistribution();
    std::vector<int> getStrategyCounts() const;
    
    // 消融对照测试模块控制方法
    void setIT2ModuleEnabled(bool enabled);
    void setChoquetOWAModuleEnabled(bool enabled);
    void setOWARLModuleEnabled(bool enabled);
    bool isIT2ModuleEnabled() const { return enableIT2Module; }
    bool isChoquetOWAModuleEnabled() const { return enableChoquetOWAModule; }
    bool isOWARLModuleEnabled() const { return enableOWARLModule; }
    
    // 消融对照测试数据收集方法
    void collectAblationPerformanceData();
    void initializeAblationDataCollector();
    
    // 位置-策略联动方法
    void handlePositionUpdate(cObject* obj) override;
    void updateNeighborSet();
    void updateChannelQualityBasedOnMobility();
    void triggerStrategyReassessment();
    
    // 能源建模方法
    void updateEnergyConsumption();
    void calculateBlockchainPowerConsumption();
    void calculateCommunicationPowerConsumption();
    void updateBatterySOC();
    void updateResourceMembershipFromEnergy();

protected:
    // 核心模块实例
    std::unique_ptr<FuzzyTrust> fuzzyTrust;
    std::unique_ptr<ChannelQuality> channelQuality;
    std::unique_ptr<ResourceManager> resourceManager;
    std::unique_ptr<GameManager> gameManager;
    std::unique_ptr<OWARLAgent> owarlAgent;
    std::unique_ptr<FuzzyInferenceEngine> fuzzyEngine;
    std::unique_ptr<DynamicParameterOptimizer> dynamicOptimizer;
    
    // DAO治理系统模块实例
    std::unique_ptr<DAOVotingManager> daoVotingManager;
    std::unique_ptr<BlockchainGovernanceContract> blockchainContract;

    // Chapter 5.2 策略引擎 + 状态隶属度抽取 + 指标 logger（M1+M2+M3+M4 全接入）
    // 仅当 NED 参数 enableITGameEngine=true 时实例化；否则为 nullptr，行为等价旧路径
    std::unique_ptr<veins::chapter52::ITGameEngine> itGameEngine;
    std::unique_ptr<veins::chapter52::MembershipExtractor> membershipExtractor;
    std::unique_ptr<veins::chapter52::Chapter52MetricsLogger> metricsLogger;
    // 仅 RSU 节点实例化：链上治理慢时标
    std::unique_ptr<veins::chapter52::RSUGovernanceAggregator> rsuGovernance;
    cMessage* governanceTimer = nullptr;
    // 车辆/RSU 缓存：最近一次收到（或自己产出）的治理广播 θ + x_bar_local
    // 喂给 ITGameEngine：theta 通过 setParams，x_bar_local 作为 step 的 x_bar 实参
    veins::chapter52::Vec3 cachedTheta{0.40, 0.35, 0.25};
    veins::chapter52::Vec4 cachedXBarLocal{0.25, 0.25, 0.25, 0.25};
    int lastGovernanceIndex = -1;
    bool chapter52GovernanceEnabled = true;
    
    // DAO治理系统相关数据
    std::vector<std::string> validatorNodes;           // 验证节点列表
    std::vector<nlohmann::json> pendingTransactions;   // 待处理交易列表
    std::map<std::string, nlohmann::json> activeProposals; // 活跃提案映射
    double nodeStakeAmount;                            // 节点质押金额
    double nodeReputationScore;                        // 节点信誉评分
    std::unique_ptr<ARIMAPredictor> arimaPredictor;
    
    
    // 定时器
    cMessage* trustUpdateTimer;
    cMessage* qosUpdateTimer;
    cMessage* gameUpdateTimer;
    cMessage* decisionTimer;                   // 主决策定时器
    
    // DAO治理系统定时器
    cMessage* daoVotingTimer;                  // DAO投票定时器
    cMessage* blockchainTimer;                 // 区块链治理定时器
    
    // 配置参数
    std::string configFile;                    // 配置文件路径
    simtime_t trustUpdateInterval;             // 信任更新间隔
    simtime_t qosUpdateInterval;               // QoS更新间隔
    simtime_t gameUpdateInterval;              // 博弈更新间隔
    simtime_t decisionInterval;                // 主决策间隔
    
    // DAO治理系统配置参数
    simtime_t daoVotingInterval;               // DAO投票间隔
    simtime_t blockchainUpdateInterval;        // 区块链更新间隔
    bool enableDAOGovernance;                  // 是否启用DAO治理
    bool enableBlockchainIntegration;          // 是否启用区块链集成
    double votingPowerThreshold;               // 投票权重阈值
    int maxProposalsPerNode;                   // 每个节点最大提案数
    double consensusThreshold;                 // 共识阈值
    
    // 节点类型参数
    bool isRSU;                                // 是否为RSU节点
    bool isVehicleNode;                        // 是否为车辆节点
    bool sendTrustBeacons;                     // 是否发送信任信标
    
    // 第三章理论核心参数
    // 模糊信任评估参数
    double fuzzyTrustAlpha = 0.7;              // IT2-Sigmoid参数α
    double fuzzyTrustBeta = 0.3;               // IT2-Sigmoid参数β
    double fuzzyTrustGamma = 0.5;              // IT2-Sigmoid参数γ
    double fuzzyTrustThreshold = 0.6;          // 信任阈值
    
    // QoS信道质量评估参数
    double qosUrgencyWeight = 0.4;             // 紧迫性权重
    double qosReliabilityWeight = 0.6;         // 可靠性权重
    simtime_t qosDelayThreshold = 100;         // 延迟阈值(ms)
    double qosLossThreshold = 0.05;            // 丢包率阈值
    
    // 博弈理论参数
    double gameLearningRate = 0.1;             // 学习率
    double gameExplorationRate = 0.2;          // 探索率
    double gameDiscountFactor = 0.9;           // 折扣因子
    
    // OWA-RL自适应权重学习参数
    double owarlEta = 0.03;                    // 学习率η
    double owarlLambda = 0.7;                  // 正则化参数λ
    int owarlUpdatePeriod = 100;               // 更新周期
    
    // 统计变量
    int totalTrustUpdates = 0;                 // 信任更新总次数
    int totalQoSUpdates = 0;                   // QoS更新总次数
    int totalGameUpdates = 0;                  // 博弈更新总次数
    double averageTrustValue = 0.0;            // 平均信任值
    int beaconsSent = 0;                       // 发送的信标总数
    int highTrustBeaconsSent = 0;              // 高信任信标数量
    
    // DAO治理系统统计变量
    int totalDAOVotes = 0;                     // DAO投票总次数
    int totalProposalsCreated = 0;            // 创建的提案总数
    int totalProposalsExecuted = 0;           // 执行的提案总数
    double averageVotingPower = 0.0;          // 平均投票权重
    int maliciousBehaviorDetected = 0;        // 检测到的恶意行为次数
    double systemPerformanceScore = 0.0;      // 系统性能评分
    
    // 重写基类的虚函数
    void onWSM(BaseFrame1609_4* wsm) override;
    void onWSA(DemoServiceAdvertisment* wsa) override;
    void handleSelfMsg(cMessage* msg) override;
    
    // 核心更新方法
    void updateTrustEvaluation();
    void updateQoSAssessment();
    void updateGameDecision(double trustMembership = 0.6, double delayMembership = 0.7, double resourceMembership = 0.5);
    
    // 辅助方法
    void sendTrustBeacon();
    
    // DAO治理系统方法声明
    void initializeDAOGovernance();
    void performDAOVoting();
    void performBlockchainGovernance();
    
    // DAO投票相关方法
    int decideVoteOption(const nlohmann::json& proposal);
    double calculateNodeVotingPower();
    void createGovernanceProposal();
    void updateNodeGovernanceMetrics();
    
    // 区块链治理相关方法
    void handleBlockchainEvent(const BlockchainGovernanceContract::ContractEvent& event);
    void applyExecutedProposal(const std::string& proposalId);
    
    // 恶意行为检测和系统性能评估
    void detectAndPunishMaliciousBehavior();
    double calculateSystemPerformance();
    double calculateQoSPerformance();
    double calculateResourcePerformance();
    double calculateHistoricalPerformance();
    std::vector<double> generateOptimalRuleWeights();
    
    // 性能计算方法（重复声明已删除）
    
    // 优化相关方法
    std::vector<double> getRecentPerformanceData(int windowSize = 10);
};

} // namespace veins

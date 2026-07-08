package org.car2x.veins.modules.application.fuzzytrust;
import org.car2x.veins.modules.application.ieee80211p.DemoBaseApplLayer;

//
// FuzzyTrustApp - A comprehensive trust evaluation application for vehicular networks
// 
// This module implements a multi-faceted trust evaluation system that combines:
// - Fuzzy logic-based trust computation
// - Channel quality assessment
// - Resource management
// - Game theory-based decision making
// - OWARL (Optimistic Weighted Average Reward Learning) agent
//
// The module extends DemoBaseApplLayer to provide seamless integration
// with the Veins framework and standard WAVE/IEEE 802.11p communication.
//
// Key Features:
// - Real-time trust evaluation using fuzzy inference
// - Dynamic channel quality monitoring
// - Intelligent resource allocation
// - Strategic decision making through game theory
// - Adaptive learning via reinforcement learning
//
//
// FuzzyTrustApp - 一款全面的车载网络信任评估应用
//
// 该模块实现了一个多方面的信任评估系统，它结合了：
// - 基于模糊逻辑的信任计算
// - 信道质量评估
// - 资源管理
// - 基于博弈论的决策
// - OWARL（乐观加权平均奖励学习）代理
//
// 该模块扩展了 DemoBaseApplLayer，以实现与 Veins 框架和标准 WAVE/IEEE 802.11p 通信的无缝集成。
//
// 主要特点：
// - 使用模糊推理进行实时信任评估
// - 动态信道质量监控
// - 智能资源分配
// - 通过博弈论进行战略决策
// - 通过强化学习进行自适应学习
//
simple FuzzyTrustApp extends DemoBaseApplLayer
{
    parameters:
        @class(veins::FuzzyTrustApp);
        
        // Configuration file path for fuzzy trust parameters
        string configFile = default("config.json");
        
        // Update intervals for different components (in seconds)
        double trustUpdateInterval @unit(s) = default(1s);
        double qosUpdateInterval @unit(s) = default(0.5s);
        double gameUpdateInterval @unit(s) = default(2s);
        
        // Node type configuration
        bool isVehicleNode = default(true);  // true for vehicle, false for RSU
        bool isRSU = default(false);         // RSU identification flag
        
        // Decision making parameters
        double decisionInterval @unit(s) = default(0.1s);
        
        // Task characteristics (for QoS evaluation)
        double taskUrgency = default(0.5);      // 任务紧迫性因子
        double taskReliability = default(0.5);  // 任务可靠性因子
        double taskElasticity = default(0.5);   // 任务弹性因子
        
        // 第三章理论核心参数
        // IT2-Sigmoid模糊信任评估参数
        double fuzzyTrust_alpha = default(0.7);           // IT2-Sigmoid参数α
        double fuzzyTrust_beta = default(0.3);            // IT2-Sigmoid参数β
        double fuzzyTrust_gamma = default(0.5);           // IT2-Sigmoid参数γ
        double fuzzyTrust_trustThreshold = default(0.6);  // 信任阈值
        
        // QoS信道质量评估参数（紧迫性-可靠性耦合）
        double channelQuality_urgencyWeight = default(0.4);     // 紧迫性权重
        double channelQuality_reliabilityWeight = default(0.6); // 可靠性权重
        double channelQuality_delayThreshold @unit(ms) = default(100ms); // 延迟阈值
        double channelQuality_lossThreshold = default(0.05);    // 丢包率阈值
        double channelQuality_rho = default(0.5);               // 紧迫-可靠耦合参数ρ
        
        // 博弈理论参数
        double gameManager_learningRate = default(0.1);      // 学习率
        double gameManager_explorationRate = default(0.2);   // 探索率（ε-贪心）
        double gameManager_discountFactor = default(0.9);    // 折扣因子
        
        // OWA-RL自适应权重学习参数
        double owarlAgent_eta = default(0.03);           // 学习率η
        double owarlAgent_lambda = default(0.7);         // 正则化参数λ
        int owarlAgent_updatePeriod = default(100);      // 权重更新周期
        
        // 资源管理参数
        double resourceManager_cpuThreshold = default(0.8);      // CPU使用阈值
        double resourceManager_bandwidthThreshold = default(0.7); // 带宽使用阈值
        double resourceManager_energyThreshold = default(0.3);   // 能量阈值
        double resourceManager_powerThreshold = default(0.8);    // 功率阈值
        
        // 模糊推理引擎参数
        int fuzzyEngine_inputDimension = default(7);     // 输入维度（μ_trust, μ_delay, μ_resource, ρ, F_c, F_b, F_e）
        int fuzzyEngine_outputDimension = default(3);    // 输出维度（策略偏好）
        int fuzzyEngine_ruleCount = default(27);         // 模糊规则数量（3^3）
        
        // Trust beacon configuration
        bool sendTrustBeacons = default(true);
        // beaconInterval is inherited from DemoBaseApplLayer
        
        // 统计和监控参数
        bool enableStatistics = default(true);           // 启用统计收集
        bool enableDebugOutput = default(false);         // 启用调试输出
        
        // MAE性能数据收集参数
        bool enableMAECollection = default(false);       // 启用MAE数据收集
        bool exportMAEToCSV = default(false);           // 导出MAE数据到CSV
        double maliciousRatio = default(0.0);           // 恶意节点比例
        int maeExperimentRuns = default(1);             // MAE实验运行次数
        int currentExperimentRun = default(1);          // 当前实验运行次数
        
        // Choquet-OWA性能数据收集参数
        bool enableChoquetOWACollection = default(false);           // 启用Choquet-OWA数据收集
        bool exportChoquetOWAToCSV = default(false);               // 导出Choquet-OWA数据到CSV
        double choquetSamplingInterval @unit(s) = default(1.0s);   // Choquet-OWA采样间隔
        string choquetOutputDirectory = default("results/choquet_owa/data/"); // 输出目录
        string currentTaskType = default("compute_intensive");      // 当前任务类型

        // Chapter 5.2 ITGameEngine 接入参数（plan.MD §9.2-B/C）
        // 默认 false → 不激活新模块，所有旧实验零回归
        bool enableITGameEngine = default(false);
        string itGameMethod = default("Proposed");   // Greedy | FixedW | Proposed | NoIT2 | NoGov | NoWFBRI | NoRobust
        double itGame_delta = default(0.10);          // FOU 半宽
        double itGame_alpha = default(0.5);           // α-cut
        double itGame_lambda = default(0.10);         // 熵正则
        double itGame_beta = default(0.30);           // 阻尼步长
        // 受限策略集（plan §三 异构角色，MC4）：逗号分隔的可行策略子集，如 "SC,SP"。
        // 空串 = 全策略集可行（车辆默认）。RSU 在 ini 中设为 "SC,SP"。
        string itGameFeasibleSet = default("");
        // Chapter 5.2 链上治理（M4）
        double governancePeriod @unit(s) = default(5s);  // RSU slowUpdate 周期
        double epsilonG = default(1e-3);                  // 慢时标尺度

        @display("i=block/app");
}
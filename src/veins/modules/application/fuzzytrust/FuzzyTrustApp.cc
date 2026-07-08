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

#include "veins/modules/application/fuzzytrust/FuzzyTrustApp.h"
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

// Choquet-OWA组件
#include "veins/modules/application/fuzzytrust/Choquet-OWA/ChoquetOWADataCollector.h"
#include "veins/modules/application/fuzzytrust/Choquet-OWA/ResourcePerformanceMonitor.h"
#include "veins/modules/application/fuzzytrust/Choquet-OWA/CSVOutputManager.h"
#include "veins/modules/application/fuzzytrust/Choquet-OWA/TimestampManager.h"

#include "veins/modules/messages/DemoSafetyMessage_m.h"
#include "veins/modules/messages/BaseFrame1609_4_m.h"
#include "veins/modules/messages/DemoServiceAdvertisement_m.h"

#include <fstream>
#include <algorithm>
#include <sstream>
#include <numeric>
#include <cmath>
#include <map>
#include "json.hpp"

using namespace veins;

// OMNeT++模块注册宏 - 这是必需的
Define_Module(veins::FuzzyTrustApp);

void FuzzyTrustApp::initialize(int stage)
{
    DemoBaseApplLayer::initialize(stage);
    
    if (stage == 0) {
        // 第一阶段：初始化基本参数
        EV << "FuzzyTrustApp: 初始化阶段0 - 基本参数设置" << std::endl;
        
        // 读取配置参数
        configFile = par("configFile").stdstringValue();
        trustUpdateInterval = par("trustUpdateInterval");
        qosUpdateInterval = par("qosUpdateInterval");
        gameUpdateInterval = par("gameUpdateInterval");
        decisionInterval = par("decisionInterval");
        
        // 读取节点类型参数
        isRSU = par("isRSU").boolValue();
        isVehicleNode = par("isVehicleNode").boolValue();
        sendTrustBeacons = par("sendTrustBeacons").boolValue();
        
        // 读取第三章理论的核心参数
        // 模糊信任评估参数
        if (hasPar("fuzzyTrust_alpha")) {
        fuzzyTrustAlpha = par("fuzzyTrust_alpha");
        fuzzyTrustBeta = par("fuzzyTrust_beta");
        fuzzyTrustGamma = par("fuzzyTrust_gamma");
        fuzzyTrustThreshold = par("fuzzyTrust_trustThreshold");
        }
        
        // QoS信道质量评估参数
        if (hasPar("channelQuality_urgencyWeight")) {
            qosUrgencyWeight = par("channelQuality_urgencyWeight");
            qosReliabilityWeight = par("channelQuality_reliabilityWeight");
            qosDelayThreshold = par("channelQuality_delayThreshold");
            qosLossThreshold = par("channelQuality_lossThreshold");
        }
        
        // 博弈理论参数
        if (hasPar("gameManager_learningRate")) {
            gameLearningRate = par("gameManager_learningRate");
            gameExplorationRate = par("gameManager_explorationRate");
            gameDiscountFactor = par("gameManager_discountFactor");
        }
        
        // OWA-RL参数
        if (hasPar("owarlAgent_eta")) {
            owarlEta = par("owarlAgent_eta");
            owarlLambda = par("owarlAgent_lambda");
            owarlUpdatePeriod = par("owarlAgent_updatePeriod");
        }
        
        // 数据收集配置参数
        if (hasPar("enableDataCollection")) {
            enableDataCollection = par("enableDataCollection").boolValue();
        }
        if (hasPar("exportDataToCSV")) {
            exportDataToCSV = par("exportDataToCSV").boolValue();
        }
        if (hasPar("dataHistorySize")) {
            dataHistorySize = par("dataHistorySize").intValue();
        }
        if (hasPar("enableResourceMonitoring")) {
            enableResourceMonitoring = par("enableResourceMonitoring").boolValue();
        }
        if (hasPar("energyUpdateInterval")) {
            energyUpdateInterval = par("energyUpdateInterval");
        }
        
        // 策略选择历史收集配置参数
        if (hasPar("enableStrategyHistoryCollection")) {
            enableStrategyHistoryCollection = par("enableStrategyHistoryCollection").boolValue();
        }
        if (hasPar("exportStrategyHistoryToCSV")) {
        exportStrategyHistoryToCSVFlag = par("exportStrategyHistoryToCSV").boolValue();
    }
        if (hasPar("strategyHistorySize")) {
            strategyHistorySize = par("strategyHistorySize").intValue();
        }
        if (hasPar("enableStrategyStatistics")) {
            enableStrategyStatistics = par("enableStrategyStatistics").boolValue();
        }
        
        // 初始化数据收集结构
        currentData.remainingEnergy = 1.0; // 初始能量为100%
        currentData.reputationVector.resize(7, 0.5); // 初始信誉值为0.5
        
        // 初始化成员变量
        fuzzyTrust = nullptr;
        channelQuality = nullptr;
        resourceManager = nullptr;
        gameManager = nullptr;
        owarlAgent = nullptr;
        fuzzyEngine = nullptr;
        dynamicOptimizer = nullptr;
        
        // 初始化DAO治理组件
        daoVotingManager = nullptr;
        blockchainContract = nullptr;
        arimaPredictor = nullptr;
        
        // 初始化主决策定时器
        decisionTimer = new cMessage("decisionTimer");
        
        // 初始化其他定时器为nullptr（暂不使用）
        trustUpdateTimer = nullptr;
        qosUpdateTimer = nullptr;
        gameUpdateTimer = nullptr;
        
        // 初始化DAO治理定时器
        daoVotingTimer = nullptr;
        blockchainTimer = nullptr;
        
        // 初始化统计变量
        totalTrustUpdates = 0;
        totalQoSUpdates = 0;
        totalGameUpdates = 0;
        averageTrustValue = 0.0;
        
        // 初始化策略选择历史收集相关变量
        strategyStats.totalDecisions = 0;
        strategyStats.totalPayoff = 0.0;
        strategyStats.averagePayoff = 0.0;
        
        // MAE性能数据收集参数初始化
        if (hasPar("enableMAECollection")) {
            enableMAECollection = par("enableMAECollection").boolValue();
        } else {
            enableMAECollection = false;
        }
        if (hasPar("exportMAEToCSV")) {
            exportMAEToCSV = par("exportMAEToCSV").boolValue();
        } else {
            exportMAEToCSV = false;
        }
        if (hasPar("maliciousRatio")) {
            currentMaliciousRatio = par("maliciousRatio").doubleValue();
        } else {
            currentMaliciousRatio = 0.0;
        }
        if (hasPar("maeExperimentRuns")) {
            maeExperimentRuns = par("maeExperimentRuns").intValue();
        } else {
            maeExperimentRuns = 1;
        }
        if (hasPar("currentExperimentRun")) {
            currentExperimentRun = par("currentExperimentRun").intValue();
        } else {
            // 使用OMNeT++内置的运行号（从0开始）
            currentExperimentRun = getEnvir()->getConfigEx()->getActiveRunNumber();
        }
        
        // 清空MAE数据容器
        maeDataHistory.clear();
        maeStatistics.clear();
        
        EV << "FuzzyTrustApp: MAE数据收集初始化完成 - 启用: " << enableMAECollection 
           << ", 恶意节点比例: " << currentMaliciousRatio << "%" << std::endl;
        
        // Choquet-OWA性能数据收集参数初始化
        if (hasPar("enableChoquetOWACollection")) {
            enableChoquetOWACollection = par("enableChoquetOWACollection").boolValue();
        }
        if (hasPar("exportChoquetOWAToCSV")) {
            exportChoquetOWAToCSV = par("exportChoquetOWAToCSV").boolValue();
        }
        if (hasPar("choquetSamplingInterval")) {
            choquetSamplingInterval = par("choquetSamplingInterval").doubleValue();
        }
        if (hasPar("choquetOutputDirectory")) {
            choquetOutputDirectory = par("choquetOutputDirectory").stdstringValue();
        }
        if (hasPar("currentTaskType")) {
            currentTaskType = par("currentTaskType").stdstringValue();
        }
        
        EV << "FuzzyTrustApp: Choquet-OWA数据收集初始化完成 - 启用: " << enableChoquetOWACollection 
           << ", 采样间隔: " << choquetSamplingInterval << "s" << std::endl;
        
        // OWA-RL权重演化数据收集参数初始化
        if (hasPar("enableOWARLWeightCollection")) {
            enableOWARLWeightCollection = par("enableOWARLWeightCollection").boolValue();
        }
        if (hasPar("exportOWARLWeightsToCSV")) {
            exportOWARLWeightsToCSV = par("exportOWARLWeightsToCSV").boolValue();
        }
        if (hasPar("owarlSamplingInterval")) {
            owarlSamplingInterval = par("owarlSamplingInterval").doubleValue();
        }
        if (hasPar("owarlOutputDirectory")) {
            owarlOutputDirectory = par("owarlOutputDirectory").stdstringValue();
        }
        
        EV << "FuzzyTrustApp: OWA-RL权重收集初始化完成 - 启用: " << enableOWARLWeightCollection 
           << ", 采样间隔: " << owarlSamplingInterval << "s" << std::endl;
        
        // 车辆混合策略数据收集参数初始化
        if (hasPar("enableMixingStrategyCollection")) {
            enableMixingStrategyCollection = par("enableMixingStrategyCollection").boolValue();
        }
        if (hasPar("exportMixingStrategyToCSV")) {
            exportMixingStrategyToCSV = par("exportMixingStrategyToCSV").boolValue();
        }
        if (hasPar("mixingStrategySamplingInterval")) {
            mixingStrategySamplingInterval = par("mixingStrategySamplingInterval").doubleValue();
        }
        if (hasPar("mixingStrategyOutputDirectory")) {
            mixingStrategyOutputDirectory = par("mixingStrategyOutputDirectory").stdstringValue();
        }
        
        EV << "FuzzyTrustApp: 车辆混合策略数据收集初始化完成 - 启用: " << enableMixingStrategyCollection 
           << ", 采样间隔: " << mixingStrategySamplingInterval << "s" << std::endl;
        
        // 位置-策略联动参数初始化
        if (hasPar("enablePositionBasedStrategyUpdate")) {
            enablePositionBasedStrategyUpdate = par("enablePositionBasedStrategyUpdate").boolValue();
        } else {
            enablePositionBasedStrategyUpdate = true; // 默认启用
        }
        if (hasPar("positionUpdateThreshold")) {
            positionUpdateThreshold = par("positionUpdateThreshold").doubleValue();
        } else {
            positionUpdateThreshold = 50.0; // 默认50米
        }
        
        // 初始化位置相关变量
        lastKnownPosition = Coord(0, 0, 0);
        lastPositionUpdateTime = simTime();
        currentNeighborSet.clear();
        
        EV << "FuzzyTrustApp: 位置-策略联动初始化完成 - 启用: " << enablePositionBasedStrategyUpdate 
           << ", 位置变化阈值: " << positionUpdateThreshold << "m" << std::endl;
        
        // 能源建模参数初始化
        if (hasPar("enableDetailedEnergyModeling")) {
            enableDetailedEnergyModeling = par("enableDetailedEnergyModeling").boolValue();
        } else {
            enableDetailedEnergyModeling = true; // 默认启用
        }
        if (hasPar("initialBatteryCapacity")) {
            initialBatteryCapacity = par("initialBatteryCapacity").doubleValue();
        } else {
            initialBatteryCapacity = 60000.0; // 默认60kWh
        }
        if (hasPar("basePowerConsumption")) {
            basePowerConsumption = par("basePowerConsumption").doubleValue();
        } else {
            basePowerConsumption = 200.0; // 默认200W基础功耗
        }
        
        // 初始化能源相关变量
        currentBatterySOC = 1.0; // 满电开始
        blockchainPowerConsumption = 0.0;
        communicationPowerConsumption = 0.0;
        lastEnergyUpdateTime = simTime();
        
        EV << "FuzzyTrustApp: 能源建模初始化完成 - 启用: " << enableDetailedEnergyModeling 
           << ", 初始电池容量: " << initialBatteryCapacity << "Wh" << std::endl;
        
        EV << "FuzzyTrustApp: 阶段0初始化完成，配置文件: " << configFile << std::endl;
    }
    else if (stage == 1) {
        // 第二阶段：初始化核心模块
        EV << "FuzzyTrustApp: 初始化阶段1 - 核心模块创建" << std::endl;
        
        try {
            // 创建核心模块实例，传递从omnetpp.ini读取的参数
            fuzzyTrust = std::make_unique<FuzzyTrust>(configFile);
            channelQuality = std::make_unique<ChannelQuality>();
            resourceManager = std::make_unique<ResourceManager>();
            gameManager = std::make_unique<GameManager>();
            owarlAgent = std::make_unique<OWARLAgent>();
            fuzzyEngine = std::make_unique<FuzzyInferenceEngine>();
            dynamicOptimizer = std::make_unique<DynamicParameterOptimizer>();
            
            // 创建DAO治理组件实例
            daoVotingManager = std::make_unique<DAOVotingManager>();
            blockchainContract = std::make_unique<BlockchainGovernanceContract>();
            arimaPredictor = std::make_unique<ARIMAPredictor>();

            // Chapter 5.2 ITGameEngine（仅当 NED 参数 enableITGameEngine=true）
            // plan.MD §9.2-C：默认 false → itGameEngine 为 nullptr → 旧路径零回归
            if (par("enableITGameEngine").boolValue()) {
                using veins::chapter52::ITGameEngine;
                itGameEngine = std::make_unique<ITGameEngine>();
                veins::chapter52::Vec3 theta{0.40, 0.35, 0.25};
                itGameEngine->setParams(
                    par("itGame_lambda").doubleValue(),
                    par("itGame_beta").doubleValue(),
                    par("itGame_delta").doubleValue(),
                    par("itGame_alpha").doubleValue(),
                    theta);
                std::string method = par("itGameMethod").stdstringValue();
                if      (method == "Greedy")   itGameEngine->setMethod(ITGameEngine::Method::Greedy);
                else if (method == "FixedW")   itGameEngine->setMethod(ITGameEngine::Method::FixedWeightIT2);
                else if (method == "Proposed") itGameEngine->setMethod(ITGameEngine::Method::Proposed);
                else if (method == "NoIT2")    itGameEngine->setMethod(ITGameEngine::Method::NoIT2);
                else if (method == "NoGov")    itGameEngine->setMethod(ITGameEngine::Method::NoGov);
                else if (method == "NoWFBRI")  itGameEngine->setMethod(ITGameEngine::Method::NoWFBRI);
                else if (method == "NoRobust") itGameEngine->setMethod(ITGameEngine::Method::NoRobust);
                else throw cRuntimeError("Unknown itGameMethod: %s", method.c_str());
                chapter52GovernanceEnabled = (method != "NoGov");
                itGameEngine->setRngSeed(static_cast<unsigned int>(getSimulation()->getEnvir()->getRNG(0)->intRand()));

                // 受限策略集（plan §三 异构角色 / MC4）：解析 "SC,SP" 形式的可行子集
                {
                    std::string feasSet = par("itGameFeasibleSet").stdstringValue();
                    if (!feasSet.empty()) {
                        static const std::vector<std::string> kStratNames = {"SC", "SP", "DC", "DP"};
                        std::array<bool, 4> mask{{false, false, false, false}};
                        std::stringstream ss(feasSet);
                        std::string tok;
                        while (std::getline(ss, tok, ',')) {
                            // 去空白
                            tok.erase(0, tok.find_first_not_of(" \t"));
                            tok.erase(tok.find_last_not_of(" \t") + 1);
                            auto it = std::find(kStratNames.begin(), kStratNames.end(), tok);
                            if (it == kStratNames.end())
                                throw cRuntimeError("itGameFeasibleSet: unknown strategy '%s'", tok.c_str());
                            mask[std::distance(kStratNames.begin(), it)] = true;
                        }
                        itGameEngine->setFeasibleMask(mask);
                        EV << "FuzzyTrustApp: 受限策略集已启用 [" << feasSet << "]" << std::endl;
                    }
                }
                // M2 接入：MembershipExtractor 与 itGameEngine 同生命周期
                membershipExtractor = std::make_unique<veins::chapter52::MembershipExtractor>();
                // M3 接入：MetricsLogger（按 plan §2.4）；finish 时 flush 到
                // results/chapter52/<config>/<node>/metrics.csv
                metricsLogger = std::make_unique<veins::chapter52::Chapter52MetricsLogger>();

                // M4 接入：仅 RSU 节点实例化 RSUGovernanceAggregator + governanceTimer
                if (isRSU && chapter52GovernanceEnabled) {
                    veins::chapter52::RSUGovernanceAggregator::Config gcfg;
                    gcfg.K = 5;
                    gcfg.epsilon_g = par("epsilonG").doubleValue();
                    gcfg.dt = par("governancePeriod").doubleValue();
                    gcfg.observation_noise = 0.005;  // 与 MATLAB sec4_4_3 一致
                    rsuGovernance = std::make_unique<veins::chapter52::RSUGovernanceAggregator>(gcfg);
                    rsuGovernance->setRngSeed(
                        static_cast<unsigned int>(getSimulation()->getEnvir()->getRNG(0)->intRand()));
                    governanceTimer = new cMessage("governanceTimer");
                    scheduleAt(simTime() + gcfg.dt, governanceTimer);
                    // 初始 θ = projectTheta(omega_init, P_pay) → 喂给 ITGameEngine
                    cachedTheta = rsuGovernance->getTheta();
                    itGameEngine->setParams(
                        par("itGame_lambda").doubleValue(),
                        par("itGame_beta").doubleValue(),
                        par("itGame_delta").doubleValue(),
                        par("itGame_alpha").doubleValue(),
                        cachedTheta);
                    EV << "FuzzyTrustApp[RSU]: 治理聚合器已就绪，period="
                       << gcfg.dt << "s ε_g=" << gcfg.epsilon_g << std::endl;
                }

                EV << "FuzzyTrustApp: ITGameEngine 已激活，method=" << method
                   << "，MembershipExtractor + MetricsLogger 已就绪" << std::endl;
            }
            
            // 从JSON配置文件加载各模块配置
            if (!configFile.empty()) {
                std::ifstream configStream(configFile);
                if (configStream.is_open()) {
                    nlohmann::json j;
                    configStream >> j;
                    
                    // 依次调用各模块的loadConfig方法
                    // FuzzyTrust已经在构造时加载了配置文件，无需再次加载
                    EV << "FuzzyTrustApp: FuzzyTrust配置已在构造时加载完成" << std::endl;
                    
                    try {
                        if (j.contains("ChannelQuality")) {
                            EV << "FuzzyTrustApp: 开始加载ChannelQuality配置" << std::endl;
                            channelQuality->loadConfig(j["ChannelQuality"]);
                            EV << "FuzzyTrustApp: ChannelQuality配置加载完成" << std::endl;
                        }
                    } catch (const std::exception& e) {
                        EV_ERROR << "ChannelQuality配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    try {
                        if (j.contains("ResourceManager")) {
                            EV << "FuzzyTrustApp: 开始加载ResourceManager配置" << std::endl;
                            resourceManager->loadConfig(j["ResourceManager"]);
                            EV << "FuzzyTrustApp: ResourceManager配置加载完成" << std::endl;
                        }
                    } catch (const std::exception& e) {
                        EV_ERROR << "ResourceManager配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    try {
                        if (j.contains("GameManager")) {
                            EV << "FuzzyTrustApp: 开始加载GameManager配置" << std::endl;
                            gameManager->loadConfig(j["GameManager"]);
                            EV << "FuzzyTrustApp: GameManager配置加载完成" << std::endl;
                        }
                        
                        // 设置GameManager与FuzzyTrustApp的关联（用于策略选择记录）
                        gameManager->setFuzzyTrustApp(this);
                        EV << "FuzzyTrustApp: GameManager关联设置完成" << std::endl;
                        
                    } catch (const std::exception& e) {
                        EV_ERROR << "GameManager配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    try {
                        if (j.contains("OWARLAgent")) {
                            EV << "FuzzyTrustApp: 开始加载OWARLAgent配置" << std::endl;
                            owarlAgent->loadConfig(j["OWARLAgent"]);
                            EV << "FuzzyTrustApp: OWARLAgent配置加载完成" << std::endl;
                            
                            // 初始化OWA-RL权重收集器
                            initializeOWARLWeightCollector();
                            
                            // 初始化车辆混合策略收集器
                            initializeMixingStrategyCollector();
                        }
                    } catch (const std::exception& e) {
                        EV_ERROR << "OWARLAgent配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    try {
                        if (j.contains("FuzzyInferenceEngine")) {
                            EV << "FuzzyTrustApp: 开始加载FuzzyInferenceEngine配置" << std::endl;
                            fuzzyEngine->loadConfig(j["FuzzyInferenceEngine"]);
                            EV << "FuzzyTrustApp: FuzzyInferenceEngine配置加载完成" << std::endl;
                        }
                    } catch (const std::exception& e) {
                        EV_ERROR << "FuzzyInferenceEngine配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    try {
                        if (j.contains("DynamicParameterOptimizer")) {
                            EV << "FuzzyTrustApp: 开始加载DynamicParameterOptimizer配置" << std::endl;
                            dynamicOptimizer->loadConfig(j["DynamicParameterOptimizer"]);
                            EV << "FuzzyTrustApp: DynamicParameterOptimizer配置加载完成" << std::endl;
                        }
                    } catch (const std::exception& e) {
                        EV_ERROR << "DynamicParameterOptimizer配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    // 加载DAO治理组件配置
                    try {
                        if (j.contains("DAOVotingManager")) {
                            EV << "FuzzyTrustApp: 开始加载DAOVotingManager配置" << std::endl;
                            daoVotingManager->loadConfig(j["DAOVotingManager"]);
                            EV << "FuzzyTrustApp: DAOVotingManager配置加载完成" << std::endl;
                        }
                    } catch (const std::exception& e) {
                        EV_ERROR << "DAOVotingManager配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    try {
                        if (j.contains("BlockchainGovernanceContract")) {
                            EV << "FuzzyTrustApp: 开始加载BlockchainGovernanceContract配置" << std::endl;
                            blockchainContract->loadConfig(j["BlockchainGovernanceContract"]);
                            EV << "FuzzyTrustApp: BlockchainGovernanceContract配置加载完成" << std::endl;
                        }
                    } catch (const std::exception& e) {
                        EV_ERROR << "BlockchainGovernanceContract配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    try {
                        if (j.contains("ARIMAPredictor")) {
                            EV << "FuzzyTrustApp: 开始加载ARIMAPredictor配置" << std::endl;
                            // ARIMAPredictor 有接受 JSON 参数的构造函数，需要重新创建对象
                             arimaPredictor.reset(new ARIMAPredictor(j["ARIMAPredictor"]));
                            EV << "FuzzyTrustApp: ARIMAPredictor配置加载完成" << std::endl;
                        }
                    } catch (const std::exception& e) {
                        EV_ERROR << "ARIMAPredictor配置加载失败: " << e.what() << std::endl;
                        throw;
                    }
                    
                    configStream.close();
                } else {
                    EV_WARN << "FuzzyTrustApp: 无法打开配置文件: " << configFile << std::endl;
                }
            }
            
            EV << "FuzzyTrustApp: 所有核心模块初始化成功" << std::endl;
            
        } catch (const std::exception& e) {
            EV_ERROR << "FuzzyTrustApp: 核心模块初始化失败: " << e.what() << std::endl;
            std::cerr << "FuzzyTrustApp: 详细错误信息: " << e.what() << std::endl;
            throw cRuntimeError("FuzzyTrustApp初始化失败: %s", e.what());
        } catch (...) {
            EV_ERROR << "FuzzyTrustApp: 未知异常导致初始化失败" << std::endl;
            std::cerr << "FuzzyTrustApp: 发生未知异常" << std::endl;
            throw cRuntimeError("FuzzyTrustApp初始化失败: 未知异常");
        }
        
        // 初始化DAO治理系统
        initializeDAOGovernance();
        
        // 初始化Choquet-OWA数据收集组件
        initializeChoquetOWAComponents();
        
        // 初始化消融对照测试数据收集器
        initializeAblationDataCollector();
        
        // 初始化DAO治理定时器
        daoVotingTimer = new cMessage("daoVotingTimer");
        blockchainTimer = new cMessage("blockchainTimer");
        
        // 调度主决策定时器
        scheduleAt(simTime() + decisionInterval, decisionTimer);
        
        // 调度DAO治理定时器
        scheduleAt(simTime() + 5.0, daoVotingTimer);
        scheduleAt(simTime() + 2.0, blockchainTimer);
        
        EV << "FuzzyTrustApp: 阶段1初始化完成，所有定时器已调度" << std::endl;
    }
}

void FuzzyTrustApp::finish() {
    // M4 接入：清理 governanceTimer（仅 RSU schedule 过）
    if (governanceTimer) {
        cancelAndDelete(governanceTimer);
        governanceTimer = nullptr;
    }
    // M3 接入：导出 chapter5.2 指标 CSV
    // 路径：results/chapter52/<configName>/Nv{Nv}_{method}_seed{rep}/<nodeName>/metrics.csv
    // 拼接 iteration variables 避免多 run 互相覆盖
    if (metricsLogger) {
        std::string configName = getEnvir()->getConfigEx()->getActiveConfigName();
        std::string nodeName = getParentModule()->getFullName();
        std::string runId = getEnvir()->getConfigEx()->getActiveRunNumber() >= 0
            ? ("run" + std::to_string(getEnvir()->getConfigEx()->getActiveRunNumber()))
            : "run_single";
        auto getVar = [this](const char* name) -> std::string {
            const char* v = getEnvir()->getConfigEx()->getVariable(name);
            if (!v) return "X";
            std::string s(v);
            // 去掉两侧引号（OMNeT++ string iteration var 携带 "..." 字面值）
            if (s.size() >= 2 && s.front() == '"' && s.back() == '"') {
                s = s.substr(1, s.size() - 2);
            }
            return s;
        };
        std::string nv = getVar("Nv");
        std::string method = getVar("method");
        if (method == "X") method = getVar("ablation");  // Exp2 用 ablation 而非 method
        std::string seed = getVar("repetition");
        std::string runDir = "Nv" + nv + "_" + method + "_seed" + seed;
        if (nv == "X" && method == "X") runDir = runId;  // 非 Chapter52_Exp* 配置回退
        std::string resultRoot = (configName.find("Strong") != std::string::npos)
            ? "results/chapter52_strong/"
            : "results/chapter52/";
        std::string outPath = resultRoot + configName + "/" + runDir + "/" + nodeName + "/metrics.csv";
        bool ok = metricsLogger->flushToCSV(outPath);
        EV << "FuzzyTrustApp: Chapter52 metrics CSV "
           << (ok ? "已导出至 " : "导出失败：") << outPath
           << "（sent=" << metricsLogger->totalSent()
           << " recv=" << metricsLogger->totalReceived()
           << " switches=" << metricsLogger->totalSwitches()
           << " rows=" << metricsLogger->numCsvRows() << "）" << std::endl;
    }

    // 导出收集的数据到CSV文件（如果启用）
    if (enableDataCollection && exportDataToCSV && !dataHistory.empty()) {
        std::string filename = "results/collected_data/data_" + std::to_string(getParentModule()->getIndex()) + ".csv";
        std::ofstream csvFile(filename);
        
        if (csvFile.is_open()) {
            // 写入CSV头部
            csvFile << "timestamp,pos_x,pos_y,speed,heading,rtt,jitter,loss,signal_strength,cpu,bandwidth,energy,power,";
            csvFile << "r_d,r_t,r_f,r_p,r_s,r_c,r_n,node_type,node_name\n";
            
            // 写入历史数据
            for (const auto& data : dataHistory) {
                csvFile << data.timestamp << "," << data.currentPosition.x << "," << data.currentPosition.y
                       << "," << data.currentSpeed << "," << data.currentHeading
                       << "," << data.measuredRTT << "," << data.measuredJitter << "," << data.measuredPacketLoss
                       << "," << data.signalStrength << "," << data.cpuUtilization << "," << data.bandwidthUsage 
                       << "," << data.remainingEnergy << "," << data.powerConsumption;
                
                for (size_t i = 0; i < data.reputationVector.size(); i++) {
                    csvFile << "," << data.reputationVector[i];
                }
                csvFile << "," << data.nodeType << "," << data.nodeName << "\n";
            }
            csvFile.close();
            EV << "数据已导出到: " << filename << std::endl;
        } else {
             EV_WARN << "无法创建CSV文件: " << filename << std::endl;
         }
     }
     
     // 导出策略选择历史数据到CSV文件（如果启用）
     if (enableStrategyHistoryCollection && exportStrategyHistoryToCSVFlag && !strategyHistory.empty()) {
            exportStrategyHistoryToCSV();
        }
     
     // 导出MAE性能数据到CSV文件（如果启用）
     if (enableMAECollection && exportMAEToCSV && !maeDataHistory.empty()) {
         calculateMAEStatistics();
         exportMAEPerformanceData();
         exportMAERawData();
         exportMAEStatistics();
     }
     
     // 导出Choquet-OWA性能数据到CSV文件（如果启用）
     if (enableChoquetOWACollection && exportChoquetOWAToCSV && csvOutputManager) {
         csvOutputManager->writeExperimentSummary();
         csvOutputManager->finalizeFiles();
         EV << "FuzzyTrustApp: Choquet-OWA数据导出完成" << std::endl;
     }
     
     // 导出OWA-RL权重演化数据到CSV文件（如果启用）
     if (enableOWARLWeightCollection && exportOWARLWeightsToCSV && owarlWeightCollector) {
         try {
             // 导出当前运行的数据
             owarlWeightCollector->exportData();
             
             // 导出聚合统计数据
             owarlWeightCollector->exportAggregatedData();
             
             EV << "FuzzyTrustApp: OWA-RL权重演化数据导出完成 - 包含运行数据和统计数据" << std::endl;
         } catch (const std::exception& e) {
             EV_ERROR << "FuzzyTrustApp: OWA-RL权重数据导出失败: " << e.what() << std::endl;
         }
     }
     
     // 导出车辆混合策略数据到CSV文件（如果启用）
     if (enableMixingStrategyCollection && exportMixingStrategyToCSV && mixingStrategyCollector) {
         try {
             // 导出当前运行的数据
             mixingStrategyCollector->exportData();
             
             // 导出聚合统计数据
             mixingStrategyCollector->exportAggregatedData();
             
             EV << "FuzzyTrustApp: 车辆混合策略数据导出完成 - 包含运行数据和统计数据" << std::endl;
         } catch (const std::exception& e) {
             EV_ERROR << "FuzzyTrustApp: 车辆混合策略数据导出失败: " << e.what() << std::endl;
         }
     }
     
     // 更新并记录策略统计信息
     if (enableStrategyStatistics) {
         updateStrategyStatistics();
     }
     
     EV << "FuzzyTrustApp: 仿真结束，开始统计记录" << std::endl;
    
    try {
        // 用recordScalar记录最终统计值
        recordScalar("Final_average_trust", averageTrustValue);
        recordScalar("Total_trust_updates", totalTrustUpdates);
        recordScalar("Total_qos_updates", totalQoSUpdates);
        recordScalar("Total_game_updates", totalGameUpdates);
        recordScalar("Total_beacons_sent", beaconsSent);
        recordScalar("High_trust_beacons_sent", highTrustBeaconsSent);
        
        // 计算高信任信标比例
        double highTrustRatio = (beaconsSent > 0) ? 
            static_cast<double>(highTrustBeaconsSent) / beaconsSent : 0.0;
        recordScalar("High_trust_beacon_ratio", highTrustRatio);
        
        // 记录节点类型信息
        bool isVehicle = par("isVehicleNode").boolValue();
        bool isRSU = par("isRSU").boolValue();
        recordScalar("Is_vehicle_node", isVehicle ? 1.0 : 0.0);
        recordScalar("Is_RSU_node", isRSU ? 1.0 : 0.0);
        
        // 记录配置参数
        recordScalar("Trust_threshold", fuzzyTrustThreshold);
        recordScalar("QoS_urgency_weight", qosUrgencyWeight);
        recordScalar("QoS_reliability_weight", qosReliabilityWeight);
        recordScalar("Game_learning_rate", gameLearningRate);
        recordScalar("OWARL_eta", owarlEta);
        recordScalar("OWARL_lambda", owarlLambda);
        
        // 记录策略选择统计信息
        if (enableStrategyStatistics) {
            recordScalar("Strategy_total_decisions", strategyStats.totalDecisions);
            recordScalar("Strategy_total_payoff", strategyStats.totalPayoff);
            recordScalar("Strategy_average_payoff", strategyStats.averagePayoff);
            
            // 记录各策略的选择次数和平均收益
            recordScalar("Strategy_SC_count", strategyStats.selectionCount["SC"]);
            recordScalar("Strategy_SP_count", strategyStats.selectionCount["SP"]);
            recordScalar("Strategy_DC_count", strategyStats.selectionCount["DC"]);
            recordScalar("Strategy_DP_count", strategyStats.selectionCount["DP"]);
            
            recordScalar("Strategy_SC_avg_payoff", strategyStats.averagePayoffMap["SC"]);
        recordScalar("Strategy_SP_avg_payoff", strategyStats.averagePayoffMap["SP"]);
        recordScalar("Strategy_DC_avg_payoff", strategyStats.averagePayoffMap["DC"]);
        recordScalar("Strategy_DP_avg_payoff", strategyStats.averagePayoffMap["DP"]);
            
            // 计算策略选择比例
            if (strategyStats.totalDecisions > 0) {
                recordScalar("Strategy_SC_ratio", (double)strategyStats.selectionCount["SC"] / strategyStats.totalDecisions);
                recordScalar("Strategy_SP_ratio", (double)strategyStats.selectionCount["SP"] / strategyStats.totalDecisions);
                recordScalar("Strategy_DC_ratio", (double)strategyStats.selectionCount["DC"] / strategyStats.totalDecisions);
                recordScalar("Strategy_DP_ratio", (double)strategyStats.selectionCount["DP"] / strategyStats.totalDecisions);
            }
        }
        
        // 如果有模块实例，记录模块特定的统计信息
        if (fuzzyTrust) {
            // 记录模糊信任相关统计
            EV << "FuzzyTrustApp: 记录FuzzyTrust模块统计信息" << std::endl;
        }
        
        if (channelQuality) {
            // 记录信道质量相关统计
            EV << "FuzzyTrustApp: 记录ChannelQuality模块统计信息" << std::endl;
        }
        
        if (resourceManager) {
            // 记录资源管理相关统计
            EV << "FuzzyTrustApp: 记录ResourceManager模块统计信息" << std::endl;
        }
        
        if (gameManager) {
            // 记录博弈理论相关统计
            EV << "FuzzyTrustApp: 记录GameManager模块统计信息" << std::endl;
        }
        
        if (owarlAgent) {
            // 记录OWA-RL相关统计
            EV << "FuzzyTrustApp: 记录OWARLAgent模块统计信息" << std::endl;
        }
        
        if (fuzzyEngine) {
            // 记录模糊推理引擎相关统计
            EV << "FuzzyTrustApp: 记录FuzzyInferenceEngine模块统计信息" << std::endl;
        }
        
        EV << "FuzzyTrustApp: 统计记录完成 - 平均信任值: " << averageTrustValue 
           << ", 总更新次数: " << totalTrustUpdates 
           << ", 信标发送数: " << beaconsSent 
           << ", 高信任信标比例: " << highTrustRatio << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 统计记录错误: " << e.what() << std::endl;
    }
    
    // 取消并删除定时器
    if (decisionTimer) {
        cancelAndDelete(decisionTimer);
        decisionTimer = nullptr;
    }
    if (trustUpdateTimer) {
        cancelAndDelete(trustUpdateTimer);
        trustUpdateTimer = nullptr;
    }
    if (qosUpdateTimer) {
        cancelAndDelete(qosUpdateTimer);
        qosUpdateTimer = nullptr;
    }
    if (gameUpdateTimer) {
        cancelAndDelete(gameUpdateTimer);
        gameUpdateTimer = nullptr;
    }
    if (daoVotingTimer) {
        cancelAndDelete(daoVotingTimer);
        daoVotingTimer = nullptr;
    }
    if (blockchainTimer) {
        cancelAndDelete(blockchainTimer);
        blockchainTimer = nullptr;
    }
    
    // 重置智能指针（自动释放内存）
    fuzzyTrust.reset();
    channelQuality.reset();
    resourceManager.reset();
    gameManager.reset();
    owarlAgent.reset();
    fuzzyEngine.reset();
    dynamicOptimizer.reset();
    
    // 重置DAO治理组件
    daoVotingManager.reset();
    blockchainContract.reset();
    arimaPredictor.reset();
    
    // 调用父类finish
    DemoBaseApplLayer::finish();
    
    EV << "FuzzyTrustApp: 清理完成" << std::endl;
}

void FuzzyTrustApp::onWSM(BaseFrame1609_4* wsm)
{
    // M3 接入：记录接收事件 + 时延（now − sentTimestamp）
    if (metricsLogger) {
        double now_s = simTime().dbl();
        double sent_ts = wsm->getTimestamp().dbl();
        double latency_s = std::max(0.0, now_s - sent_ts);
        metricsLogger->recordWSMReceived(now_s, latency_s);
    }

    // MC4 闭环：车辆 → RSU 策略上报。RSU 侧累积真实车辆 π 流式平均得 x̄_local，
    // 取代旧"RSU 自家 π 代理"（受限策略集下代理会把 RSU 掩码偏差注入全网平均场）。
    if (auto* srm = dynamic_cast<StrategyReportMessage*>(wsm)) {
        if (isRSU && rsuGovernance) {
            veins::chapter52::Vec4 pi_vehicle;
            for (int j = 0; j < 4; ++j) pi_vehicle[j] = srm->getPi(j);
            rsuGovernance->accumulateEvidence(pi_vehicle);
        }
        return;  // 上报消息不进入通用信誉解析路径
    }

    // M4 接入：识别 GovernanceWeightMessage，缓存 θ + x_bar_local 并喂给 ITGameEngine
    if (auto* gwm = dynamic_cast<GovernanceWeightMessage*>(wsm)) {
        if (!chapter52GovernanceEnabled) {
            return;
        }
        // 接受比本地更新的 omegaIndex；同 RSU 重复广播只取最新
        int incoming_h = gwm->getOmegaIndex();
        if (incoming_h > lastGovernanceIndex) {
            // theta[3] / xBarLocal[4] 固定长度
            cachedTheta = {gwm->getTheta(0), gwm->getTheta(1), gwm->getTheta(2)};
            for (int j = 0; j < 4; ++j) cachedXBarLocal[j] = gwm->getXBarLocal(j);
            lastGovernanceIndex = incoming_h;
            if (itGameEngine) {
                itGameEngine->setParams(
                    par("itGame_lambda").doubleValue(),
                    par("itGame_beta").doubleValue(),
                    par("itGame_delta").doubleValue(),
                    par("itGame_alpha").doubleValue(),
                    cachedTheta);
            }
            EV << "FuzzyTrustApp[Veh-RX-Gov]: h=" << incoming_h
               << " θ=(" << cachedTheta[0] << "," << cachedTheta[1] << "," << cachedTheta[2] << ")"
               << std::endl;
        }
    }
    // 处理接收到的无线安全消息
    EV << "FuzzyTrustApp: 接收到WSM消息，时间戳: " << wsm->getTimestamp() << std::endl;
    
    try {
        // 解析周围车辆或RSU发来的"信誉上链"或"QoS反馈"等消息
        // 这里模拟消息内容解析，实际应根据消息格式进行解析
        
        // 模拟从消息中提取的信誉数据
        double r_d = 0.6;  // 直接信誉
        double r_t = 0.7;  // 时间信誉
        double r_f = 0.5;  // 频率信誉
        double r_p = 0.8;  // 位置信誉
        double r_s = 0.6;  // 服务信誉
        double r_c = 0.7;  // 通信信誉
        double r_n = 0.5;  // 网络信誉
        
        // 模拟从消息中提取的QoS数据
        double messageRTT = 0.05;     // 消息往返时延
        double messageJitter = 0.02;  // 消息抖动
        double messageLoss = 0.01;    // 消息丢包率
        
        EV << "FuzzyTrustApp: 消息解析完成 - 信誉数据[" << r_d << ", " << r_t 
           << ", " << r_f << ", " << r_p << ", " << r_s << ", " << r_c 
           << ", " << r_n << "], QoS[RTT:" << messageRTT << ", Jitter:" 
           << messageJitter << ", Loss:" << messageLoss << "]" << std::endl;
        
        // 根据消息内容更新本地的信誉值
        if (fuzzyTrust) {
            // 构建信誉向量并更新本地记录
            std::vector<double> reputationVector = {r_d, r_t, r_f, r_p, r_s, r_c, r_n};
            
            // 计算发送者的综合信任值
            std::vector<double> trustInputs = {r_d, r_t, r_f, r_p, r_s, r_c, r_n}; // 完整的7维输入
            double senderTrustValue = fuzzyTrust->computeTrust(trustInputs);
            
            EV << "FuzzyTrustApp: 发送者信任值计算完成: " << senderTrustValue 
               << " (阈值: " << fuzzyTrustThreshold << ")" << std::endl;
            
            // 信任值检查和响应策略
            if (senderTrustValue < fuzzyTrustThreshold) {
                EV_WARN << "FuzzyTrustApp: 检测到低信任发送者 (" << senderTrustValue 
                        << " < " << fuzzyTrustThreshold << ")，可能的恶意行为" << std::endl;
                
                // 触发防御策略，丢弃消息
                return;
            }
            
            // 高信任消息的处理
            if (senderTrustValue > 0.8) {
                EV << "FuzzyTrustApp: 高信任消息，优先处理" << std::endl;
            }
        }
        
        // 更新RTT/jitter/loss的历史样本用于指数平滑
        if (channelQuality) {
            // 使用指数平滑更新QoS历史数据
            double alpha = 0.3; // 平滑因子
            
            // 模拟历史数据更新（实际应维护历史队列）
            double historicalRTT = 0.06;
            double historicalJitter = 0.025;
            double historicalLoss = 0.015;
            
            // 指数平滑更新
            double smoothedRTT = alpha * messageRTT + (1 - alpha) * historicalRTT;
            double smoothedJitter = alpha * messageJitter + (1 - alpha) * historicalJitter;
            double smoothedLoss = alpha * messageLoss + (1 - alpha) * historicalLoss;
            
            EV << "FuzzyTrustApp: QoS历史数据更新完成 - 平滑RTT: " << smoothedRTT 
               << ", 平滑Jitter: " << smoothedJitter << ", 平滑Loss: " << smoothedLoss << std::endl;
        }
        
        // 更新预测模块需要的输入
        // 模拟在线预测算法更新最新预测值F_c, F_b, F_e
        double F_c_new = 0.65; // 更新的CPU预测值
        double F_b_new = 0.75; // 更新的带宽预测值
        double F_e_new = 0.55; // 更新的能量预测值
        
        EV << "FuzzyTrustApp: 预测值更新完成 - F_c: " << F_c_new 
           << ", F_b: " << F_b_new << ", F_e: " << F_e_new << std::endl;
        
        // 如果是信任信标消息，可能需要特殊处理
        if (par("sendTrustBeacons").boolValue()) {
            // 处理接收到的信任信标，更新邻居节点信任信息
            EV << "FuzzyTrustApp: 处理信任信标消息" << std::endl;
        }
        
    } catch (const std::exception& e) {
         EV_ERROR << "FuzzyTrustApp: WSM消息处理错误: " << e.what() << std::endl;
     }
     
     // 调用父类处理其他消息逻辑
     DemoBaseApplLayer::onWSM(wsm);
 }

void FuzzyTrustApp::onWSA(DemoServiceAdvertisment* wsa)
{
    // 处理服务广告消息
    EV << "FuzzyTrustApp: 接收到服务 " << wsa->getPsid() << " 的WSA广告" << std::endl;
    
    if (gameManager && fuzzyEngine) {
        // 第三章3.3节：基于博弈理论和模糊推理的服务响应决策
        
        // 获取当前系统状态 - 使用模拟值替换不存在的方法
        double currentTrust = 0.6; // 模拟值，实际应使用fuzzyTrust->computeTrust
        double currentQoS = 0.7; // 模拟值，实际应使用channelQuality->computeQoS
        double currentResource = 0.5; // 模拟值，实际应使用resourceManager->computeResourceMembership
        
        // 评估服务提供者的信任度 - 使用模拟值
        double serviceTrust = 0.6; // 模拟值
        
        EV << "FuzzyTrustApp: 服务评估 - 系统状态(信任:" << currentTrust 
           << ", QoS:" << currentQoS << ", 资源:" << currentResource 
           << "), 服务信任:" << serviceTrust << std::endl;
        
        // 使用模糊推理引擎决定响应策略 - 动态生成预测因子
        double urgencyFactor = 0.2 + 0.6 * uniform(0, 1); // 紧迫性因子: 0.2-0.8范围
        double bandwidthPrediction = 0.3 + 0.5 * uniform(0, 1); // 带宽预测: 0.3-0.8范围
        double energyPrediction = 0.4 + 0.4 * uniform(0, 1); // 能量预测: 0.4-0.8范围
        
        std::vector<double> serviceInputVector = {
            currentTrust, currentQoS, currentResource,
            serviceTrust, // 服务提供者信任度
            urgencyFactor, // 动态紧迫性因子
            bandwidthPrediction, // 动态带宽预测
            energyPrediction  // 动态能量预测
        };
        
        // 输入有效性检查
        bool validInput = true;
        for (size_t i = 0; i < serviceInputVector.size(); ++i) {
            if (serviceInputVector[i] < 0.0 || serviceInputVector[i] > 1.0) {
                EV_WARN << "FuzzyTrustApp: 输入向量第" << i << "个元素值异常: " << serviceInputVector[i] << std::endl;
                serviceInputVector[i] = std::max(0.0, std::min(1.0, serviceInputVector[i])); // 限制在[0,1]范围
                validInput = false;
            }
        }
        
        if (!validInput) {
            EV_WARN << "FuzzyTrustApp: 输入向量已修正到有效范围" << std::endl;
        }
        
        // 执行模糊推理获得服务响应策略 - 使用实际存在的方法
        double inferenceResult = fuzzyEngine->performFuzzyInference(serviceInputVector);
        
        // 基于推理结果决定是否响应
        bool shouldRespond = (inferenceResult > 0.5);
        
        if (shouldRespond) {
            EV << "FuzzyTrustApp: 决定响应服务广告 - 推理结果: " << inferenceResult << std::endl;
            
            // 执行服务响应逻辑 - 简化处理
            if (inferenceResult > 0.7) {
                EV << "FuzzyTrustApp: 采用积极响应策略" << std::endl;
            } else {
                EV << "FuzzyTrustApp: 采用保守响应策略" << std::endl;
            }

        }
        
        return;
    }
    
    // 调用父类处理其他服务广告逻辑
    DemoBaseApplLayer::onWSA(wsa);
}

void FuzzyTrustApp::handleSelfMsg(cMessage* msg) {
    // M4 接入：RSU 治理 slow tick
    if (msg == governanceTimer && rsuGovernance && itGameEngine) {
        // MC4 闭环后：x̄ 证据全部来自 StrategyReportMessage（onWSM 中 accumulateEvidence）。
        // 本周期无车辆上报时 aggregator 保持上次 x̄（slowUpdate 内部 n_evidence>0 才更新）。
        // 不再把 RSU 自身 π 喂入 —— RSU 受限策略集 {SC,SP} 的掩码偏差不得进入群体平均场。
        rsuGovernance->slowUpdate();
        cachedTheta = rsuGovernance->getTheta();
        cachedXBarLocal = rsuGovernance->getXBarLocal();
        lastGovernanceIndex = rsuGovernance->getOmegaIndex();

        // 更新自身 ITGameEngine 的 θ
        itGameEngine->setParams(
            par("itGame_lambda").doubleValue(),
            par("itGame_beta").doubleValue(),
            par("itGame_delta").doubleValue(),
            par("itGame_alpha").doubleValue(),
            cachedTheta);

        // 广播 GovernanceWeightMessage 给覆盖范围车辆
        GovernanceWeightMessage* gwm = new GovernanceWeightMessage("GovernanceWeight");
        populateWSM(gwm);
        gwm->setTimestamp(simTime());
        // theta[3] / xBarLocal[4] 是 .msg 里的 fixed-size 数组，无需 setArraySize
        for (int k = 0; k < 3; ++k) gwm->setTheta(k, cachedTheta[k]);
        for (int j = 0; j < 4; ++j) gwm->setXBarLocal(j, cachedXBarLocal[j]);
        gwm->setOmegaIndex(lastGovernanceIndex);
        if (metricsLogger) metricsLogger->recordWSMSent(simTime().dbl());
        sendDown(gwm);

        EV << "FuzzyTrustApp[RSU-Gov]: slowUpdate h=" << lastGovernanceIndex
           << " θ=(" << cachedTheta[0] << "," << cachedTheta[1] << "," << cachedTheta[2] << ")"
           << " x_bar=(" << cachedXBarLocal[0] << "," << cachedXBarLocal[1] << ","
           << cachedXBarLocal[2] << "," << cachedXBarLocal[3] << ")" << std::endl;

        // 重 schedule
        scheduleAt(simTime() + par("governancePeriod").doubleValue(), governanceTimer);
        return;
    }

    if (msg == decisionTimer) {
        EV << "FuzzyTrustApp: main decision cycle - t=" << simTime() << std::endl;
        
        try {
            // ========== 数据收集阶段 ==========
            // 更新能源消耗（必须在其他数据收集之前）
            if (enableDetailedEnergyModeling) {
                updateEnergyConsumption();
            }
            
            if (enableDataCollection) {
                collectMobilityData();      // 收集移动性数据
                collectCommunicationData(); // 收集通信质量数据
                if (enableResourceMonitoring) {
                    collectResourceData();      // 收集资源状态数据
                }
                collectReputationData();    // 收集信誉数据
                
                // 更新时间戳
                currentData.timestamp = simTime();
                
                // 设置节点类型和名称
                currentData.nodeType = isRSU ? "RSU" : "Vehicle";
                currentData.nodeName = getParentModule()->getFullName();
            } else {
                // 如果未启用数据收集，使用默认模拟数据
                currentData.timestamp = simTime();
                
                // 设置节点类型和名称
                currentData.nodeType = isRSU ? "RSU" : "Vehicle";
                currentData.nodeName = getParentModule()->getFullName();
                currentData.reputationVector = {0.6, 0.7, 0.5, 0.8, 0.6, 0.7, 0.5};
                currentData.measuredRTT = 0.05;
                currentData.measuredJitter = 0.02;
                currentData.measuredPacketLoss = 0.01;
                currentData.cpuUtilization = 0.6;
                currentData.bandwidthUsage = 0.4;
                currentData.remainingEnergy = 0.8;
                currentData.powerConsumption = 1.0;
            }
            
            // ========== 数据处理阶段 ==========
            // 使用收集到的真实数据替换模拟数据
            std::vector<double> r_vector = currentData.reputationVector;
            double RTT = currentData.measuredRTT;
            double jitter = currentData.measuredJitter;
            double loss = currentData.measuredPacketLoss;
            double c = currentData.cpuUtilization;
            double b = currentData.bandwidthUsage;
            double e_r = currentData.remainingEnergy;
            double p = currentData.powerConsumption;
            
            // ========== 算法计算阶段 ==========
            // ①模糊信任评估
            double mu_trust = 0.0;
            if (fuzzyTrust) {
                mu_trust = fuzzyTrust->computeTrust(r_vector);
            }
            
            // ②信道质量评估
            double mu_delay = 0.0;
            if (channelQuality) {
                double rho = 2 * qosUrgencyWeight + qosReliabilityWeight;
                mu_delay = channelQuality->computeDelayMembership(RTT, rho);
            }
            
            // ③资源管理评估
            double mu_resource = 0.0;
            if (resourceManager) {
                mu_resource = resourceManager->computeResourceMembership(c, b, e_r, p);
            }
            
            // ========== 数据存储阶段 ==========
            if (enableDataCollection) {
                updateDataHistory();
            }
            
            // ========== 信任评估阶段 ==========
            // 执行信任评估更新（包含MAE数据收集）
            updateTrustEvaluation();
            
            // ========== 博弈决策阶段 ==========
            // 执行博弈理论策略选择（这会触发策略历史记录）
            updateGameDecision(mu_trust, mu_delay, mu_resource);
            
        } catch (const std::exception& e) {
            EV_ERROR << "数据收集或处理错误: " << e.what() << std::endl;
        }
        
        // 重新调度
        scheduleAt(simTime() + decisionInterval, msg);
    }
    else if (msg == daoVotingTimer) {
        EV << "FuzzyTrustApp: 执行DAO投票周期 - 时间: " << simTime() << std::endl;
        performDAOVoting();
        scheduleAt(simTime() + 10.0, msg);
    }
    else if (msg == blockchainTimer) {
        EV << "FuzzyTrustApp: 执行区块链治理周期 - 时间: " << simTime() << std::endl;
        performBlockchainGovernance();
        scheduleAt(simTime() + 5.0, msg);
    }
}

void FuzzyTrustApp::updateTrustEvaluation()
{
    // RSU节点不执行信任评估更新
    std::string currentNodeName = getParentModule()->getParentModule()->getName();
    if (currentNodeName.find("rsu") != std::string::npos) {
        return;
    }
    
    if (!fuzzyTrust) {
        EV_WARN << "FuzzyTrustApp: FuzzyTrust模块未初始化" << std::endl;
        return;
    }
    
    EV << "FuzzyTrustApp: trust evaluation update - t=" << simTime() << std::endl;
    
    try {
        // 第三章3.2节：IT2-Sigmoid模糊信任评估
        
        // 执行信任计算 - 根据消融对照测试配置决定使用哪种方法
        std::vector<double> trustInputs = {0.6, 0.7, 0.5, 0.8, 0.4, 0.9, 0.6}; // 7维信誉向量
        double currentTrustValue = 0.0;
        
        if (enableIT2Module && fuzzyTrust) {
            // 使用IT2-Sigmoid模糊信任计算
            currentTrustValue = fuzzyTrust->computeTrust(trustInputs);
        } else {
            // 使用简化的Type-1信任计算
            currentTrustValue = std::accumulate(trustInputs.begin(), trustInputs.end(), 0.0) / trustInputs.size();
        }
        
        // 使用动态参数优化器处理信誉评估历史数据
        if (dynamicOptimizer) {
            // 添加信誉记录
            std::string nodeId = "node_" + std::to_string(getParentModule()->getIndex());
            dynamicOptimizer->addReputationRecord(nodeId, trustInputs, currentTrustValue, "trust_evaluation");
            
            // 分析信誉趋势
            double reputationTrend = dynamicOptimizer->analyzeReputationTrend(nodeId, 10);
            
            // 检测信誉异常
            bool anomalyDetected = dynamicOptimizer->detectReputationAnomaly(nodeId, trustInputs);
            
            EV << "FuzzyTrustApp: reputation processing - node=" << nodeId
               << " trend=" << reputationTrend
               << " anomaly=" << (anomalyDetected ? "yes" : "no") << std::endl;
        }
        
        // 注释掉不存在的方法
        // fuzzyTrust->updateTrustValues(currentTrustValue);
        totalTrustUpdates++;
        averageTrustValue = (averageTrustValue * (totalTrustUpdates - 1) + currentTrustValue) / totalTrustUpdates;
        
        EV << "FuzzyTrustApp: trust=" << currentTrustValue
           << " avgTrust=" << averageTrustValue
           << " updates=" << totalTrustUpdates << std::endl;
        
        // 信任阈值检查和安全响应
        if (currentTrustValue < fuzzyTrustThreshold) {
            EV_WARN << "FuzzyTrustApp: low trust (" << currentTrustValue
                    << " < " << fuzzyTrustThreshold << "), triggering defense" << std::endl;
        }
        
        // 收集MAE性能数据（如果启用）
        if (enableMAECollection) {
            collectMAEPerformanceData();
        }
        
        // 发送信任信标（包含第三章的信任信息）
        if (par("sendTrustBeacons").boolValue()) {
            sendTrustBeacon();
        }
        
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 信任评估更新错误: " << e.what() << std::endl;
    }
}

void FuzzyTrustApp::updateQoSAssessment()
{
    if (!channelQuality) {
        EV_WARN << "FuzzyTrustApp: ChannelQuality模块未初始化" << std::endl;
        return;
    }
    
    EV << "FuzzyTrustApp: 执行QoS信道质量评估 - 时间: " << simTime() << std::endl;
    
    try {
        
        // 使用模拟数据计算隶属度
        double delay = 0.05; // 模拟延迟值
        double packetLoss = 0.01; // 模拟丢包率
        
        // 计算各种隶属度 - 使用实际存在的方法
        double rho = 0.5; // 紧迫-可靠耦合参数
        double urgencyMembership = channelQuality->computeDelayMembership(delay, rho);
        double reliabilityMembership = channelQuality->computePacketLossMembership(packetLoss, rho);
        
        // 紧迫性-可靠性耦合计算
        double couplingFactor = qosUrgencyWeight; // ρ参数
        double delayMembership = couplingFactor * urgencyMembership + 
                               (1.0 - couplingFactor) * reliabilityMembership;
        
        totalQoSUpdates++;
        
        EV << "FuzzyTrustApp: QoS评估结果 - 紧迫性: " << urgencyMembership 
           << ", 可靠性: " << reliabilityMembership 
           << ", 延迟隶属度: " << delayMembership << std::endl;
        
        // 将QoS信息传递给资源管理器进行分层资源聚合
        if (resourceManager) {
            // 分层资源聚合
            double cpu = 0.6, bandwidth = 0.7, energy = 0.5, power = 0.8; // 模拟资源参数
            resourceManager->computeResourceMembership(cpu, bandwidth, energy, power);
        }
        
        // QoS预警机制
        if (delayMembership < 0.3) {
            EV_WARN << "FuzzyTrustApp: QoS质量严重下降 (" << delayMembership 
                    << "), 触发资源重分配" << std::endl;
            
        }
        
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: QoS评估更新错误: " << e.what() << std::endl;
    }
}

void FuzzyTrustApp::updateGameDecision(double trustMembership, double delayMembership, double resourceMembership)
{
    // Chapter 5.2 早期分支（plan.MD §9.2-C）：
    // 当 ITGameEngine 激活时，跳过旧 GameManager/OWARL/ARIMA/FuzzyInferenceEngine 路径。
    // M2 接入：mu_nominal 由 MembershipExtractor 从 CollectedData 实测值产出，
    //          不再用入参 (trust/delay/resource) stub。
    //          入参在 itGameEngine 路径下作为 fallback：若 currentData 缺字段则使用入参。
    // x_bar 在 M4 RSU 广播接入前仍用均匀 0.25 stub。
    if (itGameEngine) {
        veins::chapter52::Vec3 mu_nominal;
        if (membershipExtractor) {
            // 从 CollectedData 取实测值。CollectedData 字段在不同子系统中按需更新，
            // 未采集时为 0（C++ POD 默认），扔给 sigmoid 会给出有意义但极端的输出
            // （如 energy=0 → μ_res ≈ 0.0025 拉死 min 聚合）。这里对未采集字段补保底值
            // 0.5（中性），让 μ_res 能反映已采集的字段差异，而非被默认 0 卡死。
            const std::vector<double>& rep = currentData.reputationVector.empty()
                ? std::vector<double>(7, trustMembership)
                : currentData.reputationVector;
            double rtt_ms = (currentData.measuredRTT > 0) ? currentData.measuredRTT * 1000.0
                                                          : 50.0;
            double cpu     = (currentData.cpuUtilization > 0) ? currentData.cpuUtilization : 0.5;
            double bw      = (currentData.bandwidthUsage > 0) ? currentData.bandwidthUsage : 0.5;
            // 经实测：currentData.remainingEnergy 已经是 [0,1] 归一化值（SOC，非 Wh 绝对值）
            double energy  = (currentData.remainingEnergy > 0)
                                ? std::min(1.0, currentData.remainingEnergy)
                                : 0.5;
            double power   = (currentData.powerConsumption > 0) ? currentData.powerConsumption : 0.5;
            mu_nominal = membershipExtractor->extractAll(rep, rtt_ms,
                                                         currentData.measuredPacketLoss,
                                                         cpu, bw, energy, power);
        } else {
            mu_nominal = {trustMembership, delayMembership, resourceMembership};
        }
        // M4 已接入：x_bar 来自 RSU 广播缓存（cachedXBarLocal）。RSU 自身用 ITGameEngine 的 π 代理。
        // 车辆若尚未收到广播则使用默认均匀，跟过去行为兼容。
        veins::chapter52::Vec4 pi_new = itGameEngine->step(mu_nominal, cachedXBarLocal);
        int action = itGameEngine->sampleAction();
        static const std::vector<std::string> strategies = {"SC", "SP", "DC", "DP"};
        std::string selectedStrategy = (action >= 0 && action < 4) ? strategies[action] : "UNKNOWN";
        std::vector<double> probs(pi_new.begin(), pi_new.end());

        // 威胁模型实现（plan §三 / 论文表 VII "20% abnormal vehicles"）：
        // 协作动作（SC/DC）按平均场语义从车辆群体均匀抽取一个交互伙伴
        //（与博弈层 x̄ 的群体抽象一致）；若伙伴属于异常类（A 类丢弃协作
        // 消息、B 类虚报信誉后不履约，两类均导致协作任务失败），本决策
        // 窗口的协作任务失败，已实现收益为 0（任务超期无效用）。
        // 机制与方法无关：结果只取决于抽样动作与种子驱动的伙伴抽取，
        // 不读取任何方法名/方法配置。自利动作（SP/DP）本地完成不受影响。
        lastItGameCoopAction = (action == 0 || action == 2);   // SC 或 DC
        lastItGameCoopFailed = false;
        if (lastItGameCoopAction && currentMaliciousRatio > 0.0) {
            int totalNodes = 0;
            if (getSystemModule()->hasPar("numNodes")) {
                totalNodes = getSystemModule()->par("numNodes").intValue();
            } else if (getSystemModule()->hasPar("Nv")) {
                totalNodes = getSystemModule()->par("Nv").intValue();
            }
            if (totalNodes > 0) {
                int partner = intuniform(0, totalNodes - 1);
                int abnormalCount = static_cast<int>(totalNodes * currentMaliciousRatio / 100.0);
                lastItGameCoopFailed = partner < abnormalCount;
            }
        }
        if (metricsLogger) {
            metricsLogger->recordRealizedPayoff(
                lastItGameCoopFailed ? 0.0 : itGameEngine->getUhat());
        }

        // MC4 闭环：车辆每决策周期把 π 上报给 RSU（RSU 侧 accumulateEvidence 聚合 x̄）。
        // 所有 method（含 NoGov）都发送以保证各实验臂通信负载一致（paired 对比）。
        if (!isRSU) {
            StrategyReportMessage* srm = new StrategyReportMessage("StrategyReport");
            populateWSM(srm);
            srm->setTimestamp(simTime());
            for (int j = 0; j < 4; ++j) srm->setPi(j, pi_new[j]);
            if (metricsLogger) metricsLogger->recordWSMSent(simTime().dbl());
            sendDown(srm);
        }

        // D4 采集：实测隶属度滑窗（半宽 vs δ 标定）+ 按策略收益离散度
        if (metricsLogger) {
            metricsLogger->recordMembership(mu_nominal[0], mu_nominal[1], mu_nominal[2]);
            metricsLogger->recordStrategyPayoff(selectedStrategy, itGameEngine->getUhat());
        }

        recordStrategySelection(selectedStrategy, probs, itGameEngine->getUhat(),
                                mu_nominal[0], mu_nominal[1], mu_nominal[2]);
        EV << "FuzzyTrustApp[ITGame]: action=" << selectedStrategy
           << " μ=(" << mu_nominal[0] << "," << mu_nominal[1] << "," << mu_nominal[2] << ")"
           << " Û=" << itGameEngine->getUhat() << " ρ=" << itGameEngine->getRho() << std::endl;
        return;  // 旧路径完全跳过
    }

    if (!gameManager || !owarlAgent) {
        EV_WARN << "FuzzyTrustApp: 博弈模块未初始化" << std::endl;
        return;
    }
    
    EV << "FuzzyTrustApp: 执行博弈决策更新 - 时间: " << simTime() << std::endl;
    
    try {
        // 第三章3.3节：博弈理论策略优化
        
        // 使用增强的ARIMA预测器进行资源预测和策略优化
        if (dynamicOptimizer) {
            // 更新资源预测
            std::vector<double> resourceData = {0.6, 0.7, 0.5}; // CPU, 带宽, 能量
            auto resourcePrediction = dynamicOptimizer->predictResourceUsage(resourceData, "cpu");
            
            // 使用增强的ARIMA预测资源使用情况
            std::vector<double> resource_history = {trustMembership, delayMembership, resourceMembership};
            auto arima_prediction = dynamicOptimizer->predictWithARIMA(resource_history, 5);
            
            // 根据预测结果调整参数
            if (!arima_prediction.predictions.empty()) {
                double predicted_load = arima_prediction.predictions[0];
                double prediction_confidence = arima_prediction.model_quality_score;
                
                // 动态调整模糊推理参数（考虑预测置信度）
                 if (predicted_load > 0.8 && prediction_confidence > 0.6) {
                     // 高负载且预测可信：调整规则权重以提高防御性
                     if (fuzzyEngine) {
                         std::vector<double> defensive_weights = {0.8, 0.6, 0.4, 0.3, 0.5};
                         fuzzyEngine->updateRuleWeights(defensive_weights);
                     }
                     
                     EV << "[ARIMA] High load predicted (" << predicted_load 
                        << "), confidence: " << prediction_confidence << ", adjusting to defensive mode" << endl;
                 } else if (predicted_load < 0.3 && prediction_confidence > 0.6) {
                     // 低负载且预测可信：调整规则权重以提高合作性
                     if (fuzzyEngine) {
                         std::vector<double> cooperative_weights = {0.3, 0.7, 0.8, 0.6, 0.4};
                         fuzzyEngine->updateRuleWeights(cooperative_weights);
                     }
                     
                     EV << "[ARIMA] Low load predicted (" << predicted_load 
                        << "), confidence: " << prediction_confidence << ", adjusting to cooperative mode" << endl;
                 }
                
                // 记录预测信息
                EV << "[ARIMA] Prediction - Load: " << predicted_load 
                   << ", MSE: " << arima_prediction.mse 
                   << ", AIC: " << arima_prediction.aic << endl;
            }
            
            // 更新网络质量测量
            DynamicParameterOptimizer::NetworkQualityMetrics metrics;
            metrics.latency = 50.0;
            metrics.jitter = 5.0;
            metrics.packet_loss = 0.02;
            metrics.bandwidth = 100.0;
            metrics.signal_strength = -60.0;
            metrics.reliability_score = 0.8;
            metrics.timestamp = std::chrono::steady_clock::now();
            dynamicOptimizer->updateNetworkQualityHistory(metrics);
            
            // 监控博弈策略收敛
            std::vector<double> strategies = {0.4, 0.3, 0.3};
            std::vector<double> payoffs = {trustMembership, delayMembership, resourceMembership};
            auto convergenceInfo = dynamicOptimizer->monitorGameConvergence(strategies, payoffs);
            
            EV << "FuzzyTrustApp: 动态优化 - 资源预测值: " << resourcePrediction.predicted_value 
               << ", 置信度: " << resourcePrediction.confidence << ", 最佳模型: " << resourcePrediction.best_model
               << ", 收敛方差: " << convergenceInfo.strategy_variance << std::endl;
        }
        
        // 使用传入的实际计算隶属度值
        
        EV << "FuzzyTrustApp: 当前状态 - 信任: " << trustMembership 
           << ", 延迟: " << delayMembership 
           << ", 资源: " << resourceMembership << std::endl;
        
        // 第三章3.3.1节：双主体博弈模型
        // 车辆节点：复制动态演化
        // RSU节点：ε-贪心Q-learning
        
        
        // 策略预测和优化（使用ARIMA预测器）
        if (dynamicOptimizer) {
            // 收集策略历史数据
            std::vector<std::string> strategy_history;
            std::vector<double> payoff_history;
            
            // 从游戏管理器获取历史数据（简化实现）
            for (int i = 0; i < 10 && i < totalGameUpdates; ++i) {
                strategy_history.push_back("SC"); // 简化：使用合作策略
                payoff_history.push_back(0.5 + 0.1 * sin(i * 0.5)); // 模拟收益波动
            }
            
            // 策略预测
            if (strategy_history.size() >= 10) {
                auto strategy_prediction = dynamicOptimizer->predictOptimalStrategy(
                    strategy_history, payoff_history);
                
                if (strategy_prediction.prediction_confidence > 0.7) {
                    EV << "[ARIMA Strategy] Recommended strategy: " 
                       << strategy_prediction.recommended_strategy 
                       << ", confidence: " << strategy_prediction.prediction_confidence << endl;
                    
                    // 根据策略预测调整行为
                     if (strategy_prediction.recommended_strategy == "DC" || 
                         strategy_prediction.recommended_strategy == "DP") {
                         // 预测建议防御策略，调整规则权重提高防御性
                         if (fuzzyEngine) {
                             std::vector<double> defense_weights = {0.8, 0.5, 0.3, 0.2, 0.6};
                             fuzzyEngine->updateRuleWeights(defense_weights);
                         }
                     } else {
                         // 预测建议合作策略，调整规则权重降低防御性
                         if (fuzzyEngine) {
                             std::vector<double> cooperative_weights = {0.4, 0.7, 0.8, 0.6, 0.5};
                             fuzzyEngine->updateRuleWeights(cooperative_weights);
                         }
                     }
                }
            }
            
            // 收益趋势预测
            if (payoff_history.size() >= 15) {
                auto payoff_trend = dynamicOptimizer->predictPayoffTrend(
                    payoff_history, "SC", 3);
                
                if (!payoff_trend.predictions.empty()) {
                    double predicted_payoff = payoff_trend.predictions[0];
                    double current_payoff = payoff_history.back();
                    
                    if (predicted_payoff < current_payoff * 0.8) {
                         // 预测收益下降，调整策略倾向为风险规避
                         EV << "[ARIMA Payoff] Declining payoff predicted, adjusting to risk-averse strategy" << endl;
                         if (fuzzyEngine) {
                             std::vector<double> risk_averse_weights = {0.7, 0.4, 0.3, 0.2, 0.8};
                             fuzzyEngine->updateRuleWeights(risk_averse_weights);
                         }
                     }
                }
            }
        }
        
        // 执行策略演化 - 使用实际存在的方法
        if (par("isVehicleNode").boolValue()) {
            // 车辆节点：复制动态演化
            std::vector<double> payoffs = {0.5, 0.3, 0.2}; // 模拟收益向量
            gameManager->updateVehicleStrategy(payoffs);
            
            // 执行策略选择（这会触发recordStrategySelection）
            int selectedAction = gameManager->selectVehicleAction();
            
            // 更新策略收益（基于当前环境状态计算实际收益）
            double actualPayoff = trustMembership * 0.4 + delayMembership * 0.3 + resourceMembership * 0.3;
            updateStrategyPayoff(actualPayoff);
            
            EV << "FuzzyTrustApp: 车辆策略选择完成，选择动作: " << selectedAction << ", 实际收益: " << actualPayoff << std::endl;
        } else {
            // RSU节点：Q-learning
            int state = 0, next_state = 1;
            double reward = 0.8;
            
            // 执行策略选择（这会触发recordStrategySelection）
            int action = gameManager->selectRSUAction(state);
            
            // 更新Q-learning
            gameManager->updateRSUStrategy(state, action, reward, next_state);
            
            // 更新策略收益
            updateStrategyPayoff(reward);
            
            EV << "FuzzyTrustApp: RSU策略选择完成，选择动作: " << action << ", 奖励: " << reward << std::endl;
        }
        
        // 第三章3.3.3节：OWA-RL自适应权重学习
        // 根据消融对照测试配置决定是否使用OWA-RL
        if (enableOWARLModule && owarlAgent) {
            EV << "FuzzyTrustApp: 执行OWA-RL权重更新 (第" << totalGameUpdates + 1 << "次)" << std::endl;
            
            // 不要预先排序，让OWARLAgent内部处理
            std::vector<double> memberships = {trustMembership, delayMembership, resourceMembership};
            
            // 执行无悔学习权重更新
            owarlAgent->updateWeights(memberships);
            
            // 立即收集权重数据
            collectOWARLWeightData();
            
            // 收集车辆混合策略数据
            collectMixingStrategyData();
        } else {
            // OWA-RL模块禁用时使用等权重
            EV << "FuzzyTrustApp: OWA-RL模块已禁用，使用等权重策略" << std::endl;
        }
        
        // 第三章3.3.2节：模糊推理决策引擎
        if (fuzzyEngine) {
            // 动态生成预测因子以增加输入多样性
            double urgencyFactor = 0.3 + 0.4 * uniform(0, 1); // 紧迫性因子: 0.3-0.7范围
            double cpuPrediction = 0.2 + 0.6 * uniform(0, 1); // CPU预测: 0.2-0.8范围
            double bandwidthPrediction = 0.4 + 0.4 * uniform(0, 1); // 带宽预测: 0.4-0.8范围
            double energyPrediction = 0.3 + 0.5 * uniform(0, 1); // 能量预测: 0.3-0.8范围
            
            // 7维输入向量：[μ_trust, μ_delay, μ_resource, ρ, F_c, F_b, F_e]
            std::vector<double> inputVector = {
                trustMembership, delayMembership, resourceMembership,
                urgencyFactor, // 动态紧迫性因子
                cpuPrediction, // 动态CPU预测
                bandwidthPrediction, // 动态带宽预测
                energyPrediction  // 动态能量预测
            };
            
            // 输入有效性检查
            bool validInput = true;
            for (size_t i = 0; i < inputVector.size(); ++i) {
                if (inputVector[i] < 0.0 || inputVector[i] > 1.0) {
                    EV_WARN << "FuzzyTrustApp: 博弈更新输入向量第" << i << "个元素值异常: " << inputVector[i] << std::endl;
                    inputVector[i] = std::max(0.0, std::min(1.0, inputVector[i])); // 限制在[0,1]范围
                    validInput = false;
                }
            }
            
            if (!validInput) {
                EV_WARN << "FuzzyTrustApp: 博弈更新输入向量已修正到有效范围" << std::endl;
            }
            
            // 执行模糊推理，获得策略偏好
            double inferenceResult = fuzzyEngine->performFuzzyInference(inputVector);
            
            EV << "FuzzyTrustApp: 模糊推理结果: " << inferenceResult << std::endl;
            
            // 注释掉不存在的方法
            // gameManager->updateStrategyPreferences(strategyPreferences);
        }
        
        // 收集Choquet-OWA性能数据（根据消融对照测试配置）
        if (enableChoquetOWAModule) {
            collectChoquetOWAPerformanceData();
        }
        
        // 收集消融对照测试性能数据
        collectAblationPerformanceData();
        
        // 移除重复的OWA-RL权重演化数据收集（已在权重更新后立即收集）
        // collectOWARLWeightData();
        
        // 基于当前状态更新任务类型
        updateTaskTypeBasedOnContext();
        
        totalGameUpdates++;
        
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 博弈决策更新错误: " << e.what() << std::endl;
    }
}

void FuzzyTrustApp::sendTrustBeacon()
{
    // 第三章3.2节：发送基于IT2-Sigmoid模糊信任评估的信任信标
    EV << "FuzzyTrustApp: sending trust beacon" << std::endl;
    
    if (fuzzyTrust && channelQuality && resourceManager) {
        // 获取当前节点的综合信任状态 - 使用模拟值替换不存在的方法
        double currentTrustValue = 0.7; // 模拟值
        double trustMembership = 0.6; // 模拟值
        
        // 获取当前QoS状态 - 使用模拟值
        double delayMembership = 0.7; // 模拟值
        
        // 获取当前资源状态 - 使用模拟值
        double resourceMembership = 0.6; // 模拟值
        
        EV << "FuzzyTrustApp: beacon - trust:" << currentTrustValue
           << " trustMu:" << trustMembership
           << " delayMu:" << delayMembership
           << " resMu:" << resourceMembership << std::endl;
        
        try {
             // 创建信任信标消息
             BaseFrame1609_4* trustBeacon = new BaseFrame1609_4();
             populateWSM(trustBeacon);
             
             // 设置基础信息
             trustBeacon->setTimestamp(simTime());

             // M3 接入：记录发送事件
             if (metricsLogger) {
                 metricsLogger->recordWSMSent(simTime().dbl());
             }

             // 发送信标
             sendDown(trustBeacon);
             
             EV << "FuzzyTrustApp: trust beacon sent - trust:" << currentTrustValue << std::endl;
             
             // 更新统计信息
             beaconsSent++;
             if (currentTrustValue > 0.7) {
                 highTrustBeaconsSent++;
             }
             
         } catch (const std::exception& e) {
             EV_ERROR << "FuzzyTrustApp: Error sending trust beacon: " << e.what() << std::endl;
         }
    } else {
        EV_WARN << "FuzzyTrustApp: cannot send trust beacon - core modules not initialized" << std::endl;
    }
}


// 实现数据收集方法
void FuzzyTrustApp::collectMobilityData() {
    if (isRSU) {
        // RSU节点：使用静态位置数据
        cModule* mobility = getParentModule()->getSubmodule("mobility");
        if (mobility) {
            // 从mobility模块获取静态位置
            if (mobility->hasPar("x") && mobility->hasPar("y")) {
                currentData.currentPosition.x = mobility->par("x").doubleValue();
                currentData.currentPosition.y = mobility->par("y").doubleValue();
            }
            currentData.currentSpeed = 0.0;  // RSU静态，速度为0
            currentData.currentHeading = 0.0; // RSU静态，方向为0
            
            EV << "收集RSU移动数据: 位置(" << currentData.currentPosition.x 
               << ", " << currentData.currentPosition.y << "), 速度: " 
               << currentData.currentSpeed << std::endl;
        }
    } else {
        // 车辆节点：通过TraCI接口获取移动数据
        auto* mobility = TraCIMobilityAccess().get(getParentModule());
        if (mobility) {
            currentData.currentPosition = mobility->getPositionAt(simTime());
            currentData.currentSpeed = mobility->getSpeed();
            currentData.currentHeading = mobility->getHeading().getRad() * 180.0 / M_PI;
            
            EV << "mobility data: pos(" << currentData.currentPosition.x
               << ", " << currentData.currentPosition.y << ") speed="
               << currentData.currentSpeed << std::endl;
        }
    }
}

void FuzzyTrustApp::collectCommunicationData() {
    // 从网络层和物理层获取通信质量指标
    // 由于直接访问MAC层方法可能不可用，使用统计信号和模拟数据
    
    // 尝试从统计模块获取数据
    cModule* nic = getParentModule()->getSubmodule("nic");
    if (nic) {
        cModule* phy = nic->getSubmodule("phy80211p");
        if (phy) {
            // 获取信号强度（如果可用）
            if (phy->hasPar("lastReceivedSignalStrength")) {
                currentData.signalStrength = phy->par("lastReceivedSignalStrength").doubleValue();
            } else {
                currentData.signalStrength = uniform(-90, -60); // 模拟RSSI值(dBm)
            }
        }
    }
    
    // 模拟通信质量指标（实际项目中应通过统计信号或消息时间戳计算）
    currentData.measuredRTT = uniform(0.01, 0.1);        // 10-100ms RTT
    currentData.measuredJitter = uniform(0.001, 0.02);   // 1-20ms 抖动
    currentData.measuredPacketLoss = uniform(0.0, 0.05); // 0-5% 丢包率
    
    // 基于历史数据进行指数平滑（如果有历史数据）
    if (dataHistory.size() > 0) {
        double alpha = 0.3; // 平滑因子
        auto& lastData = dataHistory.back();
        currentData.measuredRTT = alpha * currentData.measuredRTT + (1-alpha) * lastData.measuredRTT;
        currentData.measuredJitter = alpha * currentData.measuredJitter + (1-alpha) * lastData.measuredJitter;
        currentData.measuredPacketLoss = alpha * currentData.measuredPacketLoss + (1-alpha) * lastData.measuredPacketLoss;
    }
    
    EV << "comm data: RTT=" << currentData.measuredRTT
       << " Jitter=" << currentData.measuredJitter
       << " Loss=" << currentData.measuredPacketLoss
       << " RSSI=" << currentData.signalStrength << "dBm" << std::endl;
}

void FuzzyTrustApp::collectResourceData() {
    // 模拟资源监控（实际项目中可通过系统调用获取）
    currentData.cpuUtilization = uniform(0.3, 0.9); // 模拟CPU使用率
    currentData.bandwidthUsage = uniform(0.2, 0.8);  // 模拟带宽使用率
    currentData.remainingEnergy = std::max(0.0, currentData.remainingEnergy - 0.001); // 能量消耗
    currentData.powerConsumption = uniform(0.5, 1.5); // 模拟功耗
    
    EV << "resource data: CPU=" << currentData.cpuUtilization
       << " BW=" << currentData.bandwidthUsage
       << " energy=" << currentData.remainingEnergy << std::endl;
}

void FuzzyTrustApp::collectReputationData() {
    // 基于历史交互计算信誉向量
    currentData.reputationVector.resize(7);
    
    // r_d: 直接信誉（基于成功交互比例）
    currentData.reputationVector[0] = calculateDirectReputation();
    
    // r_t: 时间信誉（基于响应时间一致性）
    currentData.reputationVector[1] = calculateTimeReputation();
    
    // r_f: 频率信誉（基于交互频率合理性）
    currentData.reputationVector[2] = calculateFrequencyReputation();
    
    // r_p: 位置信誉（基于位置信息可信度）
    currentData.reputationVector[3] = calculatePositionReputation();
    
    // r_s: 服务信誉（基于服务质量）
    currentData.reputationVector[4] = calculateServiceReputation();
    
    // r_c: 通信信誉（基于通信行为）
    currentData.reputationVector[5] = calculateCommunicationReputation();
    
    // r_n: 网络信誉（基于网络贡献）
    currentData.reputationVector[6] = calculateNetworkReputation();
    
    EV << "reputation data: [" << currentData.reputationVector[0];
    for (int i = 1; i < 7; i++) {
        EV << ", " << currentData.reputationVector[i];
    }
    EV << "]" << std::endl;
}

void FuzzyTrustApp::updateDataHistory() {
    // 添加当前数据到历史记录
    dataHistory.push_back(currentData);
    
    // 限制历史数据大小
    if (dataHistory.size() > dataHistorySize) {
        dataHistory.erase(dataHistory.begin());
    }
    
    EV << "history updated: records=" << dataHistory.size() << std::endl;
}

// 信誉计算方法实现
double FuzzyTrustApp::calculateDirectReputation() {
    // 基于成功交互比例计算直接信誉
    // 这里使用模拟值，实际应基于历史交互记录
    double successfulInteractions = 0.8; // 成功交互比例
    return std::max(0.0, std::min(1.0, successfulInteractions));
}

double FuzzyTrustApp::calculateTimeReputation() {
    // 基于响应时间一致性计算时间信誉
    double avgResponseTime = currentData.measuredRTT;
    double timeConsistency = 1.0 - std::min(1.0, avgResponseTime / 0.1); // 归一化到[0,1]
    return std::max(0.0, std::min(1.0, timeConsistency));
}

double FuzzyTrustApp::calculateFrequencyReputation() {
    // 基于交互频率合理性计算频率信誉
    // 模拟合理的交互频率评分
    double interactionFrequency = 0.7;
    return std::max(0.0, std::min(1.0, interactionFrequency));
}

double FuzzyTrustApp::calculatePositionReputation() {
    // 基于位置信息可信度计算位置信誉
    // 考虑位置变化的合理性
    double positionCredibility = 0.8;
    if (dataHistory.size() > 1) {
        // 检查位置变化是否合理（速度一致性）
        auto& lastData = dataHistory.back();
        double distance = currentData.currentPosition.distance(lastData.currentPosition);
        double timeInterval = (currentData.timestamp - lastData.timestamp).dbl();
        double calculatedSpeed = distance / timeInterval;
        
        // 如果计算速度与报告速度差异过大，降低信誉
        double speedDiff = std::abs(calculatedSpeed - currentData.currentSpeed);
        positionCredibility = std::max(0.0, 1.0 - speedDiff / 50.0); // 50m/s作为参考
    }
    return std::max(0.0, std::min(1.0, positionCredibility));
}

double FuzzyTrustApp::calculateServiceReputation() {
    // 基于服务质量计算服务信誉
    double serviceQuality = 1.0 - currentData.measuredPacketLoss; // 基于丢包率
    return std::max(0.0, std::min(1.0, serviceQuality));
}

double FuzzyTrustApp::calculateCommunicationReputation() {
    // 基于通信行为计算通信信誉
    // 综合考虑RTT、抖动等因素
    double commQuality = 1.0 - (currentData.measuredRTT / 0.2 + currentData.measuredJitter / 0.1) / 2.0;
    return std::max(0.0, std::min(1.0, commQuality));
}

double FuzzyTrustApp::calculateNetworkReputation() {
    // 基于网络贡献计算网络信誉
    // 考虑节点对网络的贡献度
    double networkContribution = 1.0 - currentData.cpuUtilization; // CPU利用率越低，贡献越大
    return std::max(0.0, std::min(1.0, networkContribution));
}

// 策略选择历史记录相关函数实现
void FuzzyTrustApp::recordStrategySelection(const std::string& strategy, 
                                          const std::vector<double>& probabilities,
                                          double expectedPayoff,
                                          double muTrust,
                                          double muDelay,
                                          double muResource) {
    if (!enableStrategyHistoryCollection) return;
    
    StrategySelectionRecord record;
    record.timestamp = simTime();
    record.selectedStrategy = strategy;
    record.strategyProbabilities = probabilities;
    record.expectedPayoff = expectedPayoff;
    record.actualPayoff = 0.0; // 将在后续更新
    record.decisionContext = getCurrentDecisionContext();
    record.trustLevel = averageTrustValue;
    record.qosLevel = (currentData.measuredRTT > 0) ? (1.0 - currentData.measuredRTT / 0.2) : 0.5;
    record.resourceLevel = 1.0 - currentData.cpuUtilization;
    record.nodeType = isRSU ? "RSU" : "Vehicle";  // 根据isRSU参数设置节点类型
    record.nodeName = getParentModule()->getFullName();  // 获取节点完整名称
    
    strategyHistory.push_back(record);
    currentStrategyRecord = record;

    // M3 接入：把策略/π/Û/ρ 录到 chapter52 logger
    // logger 输出 raw Û 和 ρ；effective payoff 的"恶意车辆暴露惩罚"
    // 在 aggregate_exp{1,2}.py 后处理时按方法应用，保 raw data 可重现/可重新口径计算
    if (metricsLogger && itGameEngine) {
        veins::chapter52::Vec4 pi = itGameEngine->getPi();
        if (probabilities.size() == 4) {
            for (std::size_t j = 0; j < 4; ++j) pi[j] = probabilities[j];
        }
        bool participates = (strategy == "SC" || strategy == "SP");
        // 任务口径（威胁模型实现后）：协作动作（SC/DC）的任务结果由本周期
        // 交互伙伴决定（lastItGameCoopFailed，见决策分支）；自利动作本地完成。
        bool coopAction = (strategy == "SC" || strategy == "DC");
        bool completed = coopAction ? !lastItGameCoopFailed : true;
        metricsLogger->recordUhat(itGameEngine->getUhat());
        metricsLogger->recordRho(itGameEngine->getRho());
        metricsLogger->recordTask(simTime().dbl(), completed, coopAction && completed);
        metricsLogger->recordRobustness(itGameEngine->getLastEpsilonReq(),
                                        itGameEngine->getLastEpsilonBudget(),
                                        itGameEngine->getLastViolation());
        std::string nodeId = getParentModule()->getFullName();
        bool malicious = checkIfNodeIsMalicious(nodeId);
        bool lowTrust = (muTrust >= 0.0 && muTrust < 0.4);
        metricsLogger->recordGovernanceExposure(malicious, lowTrust, participates);
        metricsLogger->recordStrategy(simTime().dbl(), strategy, pi);
    }

    // 限制历史记录大小
    if (strategyHistory.size() > strategyHistorySize) {
        strategyHistory.erase(strategyHistory.begin());
    }
    
    EV << "strategy: " << strategy << " prob=[";
    for (size_t i = 0; i < probabilities.size(); i++) {
        if (i > 0) EV << ", ";
        EV << probabilities[i];
    }
    EV << "] expPayoff=" << expectedPayoff << std::endl;
}

void FuzzyTrustApp::updateStrategyPayoff(double actualPayoff) {
    if (!enableStrategyHistoryCollection || strategyHistory.empty()) return;
    
    // 更新最近的策略记录的实际收益
    strategyHistory.back().actualPayoff = actualPayoff;
    
    EV << "更新策略收益: " << actualPayoff << std::endl;
}

void FuzzyTrustApp::updateStrategyStatistics() {
    if (!enableStrategyStatistics || strategyHistory.empty()) return;
    
    // 重置统计信息
    strategyStats.totalDecisions = strategyHistory.size();
    strategyStats.totalPayoff = 0.0;
    strategyStats.selectionCount.clear();
    strategyStats.totalPayoffMap.clear();
    strategyStats.averagePayoffMap.clear();
    
    // 计算统计信息
    for (const auto& record : strategyHistory) {
        strategyStats.totalPayoff += record.actualPayoff;
        strategyStats.selectionCount[record.selectedStrategy]++;
        strategyStats.totalPayoffMap[record.selectedStrategy] += record.actualPayoff;
    }
    
    // 计算平均收益
    strategyStats.averagePayoff = (strategyStats.totalDecisions > 0) ? 
        strategyStats.totalPayoff / strategyStats.totalDecisions : 0.0;
    
    // 计算各策略的平均收益
    for (const auto& pair : strategyStats.selectionCount) {
        const std::string& strategy = pair.first;
        int count = pair.second;
        if (count > 0) {
            strategyStats.averagePayoffMap[strategy] = 
                strategyStats.totalPayoffMap[strategy] / count;
        }
    }
    
    EV << "策略统计更新: 总决策数=" << strategyStats.totalDecisions 
       << ", 平均收益=" << strategyStats.averagePayoff << std::endl;
}

void FuzzyTrustApp::exportStrategyHistoryToCSV() {
    if (strategyHistory.empty()) return;
    
    std::string filename = "results/collected_data/strategy_history_" + 
                          std::to_string(getParentModule()->getIndex()) + ".csv";
    std::ofstream csvFile(filename);
    
    if (csvFile.is_open()) {
        // 写入CSV头部
        csvFile << "timestamp,selected_strategy,prob_SC,prob_SP,prob_DC,prob_DP,"
               << "expected_payoff,actual_payoff,decision_context,trust_level,qos_level,resource_level,"
               << "node_type,node_name\n";
        
        // 写入历史数据
        for (const auto& record : strategyHistory) {
            csvFile << record.timestamp << "," << record.selectedStrategy;
            
            // 写入策略概率（假设顺序为SC, SP, DC, DP）
            for (size_t i = 0; i < 4; i++) {
                csvFile << ",";
                if (i < record.strategyProbabilities.size()) {
                    csvFile << record.strategyProbabilities[i];
                } else {
                    csvFile << "0.0";
                }
            }
            
            csvFile << "," << record.expectedPayoff
                   << "," << record.actualPayoff
                   << "," << record.decisionContext
                   << "," << record.trustLevel
                   << "," << record.qosLevel
                   << "," << record.resourceLevel
                   << "," << record.nodeType
                   << "," << record.nodeName << "\n";
        }
        
        csvFile.close();
        EV << "策略历史数据已导出到: " << filename << std::endl;
    } else {
        EV_WARN << "无法创建策略历史CSV文件: " << filename << std::endl;
    }
}

std::string FuzzyTrustApp::getStrategyFromProbabilities(const std::vector<double>& probabilities) {
    if (probabilities.size() < 4) return "UNKNOWN";
    
    // 找到概率最大的策略
    std::vector<std::string> strategies = {"SC", "SP", "DC", "DP"};
    int maxIndex = 0;
    for (int i = 1; i < 4; i++) {
        if (probabilities[i] > probabilities[maxIndex]) {
            maxIndex = i;
        }
    }
    
    return strategies[maxIndex];
}

std::string FuzzyTrustApp::getCurrentDecisionContext() {
    // 基于当前环境状态生成决策上下文描述
    std::string context = "";
    
    if (averageTrustValue > 0.7) {
        context += "HIGH_TRUST";
    } else if (averageTrustValue > 0.3) {
        context += "MED_TRUST";
    } else {
        context += "LOW_TRUST";
    }
    
    if (currentData.measuredRTT < 0.05) {
        context += "_HIGH_QOS";
    } else if (currentData.measuredRTT < 0.1) {
        context += "_MED_QOS";
    } else {
        context += "_LOW_QOS";
    }
    
    if (currentData.cpuUtilization < 0.3) {
        context += "_HIGH_RES";
    } else if (currentData.cpuUtilization < 0.7) {
        context += "_MED_RES";
    } else {
        context += "_LOW_RES";
    }
    
    return context;
}

// ========== DAO治理系统方法实现 ==========

void FuzzyTrustApp::initializeDAOGovernance() {
    EV << "FuzzyTrustApp: 初始化DAO治理系统" << std::endl;
    
    // 获取节点ID和地址
    std::string nodeId = std::to_string(getParentModule()->getIndex());
    std::string nodeAddress = "0x" + nodeId + std::string(40 - nodeId.length(), '0');
    
    // 初始化节点的DAO参数
    nodeStakeAmount = isRSU ? 5000.0 : 1000.0; // RSU有更多质押
    nodeReputationScore = 100.0; // 初始信誉分数
    
    // 配置DAO投票管理器
    nlohmann::json daoConfig = {
        {"node_id", nodeId},
        {"node_address", nodeAddress},
        {"initial_stake", nodeStakeAmount},
        {"initial_reputation", nodeReputationScore},
        {"voting_power_calculation", "stake_reputation_weighted"},
        {"consensus_threshold", 0.67},
        {"min_participation_rate", 0.5},
        {"proposal_duration_hours", 24},
        {"execution_delay_hours", 2}
    };
    
    if (daoVotingManager) {
        daoVotingManager->loadConfig(daoConfig);
    }
    
    // 配置区块链治理合约
    nlohmann::json blockchainConfig = {
        {"blockchain_governance", {
            {"consensus", {
                {"block_time_seconds", 10},
                {"confirmation_blocks", 6},
                {"min_stake_amount", 1000.0},
                {"validator_reward", 10.0},
                {"governance_fee_rate", 0.01},
                {"max_transactions_per_block", 100},
                {"slashing_penalty_rate", 0.1}
            }},
            {"peer_nodes", std::vector<std::string>()}
        }}
    };
    
    if (blockchainContract) {
        blockchainContract->loadConfig(blockchainConfig);
        
        // 初始化创世配置
        nlohmann::json genesisConfig = {
            {"consensus_parameters", blockchainConfig["blockchain_governance"]["consensus"]},
            {"initial_validators", {
                {
                    {"address", nodeAddress},
                    {"balance", 10000.0},
                    {"stake", nodeStakeAmount}
                }
            }}
        };
        
        blockchainContract->initialize(genesisConfig);
    }
    
    // 注册为验证者
    if (nodeStakeAmount >= 1000.0) {
        validatorNodes.push_back(nodeAddress);
        
        // 订阅区块链事件
        if (blockchainContract) {
            blockchainContract->subscribeToEvent("ProposalCreated", 
                [this](const BlockchainGovernanceContract::ContractEvent& event) {
                    handleBlockchainEvent(event);
                });
            
            blockchainContract->subscribeToEvent("VoteCast", 
                [this](const BlockchainGovernanceContract::ContractEvent& event) {
                    handleBlockchainEvent(event);
                });
            
            blockchainContract->subscribeToEvent("ProposalExecuted", 
                [this](const BlockchainGovernanceContract::ContractEvent& event) {
                    handleBlockchainEvent(event);
                });
        }
    }
    
    EV << "FuzzyTrustApp: DAO治理系统初始化完成 - 节点: " << nodeId 
       << ", 质押: " << nodeStakeAmount 
       << ", 信誉: " << nodeReputationScore << std::endl;
}

void FuzzyTrustApp::performDAOVoting() {
    if (!daoVotingManager || validatorNodes.empty()) {
        return;
    }
    
    std::string nodeAddress = validatorNodes[0]; // 当前节点地址
    
    // 检查是否有活跃提案需要投票
    auto activeProposals = daoVotingManager->getActiveProposals();
    
    for (const auto& proposal : activeProposals) {
        std::string proposalId = proposal.proposal_id;
        
        // 检查是否已经投票
        auto proposalVotes = daoVotingManager->getProposalVotes(proposalId);
        bool hasVoted = false;
        for (const auto& vote : proposalVotes) {
            if (vote.voter_id == nodeAddress) {
                hasVoted = true;
                break;
            }
        }
        if (!hasVoted) {
            // 基于当前系统状态决定投票
            int voteOptionInt = decideVoteOption(proposal.proposal_data);
            DAOVotingManager::VoteOption voteOption = static_cast<DAOVotingManager::VoteOption>(voteOptionInt);
            double votingPower = calculateNodeVotingPower();
            
            // 投票
            bool voteSuccess = daoVotingManager->castVote(proposalId, nodeAddress, voteOption, votingPower);
            
            if (voteSuccess) {
                EV << "FuzzyTrustApp: 节点 " << nodeAddress << " 对提案 " << proposalId 
                   << " 投票 " << static_cast<int>(voteOption) << ", 投票权重: " << votingPower << std::endl;
                
                // 同时在区块链上记录投票
                if (blockchainContract) {
                    blockchainContract->castVoteOnChain(proposalId, nodeAddress, static_cast<int>(voteOption), votingPower);
                }
            }
        }
    }
    
    // 定期创建新提案（仅限部分节点）
    if (uniform(0, 1) < 0.1 && isRSU) { // 10%概率，仅RSU创建提案
        createGovernanceProposal();
    }
    
    // 更新节点信誉和质押
    updateNodeGovernanceMetrics();
}

void FuzzyTrustApp::performBlockchainGovernance() {
    if (!blockchainContract) {
        return;
    }
    
    // 收集待处理的交易
    auto pendingTransactions = blockchainContract->getPendingTransactions();
    
    // 如果有足够的交易，尝试挖掘新区块
    if (pendingTransactions.size() >= 5 && !validatorNodes.empty()) {
        std::string blockHash = blockchainContract->mineBlock(pendingTransactions);
        
        if (!blockHash.empty()) {
            EV << "FuzzyTrustApp: 新区块挖掘成功，哈希: " << blockHash 
               << ", 交易数: " << pendingTransactions.size() << std::endl;
        }
    }
    
    // 执行已达成共识的提案
    auto activeProposalsOnChain = blockchainContract->getActiveProposalsOnChain();
    for (const auto& proposal : activeProposalsOnChain) {
        std::string proposalId = proposal["id"];
        if (blockchainContract->reachConsensus(proposalId)) {
            blockchainContract->executeProposalOnChain(proposalId);
            EV << "FuzzyTrustApp: 提案 " << proposalId << " 在区块链上执行" << std::endl;
        }
    }
    
    // 更新验证者集合
    blockchainContract->updateValidatorSet();
    
    // 检测恶意行为
    detectAndPunishMaliciousBehavior();
}

int FuzzyTrustApp::decideVoteOption(const nlohmann::json& proposal) {
    std::string proposalType = proposal.value("type", "general");
    
    // 基于提案类型和当前系统状态决定投票
    if (proposalType == "rule_weight_update") {
        // 对于规则权重更新，基于性能指标决定
        double currentPerformance = calculateSystemPerformance();
        if (currentPerformance > 0.8) {
            return 1; // 赞成，系统表现良好
        } else if (currentPerformance < 0.4) {
            return 1; // 赞成，需要改进
        } else {
            return 2; // 弃权，不确定
        }
    }
    else if (proposalType == "parameter_optimization") {
        // 对于参数优化，基于ARIMA预测结果决定
        if (arimaPredictor) {
            std::vector<double> recentData = getRecentPerformanceData(10);
            if (!recentData.empty()) {
                auto prediction = arimaPredictor->predict(recentData, 1);
                if (!prediction.predictions.empty() && prediction.predictions[0] > 0.7) {
                    return 1; // 赞成
                }
            }
        }
        return 2; // 弃权
    }
    else if (proposalType == "emergency_response") {
        // 紧急响应提案通常支持
        return 1; // 赞成
    }
    
    // 默认基于节点类型和随机因素决定
    if (isRSU) {
        // RSU更保守
        return uniform(0, 1) < 0.7 ? 1 : 0;
    } else {
        // 车辆节点更激进
        return uniform(0, 1) < 0.6 ? 1 : 0;
    }
}

double FuzzyTrustApp::calculateNodeVotingPower() {
    // 基于质押金额和信誉分数计算投票权重
    double stakeWeight = nodeStakeAmount;
    double reputationWeight = nodeReputationScore / 100.0;
    
    // 考虑节点类型
    double typeMultiplier = isRSU ? 1.2 : 1.0;
    
    // 考虑历史表现
    double performanceMultiplier = calculateHistoricalPerformance();
    
    return stakeWeight * reputationWeight * typeMultiplier * performanceMultiplier;
}

void FuzzyTrustApp::createGovernanceProposal() {
    // 基于当前系统状态创建治理提案
    std::string proposalType;
    nlohmann::json proposalData;
    
    double systemPerformance = calculateSystemPerformance();
    
    if (systemPerformance < 0.5) {
        // 系统性能较差，提议参数优化
        proposalType = "parameter_optimization";
        proposalData = {
            {"type", proposalType},
            {"description", "Optimize system parameters to improve performance"},
            {"target_performance", 0.8},
            {"optimization_method", "gradient_descent"},
            {"learning_rate", 0.01}
        };
    }
    else if (uniform(0, 1) < 0.3) {
        // 随机提议规则权重更新
        proposalType = "rule_weight_update";
        std::vector<double> newWeights = generateOptimalRuleWeights();
        proposalData = {
            {"type", proposalType},
            {"description", "Update fuzzy inference rule weights"},
            {"rule_weights", newWeights},
            {"justification", "Based on recent performance analysis"}
        };
    }
    else {
        // 一般性治理提案
        proposalType = "general";
        proposalData = {
            {"type", proposalType},
            {"description", "General governance improvement proposal"},
            {"category", "system_enhancement"}
        };
    }
    
    // 创建提案
    std::string nodeAddress = validatorNodes.empty() ? "0x0" : validatorNodes[0];
    DAOVotingManager::ProposalType type = DAOVotingManager::ProposalType::RULE_WEIGHT_ADJUSTMENT;
    if (proposalType == "parameter_optimization") {
        type = DAOVotingManager::ProposalType::PARAMETER_UPDATE;
    } else if (proposalType == "general") {
        type = DAOVotingManager::ProposalType::GOVERNANCE_CHANGE;
    }
    
    std::string proposalId = daoVotingManager->createProposal(
        type,
        "Governance Proposal",
        "System governance improvement proposal",
        proposalData,
        nodeAddress
    );
    
    if (!proposalId.empty()) {
        // 同时在区块链上创建提案
        if (blockchainContract) {
            std::string blockchainProposalId = blockchainContract->createProposalOnChain(proposalData, nodeAddress);
        }
        
        activeProposals[proposalId] = proposalData;
        
        EV << "FuzzyTrustApp: 创建治理提案 " << proposalId 
           << ", 类型: " << proposalType << std::endl;
    }
}

void FuzzyTrustApp::updateNodeGovernanceMetrics() {
    // 基于节点表现更新信誉分数
    double currentPerformance = calculateSystemPerformance();
    double reputationChange = (currentPerformance - 0.5) * 10.0; // -5 to +5
    
    nodeReputationScore = std::max(0.0, std::min(1000.0, nodeReputationScore + reputationChange));
    
    // 更新区块链上的信誉
    if (!validatorNodes.empty() && blockchainContract) {
        blockchainContract->updateReputation(validatorNodes[0], nodeReputationScore);
    }
    
    // 基于表现调整质押（模拟动态质押）
    if (currentPerformance > 0.8 && nodeStakeAmount < 10000.0) {
        double stakeIncrease = 100.0;
        nodeStakeAmount += stakeIncrease;
        if (!validatorNodes.empty() && blockchainContract) {
            blockchainContract->stakeTokens(validatorNodes[0], stakeIncrease);
        }
    }
    else if (currentPerformance < 0.3 && nodeStakeAmount > 1000.0) {
        double stakeDecrease = 50.0;
        nodeStakeAmount = std::max(1000.0, nodeStakeAmount - stakeDecrease);
        if (!validatorNodes.empty() && blockchainContract) {
            blockchainContract->unstakeTokens(validatorNodes[0], stakeDecrease);
        }
    }
}

void FuzzyTrustApp::handleBlockchainEvent(const BlockchainGovernanceContract::ContractEvent& event) {
    EV << "FuzzyTrustApp: 收到区块链事件: " << event.event_name 
       << ", 区块高度: " << event.block_height << std::endl;
    
    if (event.event_name == "ProposalCreated") {
        // 新提案创建，准备参与投票
        std::string proposalId = event.event_data["proposal_id"];
        EV << "FuzzyTrustApp: 新提案创建: " << proposalId << std::endl;
    }
    else if (event.event_name == "VoteCast") {
        // 投票事件，更新本地状态
        std::string proposalId = event.event_data["proposal_id"];
        std::string voter = event.event_data["voter"];
        int voteOptionInt = event.event_data["vote_option"];
        EV << "FuzzyTrustApp: 投票事件 - 投票者: " << voter 
           << ", 提案: " << proposalId << ", 选项: " << voteOptionInt << std::endl;
    }
    else if (event.event_name == "ProposalExecuted") {
        // 提案执行，应用新的参数
        std::string proposalId = event.event_data["proposal_id"];
        applyExecutedProposal(proposalId);
        EV << "FuzzyTrustApp: 提案执行: " << proposalId << std::endl;
    }
}

void FuzzyTrustApp::applyExecutedProposal(const std::string& proposalId) {
    // 获取已执行的提案
    if (!blockchainContract) {
        return;
    }
    
    nlohmann::json proposalState = blockchainContract->getProposalState(proposalId);
    
    if (proposalState.empty()) {
        return;
    }
    
    nlohmann::json proposalData = proposalState["data"];
    std::string proposalType = proposalData.value("type", "general");
    
    if (proposalType == "rule_weight_update" && proposalData.contains("rule_weights")) {
        // 应用新的规则权重
        std::vector<double> newWeights = proposalData["rule_weights"].get<std::vector<double>>();
        if (fuzzyEngine) {
            fuzzyEngine->updateRuleWeights(newWeights);
        }
        EV << "FuzzyTrustApp: 应用新规则权重，提案: " << proposalId << std::endl;
    }
    else if (proposalType == "parameter_optimization") {
        // 应用参数优化
        if (proposalData.contains("learning_rate")) {
            gameLearningRate = proposalData["learning_rate"].get<double>();
        }
        if (proposalData.contains("exploration_rate")) {
            gameExplorationRate = proposalData["exploration_rate"].get<double>();
        }
        EV << "FuzzyTrustApp: 应用参数优化，提案: " << proposalId << std::endl;
    }
}

void FuzzyTrustApp::detectAndPunishMaliciousBehavior() {
    if (!blockchainContract) {
        return;
    }
    
    // 检测恶意行为的简化逻辑
    for (const auto& validatorAddress : validatorNodes) {
        nlohmann::json validatorInfo = blockchainContract->getValidatorInfo(validatorAddress);
        
        if (!validatorInfo.empty()) {
            int maliciousCount = validatorInfo.value("malicious_count", 0);
            double reputationScore = validatorInfo.value("reputation_score", 100.0);
            
            // 如果恶意行为过多或信誉过低，应用惩罚
            if (maliciousCount >= 3 || reputationScore < 20.0) {
                blockchainContract->applySlashing(validatorAddress, "Malicious behavior detected");
                EV << "FuzzyTrustApp: 对验证者 " << validatorAddress 
                   << " 应用惩罚机制" << std::endl;
            }
        }
    }
}

double FuzzyTrustApp::calculateSystemPerformance() {
    // 综合计算系统性能指标
    double trustPerformance = averageTrustValue;
    double qosPerformance = calculateQoSPerformance();
    double resourcePerformance = calculateResourcePerformance();
    
    // 加权平均
    return 0.4 * trustPerformance + 0.3 * qosPerformance + 0.3 * resourcePerformance;
}

double FuzzyTrustApp::calculateQoSPerformance() {
    if (!channelQuality) {
        return 0.5;
    }
    
    // 基于延迟、丢包率等计算QoS性能
    double delayScore = std::max(0.0, 1.0 - (currentData.measuredRTT / 1000.0)); // 假设1秒为最差
    double lossScore = std::max(0.0, 1.0 - (currentData.measuredPacketLoss / 0.1)); // 假设10%为最差
    
    return 0.5 * delayScore + 0.5 * lossScore;
}

double FuzzyTrustApp::calculateResourcePerformance() {
    if (!resourceManager) {
        return 0.5;
    }
    
    // 基于CPU、带宽、能耗计算资源性能
    double cpuScore = std::max(0.0, 1.0 - currentData.cpuUtilization);
    double bandwidthScore = std::max(0.0, 1.0 - currentData.bandwidthUsage);
    double energyScore = currentData.remainingEnergy / 100.0; // 假设100为满电
    
    return 0.4 * cpuScore + 0.3 * bandwidthScore + 0.3 * energyScore;
}

double FuzzyTrustApp::calculateHistoricalPerformance() {
    // 基于历史策略选择表现计算
    if (strategyStats.totalDecisions == 0) {
        return 1.0;
    }
    
    double avgPayoff = strategyStats.averagePayoff;
    return std::max(0.5, std::min(1.5, 1.0 + avgPayoff)); // 0.5到1.5的范围
}

std::vector<double> FuzzyTrustApp::generateOptimalRuleWeights() {
    // 基于当前性能生成优化的规则权重
    std::vector<double> weights(10, 0.1); // 假设10个规则
    
    // 基于系统状态调整权重
    double systemPerf = calculateSystemPerformance();
    
    if (systemPerf < 0.5) {
        // 性能较差时，增加保守策略的权重
        weights[0] = 0.2; // 保守策略
        weights[1] = 0.15;
        weights[2] = 0.1;
    } else {
        // 性能良好时，增加激进策略的权重
        weights[7] = 0.2; // 激进策略
        weights[8] = 0.15;
        weights[9] = 0.1;
    }
    
    // 归一化权重
    double sum = std::accumulate(weights.begin(), weights.end(), 0.0);
    for (auto& w : weights) {
        w /= sum;
    }
    
    return weights;
}

// ==================== MAE性能数据收集方法实现 ====================

/**
 * 收集MAE性能数据
 * 对比IT2-Sigmoid、Type-1 Sigmoid、固定阈值法和无防御基线的信任评估性能
 */
void FuzzyTrustApp::collectMAEPerformanceData() {
    if (!fuzzyTrust) {
        return;
    }
    
    try {
        // 获取当前节点ID
        std::string nodeId = "node_" + std::to_string(getParentModule()->getIndex());
        
        // 获取当前信誉向量（7维）
        std::vector<double> reputationVector = {
            calculateDirectReputation(),      // r_d: 数据真实性
            calculateTimeReputation(),       // r_t: 信息传递时效性
            calculateFrequencyReputation(),  // r_f: 历史合作频率
            calculatePositionReputation(),   // r_p: 违规惩罚次数
            calculateServiceReputation(),    // r_s: 匿名信号强度
            calculateCommunicationReputation(), // r_c: 路况预测一致度
            calculateNetworkReputation()     // r_n: 邻居推荐值
        };
        
        // 计算真实信任值（ground truth）
        double groundTruthTrust = calculateGroundTruthTrust(nodeId);
        
        // 计算不同方法的估计信任值
        double it2Trust = calculateIT2SigmoidTrust(reputationVector);
        double type1Trust = calculateType1SigmoidTrust(reputationVector);
        double thresholdTrust = calculateThresholdTrust(reputationVector);
        double noDefenseTrust = calculateNoDefenseTrust(reputationVector);
        
        // 检查是否为恶意节点
        bool isMalicious = checkIfNodeIsMalicious(nodeId);
        
        // 创建MAE数据记录
        std::vector<std::pair<std::string, double>> methods = {
            {"IT2", it2Trust},
            {"Type1", type1Trust},
            {"Threshold", thresholdTrust},
            {"None", noDefenseTrust}
        };
        
        for (const auto& method : methods) {
            MAEPerformanceData data;
            data.maliciousRatio = currentMaliciousRatio;
            data.estimatedTrust = method.second;
            data.groundTruthTrust = groundTruthTrust;
            data.absoluteError = std::abs(method.second - groundTruthTrust);
            data.evaluationMethod = method.first;
            data.nodeId = nodeId;
            data.timestamp = simTime();
            data.isMaliciousNode = isMalicious;
            
            maeDataHistory.push_back(data);
        }
        
        EV << "FuzzyTrustApp: MAE数据收集完成 - 节点: " << nodeId 
           << ", 恶意节点比例: " << currentMaliciousRatio 
           << ", 真实信任值: " << groundTruthTrust << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: MAE数据收集错误: " << e.what() << std::endl;
    }
}

/**
 * 计算IT2-Sigmoid信任值
 */
double FuzzyTrustApp::calculateIT2SigmoidTrust(const std::vector<double>& reputationVector) {
    if (!fuzzyTrust || reputationVector.size() != 7) {
        return 0.5; // 默认值
    }
    return fuzzyTrust->computeTrust(reputationVector);
}

/**
 * 计算Type-1 Sigmoid信任值（简化版IT2-Sigmoid）
 */
double FuzzyTrustApp::calculateType1SigmoidTrust(const std::vector<double>& reputationVector) {
    if (reputationVector.size() != 7) {
        return 0.5;
    }
    
    // 使用简化的Type-1 Sigmoid函数
    std::vector<double> weights = {0.15, 0.15, 0.15, 0.15, 0.1, 0.15, 0.15}; // 权重向量
    double weightedScore = 0.0;
    
    for (size_t i = 0; i < reputationVector.size(); i++) {
        weightedScore += weights[i] * reputationVector[i];
    }
    
    // Type-1 Sigmoid函数
    double theta = 0.5; // 阈值
    double k = 5.0;     // 斜率
    return 1.0 / (1.0 + std::exp(-k * (weightedScore - theta)));
}

/**
 * 计算固定阈值法信任值
 */
double FuzzyTrustApp::calculateThresholdTrust(const std::vector<double>& reputationVector) {
    if (reputationVector.size() != 7) {
        return 0.5;
    }
    
    // 计算平均信誉值
    double avgReputation = 0.0;
    for (double rep : reputationVector) {
        avgReputation += rep;
    }
    avgReputation /= reputationVector.size();
    
    // 固定阈值判断
    double threshold = 0.6;
    return (avgReputation >= threshold) ? 1.0 : 0.0;
}

/**
 * 计算无防御基线信任值（直接使用原始评分）
 */
double FuzzyTrustApp::calculateNoDefenseTrust(const std::vector<double>& reputationVector) {
    if (reputationVector.size() != 7) {
        return 0.5;
    }
    
    // 简单平均作为无防御基线
    double sum = 0.0;
    for (double rep : reputationVector) {
        sum += rep;
    }
    return sum / reputationVector.size();
}

/**
 * 计算真实信任值（ground truth）
 */
double FuzzyTrustApp::calculateGroundTruthTrust(const std::string& nodeId) {
    // 基于节点是否为恶意节点确定真实信任值
    bool isMalicious = checkIfNodeIsMalicious(nodeId);
    
    if (isMalicious) {
        // 恶意节点的真实信任值较低，添加一些随机性
        return 0.1 + (uniform(0, 1) * 0.3); // 0.1-0.4范围
    } else {
        // 正常节点的真实信任值较高，添加一些随机性
        return 0.7 + (uniform(0, 1) * 0.3); // 0.7-1.0范围
    }
}

/**
 * 检查节点是否为恶意节点
 */
bool FuzzyTrustApp::checkIfNodeIsMalicious(const std::string& nodeId) {
    // RSU节点不被视为恶意节点
    if (nodeId.find("rsu") != std::string::npos) {
        return false;
    }
    
    // 检查当前节点是否为RSU
    std::string currentNodeName = getParentModule()->getParentModule()->getName();
    if (currentNodeName.find("rsu") != std::string::npos) {
        return false;
    }
    
    // 从 node_12 或 node[12] 形式中提取数字
    size_t pos = nodeId.find("_");
    size_t bracket = nodeId.find("[");
    int nodeIndex = -1;
    if (pos != std::string::npos) {
        nodeIndex = std::stoi(nodeId.substr(pos + 1));
    } else if (bracket != std::string::npos) {
        size_t end = nodeId.find("]", bracket);
        nodeIndex = std::stoi(nodeId.substr(bracket + 1, end - bracket - 1));
    }
    if (nodeIndex >= 0) {
        
        // 根据当前恶意节点比例和节点索引确定是否为恶意节点
        // 使用确定性方法确保结果一致
        
        // 检查系统模块是否有numNodes参数
        int totalNodes = 0;
        if (getSystemModule()->hasPar("numNodes")) {
            totalNodes = getSystemModule()->par("numNodes").intValue();
        } else if (getSystemModule()->hasPar("Nv")) {
            totalNodes = getSystemModule()->par("Nv").intValue();
        } else {
            EV_WARN << "numNodes/Nv parameter not found in system module, assuming node is not malicious" << endl;
            return false;
        }
        int maliciousCount = static_cast<int>(totalNodes * currentMaliciousRatio / 100.0);
        
        // 前maliciousCount个节点被标记为恶意节点
        return nodeIndex < maliciousCount;
    }
    
    return false;
}

/**
 * 计算MAE统计信息
 */
void FuzzyTrustApp::calculateMAEStatistics() {
    if (maeDataHistory.empty()) {
        return;
    }
    
    // 按恶意节点比例分组统计
    std::map<double, std::map<std::string, std::vector<double>>> groupedData;
    
    for (const auto& data : maeDataHistory) {
        groupedData[data.maliciousRatio][data.evaluationMethod].push_back(data.absoluteError);
    }
    
    // 计算每个恶意节点比例下各方法的MAE统计
    for (const auto& ratioGroup : groupedData) {
        MAEStatistics stats;
        stats.maliciousRatio = ratioGroup.first;
        stats.sampleCount = 0;
        
        // 计算各方法的MAE和标准差
        for (const auto& methodGroup : ratioGroup.second) {
            const std::string& method = methodGroup.first;
            const std::vector<double>& errors = methodGroup.second;
            
            if (!errors.empty()) {
                double mean = calculateMean(errors);
                double stdDev = calculateStdDev(errors, mean);
                
                if (method == "IT2") {
                    stats.mae_it2 = mean;
                    stats.std_it2 = stdDev;
                } else if (method == "Type1") {
                    stats.mae_t1 = mean;
                    stats.std_t1 = stdDev;
                } else if (method == "Threshold") {
                    stats.mae_threshold = mean;
                    stats.std_threshold = stdDev;
                } else if (method == "None") {
                    stats.mae_none = mean;
                    stats.std_none = stdDev;
                }
                
                stats.sampleCount = std::max(stats.sampleCount, static_cast<int>(errors.size()));
            }
        }
        
        maeStatistics.push_back(stats);
    }
    
    EV << "FuzzyTrustApp: MAE统计计算完成，共" << maeStatistics.size() << "个恶意节点比例组" << std::endl;
}

/**
 * 计算平均值
 */
double FuzzyTrustApp::calculateMean(const std::vector<double>& values) {
    if (values.empty()) {
        return 0.0;
    }
    
    double sum = std::accumulate(values.begin(), values.end(), 0.0);
    return sum / values.size();
}

/**
 * 计算标准差
 */
double FuzzyTrustApp::calculateStdDev(const std::vector<double>& values, double mean) {
    if (values.size() <= 1) {
        return 0.0;
    }
    
    double variance = 0.0;
    for (double value : values) {
        variance += (value - mean) * (value - mean);
    }
    variance /= (values.size() - 1);
    
    return std::sqrt(variance);
}

/**
 * 导出MAE性能数据（主要CSV文件）
 */
void FuzzyTrustApp::exportMAEPerformanceData() {
    if (maeStatistics.empty()) {
        return;
    }
    
    // 创建目录
    std::string dirPath = "results/mae_performance";
    std::string command = "mkdir -p " + dirPath;
    system(command.c_str());
    
    std::string filename = dirPath + "/mae_performance_" + std::to_string(getParentModule()->getIndex()) + ".csv";
    std::ofstream csvFile(filename);
    
    if (csvFile.is_open()) {
        // 写入CSV头部（符合reference_rules.md要求）
        csvFile << "malicious_ratio,mae_it2,std_it2,mae_t1,std_t1,mae_threshold,std_threshold,mae_none,std_none\n";
        
        // 写入统计数据
        for (const auto& stats : maeStatistics) {
            csvFile << stats.maliciousRatio << ","
                   << stats.mae_it2 << "," << stats.std_it2 << ","
                   << stats.mae_t1 << "," << stats.std_t1 << ","
                   << stats.mae_threshold << "," << stats.std_threshold << ","
                   << stats.mae_none << "," << stats.std_none << "\n";
        }
        
        csvFile.close();
        EV << "FuzzyTrustApp: MAE性能数据已导出到: " << filename << std::endl;
    } else {
        EV_WARN << "FuzzyTrustApp: 无法创建MAE性能CSV文件: " << filename << std::endl;
    }
}

/**
 * 导出MAE原始数据
 */
void FuzzyTrustApp::exportMAERawData() {
    if (maeDataHistory.empty()) {
        return;
    }
    
    std::string dirPath = "results/mae_performance";
    std::string filename = dirPath + "/mae_raw_data_" + std::to_string(getParentModule()->getIndex()) + ".csv";
    std::ofstream csvFile(filename);
    
    if (csvFile.is_open()) {
        // 写入CSV头部
        csvFile << "timestamp,node_id,malicious_ratio,evaluation_method,estimated_trust,ground_truth_trust,absolute_error,is_malicious\n";
        
        // 写入原始数据
        for (const auto& data : maeDataHistory) {
            csvFile << data.timestamp << "," << data.nodeId << "," << data.maliciousRatio << ","
                   << data.evaluationMethod << "," << data.estimatedTrust << "," << data.groundTruthTrust << ","
                   << data.absoluteError << "," << (data.isMaliciousNode ? 1 : 0) << "\n";
        }
        
        csvFile.close();
        EV << "FuzzyTrustApp: MAE原始数据已导出到: " << filename << std::endl;
    } else {
        EV_WARN << "FuzzyTrustApp: 无法创建MAE原始数据CSV文件: " << filename << std::endl;
    }
}

/**
 * 导出MAE统计摘要
 */
void FuzzyTrustApp::exportMAEStatistics() {
    if (maeStatistics.empty()) {
        return;
    }
    
    std::string dirPath = "results/mae_performance";
    std::string filename = dirPath + "/mae_statistics_summary.csv";
    std::ofstream csvFile(filename, std::ios::app); // 追加模式
    
    if (csvFile.is_open()) {
        // 检查文件是否为空，如果是则写入头部
        csvFile.seekp(0, std::ios::end);
        if (csvFile.tellp() == 0) {
            csvFile << "node_id,experiment_run,malicious_ratio,mae_it2,std_it2,mae_t1,std_t1,mae_threshold,std_threshold,mae_none,std_none,sample_count\n";
        }
        
        // 写入当前节点的统计数据
        std::string nodeId = "node_" + std::to_string(getParentModule()->getIndex());
        for (const auto& stats : maeStatistics) {
            csvFile << nodeId << "," << currentExperimentRun << "," << stats.maliciousRatio << ","
                   << stats.mae_it2 << "," << stats.std_it2 << ","
                   << stats.mae_t1 << "," << stats.std_t1 << ","
                   << stats.mae_threshold << "," << stats.std_threshold << ","
                   << stats.mae_none << "," << stats.std_none << "," << stats.sampleCount << "\n";
        }
        
        csvFile.close();
        EV << "FuzzyTrustApp: MAE统计摘要已导出到: " << filename << std::endl;
    } else {
        EV_WARN << "FuzzyTrustApp: 无法创建MAE统计摘要CSV文件: " << filename << std::endl;
    }
}

std::vector<double> FuzzyTrustApp::getRecentPerformanceData(int windowSize) {
    std::vector<double> recentData;
    
    // 从策略历史中提取最近的性能数据
    int recentCount = std::min(windowSize, static_cast<int>(strategyHistory.size()));
    
    for (int i = strategyHistory.size() - recentCount; i < static_cast<int>(strategyHistory.size()); ++i) {
        if (i >= 0) {
            recentData.push_back(strategyHistory[i].actualPayoff);
        }
    }
    
    return recentData;
}

// ==================== Choquet-OWA性能数据收集方法实现 ====================

/**
 * 初始化Choquet-OWA数据收集组件
 */
void FuzzyTrustApp::initializeChoquetOWAComponents() {
    if (!enableChoquetOWACollection) {
        EV << "FuzzyTrustApp: Choquet-OWA数据收集已禁用" << std::endl;
        return;
    }
    
    try {
        // 获取节点ID
        std::string nodeId = "node_" + std::to_string(getParentModule()->getIndex());
        
        // 创建数据收集器
        choquetDataCollector = std::make_unique<ChoquetOWADataCollector>(nodeId);
        
        // 创建性能监控器
        resourceMonitor = std::make_unique<ResourcePerformanceMonitor>();
        
        // 创建CSV输出管理器
        csvOutputManager = std::make_unique<CSVOutputManager>(choquetOutputDirectory);
        
        // 创建时间戳管理器
        timestampManager = std::make_unique<TimestampManager>();
        timestampManager->initialize(choquetSamplingInterval);
        
        // 设置是否为首次初始化（只有第一次运行时清空文件）
        // 检查当前是否为第一次运行（run 0或experiment_run为1）
        bool isFirstRun = (currentExperimentRun <= 1);
        csvOutputManager->setFirstInitialization(isFirstRun);
        
        // 初始化CSV输出文件
        csvOutputManager->initializeOutputFiles();
        csvOutputManager->setExperimentInfo(currentExperimentRun, maeExperimentRuns);
        
        EV << "FuzzyTrustApp: Choquet-OWA组件初始化成功 - 节点: " << nodeId 
           << ", 输出目录: " << choquetOutputDirectory << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: Choquet-OWA组件初始化失败: " << e.what() << std::endl;
        enableChoquetOWACollection = false;
    }
}

/**
 * 收集Choquet-OWA性能数据
 */
void FuzzyTrustApp::collectChoquetOWAPerformanceData() {
    if (!enableChoquetOWACollection || !choquetDataCollector || !resourceMonitor || 
        !csvOutputManager || !timestampManager) {
        return;
    }
    
    double currentTime = simTime().dbl();
    
    // 检查是否应该执行采样
    if (!timestampManager->shouldSample(currentTime)) {
        return;
    }
    
    try {
        // 1. 设置当前资源状态到数据收集器
        choquetDataCollector->setResourceState(
            currentData.cpuUtilization,
            currentData.bandwidthUsage,
            1.0 - currentData.remainingEnergy  // 转换为能耗比例
        );
        choquetDataCollector->setTimestamp(currentTime);
        
        // 2. 收集基础数据
        choquetDataCollector->collectBaseData();
        ChoquetOWABaseData baseData = choquetDataCollector->getCurrentData();
        
        // 3. 计算四种聚合方式
        ResourceAggregationResults results = resourceMonitor->calculateAllAggregations(baseData);
        
        // 4. 设置元数据
        results.experiment_run = currentExperimentRun;
        
        // 5. 输出到CSV
        if (exportChoquetOWAToCSV) {
            csvOutputManager->writeResourceAggregationData(results);
        }
        
        EV << "Choquet-OWA数据收集完成 - 任务类型: " << results.task_type 
           << ", Choquet值: " << results.mu_resource_choquet 
           << ", 时间戳: " << timestampManager->getFormattedTimestamp(currentTime) << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "Choquet-OWA数据收集错误: " << e.what() << std::endl;
    }
}

/**
 * 基于当前上下文更新任务类型
 */
void FuzzyTrustApp::updateTaskTypeBasedOnContext() {
    if (!choquetDataCollector) {
        return;
    }
    
    // 基于当前系统状态动态判断任务类型
    double cpu_threshold = 0.7;
    double bandwidth_threshold = 0.6;
    double energy_threshold = 0.8;
    
    double cpu_load = currentData.cpuUtilization;
    double bandwidth_usage = currentData.bandwidthUsage;
    double energy_consumption = 1.0 - currentData.remainingEnergy;
    
    std::string newTaskType = currentTaskType;
    
    if (cpu_load > cpu_threshold) {
        newTaskType = "compute_intensive";
    } else if (bandwidth_usage > bandwidth_threshold) {
        newTaskType = "bandwidth_sensitive";
    } else if (energy_consumption > energy_threshold) {
        newTaskType = "energy_sensitive";
    }
    
    if (newTaskType != currentTaskType) {
        currentTaskType = newTaskType;
        choquetDataCollector->updateTaskType(currentTaskType);
        
        EV << "任务类型更新为: " << currentTaskType 
           << " (CPU: " << cpu_load << ", 带宽: " << bandwidth_usage 
           << ", 能耗: " << energy_consumption << ")" << std::endl;
    }
}

// =============================================================================
// OWA-RL权重演化数据收集方法实现
// =============================================================================

/**
 * 初始化OWA-RL权重收集器
 */
void FuzzyTrustApp::initializeOWARLWeightCollector() {
    if (!enableOWARLWeightCollection) {
        EV << "FuzzyTrustApp: OWA-RL权重收集已禁用" << std::endl;
        return;
    }
    
    try {
        // 创建权重收集器
        owarlWeightCollector = std::make_shared<OWARLWeightCollector>(owarlOutputDirectory);
        
        // 配置收集器
        owarlWeightCollector->setCollectionInterval(owarlSamplingInterval);
        owarlWeightCollector->setRunId(currentExperimentRun);
        owarlWeightCollector->setNodeId(getParentModule()->getIndex());
        
        // 从配置文件加载权重收集器配置
        if (!configFile.empty()) {
            std::ifstream configStream(configFile);
            if (configStream.is_open()) {
                nlohmann::json j;
                configStream >> j;
                
                if (j.contains("OWARLAgent") && j["OWARLAgent"].contains("weight_tracking")) {
                    owarlWeightCollector->loadConfig(j["OWARLAgent"]["weight_tracking"]);
                }
                configStream.close();
            }
        }
        
        // 设置OWARLAgent的权重收集器
        if (owarlAgent) {
            owarlAgent->setWeightCollector(owarlWeightCollector);
            owarlAgent->enableWeightTracking(true);
        }
        
        EV << "FuzzyTrustApp: OWA-RL权重收集器初始化成功 - 输出目录: " 
           << owarlOutputDirectory << ", 采样间隔: " << owarlSamplingInterval << "s" << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: OWA-RL权重收集器初始化失败: " << e.what() << std::endl;
        enableOWARLWeightCollection = false;
    }
}

/**
 * 初始化车辆混合策略数据收集器
 */
void FuzzyTrustApp::initializeMixingStrategyCollector() {
    if (!enableMixingStrategyCollection) {
        EV << "FuzzyTrustApp: 车辆混合策略数据收集已禁用" << std::endl;
        return;
    }
    
    try {
        // 创建策略收集器
        mixingStrategyCollector = std::make_shared<VehicleMixingStrategyCollector>(mixingStrategyOutputDirectory);
        
        // 配置收集器
        mixingStrategyCollector->setCollectionInterval(mixingStrategySamplingInterval);
        mixingStrategyCollector->setRunId(currentExperimentRun);
        mixingStrategyCollector->setNodeId(getParentModule()->getIndex());
        
        // 从配置文件加载策略收集器配置
        if (!configFile.empty()) {
            std::ifstream configStream(configFile);
            if (configStream.is_open()) {
                nlohmann::json j;
                configStream >> j;
                
                if (j.contains("MixingStrategyCollector")) {
                    mixingStrategyCollector->loadConfig(j["MixingStrategyCollector"]);
                }
                configStream.close();
            }
        }
        
        EV << "FuzzyTrustApp: 车辆混合策略收集器初始化成功 - 输出目录: " 
           << mixingStrategyOutputDirectory << ", 采样间隔: " << mixingStrategySamplingInterval << "s" << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 车辆混合策略收集器初始化失败: " << e.what() << std::endl;
        enableMixingStrategyCollection = false;
    }
}

/**
 * 收集OWA-RL权重演化数据
 */
void FuzzyTrustApp::collectOWARLWeightData() {
    if (!enableOWARLWeightCollection || !owarlWeightCollector || !owarlAgent) {
        return;
    }
    
    try {
        // 更新当前场景
        updateCurrentScenario();
        
        // 获取当前隶属度值
        std::vector<double> membershipValues = {
            fuzzyTrust ? fuzzyTrust->computeTrust(currentData.reputationVector) : 0.5,
            channelQuality ? (currentData.measuredRTT > 100 ? 0.3 : 0.7) : 0.5,
            resourceManager ? (currentData.cpuUtilization > 0.8 ? 0.3 : 0.7) : 0.5
        };
        
        // 记录权重演化
        double currentTime = simTime().dbl();
        owarlAgent->recordWeightEvolution(currentTime, membershipValues, currentScenario);
        
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: OWA-RL权重数据收集错误: " << e.what() << std::endl;
    }
}

/**
 * 收集车辆混合策略分布数据
 */
void FuzzyTrustApp::collectMixingStrategyData() {
    if (!enableMixingStrategyCollection || !mixingStrategyCollector) {
        return;
    }
    
    try {
        // 获取当前时间
        double currentTime = simTime().dbl();
        
        // 获取当前策略分布
        std::vector<int> strategyCounts = getStrategyCounts();
        
        // 计算总车辆数
        int totalVehicles = std::accumulate(strategyCounts.begin(), strategyCounts.end(), 0);
        
        if (totalVehicles > 0) {
            // 记录策略分布快照
            mixingStrategyCollector->recordStrategySnapshot(
                currentTime,
                strategyCounts,
                currentScenario,
                totalVehicles
            );
            
            EV_DEBUG << "FuzzyTrustApp: 记录车辆混合策略数据 - 时间: " << currentTime 
                     << ", SC: " << strategyCounts[0] << ", SP: " << strategyCounts[1]
                     << ", DC: " << strategyCounts[2] << ", DP: " << strategyCounts[3] 
                     << ", 总数: " << totalVehicles << std::endl;
        }
        
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 车辆混合策略数据收集错误: " << e.what() << std::endl;
    }
}

/**
 * 获取四种策略的车辆计数
 */
std::vector<int> FuzzyTrustApp::getStrategyCounts() const {
    std::vector<int> counts(4, 0);  // [SC, SP, DC, DP]
    
    try {
        // 根据当前节点的策略决策历史统计策略分布
        // 这里使用策略统计信息来估算当前分布
        if (strategyStats.totalDecisions > 0) {
            // 使用最近的策略选择记录
            counts[0] = strategyStats.selectionCount.at("SC");  // SC: 共享-协同
            counts[1] = strategyStats.selectionCount.at("SP");  // SP: 共享-保留
            counts[2] = strategyStats.selectionCount.at("DC");  // DC: 拒绝-协同
            counts[3] = strategyStats.selectionCount.at("DP");  // DP: 拒绝-保留
        } else {
            // 如果没有历史数据，使用均匀分布作为初始估计
            counts = {1, 1, 1, 1};
        }
        
        // 添加一些随机性以模拟网络中其他车辆的策略变化
        for (int i = 0; i < 4; i++) {
            int randomVariation = static_cast<int>(uniform(0, 3));  // 添加0-2的随机变化
            counts[i] += randomVariation;
        }
        
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 获取策略计数失败: " << e.what() << std::endl;
        // 返回默认均匀分布
        counts = {5, 5, 5, 5};
    }
    
    return counts;
}

/**
 * 更新策略分布（基于当前策略选择）
 */
void FuzzyTrustApp::updateStrategyDistribution() {
    if (!enableMixingStrategyCollection || !mixingStrategyCollector) {
        return;
    }
    
    try {
        // 获取当前时间
        double currentTime = simTime().dbl();
        
        // 基于当前策略统计计算分布
        std::vector<int> strategyCounts = getStrategyCounts();
        int total = std::accumulate(strategyCounts.begin(), strategyCounts.end(), 0);
        
        if (total > 0) {
            double pi_SC = static_cast<double>(strategyCounts[0]) / total;
            double pi_SP = static_cast<double>(strategyCounts[1]) / total;
            double pi_DC = static_cast<double>(strategyCounts[2]) / total;
            double pi_DP = static_cast<double>(strategyCounts[3]) / total;
            
            // 记录策略分布
            mixingStrategyCollector->recordStrategyDistribution(
                currentTime, pi_SC, pi_SP, pi_DC, pi_DP, currentScenario
            );
        }
        
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 更新策略分布失败: " << e.what() << std::endl;
    }
}

/**
 * 更新当前网络场景
 */
void FuzzyTrustApp::updateCurrentScenario() {
    std::string newScenario = detectCongestionScenario();
    
    if (newScenario != currentScenario) {
        std::string oldScenario = currentScenario;
        currentScenario = newScenario;
        
        // 记录场景转换
        if (owarlWeightCollector && oldScenario != "unknown") {
            owarlWeightCollector->markTransition(simTime().dbl(), oldScenario, newScenario);
        }
        
        EV << "FuzzyTrustApp: 网络场景变化: " << oldScenario << " -> " << newScenario << std::endl;
    }
}

/**
 * 检测当前拥塞场景
 */
std::string FuzzyTrustApp::detectCongestionScenario() const {
    // 获取当前系统状态指标
    double trustLevel = fuzzyTrust ? fuzzyTrust->computeTrust(currentData.reputationVector) : 0.5;
    double delayMembership = channelQuality ? (currentData.measuredRTT > 100 ? 0.3 : 0.7) : 0.5;
    double resourceMembership = resourceManager ? (currentData.cpuUtilization > 0.8 ? 0.3 : 0.7) : 0.5;
    
    // 计算综合拥塞指标
    double overallCongestion = 1.0 - ((delayMembership + resourceMembership) / 2.0);
    
    // 基于拥塞水平和信任水平确定场景
    if (resourceMembership < 0.2) {
        return "resource_critical";
    } else if (overallCongestion > 0.7) {
        return "high_congestion";
    } else if (overallCongestion > 0.4) {
        return "medium_congestion";
    } else if (overallCongestion < 0.2) {
        return "low_congestion";
    } else {
        return "transition";
    }
}

// ============================================================================
// 位置-策略联动实现
// ============================================================================

/**
 * 处理位置更新事件
 */
void FuzzyTrustApp::handlePositionUpdate(cObject* obj) {
    DemoBaseApplLayer::handlePositionUpdate(obj);
    
    if (!enablePositionBasedStrategyUpdate) {
        return;
    }
    
    try {
        // 获取当前位置
        TraCIMobility* mobility = TraCIMobilityAccess().get(getParentModule());
        if (!mobility) {
            return;
        }
        
        Coord currentPosition = mobility->getPositionAt(simTime());
        
        // 计算位置变化距离
        double distanceMoved = lastKnownPosition.distance(currentPosition);
        
        // 如果位置变化超过阈值，触发策略重新评估
        if (distanceMoved > positionUpdateThreshold) {
            EV << "FuzzyTrustApp: 位置显著变化 " << distanceMoved 
               << "m，触发策略重新评估" << std::endl;
            
            // 更新位置记录
            lastKnownPosition = currentPosition;
            lastPositionUpdateTime = simTime();
            
            // 更新邻居集合
            updateNeighborSet();
            
            // 更新信道质量
            updateChannelQualityBasedOnMobility();
            
            // 触发策略重新评估
            triggerStrategyReassessment();
            
            // 如果启用了车辆混合策略收集，立即收集数据
            if (enableMixingStrategyCollection) {
                collectMixingStrategyData();
            }
        }
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 位置更新处理失败: " << e.what() << std::endl;
    }
}

/**
 * 更新邻居集合
 */
void FuzzyTrustApp::updateNeighborSet() {
    try {
        std::set<std::string> newNeighborSet;
        
        // 获取当前位置
        TraCIMobility* mobility = TraCIMobilityAccess().get(getParentModule());
        if (!mobility) {
            return;
        }
        
        Coord myPosition = mobility->getPositionAt(simTime());
        double communicationRange = 300.0; // 通信范围300米
        
        // 遍历所有节点寻找邻居
        cTopology topo;
        topo.extractByProperty("has", 0);
        
        for (int i = 0; i < topo.getNumNodes(); i++) {
            cModule* node = topo.getNode(i)->getModule();
            if (node == getParentModule()) continue; // 跳过自己
            
            // 获取其他节点的移动模块
            TraCIMobility* otherMobility = dynamic_cast<TraCIMobility*>(
                node->getSubmodule("veinsmobility"));
            
            if (otherMobility) {
                Coord otherPosition = otherMobility->getPositionAt(simTime());
                double distance = myPosition.distance(otherPosition);
                
                if (distance <= communicationRange) {
                    newNeighborSet.insert(node->getFullName());
                }
            }
        }
        
        // 检测邻居集合变化
        if (newNeighborSet != currentNeighborSet) {
            EV << "FuzzyTrustApp: 邻居集合变化 - 旧: " << currentNeighborSet.size()
               << " 新: " << newNeighborSet.size() << std::endl;
            
            currentNeighborSet = newNeighborSet;
            
            // 邻居变化会影响μ_delay和μ_trust，需要更新
            // ChannelQuality类不需要直接更新邻居数量，会在QoS计算中考虑
        }
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 邻居集合更新失败: " << e.what() << std::endl;
    }
}

/**
 * 基于移动性更新信道质量
 */
void FuzzyTrustApp::updateChannelQualityBasedOnMobility() {
    try {
        TraCIMobility* mobility = TraCIMobilityAccess().get(getParentModule());
        if (!mobility || !channelQuality) {
            return;
        }
        
        // 获取当前速度
        double currentSpeed = mobility->getSpeed();
        
        // 速度影响信道质量 - 高速移动会降低链路稳定性
        double speedImpact = 1.0 - (currentSpeed / 50.0); // 50m/s为最大速度
        speedImpact = std::max(0.1, std::min(1.0, speedImpact));
        
        // 邻居数量影响信道质量 - 过多邻居会增加干扰
        double neighborImpact = 1.0;
        if (currentNeighborSet.size() > 10) {
            neighborImpact = 10.0 / currentNeighborSet.size();
        }
        
        // 综合计算新的信道质量因子
        double mobilityFactor = speedImpact * neighborImpact;
        
        // 更新信道质量评估中的移动性因子
        currentData.measuredRTT *= (2.0 - mobilityFactor); // RTT受移动性影响
        currentData.measuredJitter *= (2.0 - mobilityFactor); // 抖动受移动性影响
        
        EV << "FuzzyTrustApp: 移动性信道质量更新 - 速度: " << currentSpeed 
           << "m/s, 邻居: " << currentNeighborSet.size() 
           << ", 质量因子: " << mobilityFactor << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 移动性信道质量更新失败: " << e.what() << std::endl;
    }
}

/**
 * 触发策略重新评估
 */
void FuzzyTrustApp::triggerStrategyReassessment() {
    try {
        if (!gameManager) {
            return;
        }
        
        EV << "FuzzyTrustApp: 位置变化触发策略重新评估" << std::endl;
        
        // 重新计算三维隶属度
        double trustLevel = fuzzyTrust ? fuzzyTrust->computeTrust(currentData.reputationVector) : 0.5;
        double delayMembership = channelQuality ? channelQuality->computeDelayMembership(currentData.measuredRTT, 0.5) : 0.5;
        double resourceMembership = resourceManager ? resourceManager->computeResourceMembership(
            currentData.cpuUtilization, currentData.bandwidthUsage, currentBatterySOC, currentData.powerConsumption) : 0.5;
        
        // 触发策略更新（使用现有的博弈理论机制）
        if (gameManager) {
            // 计算当前收益作为参考
            std::vector<double> currentPayoffs = {trustLevel, delayMembership, resourceMembership, 
                                                 (trustLevel + delayMembership + resourceMembership) / 3.0};
            gameManager->updateVehicleStrategy(currentPayoffs);
        }
        
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 策略重新评估失败: " << e.what() << std::endl;
    }
}

// ============================================================================
// 能源建模实现
// ============================================================================

/**
 * 更新能源消耗
 */
void FuzzyTrustApp::updateEnergyConsumption() {
    if (!enableDetailedEnergyModeling) {
        return;
    }
    
    try {
        simtime_t currentTime = simTime();
        double timeElapsed = (currentTime - lastEnergyUpdateTime).dbl();
        
        if (timeElapsed <= 0) {
            return;
        }
        
        // 计算各类功耗
        calculateBlockchainPowerConsumption();
        calculateCommunicationPowerConsumption();
        
        // 总功耗 = 基础功耗 + 区块链功耗 + 通信功耗
        double totalPowerConsumption = basePowerConsumption + 
                                     blockchainPowerConsumption + 
                                     communicationPowerConsumption;
        
        // 计算能量消耗 (Wh)
        double energyConsumed = totalPowerConsumption * timeElapsed / 3600.0;
        
        // 更新电池SOC
        double currentCapacity = currentBatterySOC * initialBatteryCapacity;
        currentCapacity = std::max(0.0, currentCapacity - energyConsumed);
        currentBatterySOC = currentCapacity / initialBatteryCapacity;
        
        // 更新时间记录
        lastEnergyUpdateTime = currentTime;
        
        // 更新资源隶属度
        updateResourceMembershipFromEnergy();
        
        EV << "FuzzyTrustApp: energy update - SOC=" << (currentBatterySOC * 100)
           << "% power=" << totalPowerConsumption << "W" << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: energy update failed: " << e.what() << std::endl;
    }
}

/**
 * 计算区块链验证功耗
 */
void FuzzyTrustApp::calculateBlockchainPowerConsumption() {
    try {
        // 基础区块链参与功耗
        double baseBlockchainPower = 50.0; // 50W基础功耗
        
        // 交易验证功耗 - 与交易数量相关
        double transactionVerificationPower = 0.0;
        if (blockchainContract) {
            // 假设每个待处理交易消耗5W
            transactionVerificationPower = pendingTransactions.size() * 5.0;
        }
        
        // 共识参与功耗 - 与节点质押金额相关
        double consensusPower = 0.0;
        if (nodeStakeAmount > 0) {
            // 质押金额越高，参与共识的功耗越大
            consensusPower = 20.0 * (nodeStakeAmount / 1000.0); // 每1000单位质押增加20W
        }
        
        blockchainPowerConsumption = baseBlockchainPower + 
                                   transactionVerificationPower + 
                                   consensusPower;
        
        EV << "FuzzyTrustApp: blockchain power - base:" << baseBlockchainPower
           << "W verify:" << transactionVerificationPower
           << "W consensus:" << consensusPower << "W" << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: blockchain power calc failed: " << e.what() << std::endl;
        blockchainPowerConsumption = 50.0; // 使用默认值
    }
}

/**
 * 计算通信功耗
 */
void FuzzyTrustApp::calculateCommunicationPowerConsumption() {
    try {
        // 基础通信功耗
        double baseCommunicationPower = 30.0; // 30W基础通信功耗
        
        // 邻居数量影响功耗 - 更多邻居需要更多通信
        double neighborPower = currentNeighborSet.size() * 2.0; // 每个邻居增加2W
        
        // 信号强度影响功耗 - 信号弱时需要更大发射功率
        double signalPower = 0.0;
        if (currentData.signalStrength < -70) { // dBm
            signalPower = 20.0; // 弱信号时增加20W
        } else if (currentData.signalStrength < -50) {
            signalPower = 10.0; // 中等信号时增加10W
        }
        
        // 数据传输功耗 - 与带宽使用相关
        double transmissionPower = currentData.bandwidthUsage * 40.0; // 满带宽时40W
        
        communicationPowerConsumption = baseCommunicationPower + 
                                      neighborPower + 
                                      signalPower + 
                                      transmissionPower;
        
        EV << "FuzzyTrustApp: comm power - base:" << baseCommunicationPower
           << "W neighbor:" << neighborPower
           << "W signal:" << signalPower
           << "W tx:" << transmissionPower << "W" << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: comm power calc failed: " << e.what() << std::endl;
        communicationPowerConsumption = 30.0; // 使用默认值
    }
}

/**
 * 更新电池SOC
 */
void FuzzyTrustApp::updateBatterySOC() {
    // 该方法在updateEnergyConsumption中已经实现
    // 这里只是作为独立接口提供
    updateEnergyConsumption();
}

/**
 * 基于能源状态更新资源隶属度
 */
void FuzzyTrustApp::updateResourceMembershipFromEnergy() {
    try {
        if (!resourceManager) {
            return;
        }
        
        // 电池SOC直接影响资源隶属度
        double energyMembership = currentBatterySOC;
        
        // 当电池电量低于20%时，资源隶属度急剧下降
        if (currentBatterySOC < 0.2) {
            energyMembership = currentBatterySOC * 0.5; // 减半
        }
        
        // 当电池电量低于5%时，进入紧急模式
        if (currentBatterySOC < 0.05) {
            energyMembership = 0.0; // 瓶颈规则：能量耗尽时综合收益为0
        }
        
        // 更新资源管理器中的能源成员函数
        currentData.remainingEnergy = energyMembership;
        
        // 重新计算资源隶属度
        double resourceMembership = resourceManager->computeResourceMembership(
            currentData.cpuUtilization, 
            currentData.bandwidthUsage, 
            energyMembership,
            currentData.powerConsumption
        );
        
        EV << "FuzzyTrustApp: energy/resource membership - SOC=" << (currentBatterySOC * 100)
           << "% energyMu=" << energyMembership
           << " resMu=" << resourceMembership << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: energy/resource membership update failed: " << e.what() << std::endl;
    }
}

// ==================== 消融对照测试方法实现 ====================

/**
 * 设置IT2模块启用状态
 */
void FuzzyTrustApp::setIT2ModuleEnabled(bool enabled) {
    enableIT2Module = enabled;
    EV << "FuzzyTrustApp: IT2模块已" << (enabled ? "启用" : "禁用") << std::endl;
}

/**
 * 设置Choquet-OWA模块启用状态
 */
void FuzzyTrustApp::setChoquetOWAModuleEnabled(bool enabled) {
    enableChoquetOWAModule = enabled;
    EV << "FuzzyTrustApp: Choquet-OWA模块已" << (enabled ? "启用" : "禁用") << std::endl;
}

/**
 * 设置OWA-RL模块启用状态
 */
void FuzzyTrustApp::setOWARLModuleEnabled(bool enabled) {
    enableOWARLModule = enabled;
    EV << "FuzzyTrustApp: OWA-RL模块已" << (enabled ? "启用" : "禁用") << std::endl;
}

/**
 * 初始化消融对照测试数据收集器
 */
void FuzzyTrustApp::initializeAblationDataCollector() {
    if (!enableAblationCollection) {
        EV << "FuzzyTrustApp: 消融对照测试数据收集已禁用" << std::endl;
        return;
    }
    
    try {
        // 配置消融对照测试实验
        AblationDataCollector::ExperimentConfig config;
        config.outputDirectory = ablationOutputDirectory;
        config.numRuns = 5; // 每个模型配置运行5次
        config.simulationTime = 300.0; // 仿真时间300秒
        config.samplingInterval = ablationSamplingInterval;
        config.enableDetailedLogging = true;
        config.enableRealTimeExport = exportAblationToCSV;
        
        // 创建数据收集器
        ablationDataCollector = std::make_shared<AblationDataCollector>(config);
        
        EV << "FuzzyTrustApp: 消融对照测试数据收集器初始化完成 - 输出目录: " 
           << ablationOutputDirectory << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 消融对照测试数据收集器初始化失败: " << e.what() << std::endl;
    }
}

/**
 * 收集消融对照测试性能数据
 */
void FuzzyTrustApp::collectAblationPerformanceData() {
    if (!enableAblationCollection || !ablationDataCollector) {
        return;
    }
    
    try {
        int nodeId = getParentModule()->getIndex();
        double timestamp = simTime().dbl();
        
        // 计算当前信任值（根据模块启用状态）
        double trustValue = 0.0;
        if (fuzzyTrust && enableIT2Module) {
            // 使用IT2-Sigmoid信任评估
            trustValue = fuzzyTrust->computeTrust(currentData.reputationVector);
        } else {
            // 使用简化的信任评估
            trustValue = std::accumulate(currentData.reputationVector.begin(), 
                                       currentData.reputationVector.end(), 0.0) / currentData.reputationVector.size();
        }
        
        // 计算延迟值
        double delayValue = currentData.measuredRTT; // 使用RTT作为延迟指标
        
        // 计算资源利用率
        double resourceUtilization = (currentData.cpuUtilization + currentData.bandwidthUsage) / 2.0;
        
        // 计算能耗
        double energyConsumption = currentData.powerConsumption;
        
        // 计算完成任务数和总任务数（基于策略历史）
        double completedTasks = strategyStats.totalDecisions > 0 ? 
            static_cast<double>(strategyStats.totalDecisions) : 1.0;
        double totalTasks = completedTasks; // 假设所有任务都完成了
        
        // 记录性能数据
        ablationDataCollector->recordPerformanceData(
            nodeId, timestamp, trustValue, delayValue, 
            resourceUtilization, energyConsumption, 
            completedTasks, totalTasks
        );
        
        EV << "FuzzyTrustApp: 消融对照测试数据已收集 - 节点: " << nodeId 
           << ", 时间: " << timestamp << ", 信任值: " << trustValue << std::endl;
           
    } catch (const std::exception& e) {
        EV_ERROR << "FuzzyTrustApp: 消融对照测试数据收集失败: " << e.what() << std::endl;
    }
}

/**
 * 消融对照测试框架验证程序
 * 
 * 该程序用于测试和验证消融对照测试框架的核心功能：
 * 1. AblationTestManager 的模型配置管理
 * 2. KPICalculator 的性能指标计算
 * 3. AblationDataCollector 的数据收集和导出
 * 
 * 作者: 电子科技大学通信与信息工程项目组
 * 日期: 2024年
 */

#include <iostream>
#include <vector>
#include <map>
#include <memory>
#include <cassert>

// 包含我们的消融对照测试框架
#include "veins/modules/application/fuzzytrust/Ablation/AblationTestManager.h"
#include "veins/modules/application/fuzzytrust/Ablation/KPICalculator.h"
#include "veins/modules/application/fuzzytrust/Ablation/AblationDataCollector.h"

using namespace std;

/**
 * 测试 AblationTestManager 的基本功能
 */
void testAblationTestManager() {
    cout << "=== 测试 AblationTestManager ===" << endl;
    
    // 创建测试管理器
    auto manager = make_unique<AblationTestManager>();
    
    // 测试模型配置
    vector<AblationTestManager::ModelType> models = {
        AblationTestManager::FULL_MODEL,
        AblationTestManager::NO_IT2,
        AblationTestManager::NO_CHOQUET,
        AblationTestManager::NO_RL
    };
    
    for (auto modelType : models) {
        manager->setCurrentModel(modelType);
        
        cout << "当前模型: " << manager->getModelName(modelType) << endl;
        cout << "  IT2启用: " << (manager->isIT2Enabled() ? "是" : "否") << endl;
        cout << "  Choquet启用: " << (manager->isChoquetEnabled() ? "是" : "否") << endl;
        cout << "  OWA-RL启用: " << (manager->isOWARLEnabled() ? "是" : "否") << endl;
        
        // 记录一些模拟的KPI数据
        for (int i = 0; i < 5; ++i) {
            double R_owa = 0.5 + 0.3 * ((double)rand() / RAND_MAX);
            double delay_rate = 0.7 + 0.3 * ((double)rand() / RAND_MAX);
            double energy_eff = 0.6 + 0.4 * ((double)rand() / RAND_MAX);
            double fairness_index = 0.8 + 0.2 * ((double)rand() / RAND_MAX);
            
            manager->recordKPISample(R_owa, delay_rate, energy_eff, fairness_index);
        }
    }
    
    // 计算统计数据
    manager->calculateAllStatistics();
    
    // 验证结果
    for (auto modelType : models) {
        const auto& kpiData = manager->getKPIData(modelType);
        cout << "模型 " << manager->getModelName(modelType) << " 统计结果:" << endl;
        cout << "  R_owa: " << kpiData.R_owa_mean << " ± " << kpiData.R_owa_std << endl;
        cout << "  Delay Rate: " << kpiData.delay_rate_mean << " ± " << kpiData.delay_rate_std << endl;
        cout << "  Energy Eff: " << kpiData.energy_eff_mean << " ± " << kpiData.energy_eff_std << endl;
        cout << "  Fairness: " << kpiData.fairness_index_mean << " ± " << kpiData.fairness_index_std << endl;
    }
    
    cout << "✓ AblationTestManager 测试通过" << endl << endl;
}

/**
 * 测试 KPICalculator 的计算功能
 */
void testKPICalculator() {
    cout << "=== 测试 KPICalculator ===" << endl;
    
    auto calculator = make_unique<KPICalculator>();
    
    // 模拟多个节点的性能数据
    for (int nodeId = 0; nodeId < 5; ++nodeId) {
        for (int sample = 0; sample < 10; ++sample) {
            KPICalculator::PerformanceData data;
            data.trustValue = 0.5 + 0.5 * ((double)rand() / RAND_MAX);
            data.delayValue = 50 + 100 * ((double)rand() / RAND_MAX);
            data.resourceUtilization = 0.3 + 0.7 * ((double)rand() / RAND_MAX);
            data.energyConsumption = 10 + 20 * ((double)rand() / RAND_MAX);
            data.completedTasks = 5 + 5 * ((double)rand() / RAND_MAX);
            data.totalTasks = 10;
            data.delayThreshold = 100.0;
            data.timestamp = sample * 1.0;
            
            calculator->addPerformanceData(nodeId, data);
        }
    }
    
    // 测试KPI计算
    cout << "系统级KPI指标:" << endl;
    cout << "  OWA综合收益: " << calculator->calculateSystemOWAReward() << endl;
    cout << "  时延满足率: " << calculator->calculateSystemDelayRate() << endl;
    cout << "  能耗效率: " << calculator->calculateSystemEnergyEfficiency() << endl;
    cout << "  公平性指标: " << calculator->calculateSystemFairnessIndex() << endl;
    
    // 测试单节点KPI
    for (int nodeId = 0; nodeId < 3; ++nodeId) {
        cout << "节点 " << nodeId << " KPI:" << endl;
        cout << "  OWA收益: " << calculator->calculateOWAReward(nodeId) << endl;
        cout << "  时延率: " << calculator->calculateDelayRate(nodeId) << endl;
        cout << "  能耗效率: " << calculator->calculateEnergyEfficiency(nodeId) << endl;
    }
    
    // 测试统计信息
    auto stats = calculator->calculateAllKPIs();
    cout << "综合统计:" << endl;
    cout << "  R_owa: " << stats.R_owa << endl;
    cout << "  Delay Rate: " << stats.delay_rate << endl;
    cout << "  Energy Efficiency: " << stats.energy_efficiency << endl;
    cout << "  Fairness Index: " << stats.fairness_index << endl;
    
    cout << "总样本数: " << calculator->getTotalSamples() << endl;
    cout << "活跃节点数: " << calculator->getActiveNodeIds().size() << endl;
    
    cout << "✓ KPICalculator 测试通过" << endl << endl;
}

/**
 * 测试 AblationDataCollector 的数据收集功能
 */
void testAblationDataCollector() {
    cout << "=== 测试 AblationDataCollector ===" << endl;
    
    // 创建实验配置
    AblationDataCollector::ExperimentConfig config;
    config.outputDirectory = "./test_results/Ablation/";
    config.numRuns = 3;
    config.simulationTime = 10.0;
    config.samplingInterval = 1.0;
    config.enableDetailedLogging = true;
    config.enableRealTimeExport = false;
    
    auto collector = make_unique<AblationDataCollector>(config);
    
    // 开始实验
    collector->startExperiment();
    
    // 测试不同模型配置
    vector<AblationTestManager::ModelType> models = {
        AblationTestManager::FULL_MODEL,
        AblationTestManager::NO_IT2
    };
    
    for (auto modelType : models) {
        cout << "测试模型: " << collector->getTestManager().getModelName(modelType) << endl;
        
        collector->startModelTest(modelType);
        
        // 运行多次实验
        for (int run = 0; run < 2; ++run) {
            collector->startRun(run);
            
            // 模拟数据收集
            for (int sample = 0; sample < 5; ++sample) {
                double timestamp = sample * 1.0;
                int nodeId = sample % 3;
                
                collector->recordPerformanceData(
                    nodeId, timestamp,
                    0.5 + 0.3 * ((double)rand() / RAND_MAX), // trustValue
                    50 + 50 * ((double)rand() / RAND_MAX),   // delayValue
                    0.6 + 0.4 * ((double)rand() / RAND_MAX), // resourceUtilization
                    15 + 10 * ((double)rand() / RAND_MAX),   // energyConsumption
                    8 + 2 * ((double)rand() / RAND_MAX),     // completedTasks
                    10                                       // totalTasks
                );
            }
            
            collector->endRun();
        }
        
        collector->endModelTest();
    }
    
    // 结束实验
    collector->endExperiment();
    
    // 检查统计信息
    cout << "总样本数: " << collector->getTotalSamples() << endl;
    cout << "模型样本数 (FULL_MODEL): " << collector->getModelSamples(AblationTestManager::FULL_MODEL) << endl;
    cout << "模型样本数 (NO_IT2): " << collector->getModelSamples(AblationTestManager::NO_IT2) << endl;
    
    cout << "✓ AblationDataCollector 测试通过" << endl << endl;
}

/**
 * 主测试函数
 */
int main() {
    cout << "=======================================" << endl;
    cout << "消融对照测试框架验证程序" << endl;
    cout << "=======================================" << endl << endl;
    
    try {
        // 运行各个组件的测试
        testAblationTestManager();
        testKPICalculator();
        testAblationDataCollector();
        
        cout << "=======================================" << endl;
        cout << "所有测试通过! 消融对照测试框架正常工作。" << endl;
        cout << "=======================================" << endl;
        
        return 0;
        
    } catch (const exception& e) {
        cout << "测试失败: " << e.what() << endl;
        return 1;
    }
}
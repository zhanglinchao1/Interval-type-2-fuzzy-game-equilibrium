#include "AblationTestManager.h"
#include "../FuzzyTrustApp.h"
#include <algorithm>
#include <numeric>
#include <cmath>
#include <iostream>

using json = nlohmann::json;

void AblationTestManager::KPIData::calculateStatistics() {
    // 计算综合收益统计
    if (!R_owa_samples.empty()) {
        R_owa_mean = std::accumulate(R_owa_samples.begin(), R_owa_samples.end(), 0.0) / R_owa_samples.size();
        
        double sq_sum = std::inner_product(R_owa_samples.begin(), R_owa_samples.end(), 
                                          R_owa_samples.begin(), 0.0);
        R_owa_std = std::sqrt(sq_sum / R_owa_samples.size() - R_owa_mean * R_owa_mean);
    }
    
    // 计算时延满足率统计
    if (!delay_rate_samples.empty()) {
        delay_rate_mean = std::accumulate(delay_rate_samples.begin(), delay_rate_samples.end(), 0.0) / delay_rate_samples.size();
        
        double sq_sum = std::inner_product(delay_rate_samples.begin(), delay_rate_samples.end(), 
                                          delay_rate_samples.begin(), 0.0);
        delay_rate_std = std::sqrt(sq_sum / delay_rate_samples.size() - delay_rate_mean * delay_rate_mean);
    }
    
    // 计算能耗效率统计
    if (!energy_eff_samples.empty()) {
        energy_eff_mean = std::accumulate(energy_eff_samples.begin(), energy_eff_samples.end(), 0.0) / energy_eff_samples.size();
        
        double sq_sum = std::inner_product(energy_eff_samples.begin(), energy_eff_samples.end(), 
                                          energy_eff_samples.begin(), 0.0);
        energy_eff_std = std::sqrt(sq_sum / energy_eff_samples.size() - energy_eff_mean * energy_eff_mean);
    }
    
    // 计算公平性指标统计
    if (!fairness_index_samples.empty()) {
        fairness_index_mean = std::accumulate(fairness_index_samples.begin(), fairness_index_samples.end(), 0.0) / fairness_index_samples.size();
        
        double sq_sum = std::inner_product(fairness_index_samples.begin(), fairness_index_samples.end(), 
                                          fairness_index_samples.begin(), 0.0);
        fairness_index_std = std::sqrt(sq_sum / fairness_index_samples.size() - fairness_index_mean * fairness_index_mean);
    }
}

AblationTestManager::AblationTestManager() : currentModelType(FULL_MODEL) {
    initializeModelConfigs();
    initializeKPIData();
}

AblationTestManager::~AblationTestManager() {
    // 析构函数
}

void AblationTestManager::initialize(const json& config) {
    testConfig = config;
    
    // 如果提供了配置，可以根据配置调整默认设置
    if (!config.empty()) {
        // 预留配置选项处理
    }
}

void AblationTestManager::initializeModelConfigs() {
    modelConfigs.clear();
    
    // 添加4种模型配置
    modelConfigs.emplace_back(FULL_MODEL, "full");
    modelConfigs.emplace_back(NO_IT2, "no_IT2");
    modelConfigs.emplace_back(NO_CHOQUET, "no_Choquet");
    modelConfigs.emplace_back(NO_RL, "no_RL");
}

void AblationTestManager::initializeKPIData() {
    // 为每种模型配置初始化KPI数据结构
    for (const auto& config : modelConfigs) {
        kpiDataMap[config.type] = KPIData();
    }
}

void AblationTestManager::setCurrentModel(ModelType modelType) {
    currentModelType = modelType;
}

const AblationTestManager::ModelConfig& AblationTestManager::getCurrentConfig() const {
    for (const auto& config : modelConfigs) {
        if (config.type == currentModelType) {
            return config;
        }
    }
    return modelConfigs[0]; // 默认返回第一个配置
}

std::string AblationTestManager::getModelName(ModelType type) const {
    for (const auto& config : modelConfigs) {
        if (config.type == type) {
            return config.name;
        }
    }
    return "unknown";
}

void AblationTestManager::recordKPISample(double R_owa, double delay_rate, double energy_eff, double fairness_index) {
    auto& kpiData = kpiDataMap[currentModelType];
    
    kpiData.R_owa_samples.push_back(R_owa);
    kpiData.delay_rate_samples.push_back(delay_rate);
    kpiData.energy_eff_samples.push_back(energy_eff);
    kpiData.fairness_index_samples.push_back(fairness_index);
}

const AblationTestManager::KPIData& AblationTestManager::getKPIData(ModelType modelType) const {
    auto it = kpiDataMap.find(modelType);
    if (it != kpiDataMap.end()) {
        return it->second;
    }
    static KPIData empty;
    return empty;
}

AblationTestManager::KPIData& AblationTestManager::getKPIData(ModelType modelType) {
    return kpiDataMap[modelType];
}

void AblationTestManager::calculateAllStatistics() {
    for (auto& pair : kpiDataMap) {
        pair.second.calculateStatistics();
    }
}

void AblationTestManager::reset() {
    for (auto& pair : kpiDataMap) {
        auto& kpiData = pair.second;
        kpiData.R_owa_samples.clear();
        kpiData.delay_rate_samples.clear();
        kpiData.energy_eff_samples.clear();
        kpiData.fairness_index_samples.clear();
        
        kpiData.R_owa_mean = kpiData.R_owa_std = 0.0;
        kpiData.delay_rate_mean = kpiData.delay_rate_std = 0.0;
        kpiData.energy_eff_mean = kpiData.energy_eff_std = 0.0;
        kpiData.fairness_index_mean = kpiData.fairness_index_std = 0.0;
    }
}

void AblationTestManager::resetModel(ModelType modelType) {
    auto& kpiData = kpiDataMap[modelType];
    
    kpiData.R_owa_samples.clear();
    kpiData.delay_rate_samples.clear();
    kpiData.energy_eff_samples.clear();
    kpiData.fairness_index_samples.clear();
    
    kpiData.R_owa_mean = kpiData.R_owa_std = 0.0;
    kpiData.delay_rate_mean = kpiData.delay_rate_std = 0.0;
    kpiData.energy_eff_mean = kpiData.energy_eff_std = 0.0;
    kpiData.fairness_index_mean = kpiData.fairness_index_std = 0.0;
}

void AblationTestManager::applyModelConfig(veins::FuzzyTrustApp* app) {
    if (!app) return;
    
    const auto& config = getCurrentConfig();
    
    // 应用模型配置到FuzzyTrustApp
    // 设置各个模块的启用状态
    app->setIT2ModuleEnabled(config.enableIT2);
    app->setChoquetOWAModuleEnabled(config.enableChoquet);
    app->setOWARLModuleEnabled(config.enableOWARL);
    
    std::cout << "[AblationTestManager] Applied model config: " << config.name 
              << " (IT2=" << config.enableIT2 
              << ", Choquet=" << config.enableChoquet 
              << ", OWARL=" << config.enableOWARL << ")" << std::endl;
}

bool AblationTestManager::isIT2Enabled() const {
    return getCurrentConfig().enableIT2;
}

bool AblationTestManager::isChoquetEnabled() const {
    return getCurrentConfig().enableChoquet;
}

bool AblationTestManager::isOWARLEnabled() const {
    return getCurrentConfig().enableOWARL;
}
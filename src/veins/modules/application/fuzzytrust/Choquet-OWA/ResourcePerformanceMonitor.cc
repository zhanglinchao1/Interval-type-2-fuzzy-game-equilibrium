//
// Copyright (C) 2024 FuzzyTrust Project  
// 资源性能监控器实现
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#include "ResourcePerformanceMonitor.h"
#include <algorithm>
#include <numeric>
#include <cmath>

namespace veins {

ResourcePerformanceMonitor::ResourcePerformanceMonitor()
{
    // 初始化默认配置
    initializeDefaultConfiguration();
}

ResourceAggregationResults ResourcePerformanceMonitor::calculateAllAggregations(const ChoquetOWABaseData& baseData)
{
    ResourceAggregationResults results;
    
    // 设置基本信息
    results.task_type = baseData.task_type;
    results.timestamp = baseData.timestamp;
    results.node_id = baseData.node_id;
    
    // 获取隶属度值
    double mu_c = baseData.mu_c;
    double mu_b = baseData.mu_b;
    double mu_e = baseData.mu_e;
    
    // 计算四种聚合方式
    results.mu_resource_min = calculateMinAggregation(mu_c, mu_b, mu_e);
    results.mu_resource_mean = calculateMeanAggregation(mu_c, mu_b, mu_e);
    results.mu_resource_owa = calculateOWAAggregation(mu_c, mu_b, mu_e);
    results.mu_resource_choquet = calculateChoquetOWAAggregation(mu_c, mu_b, mu_e);
    
    return results;
}

void ResourcePerformanceMonitor::setOWAWeights(const std::vector<double>& weights)
{
    if (weights.size() == 3) {
        // 验证权重归一化
        double sum = std::accumulate(weights.begin(), weights.end(), 0.0);
        if (std::abs(sum - 1.0) < 1e-6) {
            owa_weights = weights;
        }
    }
}

void ResourcePerformanceMonitor::setChoquetOWAWeights(const std::vector<double>& weights)
{
    choquet_owa_weights = weights;
}

void ResourcePerformanceMonitor::setFuzzyMeasures(const std::map<std::string, double>& measures)
{
    fuzzy_measures = measures;
}

double ResourcePerformanceMonitor::calculateMinAggregation(double mu_c, double mu_b, double mu_e)
{
    // Min聚合 - 瓶颈模式
    // μ_min = min{μ_c, μ_b, μ_e}
    return std::min({mu_c, mu_b, mu_e});
}

double ResourcePerformanceMonitor::calculateMeanAggregation(double mu_c, double mu_b, double mu_e)
{
    // 平均聚合 - 简单基准
    // μ_mean = (μ_c + μ_b + μ_e) / 3
    return (mu_c + mu_b + mu_e) / 3.0;
}

double ResourcePerformanceMonitor::calculateOWAAggregation(double mu_c, double mu_b, double mu_e)
{
    // 单阶OWA聚合
    // 1. 对隶属度进行降序排序
    std::vector<double> sorted_values = {mu_c, mu_b, mu_e};
    std::sort(sorted_values.rbegin(), sorted_values.rend());
    
    // 2. 应用OWA权重
    double result = 0.0;
    for (size_t i = 0; i < sorted_values.size() && i < owa_weights.size(); ++i) {
        result += owa_weights[i] * sorted_values[i];
    }
    
    return result;
}

double ResourcePerformanceMonitor::calculateChoquetOWAAggregation(double mu_c, double mu_b, double mu_e)
{
    // 双阶Choquet-OWA聚合
    
    // 第一阶：Choquet积分 - 考虑资源间相互作用
    std::vector<double> values = {mu_c, mu_b, mu_e};
    double choquet_result = calculateChoquetIntegral(values);
    
    // 第二阶：OWA算子 - 处理聚合结果
    // 为了演示双阶特性，我们创建多个Choquet结果并应用OWA
    std::vector<double> choquet_results;
    
    // 计算不同资源组合的Choquet积分
    choquet_results.push_back(calculateChoquetIntegral({mu_c, mu_b}));  // CPU+带宽
    choquet_results.push_back(calculateChoquetIntegral({mu_c, mu_e}));  // CPU+能耗
    choquet_results.push_back(calculateChoquetIntegral({mu_b, mu_e}));  // 带宽+能耗
    
    // 对Choquet结果进行排序
    std::sort(choquet_results.rbegin(), choquet_results.rend());
    
    // 应用第二阶OWA权重
    double final_result = 0.0;
    for (size_t i = 0; i < choquet_results.size() && i < choquet_owa_weights.size(); ++i) {
        final_result += choquet_owa_weights[i] * choquet_results[i];
    }
    
    // 与完整的三元Choquet积分结合
    return 0.7 * choquet_result + 0.3 * final_result;
}

double ResourcePerformanceMonitor::calculateChoquetIntegral(const std::vector<double>& values)
{
    if (values.empty()) return 0.0;
    
    // 创建带索引的值对，便于排序后知道原始位置
    std::vector<std::pair<double, int>> indexed_values;
    for (size_t i = 0; i < values.size(); ++i) {
        indexed_values.push_back({values[i], static_cast<int>(i)});
    }
    
    // 按值降序排序
    std::sort(indexed_values.rbegin(), indexed_values.rend());
    
    double result = 0.0;
    
    // Choquet积分公式: C_μ(f) = Σ[f(x_σ(i)) - f(x_σ(i+1))] * μ(A_σ(i))
    for (size_t i = 0; i < indexed_values.size(); ++i) {
        double current_value = indexed_values[i].first;
        double next_value = (i + 1 < indexed_values.size()) ? indexed_values[i + 1].first : 0.0;
        
        // 构建当前级别的子集标识符
        std::string subset = "";
        for (size_t j = 0; j <= i; ++j) {
            int index = indexed_values[j].second;
            if (index == 0) subset += "c";      // CPU
            else if (index == 1) subset += "b"; // 带宽
            else if (index == 2) subset += "e"; // 能耗
        }
        
        double measure = getFuzzyMeasure(subset);
        result += (current_value - next_value) * measure;
    }
    
    return result;
}

double ResourcePerformanceMonitor::getFuzzyMeasure(const std::string& subset)
{
    // 查找对应的模糊测度值
    auto it = fuzzy_measures.find(subset);
    if (it != fuzzy_measures.end()) {
        return it->second;
    }
    
    // 如果没有找到，根据子集大小返回默认值
    if (subset.empty()) return 0.0;
    if (subset.length() == 1) return 0.3;     // 单个资源
    if (subset.length() == 2) return 0.6;     // 两个资源
    if (subset.length() == 3) return 1.0;     // 三个资源
    
    return 0.0;
}

void ResourcePerformanceMonitor::initializeDefaultConfiguration()
{
    // 默认OWA权重：偏向于较好的性能
    owa_weights = {0.5, 0.3, 0.2};
    
    // 默认Choquet-OWA权重：平衡考虑
    choquet_owa_weights = {0.4, 0.4, 0.2};
    
    // 默认模糊测度配置
    fuzzy_measures.clear();
    
    // 单个资源的测度
    fuzzy_measures["c"] = 0.3;    // CPU单独的重要性
    fuzzy_measures["b"] = 0.25;   // 带宽单独的重要性
    fuzzy_measures["e"] = 0.2;    // 能耗单独的重要性
    
    // 两个资源的测度（考虑协同效应）
    fuzzy_measures["cb"] = 0.65;  // CPU+带宽的协同重要性
    fuzzy_measures["ce"] = 0.6;   // CPU+能耗的协同重要性
    fuzzy_measures["be"] = 0.55;  // 带宽+能耗的协同重要性
    
    // 三个资源的测度
    fuzzy_measures["cbe"] = 1.0;  // 所有资源的总重要性
    
    // 处理不同顺序的子集标识符
    fuzzy_measures["bc"] = fuzzy_measures["cb"];
    fuzzy_measures["ec"] = fuzzy_measures["ce"];
    fuzzy_measures["eb"] = fuzzy_measures["be"];
    fuzzy_measures["bce"] = fuzzy_measures["cbe"];
    fuzzy_measures["ecb"] = fuzzy_measures["cbe"];
    fuzzy_measures["ebc"] = fuzzy_measures["cbe"];
    fuzzy_measures["ceb"] = fuzzy_measures["cbe"];
    fuzzy_measures["bec"] = fuzzy_measures["cbe"];
}

} // namespace veins 
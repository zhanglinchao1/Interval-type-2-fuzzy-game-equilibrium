//
// Copyright (C) 2024 FuzzyTrust Project  
// Choquet积分计算器实现
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#include "ChoquetIntegralCalculator.h"
#include <algorithm>
#include <numeric>

namespace veins {

ChoquetIntegralCalculator::ChoquetIntegralCalculator()
{
    initializeDefaultMeasures();
}

double ChoquetIntegralCalculator::calculateChoquetIntegral(const std::vector<double>& values, 
                                                          const std::map<std::string, double>& fuzzy_measures)
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
        
        // 构建当前级别的子集索引
        std::vector<int> current_indices;
        for (size_t j = 0; j <= i; ++j) {
            current_indices.push_back(indexed_values[j].second);
        }
        
        // 生成子集标识符
        std::string subset = generateSubsetIdentifier(current_indices);
        
        // 获取模糊测度
        double measure = getFuzzyMeasure(subset, fuzzy_measures);
        
        // 累加积分值
        result += (current_value - next_value) * measure;
    }
    
    return result;
}

void ChoquetIntegralCalculator::setDefaultFuzzyMeasures(const std::map<std::string, double>& measures)
{
    defaultFuzzyMeasures = measures;
}

double ChoquetIntegralCalculator::getFuzzyMeasure(const std::string& subset, 
                                                 const std::map<std::string, double>& fuzzy_measures)
{
    // 首先查找传入的模糊测度映射
    auto it = fuzzy_measures.find(subset);
    if (it != fuzzy_measures.end()) {
        return it->second;
    }
    
    // 如果没有找到，使用默认模糊测度
    auto default_it = defaultFuzzyMeasures.find(subset);
    if (default_it != defaultFuzzyMeasures.end()) {
        return default_it->second;
    }
    
    // 如果都没有找到，根据子集大小返回启发式值
    if (subset.empty()) return 0.0;
    if (subset.length() == 1) return 0.3;     // 单个资源
    if (subset.length() == 2) return 0.6;     // 两个资源
    if (subset.length() == 3) return 1.0;     // 三个资源
    
    return 0.0;
}

void ChoquetIntegralCalculator::initializeDefaultMeasures()
{
    defaultFuzzyMeasures.clear();
    
    // 单个资源的测度
    defaultFuzzyMeasures["c"] = 0.3;    // CPU单独的重要性
    defaultFuzzyMeasures["b"] = 0.25;   // 带宽单独的重要性
    defaultFuzzyMeasures["e"] = 0.2;    // 能耗单独的重要性
    
    // 两个资源的测度（考虑协同效应）
    defaultFuzzyMeasures["cb"] = 0.65;  // CPU+带宽的协同重要性
    defaultFuzzyMeasures["ce"] = 0.6;   // CPU+能耗的协同重要性
    defaultFuzzyMeasures["be"] = 0.55;  // 带宽+能耗的协同重要性
    
    // 三个资源的测度
    defaultFuzzyMeasures["cbe"] = 1.0;  // 所有资源的总重要性
    
    // 处理不同顺序的子集标识符
    defaultFuzzyMeasures["bc"] = defaultFuzzyMeasures["cb"];
    defaultFuzzyMeasures["ec"] = defaultFuzzyMeasures["ce"];
    defaultFuzzyMeasures["eb"] = defaultFuzzyMeasures["be"];
    defaultFuzzyMeasures["bce"] = defaultFuzzyMeasures["cbe"];
    defaultFuzzyMeasures["ecb"] = defaultFuzzyMeasures["cbe"];
    defaultFuzzyMeasures["ebc"] = defaultFuzzyMeasures["cbe"];
    defaultFuzzyMeasures["ceb"] = defaultFuzzyMeasures["cbe"];
    defaultFuzzyMeasures["bec"] = defaultFuzzyMeasures["cbe"];
}

std::string ChoquetIntegralCalculator::generateSubsetIdentifier(const std::vector<int>& indices)
{
    std::string subset = "";
    std::vector<int> sorted_indices = indices;
    std::sort(sorted_indices.begin(), sorted_indices.end());
    
    for (int index : sorted_indices) {
        if (index == 0) subset += "c";      // CPU
        else if (index == 1) subset += "b"; // 带宽
        else if (index == 2) subset += "e"; // 能耗
    }
    
    return subset;
}

} // namespace veins 
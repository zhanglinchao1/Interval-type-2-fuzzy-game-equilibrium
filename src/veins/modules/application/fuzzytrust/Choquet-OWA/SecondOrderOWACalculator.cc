//
// Copyright (C) 2024 FuzzyTrust Project  
// 二阶OWA计算器实现
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#include "SecondOrderOWACalculator.h"
#include <algorithm>
#include <numeric>
#include <cmath>

namespace veins {

SecondOrderOWACalculator::SecondOrderOWACalculator()
{
    initializeDefaultWeights();
}

double SecondOrderOWACalculator::calculateSecondOrderOWA(const std::vector<double>& choquet_results, 
                                                        const std::vector<double>& weights)
{
    if (choquet_results.empty()) return 0.0;
    
    // 使用提供的权重，如果为空则使用默认权重
    std::vector<double> owa_weights = weights.empty() ? defaultWeights : weights;
    
    // 验证和归一化权重
    if (!validateWeights(owa_weights)) {
        owa_weights = normalizeWeights(owa_weights);
    }
    
    // 对Choquet积分结果进行降序排序
    std::vector<double> sorted_results = choquet_results;
    std::sort(sorted_results.rbegin(), sorted_results.rend());
    
    // 计算OWA聚合
    double result = 0.0;
    size_t max_size = std::min(sorted_results.size(), owa_weights.size());
    
    for (size_t i = 0; i < max_size; ++i) {
        result += owa_weights[i] * sorted_results[i];
    }
    
    // 如果结果向量比权重向量长，用最后一个权重处理剩余的值
    if (sorted_results.size() > owa_weights.size() && !owa_weights.empty()) {
        double last_weight = owa_weights.back() / (sorted_results.size() - owa_weights.size() + 1);
        for (size_t i = owa_weights.size(); i < sorted_results.size(); ++i) {
            result += last_weight * sorted_results[i];
        }
    }
    
    return result;
}

void SecondOrderOWACalculator::setDefaultOWAWeights(const std::vector<double>& weights)
{
    if (validateWeights(weights)) {
        defaultWeights = weights;
    } else {
        defaultWeights = normalizeWeights(weights);
    }
}

std::vector<double> SecondOrderOWACalculator::getDefaultOWAWeights() const
{
    return defaultWeights;
}

void SecondOrderOWACalculator::initializeDefaultWeights()
{
    // 默认二阶OWA权重：倾向于平衡考虑
    defaultWeights = {0.4, 0.4, 0.2};
}

bool SecondOrderOWACalculator::validateWeights(const std::vector<double>& weights) const
{
    if (weights.empty()) return false;
    
    // 检查所有权重是否非负
    for (double weight : weights) {
        if (weight < 0.0) return false;
    }
    
    // 检查权重和是否接近1.0
    double sum = std::accumulate(weights.begin(), weights.end(), 0.0);
    return std::abs(sum - 1.0) < 1e-6;
}

std::vector<double> SecondOrderOWACalculator::normalizeWeights(const std::vector<double>& weights) const
{
    if (weights.empty()) return defaultWeights;
    
    std::vector<double> normalized_weights;
    double sum = 0.0;
    
    // 计算非负权重的总和
    for (double weight : weights) {
        double normalized_weight = std::max(0.0, weight);
        normalized_weights.push_back(normalized_weight);
        sum += normalized_weight;
    }
    
    // 归一化
    if (sum > 1e-9) {  // 避免除零
        for (double& weight : normalized_weights) {
            weight /= sum;
        }
    } else {
        // 如果所有权重都是0或负数，使用均匀分布
        std::fill(normalized_weights.begin(), normalized_weights.end(), 1.0 / normalized_weights.size());
    }
    
    return normalized_weights;
}

} // namespace veins 
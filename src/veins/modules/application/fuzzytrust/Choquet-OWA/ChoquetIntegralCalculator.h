//
// Copyright (C) 2024 FuzzyTrust Project  
// Choquet积分计算器 - 专门用于双阶Choquet-OWA聚合中的Choquet积分计算
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#pragma once

#include <vector>
#include <string>
#include <map>

namespace veins {

/**
 * @brief Choquet积分计算器
 * 
 * 专门用于计算Choquet积分，考虑资源间的相互作用和重要性。
 * Choquet积分公式：C_μ(f) = Σ[f(x_σ(i)) - f(x_σ(i+1))] * μ(A_σ(i))
 * 其中σ是排序，μ是模糊测度，A_σ(i)是前i个最大值的集合
 */
class ChoquetIntegralCalculator {
public:
    /**
     * @brief 构造函数
     */
    ChoquetIntegralCalculator();
    
    /**
     * @brief 析构函数
     */
    ~ChoquetIntegralCalculator() = default;
    
    /**
     * @brief 计算Choquet积分
     * 
     * @param values 输入值向量（CPU, 带宽, 能耗隶属度）
     * @param fuzzy_measures 模糊测度映射
     * @return Choquet积分结果
     */
    double calculateChoquetIntegral(const std::vector<double>& values, 
                                   const std::map<std::string, double>& fuzzy_measures);
    
    /**
     * @brief 设置默认模糊测度
     * @param measures 模糊测度映射
     */
    void setDefaultFuzzyMeasures(const std::map<std::string, double>& measures);
    
    /**
     * @brief 获取模糊测度值
     * @param subset 子集标识符
     * @param fuzzy_measures 模糊测度映射
     * @return 对应的模糊测度值
     */
    double getFuzzyMeasure(const std::string& subset, 
                          const std::map<std::string, double>& fuzzy_measures);

private:
    std::map<std::string, double> defaultFuzzyMeasures;  // 默认模糊测度
    
    /**
     * @brief 初始化默认模糊测度
     */
    void initializeDefaultMeasures();
    
    /**
     * @brief 生成子集标识符
     * @param indices 索引向量
     * @return 子集标识符字符串
     */
    std::string generateSubsetIdentifier(const std::vector<int>& indices);
};

} // namespace veins 
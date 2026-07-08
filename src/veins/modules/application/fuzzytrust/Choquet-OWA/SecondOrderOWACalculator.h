//
// Copyright (C) 2024 FuzzyTrust Project  
// 二阶OWA计算器 - 用于双阶Choquet-OWA聚合中的二阶OWA计算
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#pragma once

#include <vector>

namespace veins {

/**
 * @brief 二阶OWA计算器
 * 
 * 用于双阶Choquet-OWA聚合中的二阶OWA算子计算。
 * 第一阶：对输入值使用Choquet积分
 * 第二阶：对Choquet积分结果使用OWA算子
 */
class SecondOrderOWACalculator {
public:
    /**
     * @brief 构造函数
     */
    SecondOrderOWACalculator();
    
    /**
     * @brief 析构函数
     */
    ~SecondOrderOWACalculator() = default;
    
    /**
     * @brief 计算二阶OWA聚合
     * 
     * @param choquet_results Choquet积分结果向量
     * @param weights OWA权重向量
     * @return 二阶OWA聚合结果
     */
    double calculateSecondOrderOWA(const std::vector<double>& choquet_results, 
                                  const std::vector<double>& weights);
    
    /**
     * @brief 设置默认OWA权重
     * @param weights 权重向量
     */
    void setDefaultOWAWeights(const std::vector<double>& weights);
    
    /**
     * @brief 获取默认OWA权重
     * @return 默认权重向量
     */
    std::vector<double> getDefaultOWAWeights() const;

private:
    std::vector<double> defaultWeights;  // 默认OWA权重
    
    /**
     * @brief 初始化默认权重
     */
    void initializeDefaultWeights();
    
    /**
     * @brief 验证权重向量有效性
     * @param weights 权重向量
     * @return 是否有效
     */
    bool validateWeights(const std::vector<double>& weights) const;
    
    /**
     * @brief 归一化权重向量
     * @param weights 权重向量
     * @return 归一化后的权重向量
     */
    std::vector<double> normalizeWeights(const std::vector<double>& weights) const;
};

} // namespace veins 
//
// Copyright (C) 2024 FuzzyTrust Project  
// 资源性能监控器 - 负责计算四种聚合方式的资源隶属度
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#pragma once

#include "ChoquetOWADataCollector.h"
#include <vector>
#include <string>
#include <map>

namespace veins {

/**
 * @brief 资源聚合结果数据结构
 * 
 * 存储四种不同聚合方式计算得到的资源隶属度结果：
 * 1. Min聚合（瓶颈模式）
 * 2. 平均聚合（简单基准）
 * 3. 单阶OWA聚合（基准对比）
 * 4. 双阶Choquet-OWA聚合（主要方法）
 */
struct ResourceAggregationResults {
    double mu_resource_min;     // Min聚合: min{μ_c, μ_b, μ_e}
    double mu_resource_mean;    // 平均聚合: (μ_c + μ_b + μ_e)/3
    double mu_resource_owa;     // 单阶OWA聚合
    double mu_resource_choquet; // 双阶Choquet-OWA聚合
    
    std::string task_type;      // 任务类型
    double timestamp;           // 时间戳
    std::string node_id;        // 节点ID
    int experiment_run;         // 实验运行次数
    
    // 默认构造函数
    ResourceAggregationResults() :
        mu_resource_min(0.0), mu_resource_mean(0.0),
        mu_resource_owa(0.0), mu_resource_choquet(0.0),
        task_type(""), timestamp(0.0), node_id(""), experiment_run(0) {}
};

/**
 * @brief 资源性能监控器
 * 
 * 基于ChoquetOWABaseData计算四种不同聚合方式的资源隶属度：
 * 1. 实现Min聚合算法（瓶颈模式基准）
 * 2. 实现平均聚合算法（简单基准）
 * 3. 实现单阶OWA聚合算法（传统OWA基准）
 * 4. 实现双阶Choquet-OWA聚合算法（论文核心方法）
 */
class ResourcePerformanceMonitor {
public:
    /**
     * @brief 构造函数
     */
    ResourcePerformanceMonitor();
    
    /**
     * @brief 析构函数
     */
    ~ResourcePerformanceMonitor() = default;
    
    /**
     * @brief 计算所有聚合方式的资源隶属度
     * 
     * @param baseData 基础数据（来自ChoquetOWADataCollector）
     * @return 包含四种聚合结果的数据结构
     */
    ResourceAggregationResults calculateAllAggregations(const ChoquetOWABaseData& baseData);
    
    /**
     * @brief 设置OWA权重向量
     * @param weights OWA权重向量，必须满足归一化条件
     */
    void setOWAWeights(const std::vector<double>& weights);
    
    /**
     * @brief 设置Choquet-OWA权重向量
     * @param weights Choquet-OWA权重向量
     */
    void setChoquetOWAWeights(const std::vector<double>& weights);
    
    /**
     * @brief 设置模糊测度
     * @param measures 模糊测度映射表
     */
    void setFuzzyMeasures(const std::map<std::string, double>& measures);

private:
    // 权重配置
    std::vector<double> owa_weights;         // OWA权重 [w1, w2, w3]
    std::vector<double> choquet_owa_weights; // Choquet-OWA权重
    
    // 模糊测度配置（用于Choquet积分）
    std::map<std::string, double> fuzzy_measures;
    
    /**
     * @brief 计算Min聚合
     * 
     * Min聚合表示系统的瓶颈性能，取三个资源隶属度的最小值：
     * μ_min = min{μ_c, μ_b, μ_e}
     * 
     * @param mu_c CPU隶属度
     * @param mu_b 带宽隶属度  
     * @param mu_e 能耗隶属度
     * @return Min聚合结果
     */
    double calculateMinAggregation(double mu_c, double mu_b, double mu_e);
    
    /**
     * @brief 计算平均聚合
     * 
     * 平均聚合表示资源的均衡使用情况：
     * μ_mean = (μ_c + μ_b + μ_e) / 3
     * 
     * @param mu_c CPU隶属度
     * @param mu_b 带宽隶属度
     * @param mu_e 能耗隶属度
     * @return 平均聚合结果
     */
    double calculateMeanAggregation(double mu_c, double mu_b, double mu_e);
    
    /**
     * @brief 计算单阶OWA聚合
     * 
     * OWA (Ordered Weighted Average) 聚合，对隶属度进行排序后加权：
     * μ_owa = Σ(w_i * μ_σ(i))，其中σ是降序排序
     * 
     * @param mu_c CPU隶属度
     * @param mu_b 带宽隶属度
     * @param mu_e 能耗隶属度
     * @return OWA聚合结果
     */
    double calculateOWAAggregation(double mu_c, double mu_b, double mu_e);
    
    /**
     * @brief 计算双阶Choquet-OWA聚合
     * 
     * 双阶Choquet-OWA聚合结合了Choquet积分和OWA算子的优势：
     * 1. 第一阶：使用Choquet积分考虑资源间的相互作用
     * 2. 第二阶：使用OWA算子处理聚合结果的排序特性
     * 
     * @param mu_c CPU隶属度
     * @param mu_b 带宽隶属度
     * @param mu_e 能耗隶属度
     * @return Choquet-OWA聚合结果
     */
    double calculateChoquetOWAAggregation(double mu_c, double mu_b, double mu_e);
    
    /**
     * @brief 计算Choquet积分
     * 
     * Choquet积分考虑资源间的相互作用和重要性：
     * C_μ(f) = Σ[f(x_σ(i)) - f(x_σ(i+1))] * μ(A_σ(i))
     * 
     * @param values 输入值向量
     * @return Choquet积分结果
     */
    double calculateChoquetIntegral(const std::vector<double>& values);
    
    /**
     * @brief 获取模糊测度值
     * 
     * @param subset 子集标识符（如"c", "b", "e", "cb", "ce", "be", "cbe"）
     * @return 对应的模糊测度值
     */
    double getFuzzyMeasure(const std::string& subset);
    
    /**
     * @brief 初始化默认配置
     */
    void initializeDefaultConfiguration();
};

} // namespace veins 
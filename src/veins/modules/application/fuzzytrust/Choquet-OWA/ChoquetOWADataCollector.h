//
// Copyright (C) 2024 FuzzyTrust Project  
// Choquet-OWA双阶资源聚合性能数据收集器
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#pragma once

#include <string>
#include <vector>
#include <memory>
#include "veins/base/utils/SimpleAddress.h"
#include "veins/base/utils/Coord.h"

namespace veins {

/**
 * @brief Choquet-OWA基础数据结构
 * 
 * 存储双阶Choquet-OWA计算所需的基础数据，包括：
 * - 实时资源占用率 (r_c, r_b, r_e)
 * - 预测资源需求 (F_c, F_b, F_e)
 * - 模糊隶属度 (μ_c, μ_b, μ_e)
 * - 任务类型标识和时间戳
 */
struct ChoquetOWABaseData {
    // 实时资源占用率 [0,1]
    double r_c;  // CPU利用率
    double r_b;  // 带宽利用率  
    double r_e;  // 电量占用比
    
    // 预测资源需求
    double F_c;  // CPU预测值
    double F_b;  // 带宽预测值
    double F_e;  // 能耗预测值
    
    // 模糊隶属度 (通过Karnik-Mendel算法计算)
    double mu_c; // CPU隶属度
    double mu_b; // 带宽隶属度
    double mu_e; // 能耗隶属度
    
    // 任务类型标识
    std::string task_type; // "compute_intensive", "bandwidth_sensitive", "energy_sensitive"
    
    // 时间戳和节点信息
    double timestamp;
    std::string node_id;
    
    // 默认构造函数
    ChoquetOWABaseData() : 
        r_c(0.0), r_b(0.0), r_e(0.0),
        F_c(0.0), F_b(0.0), F_e(0.0),
        mu_c(0.0), mu_b(0.0), mu_e(0.0),
        task_type("compute_intensive"),
        timestamp(0.0), node_id("") {}
};

/**
 * @brief Choquet-OWA数据收集器
 * 
 * 负责收集双阶Choquet-OWA计算所需的基础数据：
 * 1. 实时监控系统资源状态
 * 2. 执行ARIMA预测算法获取资源需求预测
 * 3. 计算模糊隶属度函数值
 * 4. 动态识别当前任务类型
 */
class ChoquetOWADataCollector {
public:
    /**
     * @brief 构造函数
     * @param node_id 节点标识符
     */
    explicit ChoquetOWADataCollector(const std::string& node_id);
    
    /**
     * @brief 析构函数
     */
    ~ChoquetOWADataCollector() = default;
    
    /**
     * @brief 收集当前时刻的基础数据
     * 
     * 执行完整的数据收集流程：
     * 1. 获取实时资源占用率
     * 2. 执行资源需求预测
     * 3. 计算模糊隶属度
     * 4. 更新任务类型
     */
    void collectBaseData();
    
    /**
     * @brief 更新任务类型
     * @param type 新的任务类型
     */
    void updateTaskType(const std::string& type);
    
    /**
     * @brief 获取当前数据
     * @return 当前的基础数据结构
     */
    ChoquetOWABaseData getCurrentData() const;
    
    /**
     * @brief 设置外部资源状态数据
     * @param cpu_util CPU利用率 [0,1]
     * @param bandwidth_util 带宽利用率 [0,1]
     * @param energy_ratio 能耗比例 [0,1]
     */
    void setResourceState(double cpu_util, double bandwidth_util, double energy_ratio);
    
    /**
     * @brief 设置时间戳
     * @param timestamp 当前时间戳
     */
    void setTimestamp(double timestamp);

private:
    ChoquetOWABaseData currentData;  // 当前数据
    std::string nodeId;              // 节点ID
    
    // 历史数据用于预测
    std::vector<double> cpuHistory;      // CPU利用率历史
    std::vector<double> bandwidthHistory; // 带宽利用率历史
    std::vector<double> energyHistory;    // 能耗历史
    
    // 配置参数
    static const int HISTORY_SIZE = 10;  // 历史数据窗口大小
    
    /**
     * @brief 计算模糊隶属度函数
     * 
     * 使用IT2-Sigmoid函数计算各资源的隶属度：
     * μ(x) = 1 / (1 + exp(-α(x - β)))
     */
    void calculateMembershipFunctions();
    
    /**
     * @brief 更新资源预测值
     * 
     * 基于历史数据使用简化ARIMA模型预测下一时刻的资源需求
     */
    void updateResourcePredictions();
    
    /**
     * @brief 动态判断任务类型
     * 
     * 基于当前资源状态自动识别任务类型：
     * - CPU > 0.7: compute_intensive
     * - 带宽 > 0.6: bandwidth_sensitive  
     * - 能耗 > 0.8: energy_sensitive
     */
    void updateTaskTypeBasedOnContext();
    
    /**
     * @brief 更新历史数据
     */
    void updateHistory();
    
    /**
     * @brief IT2-Sigmoid隶属度函数
     * @param x 输入值
     * @param alpha sigmoid参数α
     * @param beta sigmoid参数β
     * @return 隶属度值 [0,1]
     */
    double calculateIT2Sigmoid(double x, double alpha = 5.0, double beta = 0.5) const;
};

} // namespace veins 
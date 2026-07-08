//
// Copyright (C) 2024 FuzzyTrust Project  
// Choquet-OWA双阶资源聚合性能数据收集器实现
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#include "ChoquetOWADataCollector.h"
#include <algorithm>
#include <cmath>
#include <numeric>
#include <random>

namespace veins {

ChoquetOWADataCollector::ChoquetOWADataCollector(const std::string& node_id)
    : nodeId(node_id)
{
    currentData.node_id = node_id;
    
    // 初始化历史数据容器
    cpuHistory.reserve(HISTORY_SIZE);
    bandwidthHistory.reserve(HISTORY_SIZE);
    energyHistory.reserve(HISTORY_SIZE);
    
    // 设置初始值
    currentData.r_c = 0.3;  // 初始CPU利用率30%
    currentData.r_b = 0.2;  // 初始带宽利用率20%
    currentData.r_e = 0.1;  // 初始能耗10%
    currentData.task_type = "compute_intensive";
}

void ChoquetOWADataCollector::collectBaseData()
{
    // 1. 更新历史数据
    updateHistory();
    
    // 2. 执行资源需求预测
    updateResourcePredictions();
    
    // 3. 计算模糊隶属度
    calculateMembershipFunctions();
    
    // 4. 根据当前状态动态更新任务类型
    updateTaskTypeBasedOnContext();
}

void ChoquetOWADataCollector::updateTaskType(const std::string& type)
{
    if (type == "compute_intensive" || type == "bandwidth_sensitive" || type == "energy_sensitive") {
        currentData.task_type = type;
    }
}

ChoquetOWABaseData ChoquetOWADataCollector::getCurrentData() const
{
    return currentData;
}

void ChoquetOWADataCollector::setResourceState(double cpu_util, double bandwidth_util, double energy_ratio)
{
    // 确保输入值在有效范围内 [0,1]
    currentData.r_c = std::max(0.0, std::min(1.0, cpu_util));
    currentData.r_b = std::max(0.0, std::min(1.0, bandwidth_util));
    currentData.r_e = std::max(0.0, std::min(1.0, energy_ratio));
}

void ChoquetOWADataCollector::setTimestamp(double timestamp)
{
    currentData.timestamp = timestamp;
}

void ChoquetOWADataCollector::calculateMembershipFunctions()
{
    // 使用IT2-Sigmoid函数计算各资源的模糊隶属度
    // 参数根据资源类型进行调整
    
    // CPU隶属度计算 - 考虑CPU负载对性能的影响
    currentData.mu_c = calculateIT2Sigmoid(currentData.r_c, 6.0, 0.6);
    
    // 带宽隶属度计算 - 考虑网络拥塞对通信的影响  
    currentData.mu_b = calculateIT2Sigmoid(currentData.r_b, 8.0, 0.5);
    
    // 能耗隶属度计算 - 考虑电量消耗对系统持续运行的影响
    currentData.mu_e = calculateIT2Sigmoid(currentData.r_e, 4.0, 0.7);
}

void ChoquetOWADataCollector::updateResourcePredictions()
{
    // 使用简化的ARIMA(1,1,1)模型进行资源需求预测
    // 如果历史数据不足，使用当前值作为预测值
    
    if (cpuHistory.size() < 2) {
        currentData.F_c = currentData.r_c;
        currentData.F_b = currentData.r_b;
        currentData.F_e = currentData.r_e;
        return;
    }
    
    // CPU预测 - 基于历史趋势
    double cpu_trend = cpuHistory.back() - cpuHistory[cpuHistory.size()-2];
    currentData.F_c = std::max(0.0, std::min(1.0, currentData.r_c + 0.7 * cpu_trend));
    
    // 带宽预测 - 考虑网络负载波动
    double bandwidth_trend = bandwidthHistory.back() - bandwidthHistory[bandwidthHistory.size()-2];
    currentData.F_b = std::max(0.0, std::min(1.0, currentData.r_b + 0.5 * bandwidth_trend));
    
    // 能耗预测 - 能耗通常持续增长
    double energy_trend = energyHistory.back() - energyHistory[energyHistory.size()-2];
    currentData.F_e = std::max(0.0, std::min(1.0, currentData.r_e + 0.8 * energy_trend));
    
    // 添加少量随机噪声模拟预测不确定性
    std::random_device rd;
    std::mt19937 gen(rd());
    std::normal_distribution<double> noise(0.0, 0.02);
    
    currentData.F_c += noise(gen);
    currentData.F_b += noise(gen);
    currentData.F_e += noise(gen);
    
    // 确保预测值在有效范围内
    currentData.F_c = std::max(0.0, std::min(1.0, currentData.F_c));
    currentData.F_b = std::max(0.0, std::min(1.0, currentData.F_b));
    currentData.F_e = std::max(0.0, std::min(1.0, currentData.F_e));
}

void ChoquetOWADataCollector::updateTaskTypeBasedOnContext()
{
    // 基于当前资源状态动态判断任务类型
    double cpu_threshold = 0.7;
    double bandwidth_threshold = 0.6;
    double energy_threshold = 0.8;
    
    if (currentData.r_c > cpu_threshold) {
        currentData.task_type = "compute_intensive";
    } else if (currentData.r_b > bandwidth_threshold) {
        currentData.task_type = "bandwidth_sensitive";
    } else if (currentData.r_e > energy_threshold) {
        currentData.task_type = "energy_sensitive";
    }
    // 如果都不满足阈值条件，保持当前任务类型不变
}

void ChoquetOWADataCollector::updateHistory()
{
    // 添加当前值到历史记录
    cpuHistory.push_back(currentData.r_c);
    bandwidthHistory.push_back(currentData.r_b);
    energyHistory.push_back(currentData.r_e);
    
    // 保持历史数据窗口大小
    if (cpuHistory.size() > HISTORY_SIZE) {
        cpuHistory.erase(cpuHistory.begin());
    }
    if (bandwidthHistory.size() > HISTORY_SIZE) {
        bandwidthHistory.erase(bandwidthHistory.begin());
    }
    if (energyHistory.size() > HISTORY_SIZE) {
        energyHistory.erase(energyHistory.begin());
    }
}

double ChoquetOWADataCollector::calculateIT2Sigmoid(double x, double alpha, double beta) const
{
    // IT2-Sigmoid隶属度函数
    // μ(x) = 1 / (1 + exp(-α(x - β)))
    // 其中 α 控制函数的陡峭程度，β 控制函数的中心位置
    
    double exponent = -alpha * (x - beta);
    
    // 防止数值溢出
    if (exponent > 500.0) {
        return 0.0;
    } else if (exponent < -500.0) {
        return 1.0;
    }
    
    return 1.0 / (1.0 + std::exp(exponent));
}

} // namespace veins 
#include "KPICalculator.h"
#include <map>
#include <iostream>
#include <numeric>

KPICalculator::KPICalculator() {
    // 构造函数
}

KPICalculator::~KPICalculator() {
    // 析构函数
}

void KPICalculator::addPerformanceData(int nodeId, const PerformanceData& data) {
    nodePerformanceMap[nodeId].nodeId = nodeId;
    nodePerformanceMap[nodeId].samples.push_back(data);
    
    // 累积统计
    auto& nodePerf = nodePerformanceMap[nodeId];
    nodePerf.totalReward += data.trustValue * data.resourceUtilization; // 简化的奖励计算
    nodePerf.totalEnergyConsumed += data.energyConsumption;
    nodePerf.totalTasksCompleted += data.completedTasks;
    nodePerf.totalSamples += 1.0;
    
    if (data.delayValue > data.delayThreshold) {
        nodePerf.totalDelayViolations += 1.0;
    }
}

void KPICalculator::reset() {
    nodePerformanceMap.clear();
}

void KPICalculator::resetNode(int nodeId) {
    auto it = nodePerformanceMap.find(nodeId);
    if (it != nodePerformanceMap.end()) {
        nodePerformanceMap.erase(it);
    }
}

double KPICalculator::calculateOWAReward(int nodeId) {
    if (nodeId == -1) {
        return calculateSystemOWAReward();
    }
    
    auto it = nodePerformanceMap.find(nodeId);
    if (it == nodePerformanceMap.end() || it->second.samples.empty()) {
        return 0.0;
    }
    
    const auto& nodePerf = it->second;
    
    // 计算该节点的OWA综合收益
    std::vector<double> rewards;
    for (const auto& sample : nodePerf.samples) {
        // 综合收益 = 信任值 * 资源利用率 * (1 - 延迟惩罚)
        double delayPenalty = std::min(1.0, sample.delayValue / sample.delayThreshold);
        double reward = sample.trustValue * sample.resourceUtilization * (1.0 - 0.3 * delayPenalty);
        rewards.push_back(std::max(0.0, reward));
    }
    
    if (rewards.empty()) return 0.0;
    
    // 使用OWA聚合
    std::vector<double> weights = calculateOWAWeights(rewards.size());
    return computeOWA(rewards, weights);
}

double KPICalculator::calculateDelayRate(int nodeId) {
    if (nodeId == -1) {
        return calculateSystemDelayRate();
    }
    
    auto it = nodePerformanceMap.find(nodeId);
    if (it == nodePerformanceMap.end() || it->second.samples.empty()) {
        return 0.0;
    }
    
    const auto& nodePerf = it->second;
    
    // 计算时延满足率
    int satisfiedCount = 0;
    for (const auto& sample : nodePerf.samples) {
        if (sample.delayValue <= sample.delayThreshold) {
            satisfiedCount++;
        }
    }
    
    return static_cast<double>(satisfiedCount) / nodePerf.samples.size();
}

double KPICalculator::calculateEnergyEfficiency(int nodeId) {
    if (nodeId == -1) {
        return calculateSystemEnergyEfficiency();
    }
    
    auto it = nodePerformanceMap.find(nodeId);
    if (it == nodePerformanceMap.end() || it->second.totalEnergyConsumed <= 0.0) {
        return 0.0;
    }
    
    const auto& nodePerf = it->second;
    
    // 能耗效率 = 完成任务数 / 总能耗
    return nodePerf.totalTasksCompleted / nodePerf.totalEnergyConsumed;
}

double KPICalculator::calculateFairnessIndex(const std::vector<double>& values) {
    return calculateJainsFairnessIndex(values);
}

double KPICalculator::calculateSystemOWAReward() {
    std::vector<double> nodeRewards = getNodeRewards();
    if (nodeRewards.empty()) return 0.0;
    
    // 计算系统级综合收益的平均值
    return std::accumulate(nodeRewards.begin(), nodeRewards.end(), 0.0) / nodeRewards.size();
}

double KPICalculator::calculateSystemDelayRate() {
    std::vector<double> nodeDelayRates = getNodeDelayRates();
    if (nodeDelayRates.empty()) return 0.0;
    
    // 计算系统级时延满足率的平均值
    return std::accumulate(nodeDelayRates.begin(), nodeDelayRates.end(), 0.0) / nodeDelayRates.size();
}

double KPICalculator::calculateSystemEnergyEfficiency() {
    std::vector<double> nodeEfficiencies = getNodeEnergyEfficiencies();
    if (nodeEfficiencies.empty()) return 0.0;
    
    // 计算系统级能耗效率的平均值
    return std::accumulate(nodeEfficiencies.begin(), nodeEfficiencies.end(), 0.0) / nodeEfficiencies.size();
}

double KPICalculator::calculateSystemFairnessIndex() {
    std::vector<double> nodeRewards = getNodeRewards();
    return calculateJainsFairnessIndex(nodeRewards);
}

std::vector<int> KPICalculator::getActiveNodeIds() const {
    std::vector<int> nodeIds;
    for (const auto& pair : nodePerformanceMap) {
        nodeIds.push_back(pair.first);
    }
    return nodeIds;
}

size_t KPICalculator::getTotalSamples() const {
    size_t total = 0;
    for (const auto& pair : nodePerformanceMap) {
        total += pair.second.samples.size();
    }
    return total;
}

size_t KPICalculator::getNodeSamples(int nodeId) const {
    auto it = nodePerformanceMap.find(nodeId);
    if (it != nodePerformanceMap.end()) {
        return it->second.samples.size();
    }
    return 0;
}

KPICalculator::KPIStatistics KPICalculator::calculateAllKPIs() {
    KPIStatistics stats;
    
    stats.R_owa = calculateSystemOWAReward();
    stats.delay_rate = calculateSystemDelayRate();
    stats.energy_efficiency = calculateSystemEnergyEfficiency();
    stats.fairness_index = calculateSystemFairnessIndex();
    
    return stats;
}

// 私有方法实现
double KPICalculator::calculateJainsFairnessIndex(const std::vector<double>& values) {
    if (values.empty()) return 0.0;
    if (values.size() == 1) return 1.0;
    
    double sum = std::accumulate(values.begin(), values.end(), 0.0);
    double sumSquares = std::inner_product(values.begin(), values.end(), values.begin(), 0.0);
    
    if (sumSquares <= 0.0) return 0.0;
    
    size_t n = values.size();
    return (sum * sum) / (n * sumSquares);
}

std::vector<double> KPICalculator::getNodeRewards() const {
    std::vector<double> rewards;
    for (const auto& pair : nodePerformanceMap) {
        int nodeId = pair.first;
        double reward = const_cast<KPICalculator*>(this)->calculateOWAReward(nodeId);
        rewards.push_back(reward);
    }
    return rewards;
}

std::vector<double> KPICalculator::getNodeDelayRates() const {
    std::vector<double> delayRates;
    for (const auto& pair : nodePerformanceMap) {
        int nodeId = pair.first;
        double delayRate = const_cast<KPICalculator*>(this)->calculateDelayRate(nodeId);
        delayRates.push_back(delayRate);
    }
    return delayRates;
}

std::vector<double> KPICalculator::getNodeEnergyEfficiencies() const {
    std::vector<double> efficiencies;
    for (const auto& pair : nodePerformanceMap) {
        int nodeId = pair.first;
        double efficiency = const_cast<KPICalculator*>(this)->calculateEnergyEfficiency(nodeId);
        efficiencies.push_back(efficiency);
    }
    return efficiencies;
}

std::vector<double> KPICalculator::calculateOWAWeights(size_t dimension) {
    std::vector<double> weights(dimension);
    
    if (dimension == 0) return weights;
    if (dimension == 1) {
        weights[0] = 1.0;
        return weights;
    }
    
    // 生成递减的OWA权重
    double sum = 0.0;
    for (size_t i = 0; i < dimension; ++i) {
        weights[i] = 1.0 / (i + 1.0); // 简单的递减权重
        sum += weights[i];
    }
    
    // 归一化
    for (auto& w : weights) {
        w /= sum;
    }
    
    return weights;
}

double KPICalculator::computeOWA(const std::vector<double>& values, const std::vector<double>& weights) {
    if (values.empty() || weights.empty() || values.size() != weights.size()) {
        return 0.0;
    }
    
    // 复制并排序值（降序）
    std::vector<double> sortedValues = values;
    std::sort(sortedValues.begin(), sortedValues.end(), std::greater<double>());
    
    // 计算加权和
    double result = 0.0;
    for (size_t i = 0; i < sortedValues.size(); ++i) {
        result += weights[i] * sortedValues[i];
    }
    
    return result;
}
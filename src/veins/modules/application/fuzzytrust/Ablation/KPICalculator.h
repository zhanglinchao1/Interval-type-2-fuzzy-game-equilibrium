#ifndef KPI_CALCULATOR_H
#define KPI_CALCULATOR_H

#include <vector>
#include <map>
#include <cmath>
#include <algorithm>
#include <numeric>

/**
 * @brief KPI计算器类
 * 
 * 计算消融对照测试所需的关键性能指标：
 * 1. 综合收益 (R_owa)
 * 2. 时延满足率 (delay_rate)
 * 3. 能耗效率 (energy_eff)
 * 4. 公平性指标 (fairness_index)
 */
class KPICalculator {
public:
    // 基础数据结构
    struct PerformanceData {
        double trustValue = 0.0;         // 信任值
        double delayValue = 0.0;         // 延迟值
        double resourceUtilization = 0.0; // 资源利用率
        double energyConsumption = 0.0;  // 能耗
        double completedTasks = 0.0;     // 完成任务数
        double totalTasks = 0.0;         // 总任务数
        double delayThreshold = 100.0;   // 延迟阈值(ms)
        double timestamp = 0.0;          // 时间戳
    };
    
    struct NodePerformance {
        int nodeId;
        std::vector<PerformanceData> samples;
        double totalReward = 0.0;
        double totalEnergyConsumed = 0.0;
        double totalTasksCompleted = 0.0;
        double totalDelayViolations = 0.0;
        double totalSamples = 0.0;
    };

public:
    KPICalculator();
    ~KPICalculator();

    // 数据收集
    void addPerformanceData(int nodeId, const PerformanceData& data);
    void reset();
    void resetNode(int nodeId);

    // KPI计算方法
    double calculateOWAReward(int nodeId = -1);                    // 综合收益
    double calculateDelayRate(int nodeId = -1);                   // 时延满足率  
    double calculateEnergyEfficiency(int nodeId = -1);            // 能耗效率
    double calculateFairnessIndex(const std::vector<double>& values); // 公平性指标 (Jain's Index)
    
    // 系统级KPI计算
    double calculateSystemOWAReward();
    double calculateSystemDelayRate();
    double calculateSystemEnergyEfficiency();
    double calculateSystemFairnessIndex();
    
    // 辅助方法
    std::vector<int> getActiveNodeIds() const;
    size_t getTotalSamples() const;
    size_t getNodeSamples(int nodeId) const;
    
    // 统计信息
    struct KPIStatistics {
        double R_owa = 0.0;
        double delay_rate = 0.0;
        double energy_efficiency = 0.0;
        double fairness_index = 0.0;
    };
    
    KPIStatistics calculateAllKPIs();
    
private:
    std::map<int, NodePerformance> nodePerformanceMap;
    
    // 私有辅助方法
    double calculateJainsFairnessIndex(const std::vector<double>& values);
    std::vector<double> getNodeRewards() const;
    std::vector<double> getNodeDelayRates() const;
    std::vector<double> getNodeEnergyEfficiencies() const;
    
    // OWA权重计算（简化版本）
    std::vector<double> calculateOWAWeights(size_t dimension);
    double computeOWA(const std::vector<double>& values, const std::vector<double>& weights);
};

#endif // KPI_CALCULATOR_H
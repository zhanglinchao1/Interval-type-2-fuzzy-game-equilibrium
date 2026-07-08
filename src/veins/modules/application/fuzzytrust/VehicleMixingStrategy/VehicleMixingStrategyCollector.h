#ifndef VEHICLE_MIXING_STRATEGY_COLLECTOR_H
#define VEHICLE_MIXING_STRATEGY_COLLECTOR_H

#include <vector>
#include <string>
#include <memory>
#include <fstream>
#include <map>
#include <deque>
#include <chrono>
#include <ctime>
#include "../json.hpp"

/**
 * 车辆混合策略数据收集器
 * 用于收集和导出四种策略（SC、SP、DC、DP）的分布演化数据
 */
class VehicleMixingStrategyCollector {
public:
    // 四种车辆策略类型
    enum StrategyType {
        SC = 0,  // 共享-协同 (Share-Cooperate)
        SP = 1,  // 共享-保留 (Share-Preserve)  
        DC = 2,  // 拒绝-协同 (Deny-Cooperate)
        DP = 3   // 拒绝-保留 (Deny-Preserve)
    };

    // 策略分布快照
    struct StrategySnapshot {
        double timestamp;
        double pi_SC;              // 共享-协同策略占比
        double pi_SP;              // 共享-保留策略占比
        double pi_DC;              // 拒绝-协同策略占比
        double pi_DP;              // 拒绝-保留策略占比
        std::string scenario;      // 当前场景标识
        int simulation_run;        // 仿真运行号
        int total_vehicles;        // 总车辆数
        
        // 验证占比总和是否为1
        bool isNormalized() const {
            double sum = pi_SC + pi_SP + pi_DC + pi_DP;
            return std::abs(sum - 1.0) < 1e-6;
        }
    };

    // 构造函数
    VehicleMixingStrategyCollector();
    explicit VehicleMixingStrategyCollector(const std::string& output_dir);

    // 配置方法
    void setOutputDirectory(const std::string& output_dir);
    void setCollectionInterval(double interval_seconds);
    void setRunId(int run_id);
    void setNodeId(int node_id);
    void loadConfig(const nlohmann::json& config);

    // 数据收集方法
    void recordStrategySnapshot(
        double timestamp,
        const std::vector<int>& strategy_counts,  // [SC_count, SP_count, DC_count, DP_count]
        const std::string& scenario = "",
        int total_vehicles = 0
    );
    
    void recordStrategyDistribution(
        double timestamp,
        double pi_SC, double pi_SP, double pi_DC, double pi_DP,
        const std::string& scenario = ""
    );

    // 场景管理
    void updateScenario(const std::string& new_scenario);
    std::string detectCongestionScenario(const std::vector<int>& strategy_counts);

    // 数据导出方法
    void exportRunData(int run_id);
    void exportData();  // 导出当前运行数据
    void exportAggregatedData();  // 导出聚合统计数据
    void exportRawData();  // 导出原始数据
    void finalizeAndExport();  // 最终导出

    // 统计方法
    void calculateStatistics();
    void updateStrategyStatistics(const StrategySnapshot& snapshot);

    // 清理方法
    void reset();
    void clearData();

    // 获取统计信息
    size_t getSnapshotCount() const;
    StrategySnapshot getLastSnapshot() const;
    std::vector<double> getAverageDistribution() const;

private:
    // 数据存储
    std::vector<StrategySnapshot> snapshots;
    std::deque<StrategySnapshot> sliding_window;
    
    // 配置参数
    std::string output_directory;
    double collection_interval;
    double last_collection_time;
    int current_run_id;
    int current_node_id;
    std::string current_scenario;
    size_t max_window_size;
    bool enable_real_time_export;
    
    // 统计数据
    struct StrategyStatistics {
        double mean_SC, mean_SP, mean_DC, mean_DP;
        double std_SC, std_SP, std_DC, std_DP;
        double min_SC, min_SP, min_DC, min_DP;
        double max_SC, max_SP, max_DC, max_DP;
        size_t sample_count;
        
        StrategyStatistics() : 
            mean_SC(0), mean_SP(0), mean_DC(0), mean_DP(0),
            std_SC(0), std_SP(0), std_DC(0), std_DP(0),
            min_SC(1), min_SP(1), min_DC(1), min_DP(1),
            max_SC(0), max_SP(0), max_DC(0), max_DP(0),
            sample_count(0) {}
    };
    
    StrategyStatistics strategy_stats;
    std::map<std::string, StrategyStatistics> scenario_stats;

    // 辅助方法
    std::string generateFilename(const std::string& prefix, int run_id = -1) const;
    void writeCSVHeader(std::ofstream& file) const;
    void writeStrategySnapshot(std::ofstream& file, const StrategySnapshot& snapshot) const;
    void writeAggregatedCSVHeader(std::ofstream& file) const;
    
    // 数据验证
    bool validateStrategySnapshot(const StrategySnapshot& snapshot) const;
    void normalizeDistribution(StrategySnapshot& snapshot) const;
    
    // 统计计算
    void updateRunningStatistics();
    double calculateStandardDeviation(const std::vector<double>& values, double mean) const;
};

#endif // VEHICLE_MIXING_STRATEGY_COLLECTOR_H
#include "VehicleMixingStrategyCollector.h"
#include <iostream>
#include <algorithm>
#include <numeric>
#include <cmath>
#include <iomanip>
#include <set>
#include <sys/stat.h>
#include <sys/types.h>

using json = nlohmann::json;

VehicleMixingStrategyCollector::VehicleMixingStrategyCollector() 
    : output_directory("./results/Vehicle Mixing Strategy/data/")
    , collection_interval(1.0)
    , current_run_id(0)
    , current_node_id(0)
    , current_scenario("unknown")
    , last_collection_time(0.0)
    , max_window_size(1000)
    , enable_real_time_export(false)
{
    reset();
}

VehicleMixingStrategyCollector::VehicleMixingStrategyCollector(const std::string& output_dir)
    : VehicleMixingStrategyCollector()
{
    setOutputDirectory(output_dir);
}

void VehicleMixingStrategyCollector::setOutputDirectory(const std::string& output_dir) {
    output_directory = output_dir;
    
    // Create directory recursively if it doesn't exist
    try {
        // Use system command to create directories recursively
        std::string command = "mkdir -p \"" + output_directory + "\"";
        int result = system(command.c_str());
        if (result != 0) {
            std::cerr << "Failed to create output directory: " << output_directory << std::endl;
        } else {
            std::cout << "Created output directory: " << output_directory << std::endl;
        }
    } catch (const std::exception& e) {
        std::cerr << "Failed to create output directory: " << e.what() << std::endl;
    }
}

void VehicleMixingStrategyCollector::setCollectionInterval(double interval_seconds) {
    collection_interval = interval_seconds;
}

void VehicleMixingStrategyCollector::setRunId(int run_id) {
    current_run_id = run_id;
}

void VehicleMixingStrategyCollector::setNodeId(int node_id) {
    current_node_id = node_id;
}

void VehicleMixingStrategyCollector::loadConfig(const nlohmann::json& config) {
    if (config.contains("collection_interval")) {
        collection_interval = config["collection_interval"];
    }
    if (config.contains("max_window_size")) {
        max_window_size = config["max_window_size"];
    }
    if (config.contains("enable_real_time_export")) {
        enable_real_time_export = config["enable_real_time_export"];
    }
    if (config.contains("output_directory")) {
        setOutputDirectory(config["output_directory"]);
    }
}

void VehicleMixingStrategyCollector::recordStrategySnapshot(
    double timestamp,
    const std::vector<int>& strategy_counts,
    const std::string& scenario,
    int total_vehicles
) {
    // 验证输入数据
    if (strategy_counts.size() != 4) {
        std::cerr << "Error: Strategy counts must have exactly 4 elements [SC, SP, DC, DP]" << std::endl;
        return;
    }
    
    // 计算总车辆数
    int total = total_vehicles > 0 ? total_vehicles : 
                std::accumulate(strategy_counts.begin(), strategy_counts.end(), 0);
    
    if (total == 0) {
        std::cerr << "Warning: No vehicles detected at timestamp " << timestamp << std::endl;
        return;
    }
    
    // 计算策略占比
    double pi_SC = static_cast<double>(strategy_counts[SC]) / total;
    double pi_SP = static_cast<double>(strategy_counts[SP]) / total;
    double pi_DC = static_cast<double>(strategy_counts[DC]) / total;
    double pi_DP = static_cast<double>(strategy_counts[DP]) / total;
    
    // 创建快照
    StrategySnapshot snapshot;
    snapshot.timestamp = timestamp;
    snapshot.pi_SC = pi_SC;
    snapshot.pi_SP = pi_SP;
    snapshot.pi_DC = pi_DC;
    snapshot.pi_DP = pi_DP;
    snapshot.scenario = scenario.empty() ? detectCongestionScenario(strategy_counts) : scenario;
    snapshot.simulation_run = current_run_id;
    snapshot.total_vehicles = total;
    
    // 验证和归一化
    if (!validateStrategySnapshot(snapshot)) {
        normalizeDistribution(snapshot);
    }
    
    // 存储快照
    snapshots.push_back(snapshot);
    sliding_window.push_back(snapshot);
    
    // 维护滑动窗口大小
    if (sliding_window.size() > max_window_size) {
        sliding_window.pop_front();
    }
    
    // 更新统计数据
    updateStrategyStatistics(snapshot);
    
    // 更新场景
    current_scenario = snapshot.scenario;
    last_collection_time = timestamp;
    
    // 实时导出（如果启用）
    if (enable_real_time_export && snapshots.size() % 10 == 0) {
        exportRunData(current_run_id);
    }
}

void VehicleMixingStrategyCollector::recordStrategyDistribution(
    double timestamp,
    double pi_SC, double pi_SP, double pi_DC, double pi_DP,
    const std::string& scenario
) {
    StrategySnapshot snapshot;
    snapshot.timestamp = timestamp;
    snapshot.pi_SC = pi_SC;
    snapshot.pi_SP = pi_SP;
    snapshot.pi_DC = pi_DC;
    snapshot.pi_DP = pi_DP;
    snapshot.scenario = scenario.empty() ? current_scenario : scenario;
    snapshot.simulation_run = current_run_id;
    snapshot.total_vehicles = 0;  // 未知总数
    
    // 验证和归一化
    if (!validateStrategySnapshot(snapshot)) {
        normalizeDistribution(snapshot);
    }
    
    // 存储快照
    snapshots.push_back(snapshot);
    sliding_window.push_back(snapshot);
    
    // 维护滑动窗口大小
    if (sliding_window.size() > max_window_size) {
        sliding_window.pop_front();
    }
    
    // 更新统计数据
    updateStrategyStatistics(snapshot);
    
    // 更新场景
    current_scenario = snapshot.scenario;
    last_collection_time = timestamp;
}

void VehicleMixingStrategyCollector::updateScenario(const std::string& new_scenario) {
    current_scenario = new_scenario;
}

std::string VehicleMixingStrategyCollector::detectCongestionScenario(const std::vector<int>& strategy_counts) {
    if (strategy_counts.size() != 4) return "unknown";
    
    int total = std::accumulate(strategy_counts.begin(), strategy_counts.end(), 0);
    if (total == 0) return "no_vehicles";
    
    // 基于策略分布检测场景
    double cooperate_ratio = static_cast<double>(strategy_counts[SC] + strategy_counts[DC]) / total;
    double share_ratio = static_cast<double>(strategy_counts[SC] + strategy_counts[SP]) / total;
    
    if (cooperate_ratio > 0.7) {
        return "high_cooperation";
    } else if (cooperate_ratio < 0.3) {
        return "low_cooperation";
    } else if (share_ratio > 0.7) {
        return "high_sharing";
    } else if (share_ratio < 0.3) {
        return "low_sharing";
    } else {
        return "balanced";
    }
}

void VehicleMixingStrategyCollector::exportData() {
    exportRunData(current_run_id);
}

void VehicleMixingStrategyCollector::exportRunData(int run_id) {
    std::string filename = generateFilename("vehicle_mixing_strategy", run_id);
    std::ofstream file(filename);
    
    if (!file.is_open()) {
        std::cerr << "Failed to open file for writing: " << filename << std::endl;
        return;
    }
    
    writeCSVHeader(file);
    
    // 过滤当前运行的快照
    for (const auto& snapshot : snapshots) {
        if (snapshot.simulation_run == run_id) {
            writeStrategySnapshot(file, snapshot);
        }
    }
    
    file.close();
    std::cout << "Vehicle mixing strategy data exported to: " << filename << std::endl;
    std::cout << "Total data points: " << snapshots.size() << std::endl;
}

void VehicleMixingStrategyCollector::exportAggregatedData() {
    // 按运行收集数据
    std::map<int, std::vector<StrategySnapshot>> runs;
    for (const auto& snapshot : snapshots) {
        runs[snapshot.simulation_run].push_back(snapshot);
    }
    
    if (runs.empty()) {
        std::cerr << "No data to export" << std::endl;
        return;
    }
    
    std::string filename = generateFilename("vehicle_mixing_strategy_aggregated", current_run_id);
    std::ofstream file(filename);
    
    if (!file.is_open()) {
        std::cerr << "Failed to open file for writing: " << filename << std::endl;
        return;
    }
    
    writeAggregatedCSVHeader(file);
    
    // 创建时间点到数据的映射
    std::map<double, std::vector<StrategySnapshot>> time_groups;
    for (const auto& run_entry : runs) {
        for (const auto& snapshot : run_entry.second) {
            time_groups[snapshot.timestamp].push_back(snapshot);
        }
    }
    
    // 导出聚合数据
    for (const auto& time_entry : time_groups) {
        double timestamp = time_entry.first;
        const auto& snapshots_at_time = time_entry.second;
        
        if (snapshots_at_time.empty()) continue;
        
        // 计算均值和标准差
        double mean_SC = 0, mean_SP = 0, mean_DC = 0, mean_DP = 0;
        for (const auto& snapshot : snapshots_at_time) {
            mean_SC += snapshot.pi_SC;
            mean_SP += snapshot.pi_SP;
            mean_DC += snapshot.pi_DC;
            mean_DP += snapshot.pi_DP;
        }
        size_t count = snapshots_at_time.size();
        mean_SC /= count;
        mean_SP /= count;
        mean_DC /= count;
        mean_DP /= count;
        
        // 计算标准差
        double std_SC = 0, std_SP = 0, std_DC = 0, std_DP = 0;
        for (const auto& snapshot : snapshots_at_time) {
            std_SC += std::pow(snapshot.pi_SC - mean_SC, 2);
            std_SP += std::pow(snapshot.pi_SP - mean_SP, 2);
            std_DC += std::pow(snapshot.pi_DC - mean_DC, 2);
            std_DP += std::pow(snapshot.pi_DP - mean_DP, 2);
        }
        std_SC = std::sqrt(std_SC / count);
        std_SP = std::sqrt(std_SP / count);
        std_DC = std::sqrt(std_DC / count);
        std_DP = std::sqrt(std_DP / count);
        
        // 写入聚合数据
        file << std::fixed << std::setprecision(6) << timestamp
             << "," << mean_SC << "," << std_SC
             << "," << mean_SP << "," << std_SP
             << "," << mean_DC << "," << std_DC
             << "," << mean_DP << "," << std_DP
             << "," << snapshots_at_time[0].scenario
             << "," << count << "\n";
    }
    
    file.close();
    std::cout << "Aggregated vehicle mixing strategy data exported to: " << filename << std::endl;
}

void VehicleMixingStrategyCollector::exportRawData() {
    if (snapshots.empty()) {
        std::cerr << "No raw data to export" << std::endl;
        return;
    }
    
    std::string filename = generateFilename("vehicle_mixing_strategy_raw", current_run_id);
    std::ofstream file(filename);
    
    if (!file.is_open()) {
        std::cerr << "Failed to open file for writing: " << filename << std::endl;
        return;
    }
    
    writeCSVHeader(file);
    
    // 写入所有原始数据
    for (const auto& snapshot : snapshots) {
        writeStrategySnapshot(file, snapshot);
    }
    
    file.close();
    std::cout << "Raw vehicle mixing strategy data exported to: " << filename << std::endl;
    std::cout << "Total data points: " << snapshots.size() << std::endl;
}

void VehicleMixingStrategyCollector::finalizeAndExport() {
    calculateStatistics();
    exportData();
    exportAggregatedData();
}

void VehicleMixingStrategyCollector::calculateStatistics() {
    if (snapshots.empty()) return;
    
    // 计算全局统计
    updateRunningStatistics();
    
    // 按场景计算统计
    std::map<std::string, std::vector<StrategySnapshot>> scenario_groups;
    for (const auto& snapshot : snapshots) {
        scenario_groups[snapshot.scenario].push_back(snapshot);
    }
    
    for (const auto& scenario_entry : scenario_groups) {
        const std::string& scenario = scenario_entry.first;
        const auto& scenario_snapshots = scenario_entry.second;
        
        if (scenario_snapshots.empty()) continue;
        
        StrategyStatistics stats;
        
        // 计算均值
        for (const auto& snapshot : scenario_snapshots) {
            stats.mean_SC += snapshot.pi_SC;
            stats.mean_SP += snapshot.pi_SP;
            stats.mean_DC += snapshot.pi_DC;
            stats.mean_DP += snapshot.pi_DP;
        }
        stats.sample_count = scenario_snapshots.size();
        stats.mean_SC /= stats.sample_count;
        stats.mean_SP /= stats.sample_count;
        stats.mean_DC /= stats.sample_count;
        stats.mean_DP /= stats.sample_count;
        
        // 计算标准差和极值
        std::vector<double> sc_values, sp_values, dc_values, dp_values;
        for (const auto& snapshot : scenario_snapshots) {
            sc_values.push_back(snapshot.pi_SC);
            sp_values.push_back(snapshot.pi_SP);
            dc_values.push_back(snapshot.pi_DC);
            dp_values.push_back(snapshot.pi_DP);
        }
        
        stats.std_SC = calculateStandardDeviation(sc_values, stats.mean_SC);
        stats.std_SP = calculateStandardDeviation(sp_values, stats.mean_SP);
        stats.std_DC = calculateStandardDeviation(dc_values, stats.mean_DC);
        stats.std_DP = calculateStandardDeviation(dp_values, stats.mean_DP);
        
        stats.min_SC = *std::min_element(sc_values.begin(), sc_values.end());
        stats.min_SP = *std::min_element(sp_values.begin(), sp_values.end());
        stats.min_DC = *std::min_element(dc_values.begin(), dc_values.end());
        stats.min_DP = *std::min_element(dp_values.begin(), dp_values.end());
        
        stats.max_SC = *std::max_element(sc_values.begin(), sc_values.end());
        stats.max_SP = *std::max_element(sp_values.begin(), sp_values.end());
        stats.max_DC = *std::max_element(dc_values.begin(), dc_values.end());
        stats.max_DP = *std::max_element(dp_values.begin(), dp_values.end());
        
        scenario_stats[scenario] = stats;
    }
}

void VehicleMixingStrategyCollector::updateStrategyStatistics(const StrategySnapshot& snapshot) {
    strategy_stats.sample_count++;
    
    // 更新均值（增量计算）
    double n = static_cast<double>(strategy_stats.sample_count);
    strategy_stats.mean_SC += (snapshot.pi_SC - strategy_stats.mean_SC) / n;
    strategy_stats.mean_SP += (snapshot.pi_SP - strategy_stats.mean_SP) / n;
    strategy_stats.mean_DC += (snapshot.pi_DC - strategy_stats.mean_DC) / n;
    strategy_stats.mean_DP += (snapshot.pi_DP - strategy_stats.mean_DP) / n;
    
    // 更新极值
    strategy_stats.min_SC = std::min(strategy_stats.min_SC, snapshot.pi_SC);
    strategy_stats.min_SP = std::min(strategy_stats.min_SP, snapshot.pi_SP);
    strategy_stats.min_DC = std::min(strategy_stats.min_DC, snapshot.pi_DC);
    strategy_stats.min_DP = std::min(strategy_stats.min_DP, snapshot.pi_DP);
    
    strategy_stats.max_SC = std::max(strategy_stats.max_SC, snapshot.pi_SC);
    strategy_stats.max_SP = std::max(strategy_stats.max_SP, snapshot.pi_SP);
    strategy_stats.max_DC = std::max(strategy_stats.max_DC, snapshot.pi_DC);
    strategy_stats.max_DP = std::max(strategy_stats.max_DP, snapshot.pi_DP);
}

void VehicleMixingStrategyCollector::reset() {
    snapshots.clear();
    sliding_window.clear();
    strategy_stats = StrategyStatistics();
    scenario_stats.clear();
    last_collection_time = 0.0;
    current_scenario = "unknown";
}

void VehicleMixingStrategyCollector::clearData() {
    reset();
}

size_t VehicleMixingStrategyCollector::getSnapshotCount() const {
    return snapshots.size();
}

VehicleMixingStrategyCollector::StrategySnapshot VehicleMixingStrategyCollector::getLastSnapshot() const {
    if (snapshots.empty()) {
        return StrategySnapshot();
    }
    return snapshots.back();
}

std::vector<double> VehicleMixingStrategyCollector::getAverageDistribution() const {
    if (strategy_stats.sample_count == 0) {
        return {0.25, 0.25, 0.25, 0.25};  // 默认均匀分布
    }
    return {strategy_stats.mean_SC, strategy_stats.mean_SP, 
            strategy_stats.mean_DC, strategy_stats.mean_DP};
}

std::string VehicleMixingStrategyCollector::generateFilename(const std::string& prefix, int run_id) const {
    std::string filename = output_directory + prefix;
    if (run_id >= 0) {
        filename += "_run_" + std::to_string(run_id);
    }
    
    // 添加时间戳以避免文件覆盖
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto local_time = std::localtime(&time_t);
    char timestamp[20];
    std::strftime(timestamp, sizeof(timestamp), "_%Y%m%d_%H%M%S", local_time);
    filename += timestamp;
    
    filename += ".csv";
    return filename;
}

void VehicleMixingStrategyCollector::writeCSVHeader(std::ofstream& file) const {
    file << "time,pi_SC,pi_SP,pi_DC,pi_DP,scenario,run_id,total_vehicles\n";
}

void VehicleMixingStrategyCollector::writeStrategySnapshot(std::ofstream& file, const StrategySnapshot& snapshot) const {
    file << std::fixed << std::setprecision(6) << snapshot.timestamp;
    file << "," << snapshot.pi_SC;
    file << "," << snapshot.pi_SP; 
    file << "," << snapshot.pi_DC;
    file << "," << snapshot.pi_DP;
    file << "," << snapshot.scenario;
    file << "," << snapshot.simulation_run;
    file << "," << snapshot.total_vehicles;
    file << "\n";
}

void VehicleMixingStrategyCollector::writeAggregatedCSVHeader(std::ofstream& file) const {
    file << "time,pi_SC_mean,pi_SC_std,pi_SP_mean,pi_SP_std,pi_DC_mean,pi_DC_std,pi_DP_mean,pi_DP_std,scenario,num_runs\n";
}

bool VehicleMixingStrategyCollector::validateStrategySnapshot(const StrategySnapshot& snapshot) const {
    return snapshot.isNormalized();
}

void VehicleMixingStrategyCollector::normalizeDistribution(StrategySnapshot& snapshot) const {
    double sum = snapshot.pi_SC + snapshot.pi_SP + snapshot.pi_DC + snapshot.pi_DP;
    if (sum > 0) {
        snapshot.pi_SC /= sum;
        snapshot.pi_SP /= sum;
        snapshot.pi_DC /= sum;
        snapshot.pi_DP /= sum;
    } else {
        // 如果所有值都为0，设置为均匀分布
        snapshot.pi_SC = snapshot.pi_SP = snapshot.pi_DC = snapshot.pi_DP = 0.25;
    }
}

void VehicleMixingStrategyCollector::updateRunningStatistics() {
    if (snapshots.empty()) return;
    
    // 重新计算完整统计数据
    std::vector<double> sc_values, sp_values, dc_values, dp_values;
    for (const auto& snapshot : snapshots) {
        sc_values.push_back(snapshot.pi_SC);
        sp_values.push_back(snapshot.pi_SP);
        dc_values.push_back(snapshot.pi_DC);
        dp_values.push_back(snapshot.pi_DP);
    }
    
    size_t n = snapshots.size();
    strategy_stats.sample_count = n;
    
    // 计算均值
    strategy_stats.mean_SC = std::accumulate(sc_values.begin(), sc_values.end(), 0.0) / n;
    strategy_stats.mean_SP = std::accumulate(sp_values.begin(), sp_values.end(), 0.0) / n;
    strategy_stats.mean_DC = std::accumulate(dc_values.begin(), dc_values.end(), 0.0) / n;
    strategy_stats.mean_DP = std::accumulate(dp_values.begin(), dp_values.end(), 0.0) / n;
    
    // 计算标准差
    strategy_stats.std_SC = calculateStandardDeviation(sc_values, strategy_stats.mean_SC);
    strategy_stats.std_SP = calculateStandardDeviation(sp_values, strategy_stats.mean_SP);
    strategy_stats.std_DC = calculateStandardDeviation(dc_values, strategy_stats.mean_DC);
    strategy_stats.std_DP = calculateStandardDeviation(dp_values, strategy_stats.mean_DP);
}

double VehicleMixingStrategyCollector::calculateStandardDeviation(const std::vector<double>& values, double mean) const {
    if (values.empty()) return 0.0;
    
    double sum_sq_diff = 0.0;
    for (double value : values) {
        sum_sq_diff += std::pow(value - mean, 2);
    }
    return std::sqrt(sum_sq_diff / values.size());
}
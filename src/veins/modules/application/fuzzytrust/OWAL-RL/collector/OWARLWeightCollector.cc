#include "OWARLWeightCollector.h"
#include <iostream>
#include <algorithm>
#include <numeric>
#include <cmath>
#include <iomanip>
#include <set>
#include <sys/stat.h>
#include <sys/types.h>
#include <chrono>
#include <ctime>

using json = nlohmann::json;

OWARLWeightCollector::OWARLWeightCollector() 
    : output_directory("./results/OWAL-RL/data/")
    , collection_interval(1.0)
    , current_run_id(0)
    , current_node_id(0)
    , current_scenario("unknown")
    , last_collection_time(0.0)
    , max_window_size(1000)
    , enable_real_time_export(false)
    , collect_detailed_stats(true)
{
    initializeWeightHistory();
}

OWARLWeightCollector::OWARLWeightCollector(const std::string& output_dir)
    : OWARLWeightCollector()
{
    setOutputDirectory(output_dir);
}

void OWARLWeightCollector::setOutputDirectory(const std::string& output_dir) {
    output_directory = output_dir;
    
    // Create directory if it doesn't exist
    try {
        // Create output directory if it doesn't exist
        mkdir(output_directory.c_str(), 0755);
    } catch (const std::exception& e) {
        std::cerr << "Failed to create output directory: " << e.what() << std::endl;
    }
}

void OWARLWeightCollector::setCollectionInterval(double interval_seconds) {
    collection_interval = interval_seconds;
}

void OWARLWeightCollector::setRunId(int run_id) {
    current_run_id = run_id;
}

void OWARLWeightCollector::setNodeId(int node_id) {
    current_node_id = node_id;
}

void OWARLWeightCollector::loadConfig(const json& config) {
    if (config.contains("collection_interval")) {
        collection_interval = config["collection_interval"];
    }
    if (config.contains("max_window_size")) {
        max_window_size = config["max_window_size"];
    }
    if (config.contains("enable_real_time_export")) {
        enable_real_time_export = config["enable_real_time_export"];
    }
    if (config.contains("collect_detailed_stats")) {
        collect_detailed_stats = config["collect_detailed_stats"];
    }
    if (config.contains("output_directory")) {
        setOutputDirectory(config["output_directory"]);
    }
}

void OWARLWeightCollector::recordWeightSnapshot(
    double timestamp,
    const std::vector<double>& weights,
    const std::vector<double>& membership_values,
    const std::string& scenario,
    double owa_reward
) {
    // 移除时间限制，允许更频繁的数据收集
    // if (timestamp - last_collection_time < 0.1) {
    //     return;
    // }
    
    // Create snapshot
    WeightSnapshot snapshot;
    snapshot.timestamp = timestamp;
    snapshot.weights = weights;
    snapshot.membership_values = membership_values;
    snapshot.scenario = scenario.empty() ? detectCongestionScenario(membership_values) : scenario;
    snapshot.owa_reward = owa_reward;
    snapshot.simulation_run = current_run_id;
    snapshot.node_id = current_node_id;
    
    // Store snapshot
    snapshots.push_back(snapshot);
    sliding_window.push_back(snapshot);
    
    // Maintain sliding window size
    if (sliding_window.size() > max_window_size) {
        sliding_window.pop_front();
    }
    
    // Update weight history for statistics
    updateWeightHistory(weights);
    
    // Update scenario
    current_scenario = snapshot.scenario;
    last_collection_time = timestamp;
    
    // Real-time export if enabled
    if (enable_real_time_export && snapshots.size() % 10 == 0) {
        exportRunData(current_run_id);
    }
}

void OWARLWeightCollector::updateScenario(const std::string& new_scenario) {
    current_scenario = new_scenario;
}

void OWARLWeightCollector::markTransition(double timestamp, const std::string& from_scenario, const std::string& to_scenario) {
    // Record a transition marker
    WeightSnapshot transition_marker;
    transition_marker.timestamp = timestamp;
    transition_marker.weights = {0, 0, 0}; // Placeholder
    transition_marker.membership_values = {0, 0, 0}; // Placeholder
    transition_marker.scenario = "transition_" + from_scenario + "_to_" + to_scenario;
    transition_marker.owa_reward = 0.0;
    transition_marker.simulation_run = current_run_id;
    transition_marker.node_id = current_node_id;
    
    snapshots.push_back(transition_marker);
}

void OWARLWeightCollector::exportData() {
    exportRunData(current_run_id);
}

void OWARLWeightCollector::exportRunData(int run_id) {
    std::string filename = generateFilename("weight_evolution", run_id);
    std::ofstream file(filename);
    
    if (!file.is_open()) {
        std::cerr << "Failed to open file for writing: " << filename << std::endl;
        return;
    }
    
    writeCSVHeader(file);
    
    // Filter snapshots for this run
    for (const auto& snapshot : snapshots) {
        if (snapshot.simulation_run == run_id) {
            writeWeightSnapshot(file, snapshot);
        }
    }
    
    file.close();
    std::cout << "Weight evolution data exported to: " << filename << std::endl;
}

void OWARLWeightCollector::exportAggregatedData() {
    // Collect data by run
    std::map<int, std::vector<WeightSnapshot>> runs;
    for (const auto& snapshot : snapshots) {
        runs[snapshot.simulation_run].push_back(snapshot);
    }
    
    if (runs.empty()) {
        std::cerr << "No data to export" << std::endl;
        return;
    }
    
    std::string filename = generateFilename("weight_evolution_aggregated", current_run_id);
    std::ofstream file(filename);
    
    if (!file.is_open()) {
        std::cerr << "Failed to open file for writing: " << filename << std::endl;
        return;
    }
    
    // Write header with statistics
    file << "time,w1_mean,w1_std,w2_mean,w2_std,w3_mean,w3_std,scenario,reward_mean,reward_std,num_runs\n";
    
    // Find common time points across runs
    std::set<double> all_timestamps;
    for (const auto& run_entry : runs) {
        int run_id = run_entry.first;
        const auto& run_snapshots = run_entry.second;
        for (const auto& snapshot : run_snapshots) {
            all_timestamps.insert(snapshot.timestamp);
        }
    }
    
    // Calculate statistics for each time point
    for (double timestamp : all_timestamps) {
        std::vector<std::vector<double>> weights_at_time;
        std::vector<double> rewards_at_time;
        std::string dominant_scenario = "unknown";
        std::map<std::string, int> scenario_counts;
        
        // Collect data from all runs at this timestamp (with tolerance)
        const double time_tolerance = collection_interval / 2.0;
        for (const auto& run_entry : runs) {
        int run_id = run_entry.first;
        const auto& run_snapshots = run_entry.second;
            for (const auto& snapshot : run_snapshots) {
                if (std::abs(snapshot.timestamp - timestamp) <= time_tolerance) {
                    weights_at_time.push_back(snapshot.weights);
                    rewards_at_time.push_back(snapshot.owa_reward);
                    scenario_counts[snapshot.scenario]++;
                }
            }
        }
        
        if (weights_at_time.empty()) continue;
        
        // Find dominant scenario
        int max_count = 0;
        for (const auto& scenario_entry : scenario_counts) {
            const auto& scenario = scenario_entry.first;
            int count = scenario_entry.second;
            if (count > max_count) {
                max_count = count;
                dominant_scenario = scenario;
            }
        }
        
        // Calculate statistics
        std::vector<double> w_means(3, 0.0);
        std::vector<double> w_stds(3, 0.0);
        
        // Calculate means
        for (const auto& weights : weights_at_time) {
            for (size_t i = 0; i < 3 && i < weights.size(); ++i) {
                w_means[i] += weights[i];
            }
        }
        for (auto& mean : w_means) {
            mean /= weights_at_time.size();
        }
        
        // Calculate standard deviations
        for (const auto& weights : weights_at_time) {
            for (size_t i = 0; i < 3 && i < weights.size(); ++i) {
                w_stds[i] += std::pow(weights[i] - w_means[i], 2);
            }
        }
        for (auto& std_dev : w_stds) {
            std_dev = std::sqrt(std_dev / weights_at_time.size());
        }
        
        // Calculate reward statistics
        double reward_mean = std::accumulate(rewards_at_time.begin(), rewards_at_time.end(), 0.0) / rewards_at_time.size();
        double reward_std = 0.0;
        for (double reward : rewards_at_time) {
            reward_std += std::pow(reward - reward_mean, 2);
        }
        reward_std = std::sqrt(reward_std / rewards_at_time.size());
        
        // Write row
        file << std::fixed << std::setprecision(3) << timestamp << ","
             << w_means[0] << "," << w_stds[0] << ","
             << w_means[1] << "," << w_stds[1] << ","
             << w_means[2] << "," << w_stds[2] << ","
             << dominant_scenario << ","
             << reward_mean << "," << reward_std << ","
             << weights_at_time.size() << "\n";
    }
    
    file.close();
    std::cout << "Aggregated weight evolution data exported to: " << filename << std::endl;
}

void OWARLWeightCollector::exportRawData() {
    if (snapshots.empty()) {
        std::cerr << "No raw data to export" << std::endl;
        return;
    }
    
    std::string filename = generateFilename("weight_evolution_raw", current_run_id);
    std::ofstream file(filename);
    
    if (!file.is_open()) {
        std::cerr << "Failed to open file for writing: " << filename << std::endl;
        return;
    }
    
    // 写入CSV头部
    writeCSVHeader(file);
    
    // 写入所有原始数据
    for (const auto& snapshot : snapshots) {
        writeWeightSnapshot(file, snapshot);
    }
    
    file.close();
    std::cout << "Raw weight evolution data exported to: " << filename << std::endl;
    std::cout << "Total data points: " << snapshots.size() << std::endl;
}

void OWARLWeightCollector::clearData() {
    snapshots.clear();
    sliding_window.clear();
    run_data.clear();
    initializeWeightHistory();
    last_collection_time = 0.0;
}

std::map<std::string, std::vector<double>> OWARLWeightCollector::getWeightStatistics() const {
    std::map<std::string, std::vector<double>> stats;
    
    if (weight_history.empty() || weight_history[0].empty()) {
        return stats;
    }
    
    stats["means"] = getWeightMeans();
    stats["std_devs"] = getWeightStandardDeviations();
    
    // Calculate min/max
    std::vector<double> mins(3), maxs(3);
    for (size_t i = 0; i < 3; ++i) {
        if (!weight_history[i].empty()) {
            mins[i] = *std::min_element(weight_history[i].begin(), weight_history[i].end());
            maxs[i] = *std::max_element(weight_history[i].begin(), weight_history[i].end());
        }
    }
    stats["mins"] = mins;
    stats["maxs"] = maxs;
    
    return stats;
}

std::vector<double> OWARLWeightCollector::getWeightMeans() const {
    return calculateMean(weight_history);
}

std::vector<double> OWARLWeightCollector::getWeightStandardDeviations() const {
    auto means = getWeightMeans();
    return calculateStdDev(weight_history, means);
}

// Private methods
void OWARLWeightCollector::initializeWeightHistory() {
    weight_history.clear();
    weight_history.resize(3); // w1, w2, w3
}

void OWARLWeightCollector::updateWeightHistory(const std::vector<double>& weights) {
    for (size_t i = 0; i < 3 && i < weights.size(); ++i) {
        weight_history[i].push_back(weights[i]);
        
        // Maintain history size
        if (weight_history[i].size() > max_window_size) {
            weight_history[i].erase(weight_history[i].begin());
        }
    }
}

std::string OWARLWeightCollector::generateFilename(const std::string& prefix, int run_id) const {
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

void OWARLWeightCollector::writeCSVHeader(std::ofstream& file) const {
    file << "time,w1,w2,w3,mu_trust,mu_delay,mu_resource,scenario,owa_reward,run_id,node_id\n";
}

void OWARLWeightCollector::writeWeightSnapshot(std::ofstream& file, const WeightSnapshot& snapshot) const {
    file << std::fixed << std::setprecision(6) << snapshot.timestamp;
    
    // Write weights
    for (size_t i = 0; i < snapshot.weights.size(); ++i) {
        file << "," << snapshot.weights[i];
    }
    
    // Write membership values
    for (size_t i = 0; i < snapshot.membership_values.size(); ++i) {
        file << "," << snapshot.membership_values[i];
    }
    
    file << "," << snapshot.scenario
         << "," << snapshot.owa_reward
         << "," << snapshot.simulation_run
         << "," << snapshot.node_id << "\n";
}

std::vector<double> OWARLWeightCollector::calculateMean(const std::vector<std::vector<double>>& data) const {
    std::vector<double> means(data.size(), 0.0);
    
    for (size_t i = 0; i < data.size(); ++i) {
        if (!data[i].empty()) {
            means[i] = std::accumulate(data[i].begin(), data[i].end(), 0.0) / data[i].size();
        }
    }
    
    return means;
}

std::vector<double> OWARLWeightCollector::calculateStdDev(const std::vector<std::vector<double>>& data, const std::vector<double>& means) const {
    std::vector<double> std_devs(data.size(), 0.0);
    
    for (size_t i = 0; i < data.size(); ++i) {
        if (!data[i].empty()) {
            double variance = 0.0;
            for (double value : data[i]) {
                variance += std::pow(value - means[i], 2);
            }
            std_devs[i] = std::sqrt(variance / data[i].size());
        }
    }
    
    return std_devs;
}

std::string OWARLWeightCollector::detectCongestionScenario(const std::vector<double>& membership_values) const {
    if (membership_values.size() < 3) {
        return "unknown";
    }
    
    double mu_trust = membership_values[0];
    double mu_delay = membership_values[1];
    double mu_resource = membership_values[2];
    
    // Simple heuristic for scenario detection
    if (mu_delay < 0.3 || mu_resource < 0.3) {
        return "high_congestion";
    } else if (mu_delay > 0.7 && mu_resource > 0.7) {
        return "low_congestion";
    } else {
        return "medium_congestion";
    }
}

bool OWARLWeightCollector::isTransitionState(const std::vector<double>& current_membership, const std::vector<double>& previous_membership) const {
    if (current_membership.size() != previous_membership.size() || current_membership.size() < 3) {
        return false;
    }
    
    // Check if any membership value changed significantly
    const double transition_threshold = 0.2;
    for (size_t i = 0; i < current_membership.size(); ++i) {
        if (std::abs(current_membership[i] - previous_membership[i]) > transition_threshold) {
            return true;
        }
    }
    
    return false;
}
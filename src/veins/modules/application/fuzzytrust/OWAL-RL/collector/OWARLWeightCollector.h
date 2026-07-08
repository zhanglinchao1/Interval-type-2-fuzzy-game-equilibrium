#ifndef OWARL_WEIGHT_COLLECTOR_H
#define OWARL_WEIGHT_COLLECTOR_H

#include <vector>
#include <string>
#include <fstream>
#include <map>
#include <deque>
#include "../../json.hpp"

struct WeightSnapshot {
    double timestamp;
    std::vector<double> weights;  // w1, w2, w3
    std::vector<double> membership_values;  // μ_trust, μ_delay, μ_resource
    std::string scenario;  // "low_congestion", "high_congestion", "transition"
    double owa_reward;
    int simulation_run;
    int node_id;
};

class OWARLWeightCollector {
public:
    // Constructor
    OWARLWeightCollector();
    explicit OWARLWeightCollector(const std::string& output_dir);
    
    // Configuration
    void setOutputDirectory(const std::string& output_dir);
    void setCollectionInterval(double interval_seconds);
    void setRunId(int run_id);
    void setNodeId(int node_id);
    
    // Data collection
    void recordWeightSnapshot(
        double timestamp,
        const std::vector<double>& weights,
        const std::vector<double>& membership_values,
        const std::string& scenario,
        double owa_reward
    );
    
    // Scenario management
    void updateScenario(const std::string& new_scenario);
    void markTransition(double timestamp, const std::string& from_scenario, const std::string& to_scenario);
    
    // Output management
    void exportData();
    void exportRunData(int run_id);
    void exportAggregatedData();
    void exportRawData();
    void clearData();
    
    // Statistics
    std::map<std::string, std::vector<double>> getWeightStatistics() const;
    std::vector<double> getWeightMeans() const;
    std::vector<double> getWeightStandardDeviations() const;
    
    // Configuration from JSON
    void loadConfig(const nlohmann::json& config);

private:
    std::string output_directory;
    double collection_interval;
    int current_run_id;
    int current_node_id;
    std::string current_scenario;
    
    // Data storage
    std::vector<WeightSnapshot> snapshots;
    std::deque<WeightSnapshot> sliding_window;
    std::map<int, std::vector<WeightSnapshot>> run_data;  // run_id -> snapshots
    
    // Statistics tracking
    std::vector<std::vector<double>> weight_history;  // [w1_history, w2_history, w3_history]
    double last_collection_time;
    
    // Configuration parameters
    size_t max_window_size;
    bool enable_real_time_export;
    bool collect_detailed_stats;
    
    // Internal methods
    void initializeWeightHistory();
    void updateWeightHistory(const std::vector<double>& weights);
    std::string generateFilename(const std::string& prefix, int run_id = -1) const;
    void writeCSVHeader(std::ofstream& file) const;
    void writeWeightSnapshot(std::ofstream& file, const WeightSnapshot& snapshot) const;
    std::vector<double> calculateMean(const std::vector<std::vector<double>>& data) const;
    std::vector<double> calculateStdDev(const std::vector<std::vector<double>>& data, const std::vector<double>& means) const;
    
    // Scenario detection helpers
    std::string detectCongestionScenario(const std::vector<double>& membership_values) const;
    bool isTransitionState(const std::vector<double>& current_membership, const std::vector<double>& previous_membership) const;
};

#endif
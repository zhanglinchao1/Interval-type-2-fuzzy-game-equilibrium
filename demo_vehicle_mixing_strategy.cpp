#include "../../src/veins/modules/application/fuzzytrust/VehicleMixingStrategy/VehicleMixingStrategyCollector.h"
#include <iostream>
#include <random>

int main() {
    try {
        // Initialize collector with the expected directory structure
        VehicleMixingStrategyCollector collector("results/Vehicle Mixing Strategy/data/");
        
        // Set up simulation parameters
        collector.setRunId(1);
        collector.setCollectionInterval(0.5);
        
        std::cout << "=== 车辆混合策略分布数据收集演示 ===" << std::endl;
        std::cout << "模拟OWAL-RL类似的数据收集过程..." << std::endl;
        
        // Simulate data collection over time (similar to OWAL-RL pattern)
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> vehicle_count(40, 60);
        
        double simulation_time = 0.0;
        const double time_step = 0.5;
        const double max_time = 10.0;
        
        while (simulation_time <= max_time) {
            // Generate realistic strategy distribution that evolves over time
            int total_vehicles = vehicle_count(gen);
            
            // Simulate strategy evolution (strategies change over time due to game theory)
            double time_factor = simulation_time / max_time;
            
            // SC (Share-Cooperate) - starts high, decreases due to competition
            int sc_count = static_cast<int>((0.4 - 0.1 * time_factor) * total_vehicles);
            
            // SP (Share-Preserve) - increases as vehicles become more cautious
            int sp_count = static_cast<int>((0.2 + 0.15 * time_factor) * total_vehicles);
            
            // DC (Deny-Cooperate) - fluctuates based on congestion
            int dc_count = static_cast<int>((0.25 + 0.1 * sin(time_factor * 3.14159)) * total_vehicles);
            
            // DP (Deny-Preserve) - remaining vehicles
            int dp_count = total_vehicles - sc_count - sp_count - dc_count;
            if (dp_count < 0) dp_count = 0;
            
            std::vector<int> strategy_counts = {sc_count, sp_count, dc_count, dp_count};
            
            // Determine scenario based on congestion
            std::string scenario;
            double cooperation_ratio = static_cast<double>(sc_count + dc_count) / total_vehicles;
            if (cooperation_ratio > 0.6) {
                scenario = "high_cooperation";
            } else if (cooperation_ratio < 0.4) {
                scenario = "low_cooperation"; 
            } else {
                scenario = "balanced";
            }
            
            // Record the snapshot
            collector.recordStrategySnapshot(simulation_time, strategy_counts, scenario, total_vehicles);
            
            std::cout << "Time: " << simulation_time << "s, Total: " << total_vehicles 
                     << ", SC: " << sc_count << ", SP: " << sp_count 
                     << ", DC: " << dc_count << ", DP: " << dp_count 
                     << ", Scenario: " << scenario << std::endl;
            
            simulation_time += time_step;
        }
        
        std::cout << "\\n总计收集 " << collector.getSnapshotCount() << " 个数据点" << std::endl;
        
        // Export data (following OWAL-RL pattern)
        std::cout << "\\n导出数据..." << std::endl;
        collector.exportRunData(1);  // Export run-specific data
        collector.exportAggregatedData();  // Export aggregated statistics
        
        std::cout << "\\n=== 数据收集和导出完成 ===" << std::endl;
        std::cout << "CSV文件已保存到: results/Vehicle Mixing Strategy/data/" << std::endl;
        std::cout << "\\n格式与OWAL-RL数据收集保持一致：" << std::endl;
        std::cout << "- 时间戳基础的快照记录" << std::endl;
        std::cout << "- 按运行ID分组的数据导出" << std::endl;
        std::cout << "- 聚合统计数据导出" << std::endl;
        std::cout << "- 唯一文件名避免覆盖" << std::endl;
        
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "错误: " << e.what() << std::endl;
        return 1;
    }
}
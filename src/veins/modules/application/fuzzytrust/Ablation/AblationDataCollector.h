#ifndef ABLATION_DATA_COLLECTOR_H
#define ABLATION_DATA_COLLECTOR_H

#include "AblationTestManager.h"
#include "KPICalculator.h"
#include <memory>
#include <string>
#include <fstream>
#include <chrono>
#include <map>
#include "../json.hpp"

/**
 * @brief 消融对照数据收集器
 * 
 * 负责收集4种模型配置的性能数据，计算KPI指标，
 * 并生成雷达图所需的CSV汇总数据
 */
class AblationDataCollector {
public:
    // 实验配置结构
    struct ExperimentConfig {
        std::string outputDirectory = "./results/Ablation/";
        int numRuns = 5;                    // 每个模型配置的运行次数
        double simulationTime = 300.0;      // 仿真时间(秒)
        double samplingInterval = 1.0;      // 采样间隔(秒)
        bool enableDetailedLogging = true;   // 是否启用详细日志
        bool enableRealTimeExport = false;   // 是否启用实时导出
    };

    // 运行时数据结构
    struct RunTimeData {
        double timestamp = 0.0;
        int nodeId = 0;
        double trustValue = 0.0;
        double delayValue = 0.0;
        double resourceUtilization = 0.0;
        double energyConsumption = 0.0;
        double completedTasks = 0.0;
        double totalTasks = 0.0;
        std::string modelType;
        int runId = 0;
    };

public:
    AblationDataCollector();
    explicit AblationDataCollector(const ExperimentConfig& config);
    ~AblationDataCollector();

    // 配置管理
    void setConfig(const ExperimentConfig& config);
    const ExperimentConfig& getConfig() const { return experimentConfig; }
    
    // 初始化和清理
    void initialize();
    void finalize();
    void reset();
    
    // 实验控制
    void startExperiment();
    void endExperiment();
    
    void startModelTest(AblationTestManager::ModelType modelType);
    void endModelTest();
    
    void startRun(int runId);
    void endRun();
    
    // 数据收集接口
    void recordPerformanceData(int nodeId, double timestamp, 
                              double trustValue, double delayValue,
                              double resourceUtilization, double energyConsumption,
                              double completedTasks, double totalTasks);
    
    void recordKPISample(double R_owa, double delay_rate, 
                        double energy_eff, double fairness_index);
    
    // 数据处理
    void processCurrentRun();
    void processCurrentModel();
    void processAllModels();
    
    // 导出功能
    void exportRunData(int runId);                          // 导出单次运行数据
    void exportModelData(AblationTestManager::ModelType type); // 导出模型汇总数据
    void exportRadarChartData();                            // 导出雷达图数据
    void exportDetailedResults();                          // 导出详细结果
    
    // 获取结果
    const AblationTestManager& getTestManager() const { return *testManager; }
    const KPICalculator& getKPICalculator() const { return *kpiCalculator; }
    
    // 统计信息
    size_t getTotalSamples() const;
    size_t getModelSamples(AblationTestManager::ModelType type) const;
    
    // 设置当前状态
    void setCurrentModel(AblationTestManager::ModelType type);
    void setCurrentRun(int runId);
    
private:
    std::unique_ptr<AblationTestManager> testManager;
    std::unique_ptr<KPICalculator> kpiCalculator;
    
    ExperimentConfig experimentConfig;
    
    // 当前状态
    AblationTestManager::ModelType currentModelType;
    int currentRunId = 0;
    bool experimentActive = false;
    bool modelTestActive = false;
    bool runActive = false;
    
    // 数据存储
    std::vector<RunTimeData> currentRunData;
    std::map<AblationTestManager::ModelType, std::vector<std::vector<RunTimeData>>> allRunsData;
    
    // 时间管理
    std::chrono::steady_clock::time_point experimentStartTime;
    std::chrono::steady_clock::time_point modelStartTime;
    std::chrono::steady_clock::time_point runStartTime;
    
    // 私有方法
    void createOutputDirectories();
    std::string generateTimestamp() const;
    std::string getModelTypeName(AblationTestManager::ModelType type) const;
    std::string generateFilename(const std::string& prefix, const std::string& suffix = "") const;
    
    // CSV导出辅助方法
    void writeRunDataCSV(const std::string& filename, const std::vector<RunTimeData>& data);
    void writeKPIDataCSV(const std::string& filename);
    void writeRadarDataCSV(const std::string& filename);
    
    // 统计计算
    void updateKPIStatistics();
    void calculateModelStatistics(AblationTestManager::ModelType type);
};

#endif // ABLATION_DATA_COLLECTOR_H
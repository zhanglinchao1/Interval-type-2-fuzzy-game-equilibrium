#include "AblationDataCollector.h"
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <sys/stat.h>
#include <sys/types.h>

using json = nlohmann::json;

AblationDataCollector::AblationDataCollector() 
    : testManager(std::make_unique<AblationTestManager>())
    , kpiCalculator(std::make_unique<KPICalculator>())
    , currentModelType(AblationTestManager::FULL_MODEL)
    , currentRunId(0)
    , experimentActive(false)
    , modelTestActive(false)
    , runActive(false) {
    
    initialize();
}

AblationDataCollector::AblationDataCollector(const ExperimentConfig& config)
    : AblationDataCollector() {
    setConfig(config);
}

AblationDataCollector::~AblationDataCollector() {
    if (experimentActive) {
        endExperiment();
    }
}

void AblationDataCollector::setConfig(const ExperimentConfig& config) {
    experimentConfig = config;
    createOutputDirectories();
}

void AblationDataCollector::initialize() {
    createOutputDirectories();
    reset();
}

void AblationDataCollector::finalize() {
    if (runActive) endRun();
    if (modelTestActive) endModelTest();
    if (experimentActive) endExperiment();
    
    // 处理所有数据并导出结果
    processAllModels();
    exportRadarChartData();
    exportDetailedResults();
}

void AblationDataCollector::reset() {
    testManager->reset();
    kpiCalculator->reset();
    
    currentRunData.clear();
    allRunsData.clear();
    
    currentRunId = 0;
    experimentActive = false;
    modelTestActive = false;
    runActive = false;
}

void AblationDataCollector::startExperiment() {
    experimentStartTime = std::chrono::steady_clock::now();
    experimentActive = true;
    
    std::cout << "[AblationDataCollector] Starting ablation experiment..." << std::endl;
    std::cout << "[AblationDataCollector] Output directory: " << experimentConfig.outputDirectory << std::endl;
}

void AblationDataCollector::endExperiment() {
    if (!experimentActive) return;
    
    auto endTime = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::seconds>(endTime - experimentStartTime);
    
    std::cout << "[AblationDataCollector] Experiment completed in " << duration.count() << " seconds" << std::endl;
    
    experimentActive = false;
}

void AblationDataCollector::startModelTest(AblationTestManager::ModelType modelType) {
    if (modelTestActive) endModelTest();
    
    currentModelType = modelType;
    testManager->setCurrentModel(modelType);
    modelStartTime = std::chrono::steady_clock::now();
    modelTestActive = true;
    
    std::cout << "[AblationDataCollector] Starting test for model: " 
              << getModelTypeName(modelType) << std::endl;
}

void AblationDataCollector::endModelTest() {
    if (!modelTestActive) return;
    
    processCurrentModel();
    
    auto endTime = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::seconds>(endTime - modelStartTime);
    
    std::cout << "[AblationDataCollector] Model test completed in " << duration.count() << " seconds" << std::endl;
    
    modelTestActive = false;
}

void AblationDataCollector::startRun(int runId) {
    if (runActive) endRun();
    
    currentRunId = runId;
    currentRunData.clear();
    kpiCalculator->reset(); // 重置当前运行的KPI计算器
    
    runStartTime = std::chrono::steady_clock::now();
    runActive = true;
    
    if (experimentConfig.enableDetailedLogging) {
        std::cout << "[AblationDataCollector] Starting run " << runId 
                  << " for model " << getModelTypeName(currentModelType) << std::endl;
    }
}

void AblationDataCollector::endRun() {
    if (!runActive) return;
    
    processCurrentRun();
    
    // 存储当前运行数据
    allRunsData[currentModelType].push_back(currentRunData);
    
    if (experimentConfig.enableDetailedLogging) {
        auto endTime = std::chrono::steady_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::seconds>(endTime - runStartTime);
        std::cout << "[AblationDataCollector] Run " << currentRunId 
                  << " completed in " << duration.count() << " seconds" << std::endl;
    }
    
    if (experimentConfig.enableRealTimeExport) {
        exportRunData(currentRunId);
    }
    
    runActive = false;
}

void AblationDataCollector::recordPerformanceData(int nodeId, double timestamp,
                                                  double trustValue, double delayValue,
                                                  double resourceUtilization, double energyConsumption,
                                                  double completedTasks, double totalTasks) {
    if (!runActive) return;
    
    // 记录运行时数据
    RunTimeData data;
    data.timestamp = timestamp;
    data.nodeId = nodeId;
    data.trustValue = trustValue;
    data.delayValue = delayValue;
    data.resourceUtilization = resourceUtilization;
    data.energyConsumption = energyConsumption;
    data.completedTasks = completedTasks;
    data.totalTasks = totalTasks;
    data.modelType = getModelTypeName(currentModelType);
    data.runId = currentRunId;
    
    currentRunData.push_back(data);
    
    // 添加到KPI计算器
    KPICalculator::PerformanceData perfData;
    perfData.trustValue = trustValue;
    perfData.delayValue = delayValue;
    perfData.resourceUtilization = resourceUtilization;
    perfData.energyConsumption = energyConsumption;
    perfData.completedTasks = completedTasks;
    perfData.totalTasks = totalTasks;
    perfData.timestamp = timestamp;
    
    kpiCalculator->addPerformanceData(nodeId, perfData);
}

void AblationDataCollector::recordKPISample(double R_owa, double delay_rate,
                                           double energy_eff, double fairness_index) {
    if (!runActive) return;
    
    testManager->recordKPISample(R_owa, delay_rate, energy_eff, fairness_index);
}

void AblationDataCollector::processCurrentRun() {
    if (currentRunData.empty()) return;
    
    updateKPIStatistics();
}

void AblationDataCollector::processCurrentModel() {
    calculateModelStatistics(currentModelType);
}

void AblationDataCollector::processAllModels() {
    testManager->calculateAllStatistics();
    
    std::cout << "[AblationDataCollector] Processing results for all models..." << std::endl;
    
    for (const auto& config : testManager->getAllConfigs()) {
        calculateModelStatistics(config.type);
    }
}

void AblationDataCollector::exportRunData(int runId) {
    std::string filename = generateFilename("run_data_" + std::to_string(runId), ".csv");
    
    if (!currentRunData.empty()) {
        writeRunDataCSV(filename, currentRunData);
    }
}

void AblationDataCollector::exportModelData(AblationTestManager::ModelType type) {
    std::string modelName = getModelTypeName(type);
    std::string filename = generateFilename("model_" + modelName, ".csv");
    
    // 导出该模型的所有运行数据
    auto it = allRunsData.find(type);
    if (it != allRunsData.end()) {
        std::vector<RunTimeData> allData;
        for (const auto& runData : it->second) {
            allData.insert(allData.end(), runData.begin(), runData.end());
        }
        writeRunDataCSV(filename, allData);
    }
}

void AblationDataCollector::exportRadarChartData() {
    std::string filename = generateFilename("ablation_radar_data", ".csv");
    writeRadarDataCSV(filename);
    
    std::cout << "[AblationDataCollector] Radar chart data exported to: " << filename << std::endl;
}

void AblationDataCollector::exportDetailedResults() {
    std::string filename = generateFilename("ablation_detailed_results", ".csv");
    writeKPIDataCSV(filename);
    
    std::cout << "[AblationDataCollector] Detailed results exported to: " << filename << std::endl;
}

size_t AblationDataCollector::getTotalSamples() const {
    size_t total = 0;
    for (const auto& pair : allRunsData) {
        for (const auto& runData : pair.second) {
            total += runData.size();
        }
    }
    return total;
}

size_t AblationDataCollector::getModelSamples(AblationTestManager::ModelType type) const {
    auto it = allRunsData.find(type);
    if (it != allRunsData.end()) {
        size_t total = 0;
        for (const auto& runData : it->second) {
            total += runData.size();
        }
        return total;
    }
    return 0;
}

void AblationDataCollector::setCurrentModel(AblationTestManager::ModelType type) {
    currentModelType = type;
    testManager->setCurrentModel(type);
}

void AblationDataCollector::setCurrentRun(int runId) {
    currentRunId = runId;
}

// 私有方法实现
void AblationDataCollector::createOutputDirectories() {
    try {
        mkdir(experimentConfig.outputDirectory.c_str(), 0755);
    } catch (const std::exception& e) {
        std::cerr << "[AblationDataCollector] Failed to create output directory: " << e.what() << std::endl;
    }
}

std::string AblationDataCollector::generateTimestamp() const {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto local_time = std::localtime(&time_t);
    
    std::ostringstream oss;
    oss << std::put_time(local_time, "%Y%m%d_%H%M%S");
    return oss.str();
}

std::string AblationDataCollector::getModelTypeName(AblationTestManager::ModelType type) const {
    return testManager->getModelName(type);
}

std::string AblationDataCollector::generateFilename(const std::string& prefix, const std::string& suffix) const {
    return experimentConfig.outputDirectory + prefix + "_" + generateTimestamp() + suffix;
}

void AblationDataCollector::writeRunDataCSV(const std::string& filename, const std::vector<RunTimeData>& data) {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "[AblationDataCollector] Failed to open file: " << filename << std::endl;
        return;
    }
    
    // 写入CSV头部
    file << "timestamp,node_id,trust_value,delay_value,resource_utilization,energy_consumption,"
         << "completed_tasks,total_tasks,model_type,run_id\n";
    
    // 写入数据
    for (const auto& row : data) {
        file << std::fixed << std::setprecision(6)
             << row.timestamp << ","
             << row.nodeId << ","
             << row.trustValue << ","
             << row.delayValue << ","
             << row.resourceUtilization << ","
             << row.energyConsumption << ","
             << row.completedTasks << ","
             << row.totalTasks << ","
             << row.modelType << ","
             << row.runId << "\n";
    }
    
    file.close();
}

void AblationDataCollector::writeKPIDataCSV(const std::string& filename) {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "[AblationDataCollector] Failed to open file: " << filename << std::endl;
        return;
    }
    
    // 写入CSV头部
    file << "model,R_owa_mean,R_owa_std,delay_rate_mean,delay_rate_std,"
         << "energy_eff_mean,energy_eff_std,fairness_index_mean,fairness_index_std\n";
    
    // 写入每个模型的KPI数据
    for (const auto& config : testManager->getAllConfigs()) {
        const auto& kpiData = testManager->getKPIData(config.type);
        
        file << std::fixed << std::setprecision(6)
             << config.name << ","
             << kpiData.R_owa_mean << ","
             << kpiData.R_owa_std << ","
             << kpiData.delay_rate_mean << ","
             << kpiData.delay_rate_std << ","
             << kpiData.energy_eff_mean << ","
             << kpiData.energy_eff_std << ","
             << kpiData.fairness_index_mean << ","
             << kpiData.fairness_index_std << "\n";
    }
    
    file.close();
}

void AblationDataCollector::writeRadarDataCSV(const std::string& filename) {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "[AblationDataCollector] Failed to open file: " << filename << std::endl;
        return;
    }
    
    // 写入CSV头部（雷达图专用格式）
    file << "model,R_owa_mean,delay_rate_mean,energy_eff_mean,fairness_index_mean\n";
    
    // 写入每个模型的KPI均值数据（用于雷达图）
    for (const auto& config : testManager->getAllConfigs()) {
        const auto& kpiData = testManager->getKPIData(config.type);
        
        file << std::fixed << std::setprecision(6)
             << config.name << ","
             << kpiData.R_owa_mean << ","
             << kpiData.delay_rate_mean << ","
             << kpiData.energy_eff_mean << ","
             << kpiData.fairness_index_mean << "\n";
    }
    
    file.close();
}

void AblationDataCollector::updateKPIStatistics() {
    // 从KPI计算器获取当前运行的统计数据
    auto stats = kpiCalculator->calculateAllKPIs();
    
    // 记录到测试管理器
    testManager->recordKPISample(stats.R_owa, stats.delay_rate, 
                                 stats.energy_efficiency, stats.fairness_index);
}

void AblationDataCollector::calculateModelStatistics(AblationTestManager::ModelType type) {
    // 这里可以添加额外的模型级统计计算
    // 目前主要统计已在testManager中计算
    
    const auto& kpiData = testManager->getKPIData(type);
    std::string modelName = getModelTypeName(type);
    
    if (experimentConfig.enableDetailedLogging) {
        std::cout << "[AblationDataCollector] Statistics for model " << modelName << ":\n"
                  << "  R_owa: " << kpiData.R_owa_mean << " ± " << kpiData.R_owa_std << "\n"
                  << "  Delay rate: " << kpiData.delay_rate_mean << " ± " << kpiData.delay_rate_std << "\n"
                  << "  Energy efficiency: " << kpiData.energy_eff_mean << " ± " << kpiData.energy_eff_std << "\n"
                  << "  Fairness index: " << kpiData.fairness_index_mean << " ± " << kpiData.fairness_index_std << std::endl;
    }
}
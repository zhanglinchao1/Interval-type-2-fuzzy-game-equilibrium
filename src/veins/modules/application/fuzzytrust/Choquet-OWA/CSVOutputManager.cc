//
// Copyright (C) 2024 FuzzyTrust Project  
// CSV输出管理器实现
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#include "CSVOutputManager.h"
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <numeric>
#include <cmath>
#include <sys/stat.h>
#include <sys/types.h>

namespace veins {

CSVOutputManager::CSVOutputManager(const std::string& output_dir)
    : outputDirectory(output_dir), currentRunId(1), totalRuns(1), realTimeWriting(true), isFirstInitialization(true)
{
    // 确保输出目录以/结尾
    if (!outputDirectory.empty() && outputDirectory.back() != '/') {
        outputDirectory += '/';
    }
}

CSVOutputManager::~CSVOutputManager()
{
    finalizeFiles();
}

void CSVOutputManager::initializeOutputFiles()
{
    // 创建输出目录
    if (!createDirectory(outputDirectory)) {
        std::cerr << "创建输出目录失败: " << outputDirectory << std::endl;
        return;
    }
    
    // 确定文件打开模式
    std::ios::openmode file_mode = isFirstInitialization ? 
        (std::ios::out | std::ios::trunc) : (std::ios::out | std::ios::app);
    
    // 打开原始数据文件
    std::string rawDataPath = outputDirectory + "choquet_owa_raw_data.csv";
    rawDataFile.open(rawDataPath, file_mode);
    
    // 打开汇总统计文件
    std::string summaryPath = outputDirectory + "choquet_owa_summary.csv";
    summaryFile.open(summaryPath, file_mode);
    
    // 如果是首次初始化，清空箱线图文件
    if (isFirstInitialization) {
        std::string boxplotPath = outputDirectory + "choquet_owa_boxplot_data.csv";
        std::ofstream clearFile(boxplotPath, std::ios::out | std::ios::trunc);
        if (clearFile.is_open()) {
            clearFile << "task_type,mu_resource_choquet,mu_resource_owa,mu_resource_min,mu_resource_mean\n";
            clearFile.close();
        }
    }
    
    if (!rawDataFile.is_open() || !summaryFile.is_open()) {
        std::cerr << "打开CSV文件失败" << std::endl;
        return;
    }
    
    // 只在首次初始化时写入CSV头部
    if (isFirstInitialization) {
        writeCSVHeaders();
    }
    
    // 清空数据缓存和统计信息
    dataBuffer.clear();
    statisticsMap.clear();
    
    std::cout << "CSV输出管理器" << (isFirstInitialization ? "首次" : "追加") 
              << "初始化完成，输出目录: " << outputDirectory << std::endl;
    
    // 设置为非首次初始化
    isFirstInitialization = false;
}

void CSVOutputManager::writeResourceAggregationData(const ResourceAggregationResults& results)
{
    // 添加到数据缓冲区
    dataBuffer.push_back(results);
    
    // 更新统计信息
    updateStatistics(results);
    
    // 如果启用实时写入，立即写入原始数据
    if (realTimeWriting && rawDataFile.is_open()) {
        writeRawDataRow(results);
        rawDataFile.flush();
    }
}

void CSVOutputManager::writeExperimentSummary()
{
    writeSummaryStatistics();
    if (summaryFile.is_open()) {
        summaryFile.flush();
    }
}

void CSVOutputManager::finalizeFiles()
{
    // 如果没有启用实时写入，现在批量写入所有数据
    if (!realTimeWriting && rawDataFile.is_open()) {
        for (const auto& data : dataBuffer) {
            writeRawDataRow(data);
        }
    }
    
    // 写入最终汇总统计
    writeExperimentSummary();
    
    // 生成箱线图数据
    generateBoxplotData();
    
    // 关闭所有文件
    if (rawDataFile.is_open()) {
        rawDataFile.close();
    }
    if (summaryFile.is_open()) {
        summaryFile.close();
    }
    if (boxplotFile.is_open()) {
        boxplotFile.close();
    }
    
    std::cout << "CSV文件输出完成，共处理 " << dataBuffer.size() << " 条数据记录" << std::endl;
}

void CSVOutputManager::setExperimentInfo(int run_id, int total_runs)
{
    currentRunId = run_id;
    totalRuns = total_runs;
}

void CSVOutputManager::setRealTimeWriting(bool enable)
{
    realTimeWriting = enable;
}

void CSVOutputManager::setFirstInitialization(bool is_first)
{
    isFirstInitialization = is_first;
}

bool CSVOutputManager::createDirectory(const std::string& dir_path)
{
    // 递归创建目录
    std::string path = dir_path;
    if (!path.empty() && path.back() == '/') {
        path.pop_back();
    }
    
    struct stat st;
    if (stat(path.c_str(), &st) == 0) {
        return S_ISDIR(st.st_mode);
    }
    
    // 创建父目录
    size_t pos = path.find_last_of('/');
    if (pos != std::string::npos) {
        std::string parent = path.substr(0, pos);
        if (!createDirectory(parent)) {
            return false;
        }
    }
    
    // 创建当前目录
    return mkdir(path.c_str(), 0755) == 0;
}

void CSVOutputManager::writeCSVHeaders()
{
    // 原始数据文件头部
    if (rawDataFile.is_open()) {
        rawDataFile << "task_type,experiment_run,timestamp,node_id,"
                   << "mu_resource_choquet,mu_resource_owa,mu_resource_min,mu_resource_mean\n";
    }
    
    // 汇总统计文件头部
    if (summaryFile.is_open()) {
        summaryFile << "task_type,aggregation_method,count,mean,std_dev,"
                   << "min_value,max_value,median,q1,q3\n";
    }
}

void CSVOutputManager::writeRawDataRow(const ResourceAggregationResults& data)
{
    if (!rawDataFile.is_open()) return;
    
    rawDataFile << data.task_type << ","
               << data.experiment_run << ","
               << formatTimestamp(data.timestamp) << ","
               << data.node_id << ","
               << std::fixed << std::setprecision(6)
               << data.mu_resource_choquet << ","
               << data.mu_resource_owa << ","
               << data.mu_resource_min << ","
               << data.mu_resource_mean << "\n";
}

void CSVOutputManager::updateStatistics(const ResourceAggregationResults& data)
{
    // 更新四种聚合方式的统计信息
    std::vector<std::pair<std::string, double>> aggregations = {
        {"choquet", data.mu_resource_choquet},
        {"owa", data.mu_resource_owa},
        {"min", data.mu_resource_min},
        {"mean", data.mu_resource_mean}
    };
    
    for (const auto& agg : aggregations) {
        statisticsMap[data.task_type][agg.first].samples.push_back(agg.second);
    }
}

void CSVOutputManager::calculateStatistics(AggregationStatistics& stats)
{
    if (stats.samples.empty()) return;
    
    std::vector<double> sorted_samples = stats.samples;
    std::sort(sorted_samples.begin(), sorted_samples.end());
    
    stats.count = static_cast<int>(sorted_samples.size());
    stats.min_value = sorted_samples.front();
    stats.max_value = sorted_samples.back();
    
    // 计算均值
    stats.mean = std::accumulate(sorted_samples.begin(), sorted_samples.end(), 0.0) / stats.count;
    
    // 计算标准差
    double variance = 0.0;
    for (double value : sorted_samples) {
        variance += (value - stats.mean) * (value - stats.mean);
    }
    stats.std_dev = std::sqrt(variance / stats.count);
    
    // 计算中位数和四分位数
    stats.median = calculatePercentile(sorted_samples, 0.5);
    stats.q1 = calculatePercentile(sorted_samples, 0.25);
    stats.q3 = calculatePercentile(sorted_samples, 0.75);
}

void CSVOutputManager::generateBoxplotData()
{
    std::string boxplotPath = outputDirectory + "choquet_owa_boxplot_data.csv";
    // 使用追加模式打开文件，避免覆盖之前的数据
    boxplotFile.open(boxplotPath, std::ios::out | std::ios::app);
    
    if (!boxplotFile.is_open()) {
        std::cerr << "无法打开箱线图数据文件: " << boxplotPath << std::endl;
        return;
    }
    
    // 不再写入头部，头部在初始化时已经写入
    
    // 按任务类型组织数据
    std::vector<std::string> task_types = {"compute_intensive", "bandwidth_sensitive", "energy_sensitive"};
    
    // 找到最大样本数
    int max_samples = 0;
    for (const auto& task_type : task_types) {
        if (statisticsMap.find(task_type) != statisticsMap.end()) {
            for (const auto& method_pair : statisticsMap[task_type]) {
                max_samples = std::max(max_samples, static_cast<int>(method_pair.second.samples.size()));
            }
        }
    }
    
    // 写入所有样本数据（每行一个样本点，包含所有四种方法的值）
    for (int i = 0; i < max_samples; ++i) {
        for (const auto& task_type : task_types) {
            if (statisticsMap.find(task_type) != statisticsMap.end()) {
                auto& task_stats = statisticsMap[task_type];
                
                // 检查各方法是否有足够的样本
                if (task_stats["choquet"].samples.size() > i &&
                    task_stats["owa"].samples.size() > i &&
                    task_stats["min"].samples.size() > i &&
                    task_stats["mean"].samples.size() > i) {
                    
                    boxplotFile << task_type << ","
                               << std::fixed << std::setprecision(6)
                               << task_stats["choquet"].samples[i] << ","
                               << task_stats["owa"].samples[i] << ","
                               << task_stats["min"].samples[i] << ","
                               << task_stats["mean"].samples[i] << "\n";
                }
            }
        }
    }
    
    boxplotFile.close();
    std::cout << "箱线图数据文件生成完成: " << boxplotPath << std::endl;
}

void CSVOutputManager::writeSummaryStatistics()
{
    if (!summaryFile.is_open()) return;
    
    // 计算所有统计信息并写入文件
    for (auto& task_pair : statisticsMap) {
        const std::string& task_type = task_pair.first;
        
        for (auto& method_pair : task_pair.second) {
            const std::string& method = method_pair.first;
            AggregationStatistics& stats = method_pair.second;
            
            // 计算统计指标
            calculateStatistics(stats);
            
            // 写入汇总文件
            summaryFile << task_type << "," << method << ","
                       << stats.count << ","
                       << std::fixed << std::setprecision(6)
                       << stats.mean << ","
                       << stats.std_dev << ","
                       << stats.min_value << ","
                       << stats.max_value << ","
                       << stats.median << ","
                       << stats.q1 << ","
                       << stats.q3 << "\n";
        }
    }
}

void CSVOutputManager::flushBuffers()
{
    if (rawDataFile.is_open()) {
        rawDataFile.flush();
    }
    if (summaryFile.is_open()) {
        summaryFile.flush();
    }
}

std::string CSVOutputManager::formatTimestamp(double timestamp)
{
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(3) << timestamp;
    return oss.str();
}

double CSVOutputManager::calculatePercentile(const std::vector<double>& values, double percentile)
{
    if (values.empty()) return 0.0;
    
    double index = percentile * (values.size() - 1);
    int lower_index = static_cast<int>(std::floor(index));
    int upper_index = static_cast<int>(std::ceil(index));
    
    if (lower_index == upper_index) {
        return values[lower_index];
    }
    
    double weight = index - lower_index;
    return values[lower_index] * (1.0 - weight) + values[upper_index] * weight;
}

} // namespace veins 
//
// Copyright (C) 2024 FuzzyTrust Project  
// CSV输出管理器 - 负责生成箱线图数据的CSV文件
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#pragma once

#include "ResourcePerformanceMonitor.h"
#include <string>
#include <fstream>
#include <vector>
#include <map>

namespace veins {

/**
 * @brief 统计数据结构
 * 
 * 用于存储每种任务类型和聚合方式的统计信息
 */
struct AggregationStatistics {
    std::vector<double> samples;    // 样本数据
    double mean;                    // 均值
    double std_dev;                 // 标准差
    double min_value;               // 最小值
    double max_value;               // 最大值
    double median;                  // 中位数
    double q1;                      // 第一四分位数
    double q3;                      // 第三四分位数
    int count;                      // 样本数量
    
    AggregationStatistics() : mean(0.0), std_dev(0.0), min_value(0.0), 
                             max_value(0.0), median(0.0), q1(0.0), q3(0.0), count(0) {}
};

/**
 * @brief CSV输出管理器
 * 
 * 负责管理Choquet-OWA性能数据的CSV文件输出：
 * 1. 原始数据输出（所有采样点）
 * 2. 统计汇总输出（按任务类型和聚合方式）
 * 3. 箱线图专用格式输出（Origin软件兼容）
 */
class CSVOutputManager {
public:
    /**
     * @brief 构造函数
     * @param output_dir 输出目录路径
     */
    explicit CSVOutputManager(const std::string& output_dir = "results/choquet_owa/data/");
    
    /**
     * @brief 析构函数
     */
    ~CSVOutputManager();
    
    /**
     * @brief 初始化输出文件
     * 
     * 创建必要的目录结构和CSV文件，写入头部信息
     */
    void initializeOutputFiles();
    
    /**
     * @brief 写入资源聚合数据
     * 
     * @param results 资源聚合结果数据
     */
    void writeResourceAggregationData(const ResourceAggregationResults& results);
    
    /**
     * @brief 写入实验汇总数据
     * 
     * 计算并输出统计汇总信息
     */
    void writeExperimentSummary();
    
    /**
     * @brief 完成文件输出
     * 
     * 关闭所有文件流，生成最终的箱线图数据文件
     */
    void finalizeFiles();
    
    /**
     * @brief 设置实验运行信息
     * @param run_id 实验运行ID
     * @param total_runs 总实验运行次数
     */
    void setExperimentInfo(int run_id, int total_runs);
    
    /**
     * @brief 启用/禁用实时写入
     * @param enable 是否启用实时写入
     */
    void setRealTimeWriting(bool enable);
    
    /**
     * @brief 设置是否为首次初始化
     * @param is_first 是否为首次初始化
     */
    void setFirstInitialization(bool is_first);

private:
    std::string outputDirectory;    // 输出目录
    int currentRunId;               // 当前实验运行ID
    int totalRuns;                  // 总实验运行次数
    bool realTimeWriting;           // 是否启用实时写入
    bool isFirstInitialization;     // 是否为首次初始化（用于区分清空vs追加）
    
    // 文件流
    std::ofstream rawDataFile;      // 原始数据文件
    std::ofstream summaryFile;      // 汇总统计文件
    std::ofstream boxplotFile;      // 箱线图数据文件
    
    // 数据缓存
    std::vector<ResourceAggregationResults> dataBuffer;  // 数据缓冲区
    
    // 统计数据存储 - [任务类型][聚合方式] -> 统计信息
    std::map<std::string, std::map<std::string, AggregationStatistics>> statisticsMap;
    
    /**
     * @brief 创建输出目录
     * @param dir_path 目录路径
     * @return 是否创建成功
     */
    bool createDirectory(const std::string& dir_path);
    
    /**
     * @brief 写入CSV头部
     */
    void writeCSVHeaders();
    
    /**
     * @brief 写入原始数据行
     * @param data 资源聚合结果数据
     */
    void writeRawDataRow(const ResourceAggregationResults& data);
    
    /**
     * @brief 更新统计信息
     * @param data 资源聚合结果数据
     */
    void updateStatistics(const ResourceAggregationResults& data);
    
    /**
     * @brief 计算统计指标
     * @param stats 统计数据结构引用
     */
    void calculateStatistics(AggregationStatistics& stats);
    
    /**
     * @brief 生成箱线图数据文件
     * 
     * 按照Origin软件要求的格式生成箱线图数据
     */
    void generateBoxplotData();
    
    /**
     * @brief 写入汇总统计信息
     */
    void writeSummaryStatistics();
    
    /**
     * @brief 刷新文件缓冲区
     */
    void flushBuffers();
    
    /**
     * @brief 格式化时间戳字符串
     * @param timestamp 时间戳
     * @return 格式化后的字符串
     */
    std::string formatTimestamp(double timestamp);
    
    /**
     * @brief 计算四分位数
     * @param values 数据向量（已排序）
     * @param percentile 百分位数 (0.25, 0.5, 0.75)
     * @return 四分位数值
     */
    double calculatePercentile(const std::vector<double>& values, double percentile);
};

} // namespace veins 
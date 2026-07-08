//
// Copyright (C) 2024 FuzzyTrust Project  
// 时间戳管理器 - 负责统一时间戳格式和采样间隔管理
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#pragma once

#include <string>

namespace veins {

/**
 * @brief 时间戳管理器
 * 
 * 负责统一时间戳格式和采样间隔管理：
 * 1. 管理数据采样的时间间隔
 * 2. 提供格式化的时间戳字符串
 * 3. 判断是否应该执行数据采样
 * 4. 支持不同的时间戳格式输出
 */
class TimestampManager {
public:
    /**
     * @brief 构造函数
     */
    TimestampManager();
    
    /**
     * @brief 析构函数
     */
    ~TimestampManager() = default;
    
    /**
     * @brief 初始化时间戳管理器
     * @param sampling_interval 采样间隔（秒）
     */
    void initialize(double sampling_interval);
    
    /**
     * @brief 判断当前时刻是否应该执行采样
     * @param current_time 当前时间戳
     * @return 是否应该采样
     */
    bool shouldSample(double current_time);
    
    /**
     * @brief 获取格式化的时间戳字符串
     * @param timestamp 时间戳
     * @return 格式化后的时间戳字符串
     */
    std::string getFormattedTimestamp(double timestamp) const;
    
    /**
     * @brief 获取当前记录的时间戳
     * @return 当前时间戳
     */
    double getCurrentTimestamp() const;
    
    /**
     * @brief 设置时间戳格式
     * @param format 时间戳格式字符串（printf格式）
     */
    void setTimestampFormat(const std::string& format);
    
    /**
     * @brief 设置采样间隔
     * @param interval 采样间隔（秒）
     */
    void setSamplingInterval(double interval);
    
    /**
     * @brief 获取采样间隔
     * @return 采样间隔（秒）
     */
    double getSamplingInterval() const;
    
    /**
     * @brief 重置时间戳管理器
     */
    void reset();
    
    /**
     * @brief 获取下次采样时间
     * @return 下次采样的时间戳
     */
    double getNextSampleTime() const;
    
    /**
     * @brief 获取总采样次数
     * @return 总采样次数
     */
    int getTotalSamples() const;

private:
    double lastSampleTime;      // 上次采样时间
    double samplingInterval;    // 采样间隔
    std::string timestampFormat;// 时间戳格式
    double currentTimestamp;    // 当前时间戳
    int totalSamples;           // 总采样次数
    
    /**
     * @brief 更新内部状态
     * @param timestamp 新的时间戳
     */
    void updateInternalState(double timestamp);
};

} // namespace veins 
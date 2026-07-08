//
// Copyright (C) 2024 FuzzyTrust Project  
// 时间戳管理器实现
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

#include "TimestampManager.h"
#include <sstream>
#include <iomanip>
#include <cmath>

namespace veins {

TimestampManager::TimestampManager()
    : lastSampleTime(-1.0), samplingInterval(1.0), 
      timestampFormat("%.3f"), currentTimestamp(0.0), totalSamples(0)
{
}

void TimestampManager::initialize(double sampling_interval)
{
    samplingInterval = sampling_interval;
    lastSampleTime = -1.0;
    currentTimestamp = 0.0;
    totalSamples = 0;
}

bool TimestampManager::shouldSample(double current_time)
{
    // 更新当前时间戳
    currentTimestamp = current_time;
    
    // 第一次采样
    if (lastSampleTime < 0.0) {
        updateInternalState(current_time);
        return true;
    }
    
    // 检查是否达到采样间隔
    if (current_time - lastSampleTime >= samplingInterval) {
        updateInternalState(current_time);
        return true;
    }
    
    return false;
}

std::string TimestampManager::getFormattedTimestamp(double timestamp) const
{
    std::ostringstream oss;
    
    // 根据格式字符串确定精度
    if (timestampFormat.find("%.1f") != std::string::npos) {
        oss << std::fixed << std::setprecision(1) << timestamp;
    } else if (timestampFormat.find("%.2f") != std::string::npos) {
        oss << std::fixed << std::setprecision(2) << timestamp;
    } else if (timestampFormat.find("%.3f") != std::string::npos) {
        oss << std::fixed << std::setprecision(3) << timestamp;
    } else if (timestampFormat.find("%.4f") != std::string::npos) {
        oss << std::fixed << std::setprecision(4) << timestamp;
    } else if (timestampFormat.find("%.6f") != std::string::npos) {
        oss << std::fixed << std::setprecision(6) << timestamp;
    } else {
        // 默认精度
        oss << std::fixed << std::setprecision(3) << timestamp;
    }
    
    return oss.str();
}

double TimestampManager::getCurrentTimestamp() const
{
    return currentTimestamp;
}

void TimestampManager::setTimestampFormat(const std::string& format)
{
    timestampFormat = format;
}

void TimestampManager::setSamplingInterval(double interval)
{
    if (interval > 0.0) {
        samplingInterval = interval;
    }
}

double TimestampManager::getSamplingInterval() const
{
    return samplingInterval;
}

void TimestampManager::reset()
{
    lastSampleTime = -1.0;
    currentTimestamp = 0.0;
    totalSamples = 0;
}

double TimestampManager::getNextSampleTime() const
{
    if (lastSampleTime < 0.0) {
        return 0.0;
    }
    return lastSampleTime + samplingInterval;
}

int TimestampManager::getTotalSamples() const
{
    return totalSamples;
}

void TimestampManager::updateInternalState(double timestamp)
{
    lastSampleTime = timestamp;
    currentTimestamp = timestamp;
    totalSamples++;
}

} // namespace veins 
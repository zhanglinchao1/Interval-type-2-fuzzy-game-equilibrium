/**
 * @file ARIMAPredictor.cc
 * @brief 增强的ARIMA时间序列预测模型实现
 * @author zlc
 * @date 2024
 */

#include "ARIMAPredictor.h"
#include <algorithm>
#include <numeric>
#include <cmath>
#include <random>
#include <sstream>
#include <iomanip>

// ==================== 构造函数和初始化 ====================

ARIMAPredictor::ARIMAPredictor(const ARIMAConfig& config)
    : config_(config), model_fitted_(false), residual_variance_(0.0),
      prediction_count_(0), cumulative_error_(0.0) {
    
    // 初始化策略编码映射
    strategy_encoding_["SC"] = 1.0;  // 合作策略
    strategy_encoding_["SP"] = 2.0;  // 惩罚策略
    strategy_encoding_["DC"] = 3.0;  // 防御合作
    strategy_encoding_["DP"] = 4.0;  // 防御惩罚
    
    // 反向映射
    for (const auto& pair : strategy_encoding_) {
        strategy_decoding_[pair.second] = pair.first;
    }
    
    // 初始化性能统计
    performance_.accuracy = 0.0;
    performance_.precision = 0.0;
    performance_.recall = 0.0;
    performance_.f1_score = 0.0;
    performance_.total_predictions = 0;
    performance_.correct_predictions = 0;
    performance_.last_update = std::chrono::steady_clock::now();
    
    last_update_time_ = std::chrono::steady_clock::now();
}

ARIMAPredictor::ARIMAPredictor(const json& json_config) : ARIMAPredictor() {
    if (json_config.contains("arima_predictor")) {
        const auto& arima_config = json_config["arima_predictor"];
        
        config_.p = arima_config.value("p", 2);
        config_.d = arima_config.value("d", 1);
        config_.q = arima_config.value("q", 2);
        config_.max_p = arima_config.value("max_p", 5);
        config_.max_d = arima_config.value("max_d", 2);
        config_.max_q = arima_config.value("max_q", 5);
        config_.min_history_size = arima_config.value("min_history_size", 20);
        config_.prediction_horizon = arima_config.value("prediction_horizon", 5);
        config_.confidence_level = arima_config.value("confidence_level", 0.95);
        config_.auto_select_params = arima_config.value("auto_select_params", true);
        config_.enable_seasonality = arima_config.value("enable_seasonality", false);
        config_.seasonal_period = arima_config.value("seasonal_period", 12);
    }
}

// ==================== 核心预测功能 ====================

ARIMAPredictor::PredictionResult ARIMAPredictor::predict(
    const std::vector<double>& time_series, int steps) {
    
    PredictionResult result;
    
    if (time_series.size() < static_cast<size_t>(config_.min_history_size)) {
        // 数据不足，使用简单预测
        double last_value = time_series.empty() ? 0.0 : time_series.back();
        result.predictions.assign(steps, last_value);
        result.confidence_upper.assign(steps, last_value * 1.1);
        result.confidence_lower.assign(steps, last_value * 0.9);
        result.mse = 0.0;
        result.mae = 0.0;
        result.aic = 0.0;
        result.bic = 0.0;
        result.model_info = "Insufficient data - using last value";
        result.model_quality_score = 0.3;
        return result;
    }
    
    // 数据预处理
    std::vector<double> processed_series = detectAndHandleOutliers(time_series);
    
    // 自动参数选择（如果启用）
    ARIMAConfig optimal_config = config_;
    if (config_.auto_select_params) {
        optimal_config = autoSelectParameters(processed_series);
    }
    
    // 差分处理
    std::vector<double> diff_series = processed_series;
    for (int i = 0; i < optimal_config.d; ++i) {
        diff_series = difference(diff_series, 1);
    }
    
    // 参数估计
    std::vector<double> parameters = estimateParameters(
        diff_series, optimal_config.p, optimal_config.q);
    
    // 提取AR和MA系数
    ar_coefficients_.clear();
    ma_coefficients_.clear();
    
    for (int i = 0; i < optimal_config.p; ++i) {
        if (i < static_cast<int>(parameters.size())) {
            ar_coefficients_.push_back(parameters[i]);
        }
    }
    
    for (int i = 0; i < optimal_config.q; ++i) {
        int idx = optimal_config.p + i;
        if (idx < static_cast<int>(parameters.size())) {
            ma_coefficients_.push_back(parameters[idx]);
        }
    }
    
    // 计算残差
    residuals_ = calculateResiduals(diff_series, optimal_config.p, optimal_config.q);
    residual_variance_ = calculateVariance(residuals_);
    
    // 进行预测
    std::vector<double> predictions;
    std::vector<double> current_series = diff_series;
    
    for (int step = 0; step < steps; ++step) {
        double prediction = 0.0;
        
        // AR部分
        for (int i = 0; i < optimal_config.p && i < static_cast<int>(current_series.size()); ++i) {
            if (i < static_cast<int>(ar_coefficients_.size())) {
                prediction += ar_coefficients_[i] * current_series[current_series.size() - 1 - i];
            }
        }
        
        // MA部分（使用最近的残差）
        for (int i = 0; i < optimal_config.q && i < static_cast<int>(residuals_.size()); ++i) {
            if (i < static_cast<int>(ma_coefficients_.size())) {
                prediction += ma_coefficients_[i] * residuals_[residuals_.size() - 1 - i];
            }
        }
        
        predictions.push_back(prediction);
        current_series.push_back(prediction);
        
        // 为下一步预测添加零残差
        if (residuals_.size() > 0) {
            residuals_.push_back(0.0);
        }
    }
    
    // 逆差分还原
    std::vector<double> final_predictions = predictions;
    if (optimal_config.d > 0) {
        final_predictions = inverseDifference(predictions, processed_series, optimal_config.d);
    }
    
    // 计算置信区间
    auto confidence_intervals = calculateConfidenceInterval(
        final_predictions, residual_variance_, config_.confidence_level);
    
    // 计算模型质量指标
    auto info_criteria = calculateInformationCriteria(
        residuals_, optimal_config.p + optimal_config.q, diff_series.size());
    
    // 填充结果
    result.predictions = final_predictions;
    result.confidence_upper = confidence_intervals.first;
    result.confidence_lower = confidence_intervals.second;
    result.aic = info_criteria.first;
    result.bic = info_criteria.second;
    result.mse = calculateMSE(residuals_);
    result.mae = calculateMAE(residuals_);
    
    std::stringstream ss;
    ss << "ARIMA(" << optimal_config.p << "," << optimal_config.d << "," << optimal_config.q << ")";
    result.model_info = ss.str();
    
    // 计算模型质量评分
    result.model_quality_score = calculateModelQualityScore(result.mse, result.aic, result.bic);
    
    model_fitted_ = true;
    return result;
}

ARIMAPredictor::PredictionResult ARIMAPredictor::predictMultivariate(
    const std::vector<std::vector<double>>& multivariate_series,
    int target_variable, int steps) {
    
    if (target_variable >= static_cast<int>(multivariate_series.size()) || 
        multivariate_series.empty()) {
        return predict({}, steps);
    }
    
    // 提取目标变量的时间序列
    std::vector<double> target_series = multivariate_series[target_variable];
    
    // 使用其他变量作为外生变量进行增强预测
    // 这里简化为使用目标变量的单变量预测
    // 在实际实现中可以考虑VAR模型或ARIMAX模型
    
    return predict(target_series, steps);
}

ARIMAPredictor::StrategyPrediction ARIMAPredictor::predictStrategy(
    const std::vector<std::string>& strategy_history,
    const std::vector<double>& payoff_history,
    const std::vector<std::vector<double>>& context_variables) {
    
    StrategyPrediction result;
    
    if (strategy_history.empty()) {
        // 默认策略分布
        result.strategy_probabilities["SC"] = 0.25;
        result.strategy_probabilities["SP"] = 0.25;
        result.strategy_probabilities["DC"] = 0.25;
        result.strategy_probabilities["DP"] = 0.25;
        result.recommended_strategy = "SC";
        result.prediction_confidence = 0.3;
        return result;
    }
    
    // 将策略历史编码为数值序列
    std::vector<double> encoded_strategies;
    for (const auto& strategy : strategy_history) {
        if (strategy_encoding_.find(strategy) != strategy_encoding_.end()) {
            encoded_strategies.push_back(strategy_encoding_[strategy]);
        }
    }
    
    // 预测下一个策略
    auto strategy_prediction = predict(encoded_strategies, 1);
    
    // 解码预测结果
    if (!strategy_prediction.predictions.empty()) {
        double predicted_value = strategy_prediction.predictions[0];
        
        // 计算各策略的概率
        std::map<std::string, double> probabilities;
        for (const auto& pair : strategy_encoding_) {
            double distance = std::abs(predicted_value - pair.second);
            double probability = std::exp(-distance * 2.0);  // 高斯核
            probabilities[pair.first] = probability;
        }
        
        // 归一化概率
        double total_prob = 0.0;
        for (const auto& pair : probabilities) {
            total_prob += pair.second;
        }
        
        if (total_prob > 0) {
            for (auto& pair : probabilities) {
                pair.second /= total_prob;
            }
        }
        
        result.strategy_probabilities = probabilities;
        
        // 找到概率最高的策略
        std::string best_strategy = "SC";
        double max_prob = 0.0;
        for (const auto& pair : probabilities) {
            if (pair.second > max_prob) {
                max_prob = pair.second;
                best_strategy = pair.first;
            }
        }
        
        result.recommended_strategy = best_strategy;
        result.prediction_confidence = max_prob;
    }
    
    // 预测各策略的期望收益
    if (!payoff_history.empty()) {
        auto payoff_prediction = predict(payoff_history, 1);
        if (!payoff_prediction.predictions.empty()) {
            double base_payoff = payoff_prediction.predictions[0];
            
            // 根据策略类型调整期望收益
            result.expected_payoffs["SC"] = base_payoff * 1.0;   // 基准
            result.expected_payoffs["SP"] = base_payoff * 0.8;   // 较低收益但稳定
            result.expected_payoffs["DC"] = base_payoff * 1.2;   // 较高收益但风险
            result.expected_payoffs["DP"] = base_payoff * 0.6;   // 保守策略
        }
    }
    
    // 计算趋势指标
    if (encoded_strategies.size() >= 5) {
        std::vector<double> recent_strategies(encoded_strategies.end() - 5, encoded_strategies.end());
        double trend = calculateTrend(recent_strategies);
        result.trend_indicators.push_back(trend);
        
        double volatility = calculateVolatility(recent_strategies);
        result.trend_indicators.push_back(volatility);
    }
    
    return result;
}

ARIMAPredictor::PredictionResult ARIMAPredictor::predictPayoffTrend(
    const std::vector<double>& payoff_history,
    const std::string& strategy_type,
    int prediction_horizon) {
    
    // 根据策略类型过滤收益历史
    // 这里简化为直接使用所有收益历史
    return predict(payoff_history, prediction_horizon);
}

// ==================== 模型管理功能 ====================

ARIMAPredictor::ARIMAConfig ARIMAPredictor::autoSelectParameters(
    const std::vector<double>& time_series) {
    
    ARIMAConfig best_config = config_;
    double best_aic = std::numeric_limits<double>::max();
    
    // 网格搜索最优参数
    for (int p = 0; p <= config_.max_p; ++p) {
        for (int d = 0; d <= config_.max_d; ++d) {
            for (int q = 0; q <= config_.max_q; ++q) {
                if (p + d + q == 0) continue;
                
                try {
                    // 差分处理
                    std::vector<double> diff_series = time_series;
                    for (int i = 0; i < d; ++i) {
                        diff_series = difference(diff_series, 1);
                    }
                    
                    if (diff_series.size() < static_cast<size_t>(p + q + 5)) {
                        continue;  // 数据不足
                    }
                    
                    // 参数估计
                    std::vector<double> parameters = estimateParameters(diff_series, p, q);
                    
                    // 计算残差
                    std::vector<double> residuals = calculateResiduals(diff_series, p, q);
                    
                    // 计算AIC
                    auto info_criteria = calculateInformationCriteria(
                        residuals, p + q, diff_series.size());
                    double aic = info_criteria.first;
                    
                    if (aic < best_aic) {
                        best_aic = aic;
                        best_config.p = p;
                        best_config.d = d;
                        best_config.q = q;
                    }
                } catch (...) {
                    // 参数组合无效，跳过
                    continue;
                }
            }
        }
    }
    
    return best_config;
}

bool ARIMAPredictor::fitModel(const std::vector<double>& time_series, bool validate) {
    if (time_series.size() < static_cast<size_t>(config_.min_history_size)) {
        return false;
    }
    
    training_data_ = time_series;
    
    if (validate) {
        // 交叉验证
        int fold_size = time_series.size() / 5;  // 5折交叉验证
        double total_error = 0.0;
        int valid_folds = 0;
        
        for (int fold = 0; fold < 5; ++fold) {
            int start_idx = fold * fold_size;
            int end_idx = (fold == 4) ? time_series.size() : (fold + 1) * fold_size;
            
            if (end_idx - start_idx < config_.min_history_size) continue;
            
            std::vector<double> train_data(time_series.begin() + start_idx, 
                                         time_series.begin() + end_idx - 1);
            double actual = time_series[end_idx - 1];
            
            auto prediction = predict(train_data, 1);
            if (!prediction.predictions.empty()) {
                double error = std::abs(prediction.predictions[0] - actual);
                total_error += error;
                valid_folds++;
            }
        }
        
        if (valid_folds > 0) {
            double avg_error = total_error / valid_folds;
            // 更新性能统计
            performance_.mae = avg_error;
        }
    }
    
    model_fitted_ = true;
    return true;
}

void ARIMAPredictor::updateModel(const std::vector<double>& new_data, bool retrain) {
    // 添加新数据到训练集
    training_data_.insert(training_data_.end(), new_data.begin(), new_data.end());
    
    // 限制训练数据大小
    if (training_data_.size() > 1000) {
        training_data_.erase(training_data_.begin(), 
                           training_data_.begin() + (training_data_.size() - 1000));
    }
    
    if (retrain) {
        fitModel(training_data_, false);
    }
    
    last_update_time_ = std::chrono::steady_clock::now();
}

ARIMAPredictor::ModelPerformance ARIMAPredictor::evaluateModel(
    const std::vector<double>& actual_values,
    const std::vector<double>& predicted_values) {
    
    ModelPerformance perf;
    
    if (actual_values.size() != predicted_values.size() || actual_values.empty()) {
        return perf;
    }
    
    // 计算基本指标
    double mse = 0.0, mae = 0.0;
    int correct_predictions = 0;
    
    for (size_t i = 0; i < actual_values.size(); ++i) {
        double error = actual_values[i] - predicted_values[i];
        mse += error * error;
        mae += std::abs(error);
        
        // 简单的正确性判断（误差在10%以内）
        if (std::abs(error) <= std::abs(actual_values[i]) * 0.1) {
            correct_predictions++;
        }
    }
    
    perf.total_predictions = actual_values.size();
    perf.correct_predictions = correct_predictions;
    perf.accuracy = static_cast<double>(correct_predictions) / actual_values.size();
    perf.precision = perf.accuracy;  // 简化
    perf.recall = perf.accuracy;     // 简化
    perf.f1_score = 2.0 * perf.precision * perf.recall / (perf.precision + perf.recall);
    perf.last_update = std::chrono::steady_clock::now();
    
    // 更新全局性能统计
    performance_ = perf;
    
    return perf;
}

// ==================== 数据预处理功能 ====================

std::vector<double> ARIMAPredictor::difference(const std::vector<double>& series, int order) {
    if (series.size() <= static_cast<size_t>(order)) {
        return {};
    }
    
    std::vector<double> result = series;
    
    for (int d = 0; d < order; ++d) {
        std::vector<double> diff_result;
        for (size_t i = 1; i < result.size(); ++i) {
            diff_result.push_back(result[i] - result[i-1]);
        }
        result = diff_result;
    }
    
    return result;
}

bool ARIMAPredictor::isStationary(const std::vector<double>& series) {
    if (series.size() < 10) return false;
    
    // 简化的平稳性检验：检查均值和方差的稳定性
    int window_size = series.size() / 3;
    
    // 计算前1/3和后1/3的均值和方差
    std::vector<double> first_part(series.begin(), series.begin() + window_size);
    std::vector<double> last_part(series.end() - window_size, series.end());
    
    double mean1 = calculateMean(first_part);
    double mean2 = calculateMean(last_part);
    double var1 = calculateVariance(first_part);
    double var2 = calculateVariance(last_part);
    
    // 检查均值和方差的相对变化
    double mean_change = std::abs(mean2 - mean1) / (std::abs(mean1) + 1e-8);
    double var_change = std::abs(var2 - var1) / (var1 + 1e-8);
    
    return (mean_change < 0.1 && var_change < 0.2);
}

std::vector<double> ARIMAPredictor::detectAndHandleOutliers(
    const std::vector<double>& series, double threshold) {
    
    if (series.size() < 5) return series;
    
    std::vector<double> result = series;
    double mean = calculateMean(series);
    double std_dev = std::sqrt(calculateVariance(series));
    
    for (size_t i = 0; i < result.size(); ++i) {
        double z_score = std::abs(result[i] - mean) / (std_dev + 1e-8);
        if (z_score > threshold) {
            // 用中位数替换异常值
            if (i > 0 && i < result.size() - 1) {
                result[i] = (result[i-1] + result[i+1]) / 2.0;
            } else if (i == 0) {
                result[i] = result[1];
            } else {
                result[i] = result[i-1];
            }
        }
    }
    
    return result;
}

std::vector<double> ARIMAPredictor::imputeMissingValues(
    const std::vector<double>& series, const std::string& method) {
    
    std::vector<double> result = series;
    
    for (size_t i = 0; i < result.size(); ++i) {
        if (std::isnan(result[i])) {
            if (method == "linear" && i > 0 && i < result.size() - 1) {
                // 线性插值
                size_t prev = i - 1;
                size_t next = i + 1;
                
                // 找到前一个非NaN值
                while (prev > 0 && std::isnan(result[prev])) prev--;
                // 找到后一个非NaN值
                while (next < result.size() - 1 && std::isnan(result[next])) next++;
                
                if (!std::isnan(result[prev]) && !std::isnan(result[next])) {
                    result[i] = result[prev] + (result[next] - result[prev]) * 
                               static_cast<double>(i - prev) / static_cast<double>(next - prev);
                }
            } else if (method == "mean") {
                // 用均值填充
                double sum = 0.0;
                int count = 0;
                for (double val : series) {
                    if (!std::isnan(val)) {
                        sum += val;
                        count++;
                    }
                }
                if (count > 0) {
                    result[i] = sum / count;
                }
            }
        }
    }
    
    return result;
}

// ==================== 配置和状态管理 ====================

void ARIMAPredictor::setConfig(const ARIMAConfig& config) {
    config_ = config;
    model_fitted_ = false;  // 需要重新拟合模型
}

ARIMAPredictor::ARIMAConfig ARIMAPredictor::getConfig() const {
    return config_;
}

ARIMAPredictor::ModelPerformance ARIMAPredictor::getPerformanceStats() const {
    return performance_;
}

void ARIMAPredictor::reset() {
    model_fitted_ = false;
    ar_coefficients_.clear();
    ma_coefficients_.clear();
    residuals_.clear();
    residual_variance_ = 0.0;
    training_data_.clear();
    recent_predictions_.clear();
    recent_actuals_.clear();
    prediction_count_ = 0;
    cumulative_error_ = 0.0;
    
    // 重置性能统计
    performance_.accuracy = 0.0;
    performance_.precision = 0.0;
    performance_.recall = 0.0;
    performance_.f1_score = 0.0;
    performance_.total_predictions = 0;
    performance_.correct_predictions = 0;
    performance_.last_update = std::chrono::steady_clock::now();
}

json ARIMAPredictor::exportModelState() const {
    json state;
    
    // 配置参数
    state["config"]["p"] = config_.p;
    state["config"]["d"] = config_.d;
    state["config"]["q"] = config_.q;
    state["config"]["prediction_horizon"] = config_.prediction_horizon;
    state["config"]["confidence_level"] = config_.confidence_level;
    
    // 模型参数
    state["ar_coefficients"] = ar_coefficients_;
    state["ma_coefficients"] = ma_coefficients_;
    state["residual_variance"] = residual_variance_;
    state["model_fitted"] = model_fitted_;
    
    // 性能统计
    state["performance"]["accuracy"] = performance_.accuracy;
    state["performance"]["total_predictions"] = performance_.total_predictions;
    state["performance"]["correct_predictions"] = performance_.correct_predictions;
    
    return state;
}

bool ARIMAPredictor::importModelState(const json& state) {
    try {
        // 导入配置
        if (state.contains("config")) {
            const auto& config = state["config"];
            config_.p = config.value("p", 2);
            config_.d = config.value("d", 1);
            config_.q = config.value("q", 2);
            config_.prediction_horizon = config.value("prediction_horizon", 5);
            config_.confidence_level = config.value("confidence_level", 0.95);
        }
        
        // 导入模型参数
        if (state.contains("ar_coefficients")) {
            ar_coefficients_ = state["ar_coefficients"].get<std::vector<double>>();
        }
        if (state.contains("ma_coefficients")) {
            ma_coefficients_ = state["ma_coefficients"].get<std::vector<double>>();
        }
        residual_variance_ = state.value("residual_variance", 0.0);
        model_fitted_ = state.value("model_fitted", false);
        
        // 导入性能统计
        if (state.contains("performance")) {
            const auto& perf = state["performance"];
            performance_.accuracy = perf.value("accuracy", 0.0);
            performance_.total_predictions = perf.value("total_predictions", 0);
            performance_.correct_predictions = perf.value("correct_predictions", 0);
        }
        
        return true;
    } catch (...) {
        return false;
    }
}

// ==================== 内部算法实现 ====================

std::vector<double> ARIMAPredictor::calculateACF(const std::vector<double>& series, int max_lag) {
    std::vector<double> acf;
    if (series.size() < 2) return acf;
    
    double mean = calculateMean(series);
    double variance = calculateVariance(series);
    
    for (int lag = 0; lag <= max_lag && lag < static_cast<int>(series.size()); ++lag) {
        double covariance = 0.0;
        int count = 0;
        
        for (size_t i = lag; i < series.size(); ++i) {
            covariance += (series[i] - mean) * (series[i - lag] - mean);
            count++;
        }
        
        if (count > 0 && variance > 1e-8) {
            acf.push_back(covariance / (count * variance));
        } else {
            acf.push_back(0.0);
        }
    }
    
    return acf;
}

std::vector<double> ARIMAPredictor::calculatePACF(const std::vector<double>& series, int max_lag) {
    std::vector<double> pacf;
    if (series.size() < 2) return pacf;
    
    std::vector<double> acf = calculateACF(series, max_lag);
    if (acf.empty()) return pacf;
    
    pacf.push_back(1.0);  // PACF(0) = 1
    
    if (acf.size() > 1) {
        pacf.push_back(acf[1]);  // PACF(1) = ACF(1)
    }
    
    // 使用Yule-Walker方程计算PACF
    for (int k = 2; k <= max_lag && k < static_cast<int>(acf.size()); ++k) {
        double numerator = acf[k];
        double denominator = 1.0;
        
        for (int j = 1; j < k; ++j) {
            if (j < static_cast<int>(pacf.size()) && j < static_cast<int>(acf.size())) {
                numerator -= pacf[j] * acf[k - j];
            }
        }
        
        if (std::abs(denominator) > 1e-8) {
            pacf.push_back(numerator / denominator);
        } else {
            pacf.push_back(0.0);
        }
    }
    
    return pacf;
}

std::vector<double> ARIMAPredictor::estimateParameters(
    const std::vector<double>& series, int p, int q) {
    
    std::vector<double> parameters;
    
    if (series.size() < static_cast<size_t>(p + q + 2)) {
        // 数据不足，返回默认参数
        for (int i = 0; i < p; ++i) {
            parameters.push_back(0.1);
        }
        for (int i = 0; i < q; ++i) {
            parameters.push_back(0.1);
        }
        return parameters;
    }
    
    // 简化的参数估计：使用最小二乘法
    // 这里实现一个基本的估计算法
    
    // AR参数估计（使用Yule-Walker方程）
    if (p > 0) {
        std::vector<double> acf = calculateACF(series, p);
        for (int i = 0; i < p && i < static_cast<int>(acf.size()); ++i) {
            parameters.push_back(acf[i + 1] * 0.5);  // 简化估计
        }
    }
    
    // MA参数估计（简化方法）
    if (q > 0) {
        for (int i = 0; i < q; ++i) {
            parameters.push_back(0.1 * (i + 1));  // 简化估计
        }
    }
    
    return parameters;
}

std::pair<double, double> ARIMAPredictor::calculateInformationCriteria(
    const std::vector<double>& residuals, int num_params, int n) {
    
    if (residuals.empty() || n <= num_params) {
        return {0.0, 0.0};
    }
    
    double mse = calculateMSE(residuals);
    double log_likelihood = -0.5 * n * std::log(2 * M_PI * mse) - 0.5 * n;
    
    double aic = -2 * log_likelihood + 2 * num_params;
    double bic = -2 * log_likelihood + num_params * std::log(n);
    
    return {aic, bic};
}

std::pair<std::vector<double>, std::vector<double>> ARIMAPredictor::calculateConfidenceInterval(
    const std::vector<double>& predictions,
    double residual_variance,
    double confidence_level) {
    
    std::vector<double> upper, lower;
    
    // 计算置信区间的临界值
    double alpha = 1.0 - confidence_level;
    double z_score = 1.96;  // 95%置信水平的近似值
    
    if (confidence_level == 0.99) z_score = 2.576;
    else if (confidence_level == 0.90) z_score = 1.645;
    
    double std_error = std::sqrt(residual_variance);
    
    for (size_t i = 0; i < predictions.size(); ++i) {
        double margin = z_score * std_error * std::sqrt(i + 1);  // 预测步数越远，误差越大
        upper.push_back(predictions[i] + margin);
        lower.push_back(predictions[i] - margin);
    }
    
    return {upper, lower};
}

double ARIMAPredictor::encodeStrategy(const std::string& strategy_name) {
    auto it = strategy_encoding_.find(strategy_name);
    return (it != strategy_encoding_.end()) ? it->second : 1.0;
}

std::string ARIMAPredictor::decodeStrategy(double encoded_value) {
    double min_distance = std::numeric_limits<double>::max();
    std::string best_strategy = "SC";
    
    for (const auto& pair : strategy_decoding_) {
        double distance = std::abs(encoded_value - pair.first);
        if (distance < min_distance) {
            min_distance = distance;
            best_strategy = pair.second;
        }
    }
    
    return best_strategy;
}

std::vector<double> ARIMAPredictor::movingAverage(const std::vector<double>& series, int window_size) {
    std::vector<double> result;
    
    if (window_size <= 0 || series.empty()) return result;
    
    for (size_t i = 0; i < series.size(); ++i) {
        double sum = 0.0;
        int count = 0;
        
        int start = std::max(0, static_cast<int>(i) - window_size + 1);
        for (int j = start; j <= static_cast<int>(i); ++j) {
            sum += series[j];
            count++;
        }
        
        result.push_back(count > 0 ? sum / count : 0.0);
    }
    
    return result;
}

std::vector<double> ARIMAPredictor::exponentialSmoothing(const std::vector<double>& series, double alpha) {
    std::vector<double> result;
    
    if (series.empty()) return result;
    
    result.push_back(series[0]);
    
    for (size_t i = 1; i < series.size(); ++i) {
        double smoothed = alpha * series[i] + (1.0 - alpha) * result[i - 1];
        result.push_back(smoothed);
    }
    
    return result;
}

// ==================== 辅助函数 ====================

double ARIMAPredictor::calculateMean(const std::vector<double>& data) {
    if (data.empty()) return 0.0;
    return std::accumulate(data.begin(), data.end(), 0.0) / data.size();
}

double ARIMAPredictor::calculateVariance(const std::vector<double>& data) {
    if (data.size() < 2) return 0.0;
    
    double mean = calculateMean(data);
    double sum_sq_diff = 0.0;
    
    for (double val : data) {
        double diff = val - mean;
        sum_sq_diff += diff * diff;
    }
    
    return sum_sq_diff / (data.size() - 1);
}

double ARIMAPredictor::calculateMSE(const std::vector<double>& residuals) {
    if (residuals.empty()) return 0.0;
    
    double sum_sq = 0.0;
    for (double r : residuals) {
        sum_sq += r * r;
    }
    
    return sum_sq / residuals.size();
}

double ARIMAPredictor::calculateMAE(const std::vector<double>& residuals) {
    if (residuals.empty()) return 0.0;
    
    double sum_abs = 0.0;
    for (double r : residuals) {
        sum_abs += std::abs(r);
    }
    
    return sum_abs / residuals.size();
}

std::vector<double> ARIMAPredictor::calculateResiduals(
    const std::vector<double>& series, int p, int q) {
    
    std::vector<double> residuals;
    
    // 简化的残差计算
    for (size_t i = std::max(p, q); i < series.size(); ++i) {
        double predicted = 0.0;
        
        // AR部分
        for (int j = 0; j < p && j < static_cast<int>(ar_coefficients_.size()); ++j) {
            if (i > static_cast<size_t>(j)) {
                predicted += ar_coefficients_[j] * series[i - 1 - j];
            }
        }
        
        double residual = series[i] - predicted;
        residuals.push_back(residual);
    }
    
    return residuals;
}

std::vector<double> ARIMAPredictor::inverseDifference(
    const std::vector<double>& diff_series,
    const std::vector<double>& original_series,
    int order) {
    
    if (order == 0) return diff_series;
    if (original_series.empty()) return diff_series;
    
    std::vector<double> result = diff_series;
    
    // 逆差分恢复
    for (int d = 0; d < order; ++d) {
        std::vector<double> integrated;
        
        if (!original_series.empty()) {
            integrated.push_back(original_series[original_series.size() - order + d]);
        }
        
        for (size_t i = 0; i < result.size(); ++i) {
            double next_value = integrated.back() + result[i];
            integrated.push_back(next_value);
        }
        
        result = std::vector<double>(integrated.begin() + 1, integrated.end());
    }
    
    return result;
}

double ARIMAPredictor::calculateModelQualityScore(double mse, double aic, double bic) {
    // 综合评分：MSE越小越好，AIC/BIC越小越好
    double mse_score = 1.0 / (1.0 + mse);
    double aic_score = 1.0 / (1.0 + std::abs(aic) / 100.0);
    double bic_score = 1.0 / (1.0 + std::abs(bic) / 100.0);
    
    return (mse_score * 0.5 + aic_score * 0.25 + bic_score * 0.25);
}

double ARIMAPredictor::calculateTrend(const std::vector<double>& series) {
    if (series.size() < 2) return 0.0;
    
    // 简单线性趋势计算
    double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_x2 = 0.0;
    int n = series.size();
    
    for (int i = 0; i < n; ++i) {
        sum_x += i;
        sum_y += series[i];
        sum_xy += i * series[i];
        sum_x2 += i * i;
    }
    
    double slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
    return slope;
}

double ARIMAPredictor::calculateVolatility(const std::vector<double>& series) {
    if (series.size() < 2) return 0.0;
    
    std::vector<double> returns;
    for (size_t i = 1; i < series.size(); ++i) {
        if (series[i-1] != 0) {
            returns.push_back((series[i] - series[i-1]) / series[i-1]);
        }
    }
    
    return std::sqrt(calculateVariance(returns));
}
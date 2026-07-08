#include "DynamicParameterOptimizer.h"
#include <algorithm>
#include <numeric>
#include <cmath>
#include <random>
#include <iostream>
#include <fstream>

DynamicParameterOptimizer::DynamicParameterOptimizer() {
    // 初始化默认配置
    baseline_metrics = {
        50.0,   // latency
        10.0,   // jitter
        0.01,   // packet_loss
        100.0,  // bandwidth
        -60.0,  // signal_strength
        0.9,    // reliability_score
        std::chrono::steady_clock::now()
    };
}

DynamicParameterOptimizer::DynamicParameterOptimizer(const json& config) {
    loadConfig(config);
    
    // 初始化ARIMA预测器
    arima_predictor_ = std::make_unique<ARIMAPredictor>(config);
}

void DynamicParameterOptimizer::loadConfig(const json& config) {
    if (config.contains("resource_prediction")) {
        const auto& rp = config["resource_prediction"];
        resource_prediction_config.exponential_alpha = rp.value("exponential_alpha", 0.3);
        resource_prediction_config.exponential_beta = rp.value("exponential_beta", 0.2);
        resource_prediction_config.exponential_gamma = rp.value("exponential_gamma", 0.1);
        resource_prediction_config.arima_p = rp.value("arima_p", 2);
        resource_prediction_config.arima_d = rp.value("arima_d", 1);
        resource_prediction_config.arima_q = rp.value("arima_q", 2);
        resource_prediction_config.prediction_window = rp.value("prediction_window", 10);
        resource_prediction_config.ensemble_threshold = rp.value("ensemble_threshold", 0.8);
    }
    
    if (config.contains("network_quality")) {
        const auto& nq = config["network_quality"];
        network_quality_config.measurement_interval_ms = nq.value("measurement_interval_ms", 100);
        network_quality_config.history_window_size = nq.value("history_window_size", 50);
        network_quality_config.anomaly_threshold = nq.value("anomaly_threshold", 2.0);
        network_quality_config.latency_threshold_ms = nq.value("latency_threshold_ms", 100.0);
        network_quality_config.jitter_threshold_ms = nq.value("jitter_threshold_ms", 20.0);
        network_quality_config.packet_loss_threshold = nq.value("packet_loss_threshold", 0.05);
    }
    
    if (config.contains("reputation")) {
        const auto& rep = config["reputation"];
        reputation_config.time_decay_factor = rep.value("time_decay_factor", 0.95);
        reputation_config.max_history_records = rep.value("max_history_records", 1000);
        reputation_config.anomaly_threshold = rep.value("anomaly_threshold", 2.5);
        reputation_config.trend_smoothing_factor = rep.value("trend_smoothing_factor", 0.2);
    }
    
    if (config.contains("convergence")) {
        const auto& conv = config["convergence"];
        convergence_config.convergence_threshold = conv.value("convergence_threshold", 1e-4);
        convergence_config.min_convergence_steps = conv.value("min_convergence_steps", 10);
        convergence_config.stability_threshold = conv.value("stability_threshold", 0.95);
        convergence_config.learning_rate_min = conv.value("learning_rate_min", 0.001);
        convergence_config.learning_rate_max = conv.value("learning_rate_max", 0.1);
        convergence_config.convergence_window = conv.value("convergence_window", 20);
    }
}

// ==================== 资源预测算法优化 ====================

DynamicParameterOptimizer::ResourcePrediction 
DynamicParameterOptimizer::predictResourceUsage(const std::vector<double>& history, 
                                               const std::string& resource_type) {
    if (history.empty()) {
        return {0.0, 0.0, 0.0, "none"};
    }
    
    // 多模型预测
    double exp_pred = exponentialSmoothingPredict(history, 
        resource_prediction_config.exponential_alpha,
        resource_prediction_config.exponential_beta,
        resource_prediction_config.exponential_gamma);
    
    double arima_pred = arimaPredict(history, 
        resource_prediction_config.arima_p,
        resource_prediction_config.arima_d,
        resource_prediction_config.arima_q);
    
    double nn_pred = neuralNetworkPredict(history);
    
    // 模型性能权重
    double exp_weight = model_performance.count("exponential") ? 
                       model_performance["exponential"] : 0.33;
    double arima_weight = model_performance.count("arima") ? 
                         model_performance["arima"] : 0.33;
    double nn_weight = model_performance.count("neural_network") ? 
                      model_performance["neural_network"] : 0.34;
    
    // 归一化权重
    double total_weight = exp_weight + arima_weight + nn_weight;
    if (total_weight > 0) {
        exp_weight /= total_weight;
        arima_weight /= total_weight;
        nn_weight /= total_weight;
    }
    
    // 集成预测
    double ensemble_pred = exp_weight * exp_pred + arima_weight * arima_pred + nn_weight * nn_pred;
    
    // 计算置信度和方差
    std::vector<double> predictions = {exp_pred, arima_pred, nn_pred};
    double variance = calculateVariance(predictions);
    double confidence = std::max(0.0, 1.0 - variance);
    
    // 选择最佳模型
    std::string best_model = "exponential";
    if (arima_weight > exp_weight && arima_weight > nn_weight) {
        best_model = "arima";
    } else if (nn_weight > exp_weight && nn_weight > arima_weight) {
        best_model = "neural_network";
    }
    
    return {ensemble_pred, confidence, variance, best_model};
}

double DynamicParameterOptimizer::exponentialSmoothingPredict(
    const std::vector<double>& history, double alpha, double beta, double gamma) {
    
    if (history.size() < 2) {
        return history.empty() ? 0.0 : history.back();
    }
    
    // 简化的三次指数平滑
    double level = history[0];
    double trend = history.size() > 1 ? history[1] - history[0] : 0.0;
    
    for (size_t i = 1; i < history.size(); ++i) {
        double prev_level = level;
        level = alpha * history[i] + (1 - alpha) * (level + trend);
        trend = beta * (level - prev_level) + (1 - beta) * trend;
    }
    
    return level + trend;
}

double DynamicParameterOptimizer::arimaPredict(
    const std::vector<double>& history, int p, int d, int q) {
    
    if (history.size() < static_cast<size_t>(p + d + q)) {
        return history.empty() ? 0.0 : history.back();
    }
    
    // 使用增强的ARIMA预测器
    if (arima_predictor_) {
        auto result = arima_predictor_->predict(history, 1);
        return result.predictions.empty() ? history.back() : result.predictions[0];
    }
    
    // 回退到简化的ARIMA实现 - 使用移动平均
    std::vector<double> ma = movingAverage(history, std::min(p, static_cast<int>(history.size())));
    return ma.empty() ? 0.0 : ma.back();
}

double DynamicParameterOptimizer::neuralNetworkPredict(const std::vector<double>& history) {
    if (history.size() < 3) {
        return history.empty() ? 0.0 : history.back();
    }
    
    // 简化的神经网络预测 - 使用加权平均
    double prediction = 0.0;
    double total_weight = 0.0;
    
    for (size_t i = 0; i < std::min(history.size(), size_t(5)); ++i) {
        double weight = 1.0 / (i + 1);  // 越近的数据权重越大
        prediction += weight * history[history.size() - 1 - i];
        total_weight += weight;
    }
    
    return total_weight > 0 ? prediction / total_weight : 0.0;
}

void DynamicParameterOptimizer::updateModelPerformance(
    const std::string& model_name, double predicted, double actual) {
    
    double error = std::abs(predicted - actual);
    double accuracy = std::max(0.0, 1.0 - error);
    
    // 指数移动平均更新性能
    if (model_performance.count(model_name)) {
        model_performance[model_name] = 0.9 * model_performance[model_name] + 0.1 * accuracy;
    } else {
        model_performance[model_name] = accuracy;
    }
}

// ==================== 网络质量测量实时性增强 ====================

DynamicParameterOptimizer::NetworkQualityMetrics 
DynamicParameterOptimizer::measureNetworkQuality() {
    
    // 模拟实时网络质量测量
    static std::random_device rd;
    static std::mt19937 gen(rd());
    
    NetworkQualityMetrics metrics;
    metrics.timestamp = std::chrono::steady_clock::now();
    
    // 基于历史数据和随机波动生成测量值
    std::normal_distribution<double> latency_dist(baseline_metrics.latency, 10.0);
    std::normal_distribution<double> jitter_dist(baseline_metrics.jitter, 2.0);
    std::normal_distribution<double> loss_dist(baseline_metrics.packet_loss, 0.005);
    std::normal_distribution<double> bw_dist(baseline_metrics.bandwidth, 20.0);
    std::normal_distribution<double> signal_dist(baseline_metrics.signal_strength, 5.0);
    
    metrics.latency = std::max(1.0, latency_dist(gen));
    metrics.jitter = std::max(0.1, jitter_dist(gen));
    metrics.packet_loss = std::max(0.0, std::min(1.0, loss_dist(gen)));
    metrics.bandwidth = std::max(1.0, bw_dist(gen));
    metrics.signal_strength = std::max(-100.0, std::min(-30.0, signal_dist(gen)));
    
    // 计算可靠性评分
    double latency_score = std::max(0.0, 1.0 - metrics.latency / 200.0);
    double jitter_score = std::max(0.0, 1.0 - metrics.jitter / 50.0);
    double loss_score = std::max(0.0, 1.0 - metrics.packet_loss / 0.1);
    double bw_score = std::min(1.0, metrics.bandwidth / 100.0);
    double signal_score = (metrics.signal_strength + 100.0) / 70.0;
    
    metrics.reliability_score = (latency_score + jitter_score + loss_score + bw_score + signal_score) / 5.0;
    
    return metrics;
}

void DynamicParameterOptimizer::updateNetworkQualityHistory(
    const NetworkQualityMetrics& metrics) {
    
    network_quality_history.push_back(metrics);
    
    // 保持历史窗口大小
    while (network_quality_history.size() > 
           static_cast<size_t>(network_quality_config.history_window_size)) {
        network_quality_history.pop_front();
    }
    
    // 更新基线指标
    if (network_quality_history.size() >= 10) {
        std::vector<double> latencies, jitters, losses, bandwidths, signals;
        for (const auto& m : network_quality_history) {
            latencies.push_back(m.latency);
            jitters.push_back(m.jitter);
            losses.push_back(m.packet_loss);
            bandwidths.push_back(m.bandwidth);
            signals.push_back(m.signal_strength);
        }
        
        baseline_metrics.latency = calculateMean(latencies);
        baseline_metrics.jitter = calculateMean(jitters);
        baseline_metrics.packet_loss = calculateMean(losses);
        baseline_metrics.bandwidth = calculateMean(bandwidths);
        baseline_metrics.signal_strength = calculateMean(signals);
    }
}

double DynamicParameterOptimizer::analyzeNetworkTrend(
    const std::string& metric_type, int window_size) {
    
    if (network_quality_history.size() < static_cast<size_t>(window_size)) {
        return 0.0;
    }
    
    std::vector<double> values;
    auto start_it = network_quality_history.end() - window_size;
    
    for (auto it = start_it; it != network_quality_history.end(); ++it) {
        if (metric_type == "latency") {
            values.push_back(it->latency);
        } else if (metric_type == "jitter") {
            values.push_back(it->jitter);
        } else if (metric_type == "packet_loss") {
            values.push_back(it->packet_loss);
        } else if (metric_type == "bandwidth") {
            values.push_back(it->bandwidth);
        } else if (metric_type == "signal_strength") {
            values.push_back(it->signal_strength);
        } else if (metric_type == "reliability_score") {
            values.push_back(it->reliability_score);
        }
    }
    
    return calculateTrend(values);
}

bool DynamicParameterOptimizer::detectNetworkAnomaly(
    const NetworkQualityMetrics& current_metrics) {
    
    if (network_quality_history.size() < 10) {
        return false;  // 需要足够的历史数据
    }
    
    // 检查各项指标是否异常
    std::vector<double> latencies, jitters, losses, bandwidths, signals;
    for (const auto& m : network_quality_history) {
        latencies.push_back(m.latency);
        jitters.push_back(m.jitter);
        losses.push_back(m.packet_loss);
        bandwidths.push_back(m.bandwidth);
        signals.push_back(m.signal_strength);
    }
    
    bool latency_anomaly = isOutlier(current_metrics.latency, latencies, 
                                   network_quality_config.anomaly_threshold);
    bool jitter_anomaly = isOutlier(current_metrics.jitter, jitters, 
                                  network_quality_config.anomaly_threshold);
    bool loss_anomaly = isOutlier(current_metrics.packet_loss, losses, 
                                network_quality_config.anomaly_threshold);
    bool bw_anomaly = isOutlier(current_metrics.bandwidth, bandwidths, 
                              network_quality_config.anomaly_threshold);
    bool signal_anomaly = isOutlier(current_metrics.signal_strength, signals, 
                                  network_quality_config.anomaly_threshold);
    
    return latency_anomaly || jitter_anomaly || loss_anomaly || bw_anomaly || signal_anomaly;
}

// ==================== 信誉评估历史数据处理完善 ====================

void DynamicParameterOptimizer::addReputationRecord(
    const std::string& node_id, 
    const std::vector<double>& reputation_vector,
    double trust_score,
    const std::string& interaction_type) {
    
    ReputationRecord record;
    record.node_id = node_id;
    record.reputation_vector = reputation_vector;
    record.trust_score = trust_score;
    record.timestamp = std::chrono::steady_clock::now();
    record.interaction_type = interaction_type;
    
    reputation_history[node_id].push_back(record);
    
    // 保持历史记录数量限制
    while (reputation_history[node_id].size() > 
           static_cast<size_t>(reputation_config.max_history_records)) {
        reputation_history[node_id].pop_front();
    }
}

std::vector<DynamicParameterOptimizer::ReputationRecord> 
DynamicParameterOptimizer::getNodeReputationHistory(
    const std::string& node_id, int max_records) {
    
    std::vector<ReputationRecord> result;
    
    if (reputation_history.count(node_id)) {
        const auto& history = reputation_history[node_id];
        int start_idx = std::max(0, static_cast<int>(history.size()) - max_records);
        
        for (size_t i = start_idx; i < history.size(); ++i) {
            result.push_back(history[i]);
        }
    }
    
    return result;
}

double DynamicParameterOptimizer::calculateTimeDecayWeight(
    const std::chrono::steady_clock::time_point& timestamp,
    double decay_factor) {
    
    auto now = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::hours>(now - timestamp);
    double hours_elapsed = duration.count();
    
    return std::pow(decay_factor, hours_elapsed);
}

double DynamicParameterOptimizer::analyzeReputationTrend(
    const std::string& node_id, int window_size) {
    
    if (!reputation_history.count(node_id) || 
        reputation_history[node_id].size() < static_cast<size_t>(window_size)) {
        return 0.0;
    }
    
    const auto& history = reputation_history[node_id];
    std::vector<double> trust_scores;
    
    auto start_it = history.end() - window_size;
    for (auto it = start_it; it != history.end(); ++it) {
        trust_scores.push_back(it->trust_score);
    }
    
    return calculateTrend(trust_scores);
}

bool DynamicParameterOptimizer::detectReputationAnomaly(
    const std::string& node_id, 
    const std::vector<double>& current_reputation) {
    
    if (!reputation_history.count(node_id) || reputation_history[node_id].size() < 10) {
        return false;
    }
    
    const auto& history = reputation_history[node_id];
    
    // 检查每个维度的信誉值是否异常
    for (size_t dim = 0; dim < current_reputation.size() && dim < 7; ++dim) {
        std::vector<double> historical_values;
        for (const auto& record : history) {
            if (record.reputation_vector.size() > dim) {
                historical_values.push_back(record.reputation_vector[dim]);
            }
        }
        
        if (!historical_values.empty() && 
            isOutlier(current_reputation[dim], historical_values, 
                     reputation_config.anomaly_threshold)) {
            return true;
        }
    }
    
    return false;
}

void DynamicParameterOptimizer::cleanupExpiredData(
    std::chrono::hours retention_period) {
    
    auto cutoff_time = std::chrono::steady_clock::now() - retention_period;
    
    // 清理网络质量历史数据
    network_quality_history.erase(
        std::remove_if(network_quality_history.begin(), network_quality_history.end(),
                      [cutoff_time](const NetworkQualityMetrics& m) {
                          return m.timestamp < cutoff_time;
                      }),
        network_quality_history.end());
    
    // 清理信誉历史数据
    for (auto& pair : reputation_history) {
        auto& node_id = pair.first;
        auto& history = pair.second;
        history.erase(
            std::remove_if(history.begin(), history.end(),
                          [cutoff_time](const ReputationRecord& r) {
                              return r.timestamp < cutoff_time;
                          }),
            history.end());
    }
}

// ==================== 博弈策略收敛监控优化 ====================

DynamicParameterOptimizer::ConvergenceMetrics 
DynamicParameterOptimizer::monitorGameConvergence(
    const std::vector<double>& strategy_history,
    const std::vector<double>& payoff_history) {
    
    ConvergenceMetrics metrics;
    
    if (strategy_history.size() < static_cast<size_t>(convergence_config.min_convergence_steps)) {
        metrics.is_converged = false;
        metrics.strategy_variance = 1.0;
        metrics.payoff_stability = 0.0;
        metrics.convergence_rate = 0.0;
        metrics.steps_to_convergence = -1;
        metrics.convergence_type = "insufficient_data";
        return metrics;
    }
    
    // 计算策略方差
    int window = std::min(convergence_config.convergence_window, 
                         static_cast<int>(strategy_history.size()));
    std::vector<double> recent_strategies(strategy_history.end() - window, 
                                        strategy_history.end());
    metrics.strategy_variance = calculateVariance(recent_strategies);
    
    // 计算收益稳定性
    if (!payoff_history.empty()) {
        std::vector<double> recent_payoffs(payoff_history.end() - 
                                         std::min(window, static_cast<int>(payoff_history.size())), 
                                         payoff_history.end());
        double payoff_variance = calculateVariance(recent_payoffs);
        metrics.payoff_stability = std::max(0.0, 1.0 - payoff_variance);
    } else {
        metrics.payoff_stability = 0.0;
    }
    
    // 检查收敛性
    metrics.is_converged = (metrics.strategy_variance < convergence_config.convergence_threshold) &&
                          (metrics.payoff_stability > convergence_config.stability_threshold);
    
    // 计算收敛速率
    if (strategy_history.size() >= 2) {
        double initial_variance = calculateVariance(
            std::vector<double>(strategy_history.begin(), 
                              strategy_history.begin() + std::min(window, static_cast<int>(strategy_history.size()))));
        metrics.convergence_rate = std::max(0.0, 
            (initial_variance - metrics.strategy_variance) / strategy_history.size());
    }
    
    // 估计收敛步数
    if (metrics.is_converged) {
        // 找到首次满足收敛条件的位置
        for (int i = convergence_config.min_convergence_steps; 
             i <= static_cast<int>(strategy_history.size()); ++i) {
            std::vector<double> sub_strategies(strategy_history.end() - i, strategy_history.end());
            if (calculateVariance(sub_strategies) < convergence_config.convergence_threshold) {
                metrics.steps_to_convergence = strategy_history.size() - i;
                break;
            }
        }
    } else {
        metrics.steps_to_convergence = -1;
    }
    
    // 检测收敛类型
    metrics.convergence_type = detectConvergenceType(strategy_history);
    
    return metrics;
}

double DynamicParameterOptimizer::calculateStrategyStability(
    const std::vector<std::vector<double>>& strategy_sequence) {
    
    if (strategy_sequence.size() < 2) {
        return 0.0;
    }
    
    double total_distance = 0.0;
    for (size_t i = 1; i < strategy_sequence.size(); ++i) {
        double distance = 0.0;
        for (size_t j = 0; j < strategy_sequence[i].size() && 
                           j < strategy_sequence[i-1].size(); ++j) {
            distance += std::pow(strategy_sequence[i][j] - strategy_sequence[i-1][j], 2);
        }
        total_distance += std::sqrt(distance);
    }
    
    double avg_distance = total_distance / (strategy_sequence.size() - 1);
    return std::max(0.0, 1.0 - avg_distance);
}

std::string DynamicParameterOptimizer::detectConvergenceType(
    const std::vector<double>& strategy_history) {
    
    if (strategy_history.size() < 10) {
        return "insufficient_data";
    }
    
    // 分析最近的策略变化模式
    std::vector<double> recent_changes;
    for (size_t i = 1; i < strategy_history.size(); ++i) {
        recent_changes.push_back(std::abs(strategy_history[i] - strategy_history[i-1]));
    }
    
    double avg_change = calculateMean(recent_changes);
    double change_variance = calculateVariance(recent_changes);
    
    if (avg_change < 0.001) {
        return "stable_convergence";
    } else if (change_variance < 0.001) {
        return "oscillatory_convergence";
    } else if (avg_change > 0.1) {
        return "divergence";
    } else {
        return "slow_convergence";
    }
}

double DynamicParameterOptimizer::recommendLearningRate(
    const ConvergenceMetrics& metrics) {
    
    if (metrics.convergence_type == "divergence") {
        return convergence_config.learning_rate_min;
    } else if (metrics.convergence_type == "stable_convergence") {
        return convergence_config.learning_rate_max;
    } else if (metrics.convergence_type == "slow_convergence") {
        return (convergence_config.learning_rate_min + convergence_config.learning_rate_max) / 2.0;
    } else {
        // 基于收敛速率调整
        double rate_factor = std::min(1.0, metrics.convergence_rate * 10.0);
        return convergence_config.learning_rate_min + 
               rate_factor * (convergence_config.learning_rate_max - convergence_config.learning_rate_min);
    }
}

std::vector<double> DynamicParameterOptimizer::recommendStrategyAdjustment(
    const std::vector<double>& current_strategy,
    const ConvergenceMetrics& metrics) {
    
    std::vector<double> adjusted_strategy = current_strategy;
    
    if (metrics.convergence_type == "oscillatory_convergence") {
        // 减少策略变化幅度
        for (size_t i = 0; i < adjusted_strategy.size(); ++i) {
            adjusted_strategy[i] = 0.9 * current_strategy[i] + 0.1 * (1.0 / current_strategy.size());
        }
    } else if (metrics.convergence_type == "divergence") {
        // 回归到均匀分布
        std::fill(adjusted_strategy.begin(), adjusted_strategy.end(), 1.0 / adjusted_strategy.size());
    }
    
    return adjusted_strategy;
}

// ==================== 内部辅助方法 ====================

double DynamicParameterOptimizer::calculateMean(const std::vector<double>& data) {
    if (data.empty()) return 0.0;
    return std::accumulate(data.begin(), data.end(), 0.0) / data.size();
}

double DynamicParameterOptimizer::calculateVariance(const std::vector<double>& data) {
    if (data.size() < 2) return 0.0;
    
    double mean = calculateMean(data);
    double variance = 0.0;
    for (double value : data) {
        variance += std::pow(value - mean, 2);
    }
    return variance / (data.size() - 1);
}

double DynamicParameterOptimizer::calculateStandardDeviation(const std::vector<double>& data) {
    return std::sqrt(calculateVariance(data));
}

std::vector<double> DynamicParameterOptimizer::movingAverage(
    const std::vector<double>& data, int window_size) {
    
    std::vector<double> result;
    if (data.size() < static_cast<size_t>(window_size)) {
        return result;
    }
    
    for (size_t i = window_size - 1; i < data.size(); ++i) {
        double sum = 0.0;
        for (int j = 0; j < window_size; ++j) {
            sum += data[i - j];
        }
        result.push_back(sum / window_size);
    }
    
    return result;
}

double DynamicParameterOptimizer::calculateTrend(const std::vector<double>& data) {
    if (data.size() < 2) return 0.0;
    
    // 简单线性回归计算趋势
    double n = data.size();
    double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_x2 = 0.0;
    
    for (size_t i = 0; i < data.size(); ++i) {
        double x = i;
        double y = data[i];
        sum_x += x;
        sum_y += y;
        sum_xy += x * y;
        sum_x2 += x * x;
    }
    
    double slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
    return slope;
}

bool DynamicParameterOptimizer::isOutlier(
    double value, const std::vector<double>& reference_data, double threshold) {
    
    if (reference_data.size() < 3) return false;
    
    double mean = calculateMean(reference_data);
    double std_dev = calculateStandardDeviation(reference_data);
    
    return std::abs(value - mean) > threshold * std_dev;
}

void DynamicParameterOptimizer::cleanupOldData() {
    cleanupExpiredData(std::chrono::hours(168)); // 默认7天
}

// ==================== 增强的ARIMA预测方法 ====================

ARIMAPredictor::PredictionResult DynamicParameterOptimizer::predictWithARIMA(
    const std::vector<double>& data, int steps) {
    
    if (!arima_predictor_) {
        // 创建默认的ARIMA预测器
        json default_config;
        arima_predictor_ = std::make_unique<ARIMAPredictor>(default_config);
    }
    
    auto result = arima_predictor_->predict(data, steps);
    
    // 更新预测历史
    if (!result.predictions.empty()) {
        recent_predictions_.insert(recent_predictions_.end(), 
                                 result.predictions.begin(), result.predictions.end());
        
        // 限制历史大小
        if (recent_predictions_.size() > 100) {
            recent_predictions_.erase(recent_predictions_.begin(), 
                                    recent_predictions_.begin() + (recent_predictions_.size() - 100));
        }
    }
    
    return result;
}

ARIMAPredictor::StrategyPrediction DynamicParameterOptimizer::predictOptimalStrategy(
    const std::vector<std::string>& strategy_history,
    const std::vector<double>& payoff_history,
    const std::vector<std::vector<double>>& context_variables) {
    
    if (!arima_predictor_) {
        json default_config;
        arima_predictor_ = std::make_unique<ARIMAPredictor>(default_config);
    }
    
    // 更新内部策略历史
    strategy_history_ = strategy_history;
    payoff_history_ = payoff_history;
    
    // 使用ARIMA预测器进行策略预测
    auto prediction = arima_predictor_->predictStrategy(
        strategy_history, payoff_history, context_variables);
    
    // 更新策略性能历史
    if (!strategy_history.empty()) {
        std::string last_strategy = strategy_history.back();
        if (!payoff_history.empty()) {
            strategy_performance_history_[last_strategy].push_back(payoff_history.back());
            
            // 限制历史大小
            if (strategy_performance_history_[last_strategy].size() > 50) {
                strategy_performance_history_[last_strategy].erase(
                    strategy_performance_history_[last_strategy].begin());
            }
        }
    }
    
    return prediction;
}

ARIMAPredictor::PredictionResult DynamicParameterOptimizer::predictPayoffTrend(
    const std::vector<double>& payoff_history,
    const std::string& strategy_type,
    int prediction_horizon) {
    
    if (!arima_predictor_) {
        json default_config;
        arima_predictor_ = std::make_unique<ARIMAPredictor>(default_config);
    }
    
    return arima_predictor_->predictPayoffTrend(
        payoff_history, strategy_type, prediction_horizon);
}
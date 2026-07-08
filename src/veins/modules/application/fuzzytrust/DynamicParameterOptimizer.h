#ifndef DYNAMIC_PARAMETER_OPTIMIZER_H
#define DYNAMIC_PARAMETER_OPTIMIZER_H

#include <vector>
#include <deque>
#include <map>
#include <string>
#include <chrono>
#include <memory>
#include "json.hpp"
#include "ARIMAPredictor.h"

using json = nlohmann::json;

/**
 * 动态参数优化器
 * 负责改进资源预测算法的准确性、增强网络质量测量的实时性、
 * 完善信誉评估的历史数据处理、优化博弈策略的收敛监控
 */
class DynamicParameterOptimizer {
public:
    // 构造函数
    DynamicParameterOptimizer();
    explicit DynamicParameterOptimizer(const json& config);
    
    // 配置加载
    void loadConfig(const json& config);
    
    // ==================== 资源预测算法优化 ====================
    
    /**
     * 改进的资源预测算法
     * 使用多种预测模型的集成方法提高准确性
     */
    struct ResourcePrediction {
        double predicted_value;     // 预测值
        double confidence;          // 置信度
        double variance;           // 预测方差
        std::string best_model;    // 最佳预测模型
    };
    
    // 多模型资源预测
    ResourcePrediction predictResourceUsage(const std::vector<double>& history, 
                                          const std::string& resource_type);
    
    // 指数平滑预测
    double exponentialSmoothingPredict(const std::vector<double>& history, 
                                     double alpha, double beta, double gamma);
    
    // ARIMA预测
    double arimaPredict(const std::vector<double>& history, int p, int d, int q);
    
    // 神经网络预测（简化版）
    double neuralNetworkPredict(const std::vector<double>& history);
    
    // 增强的ARIMA预测方法
    ARIMAPredictor::PredictionResult predictWithARIMA(const std::vector<double>& data, int steps = 5);
    ARIMAPredictor::StrategyPrediction predictOptimalStrategy(
        const std::vector<std::string>& strategy_history,
        const std::vector<double>& payoff_history,
        const std::vector<std::vector<double>>& context_variables = {});
    ARIMAPredictor::PredictionResult predictPayoffTrend(
        const std::vector<double>& payoff_history,
        const std::string& strategy_type,
        int prediction_horizon = 5);
    
    // 预测模型性能评估
    void updateModelPerformance(const std::string& model_name, 
                               double predicted, double actual);
    
    // ==================== 网络质量测量实时性增强 ====================
    
    /**
     * 实时网络质量测量
     * 提供高频率、低延迟的网络质量评估
     */
    struct NetworkQualityMetrics {
        double latency;            // 延迟 (ms)
        double jitter;             // 抖动 (ms)
        double packet_loss;        // 丢包率 [0,1]
        double bandwidth;          // 可用带宽 (Mbps)
        double signal_strength;    // 信号强度 (dBm)
        double reliability_score;  // 可靠性评分 [0,1]
        std::chrono::steady_clock::time_point timestamp;
    };
    
    // 实时网络质量测量
    NetworkQualityMetrics measureNetworkQuality();
    
    // 网络质量历史数据管理
    void updateNetworkQualityHistory(const NetworkQualityMetrics& metrics);
    
    // 网络质量趋势分析
    double analyzeNetworkTrend(const std::string& metric_type, int window_size = 10);
    
    // 网络异常检测
    bool detectNetworkAnomaly(const NetworkQualityMetrics& current_metrics);
    
    // ==================== 信誉评估历史数据处理完善 ====================
    
    /**
     * 信誉历史数据管理
     * 提供完善的历史数据处理和分析功能
     */
    struct ReputationRecord {
        std::vector<double> reputation_vector;  // 7维信誉向量
        double trust_score;                     // 信任评分
        std::chrono::steady_clock::time_point timestamp;
        std::string node_id;                    // 节点ID
        std::string interaction_type;           // 交互类型
    };
    
    // 添加信誉记录
    void addReputationRecord(const std::string& node_id, 
                           const std::vector<double>& reputation_vector,
                           double trust_score,
                           const std::string& interaction_type = "general");
    
    // 获取节点历史信誉
    std::vector<ReputationRecord> getNodeReputationHistory(const std::string& node_id, 
                                                          int max_records = 100);
    
    // 计算时间衰减权重
    double calculateTimeDecayWeight(const std::chrono::steady_clock::time_point& timestamp,
                                  double decay_factor = 0.95);
    
    // 信誉趋势分析
    double analyzeReputationTrend(const std::string& node_id, int window_size = 20);
    
    // 信誉异常检测
    bool detectReputationAnomaly(const std::string& node_id, 
                               const std::vector<double>& current_reputation);
    
    // 清理过期数据
    void cleanupExpiredData(std::chrono::hours retention_period = std::chrono::hours(24));
    
    // ==================== 博弈策略收敛监控优化 ====================
    
    /**
     * 博弈策略收敛监控
     * 提供精确的收敛检测和策略优化建议
     */
    struct ConvergenceMetrics {
        double strategy_variance;      // 策略方差
        double payoff_stability;       // 收益稳定性
        double convergence_rate;       // 收敛速率
        bool is_converged;            // 是否收敛
        int steps_to_convergence;     // 收敛步数
        std::string convergence_type; // 收敛类型
    };
    
    // 监控博弈策略收敛
    ConvergenceMetrics monitorGameConvergence(const std::vector<double>& strategy_history,
                                            const std::vector<double>& payoff_history);
    
    // 计算策略稳定性
    double calculateStrategyStability(const std::vector<std::vector<double>>& strategy_sequence);
    
    // 检测收敛类型
    std::string detectConvergenceType(const std::vector<double>& strategy_history);
    
    // 优化学习率建议
    double recommendLearningRate(const ConvergenceMetrics& metrics);
    
    // 策略调整建议
    std::vector<double> recommendStrategyAdjustment(const std::vector<double>& current_strategy,
                                                  const ConvergenceMetrics& metrics);
    
    // ==================== 配置参数 ====================
    
private:
    // 资源预测参数
    struct ResourcePredictionConfig {
        double exponential_alpha = 0.3;        // 指数平滑α参数
        double exponential_beta = 0.2;         // 指数平滑β参数
        double exponential_gamma = 0.1;        // 指数平滑γ参数
        int arima_p = 2;                       // ARIMA p参数
        int arima_d = 1;                       // ARIMA d参数
        int arima_q = 2;                       // ARIMA q参数
        int prediction_window = 10;            // 预测窗口大小
        double ensemble_threshold = 0.8;       // 集成阈值
    } resource_prediction_config;
    
    // 网络质量测量参数
    struct NetworkQualityConfig {
        int measurement_interval_ms = 100;     // 测量间隔(ms)
        int history_window_size = 50;          // 历史窗口大小
        double anomaly_threshold = 2.0;        // 异常检测阈值(标准差倍数)
        double latency_threshold_ms = 100.0;   // 延迟阈值
        double jitter_threshold_ms = 20.0;     // 抖动阈值
        double packet_loss_threshold = 0.05;   // 丢包率阈值
    } network_quality_config;
    
    // 信誉评估参数
    struct ReputationConfig {
        double time_decay_factor = 0.95;       // 时间衰减因子
        int max_history_records = 1000;        // 最大历史记录数
        double anomaly_threshold = 2.5;        // 异常检测阈值
        std::chrono::hours data_retention_hours{24}; // 数据保留时间
        double trend_smoothing_factor = 0.2;   // 趋势平滑因子
    } reputation_config;
    
    // 博弈收敛监控参数
    struct ConvergenceConfig {
        double convergence_threshold = 1e-4;   // 收敛阈值
        int min_convergence_steps = 10;        // 最小收敛步数
        double stability_threshold = 0.95;     // 稳定性阈值
        double learning_rate_min = 0.001;      // 最小学习率
        double learning_rate_max = 0.1;        // 最大学习率
        int convergence_window = 20;           // 收敛检测窗口
    } convergence_config;
    
    // ==================== 数据存储 ====================
    
    // 资源预测相关
    std::map<std::string, std::deque<double>> resource_history;
    std::map<std::string, double> model_performance;
    
    // 网络质量相关
    std::deque<NetworkQualityMetrics> network_quality_history;
    NetworkQualityMetrics baseline_metrics;
    
    // 信誉评估相关
    std::map<std::string, std::deque<ReputationRecord>> reputation_history;
    
    // 博弈收敛相关
    std::deque<std::vector<double>> strategy_history;
    std::deque<double> payoff_history;
    
    // ARIMA预测器
    std::unique_ptr<ARIMAPredictor> arima_predictor_;
    
    // 预测历史和性能跟踪
    std::vector<double> recent_predictions_;
    std::vector<double> recent_actuals_;
    std::map<std::string, double> prediction_accuracy_;
    
    // 策略预测相关
    std::vector<std::string> strategy_history_;
    std::vector<double> payoff_history_;
    std::map<std::string, std::vector<double>> strategy_performance_history_;
    
    // ==================== 内部辅助方法 ====================
    
    // 统计计算
    double calculateMean(const std::vector<double>& data);
    double calculateVariance(const std::vector<double>& data);
    double calculateStandardDeviation(const std::vector<double>& data);
    
    // 时间序列分析
    std::vector<double> movingAverage(const std::vector<double>& data, int window_size);
    double calculateTrend(const std::vector<double>& data);
    
    // 异常检测
    bool isOutlier(double value, const std::vector<double>& reference_data, double threshold = 2.0);
    
    // 数据清理
    void cleanupOldData();
};

#endif // DYNAMIC_PARAMETER_OPTIMIZER_H
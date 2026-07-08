/**
 * @file ARIMAPredictor.h
 * @brief 增强的ARIMA时间序列预测模型
 * @author zlc
 * @date 2024
 * 
 * 本模块实现了完整的ARIMA(p,d,q)时间序列预测算法，
 * 专门用于车联网环境下的策略选择预测和决策优化。
 */

#ifndef ARIMAPREDICTOR_H_
#define ARIMAPREDICTOR_H_

#include <vector>
#include <string>
#include <map>
#include <memory>
#include <chrono>
#include "json.hpp"

using json = nlohmann::json;

/**
 * @class ARIMAPredictor
 * @brief 增强的ARIMA时间序列预测器
 * 
 * 提供完整的ARIMA(p,d,q)模型实现，支持：
 * - 自动参数选择和模型优化
 * - 多变量时间序列预测
 * - 策略选择概率预测
 * - 收益趋势预测
 * - 模型性能评估和自适应调整
 */
class ARIMAPredictor {
public:
    /**
     * @struct ARIMAConfig
     * @brief ARIMA模型配置参数
     */
    struct ARIMAConfig {
        int p;                          // 自回归阶数
        int d;                          // 差分阶数
        int q;                          // 移动平均阶数
        int max_p;                      // 最大p值（用于自动选择）
        int max_d;                      // 最大d值（用于自动选择）
        int max_q;                      // 最大q值（用于自动选择）
        int min_history_size;          // 最小历史数据大小
        int prediction_horizon;         // 预测步长
        double confidence_level;     // 置信水平
        bool auto_select_params;     // 自动参数选择
        bool enable_seasonality;    // 季节性检测
        int seasonal_period;           // 季节周期
        
        // 构造函数提供默认值
        ARIMAConfig() : p(2), d(1), q(2), max_p(5), max_d(2), max_q(5),
                       min_history_size(20), prediction_horizon(5),
                       confidence_level(0.95), auto_select_params(true),
                       enable_seasonality(false), seasonal_period(12) {}
    };
    
    /**
     * @struct PredictionResult
     * @brief 预测结果结构
     */
    struct PredictionResult {
        std::vector<double> predictions;     // 预测值序列
        std::vector<double> confidence_upper; // 置信区间上界
        std::vector<double> confidence_lower; // 置信区间下界
        double mse;                         // 均方误差
        double mae;                         // 平均绝对误差
        double aic;                         // 赤池信息准则
        double bic;                         // 贝叶斯信息准则
        std::string model_info;             // 模型信息
        double model_quality_score;         // 模型质量评分
        
        // 构造函数提供默认值
        PredictionResult() : mse(0.0), mae(0.0), aic(0.0), bic(0.0),
                           model_quality_score(0.0) {}
    };
    
    /**
     * @struct StrategyPrediction
     * @brief 策略预测结果
     */
    struct StrategyPrediction {
        std::map<std::string, double> strategy_probabilities; // 策略概率预测
        std::map<std::string, double> expected_payoffs;      // 预期收益预测
        std::string recommended_strategy;                    // 推荐策略
        double prediction_confidence;                        // 预测置信度
        std::vector<double> trend_indicators;                // 趋势指标
        
        // 构造函数提供默认值
        StrategyPrediction() : prediction_confidence(0.0) {}
    };
    
    /**
     * @struct ModelPerformance
     * @brief 模型性能指标
     */
    struct ModelPerformance {
        double accuracy;                    // 预测准确率
        double precision;                   // 精确度
        double recall;                      // 召回率
        double f1_score;                    // F1分数
        double mae;                         // 平均绝对误差
        double mse;                         // 均方误差
        int total_predictions;              // 总预测次数
        int correct_predictions;            // 正确预测次数
        std::chrono::steady_clock::time_point last_update; // 最后更新时间
        
        // 构造函数提供默认值
        ModelPerformance() : accuracy(0.0), precision(0.0), recall(0.0),
                           f1_score(0.0), mae(0.0), mse(0.0), total_predictions(0),
                           correct_predictions(0) {}
    };

public:
    /**
     * @brief 构造函数
     * @param config ARIMA配置参数
     */
    explicit ARIMAPredictor(const ARIMAConfig& config = ARIMAConfig());
    
    /**
     * @brief 从JSON配置初始化
     * @param json_config JSON配置对象
     */
    explicit ARIMAPredictor(const json& json_config);
    
    /**
     * @brief 析构函数
     */
    ~ARIMAPredictor() = default;
    
    // ==================== 核心预测功能 ====================
    
    /**
     * @brief 单变量时间序列预测
     * @param time_series 时间序列数据
     * @param steps 预测步数
     * @return 预测结果
     */
    PredictionResult predict(const std::vector<double>& time_series, int steps = 1);
    
    /**
     * @brief 多变量时间序列预测
     * @param multivariate_series 多变量时间序列数据
     * @param target_variable 目标变量索引
     * @param steps 预测步数
     * @return 预测结果
     */
    PredictionResult predictMultivariate(
        const std::vector<std::vector<double>>& multivariate_series,
        int target_variable, int steps = 1);
    
    /**
     * @brief 策略选择预测
     * @param strategy_history 策略选择历史
     * @param payoff_history 收益历史
     * @param context_variables 上下文变量（信任度、QoS、资源等）
     * @return 策略预测结果
     */
    StrategyPrediction predictStrategy(
        const std::vector<std::string>& strategy_history,
        const std::vector<double>& payoff_history,
        const std::vector<std::vector<double>>& context_variables);
    
    /**
     * @brief 收益趋势预测
     * @param payoff_history 收益历史数据
     * @param strategy_type 策略类型
     * @param prediction_horizon 预测时间范围
     * @return 收益预测结果
     */
    PredictionResult predictPayoffTrend(
        const std::vector<double>& payoff_history,
        const std::string& strategy_type,
        int prediction_horizon = 5);
    
    // ==================== 模型管理功能 ====================
    
    /**
     * @brief 自动选择最优ARIMA参数
     * @param time_series 时间序列数据
     * @return 最优参数组合
     */
    ARIMAConfig autoSelectParameters(const std::vector<double>& time_series);
    
    /**
     * @brief 模型训练和拟合
     * @param time_series 训练数据
     * @param validate 是否进行交叉验证
     * @return 训练成功标志
     */
    bool fitModel(const std::vector<double>& time_series, bool validate = true);
    
    /**
     * @brief 更新模型参数
     * @param new_data 新的观测数据
     * @param retrain 是否重新训练
     */
    void updateModel(const std::vector<double>& new_data, bool retrain = false);
    
    /**
     * @brief 模型性能评估
     * @param actual_values 实际值
     * @param predicted_values 预测值
     * @return 性能指标
     */
    ModelPerformance evaluateModel(
        const std::vector<double>& actual_values,
        const std::vector<double>& predicted_values);
    
    // ==================== 数据预处理功能 ====================
    
    /**
     * @brief 时间序列差分
     * @param series 原始序列
     * @param order 差分阶数
     * @return 差分后的序列
     */
    std::vector<double> difference(const std::vector<double>& series, int order = 1);
    
    /**
     * @brief 时间序列平稳性检验
     * @param series 时间序列
     * @return 是否平稳
     */
    bool isStationary(const std::vector<double>& series);
    
    /**
     * @brief 异常值检测和处理
     * @param series 时间序列
     * @param threshold 异常值阈值
     * @return 处理后的序列
     */
    std::vector<double> detectAndHandleOutliers(
        const std::vector<double>& series, double threshold = 3.0);
    
    /**
     * @brief 缺失值插补
     * @param series 包含缺失值的序列（NaN表示缺失）
     * @param method 插补方法（"linear", "spline", "mean"）
     * @return 插补后的序列
     */
    std::vector<double> imputeMissingValues(
        const std::vector<double>& series, const std::string& method = "linear");
    
    // ==================== 配置和状态管理 ====================
    
    /**
     * @brief 设置配置参数
     * @param config 新的配置参数
     */
    void setConfig(const ARIMAConfig& config);
    
    /**
     * @brief 获取当前配置
     * @return 当前配置参数
     */
    ARIMAConfig getConfig() const;
    
    /**
     * @brief 获取模型性能统计
     * @return 性能统计信息
     */
    ModelPerformance getPerformanceStats() const;
    
    /**
     * @brief 重置模型状态
     */
    void reset();
    
    /**
     * @brief 导出模型状态
     * @return JSON格式的模型状态
     */
    json exportModelState() const;
    
    /**
     * @brief 导入模型状态
     * @param state JSON格式的模型状态
     * @return 导入成功标志
     */
    bool importModelState(const json& state);

private:
    // ==================== 内部算法实现 ====================
    
    /**
     * @brief 计算自相关函数
     * @param series 时间序列
     * @param max_lag 最大滞后阶数
     * @return 自相关系数
     */
    std::vector<double> calculateACF(const std::vector<double>& series, int max_lag);
    
    /**
     * @brief 计算偏自相关函数
     * @param series 时间序列
     * @param max_lag 最大滞后阶数
     * @return 偏自相关系数
     */
    std::vector<double> calculatePACF(const std::vector<double>& series, int max_lag);
    
    /**
     * @brief 最大似然估计参数
     * @param series 时间序列
     * @param p AR阶数
     * @param q MA阶数
     * @return 参数估计结果
     */
    std::vector<double> estimateParameters(
        const std::vector<double>& series, int p, int q);
    
    /**
     * @brief 计算信息准则
     * @param residuals 残差序列
     * @param num_params 参数个数
     * @param n 样本大小
     * @return AIC和BIC值
     */
    std::pair<double, double> calculateInformationCriteria(
        const std::vector<double>& residuals, int num_params, int n);
    
    /**
     * @brief 预测置信区间计算
     * @param predictions 预测值
     * @param residual_variance 残差方差
     * @param confidence_level 置信水平
     * @return 置信区间
     */
    std::pair<std::vector<double>, std::vector<double>> calculateConfidenceInterval(
        const std::vector<double>& predictions,
        double residual_variance,
        double confidence_level);
    
    /**
     * @brief 策略编码转换
     * @param strategy_name 策略名称
     * @return 数值编码
     */
    double encodeStrategy(const std::string& strategy_name);
    
    /**
     * @brief 策略解码转换
     * @param encoded_value 数值编码
     * @return 策略名称
     */
    std::string decodeStrategy(double encoded_value);
    
    /**
     * @brief 移动平均计算
     * @param series 时间序列
     * @param window_size 窗口大小
     * @return 移动平均序列
     */
    std::vector<double> movingAverage(const std::vector<double>& series, int window_size);
    
    /**
     * @brief 指数平滑
     * @param series 时间序列
     * @param alpha 平滑参数
     * @return 平滑后的序列
     */
    std::vector<double> exponentialSmoothing(const std::vector<double>& series, double alpha);
    
    /**
     * @brief 计算均方误差
     * @param residuals 残差序列
     * @return 均方误差值
     */
    double calculateMSE(const std::vector<double>& residuals);
    
    /**
     * @brief 计算平均绝对误差
     * @param residuals 残差序列
     * @return 平均绝对误差值
     */
    double calculateMAE(const std::vector<double>& residuals);
    
    /**
     * @brief 计算方差
     * @param data 数据序列
     * @return 方差值
     */
    double calculateVariance(const std::vector<double>& data);
    
    /**
     * @brief 计算均值
     * @param data 数据序列
     * @return 均值
     */
    double calculateMean(const std::vector<double>& data);
    
    /**
     * @brief 计算模型质量评分
     * @param mse 均方误差
     * @param aic AIC值
     * @param bic BIC值
     * @return 质量评分
     */
    double calculateModelQualityScore(double mse, double aic, double bic);
    
    /**
     * @brief 计算趋势
     * @param series 时间序列
     * @return 趋势值
     */
    double calculateTrend(const std::vector<double>& series);
    
    /**
     * @brief 计算波动率
     * @param series 时间序列
     * @return 波动率值
     */
    double calculateVolatility(const std::vector<double>& series);
    
    /**
     * @brief 计算残差
     * @param series 时间序列
     * @param p AR阶数
     * @param q MA阶数
     * @return 残差序列
     */
    std::vector<double> calculateResiduals(
        const std::vector<double>& series, int p, int q);
    
    /**
     * @brief 逆差分
     * @param diff_series 差分序列
     * @param original_series 原始序列
     * @param order 差分阶数
     * @return 逆差分后的序列
     */
    std::vector<double> inverseDifference(
        const std::vector<double>& diff_series,
        const std::vector<double>& original_series,
        int order);

private:
    ARIMAConfig config_;                                    // 配置参数
    ModelPerformance performance_;                          // 性能统计
    std::vector<double> ar_coefficients_;                   // AR系数
    std::vector<double> ma_coefficients_;                   // MA系数
    std::vector<double> residuals_;                         // 残差序列
    double residual_variance_;                              // 残差方差
    bool model_fitted_;                                     // 模型是否已拟合
    
    // 策略编码映射
    std::map<std::string, double> strategy_encoding_;
    std::map<double, std::string> strategy_decoding_;
    
    // 历史数据缓存
    std::vector<double> training_data_;
    std::vector<double> recent_predictions_;
    std::vector<double> recent_actuals_;
    
    // 性能追踪
    std::chrono::steady_clock::time_point last_update_time_;
    int prediction_count_;
    double cumulative_error_;
};

#endif /* ARIMAPREDICTOR_H_ */
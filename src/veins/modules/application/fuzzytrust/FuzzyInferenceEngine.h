#ifndef FUZZY_INFERENCE_ENGINE_H
#define FUZZY_INFERENCE_ENGINE_H

#include <vector>
#include <string>
#include <random>
#include <algorithm>
#include <numeric>
#include <cmath>
#include <fstream>
#include "json.hpp"

class FuzzyInferenceEngine {
public:
    FuzzyInferenceEngine();
    explicit FuzzyInferenceEngine(const nlohmann::json& config);

    // 加载 json 配置（输入变量、隶属函数、规则库、权重等）
    void loadConfig(const nlohmann::json& config);

    // 设置输入向量 z = [mu_trust, mu_delay, mu_resource, rho, F_c, F_b, F_e]
    void setInput(const std::vector<double>& z);

    // 运行推理与去模糊，返回策略概率向量 pi
    std::vector<double> infer();
    
    // 执行模糊推理，返回加权输出
    double performFuzzyInference(const std::vector<double>& inputs);

    // 动态调整规则权重
    void updateRuleWeights(const std::vector<double>& weights);

    // 权重自适应更新机制 - 基于DAO投票
    void adaptWeightsDAO(const std::vector<double>& performance_gains);

    // 双时间尺度演化机制
    void dualTimescaleEvolution(double fast_time_ms, int slow_time_blocks);

    // Lyapunov势函数监控
    double computeLyapunovPotential(const std::vector<double>& strategy_dist) const;

    // 检查系统收敛性
    bool checkConvergence(const std::vector<double>& current_potential) const;

    // 日志记录
    void logInference(const std::string& filename = "");
    void logRuleActivations(const std::vector<double>& activations, const std::vector<double>& strategy_probs);
    
    // ==================== 规则权重优化算法 ====================
    
    // 主要优化方法
    void optimizeRuleWeights();                    // 基于历史性能数据动态调整规则权重
    void adaptiveWeightAdjustment();               // 自适应权重调整机制
    
    // 性能评估方法
    double calculateRulePerformanceScore(size_t rule_index);  // 计算规则的综合性能评分
    double computeRuleUsageFrequency(size_t rule_index);      // 计算规则的使用频率
    double calculateRecentPerformance();                      // 计算最近的性能表现
    double calculateHistoricalPerformance();                  // 计算历史平均性能
    
    // 辅助方法
    void recordWeightAdjustment();                 // 记录权重调整历史
    void recordDecisionQuality(double output);     // 记录决策质量

private:
    // 输入变量名与当前输入
    std::vector<std::string> input_vars;
    std::vector<double> input_z;

    // 隶属函数参数
    nlohmann::json membership_params;

    // 规则库与权重
    nlohmann::json rules;
    std::vector<double> rule_weights;

    // 去模糊方法
    std::string defuzz_method;

    // 配置参数
    double dao_voting_threshold;       // DAO投票阈值
    double dao_weight_update_rate;     // DAO权重更新率
    double dao_consensus_threshold;    // DAO共识阈值
    
    // Lyapunov势函数参数
    struct LyapunovParams {
        size_t window_size;            // 窗口大小
        double stability_threshold;    // 稳定性阈值
        double potential_function_alpha; // 势函数参数α
        double potential_function_beta;  // 势函数参数β
        double convergence_tolerance;  // 收敛容忍度
        int max_iterations;           // 最大迭代次数
        double gradient_step_size;    // 梯度步长
        double momentum_coefficient;  // 动量系数
    } lyapunov_params;
    
    // 时间尺度参数
    struct TimescaleParams {
        int fast_timescale_steps;     // 快时标步数
        int slow_timescale_steps;     // 慢时标步数
        double fast_dt;               // 快时标时间步长
        double slow_dt;               // 慢时标时间步长
        double separation_ratio;      // 时间尺度分离比
    } timescale_params;
    
    // 预测调制参数
    struct PredictionModulation {
        double lambda_c;              // CPU预测权重
        double lambda_b;              // 带宽预测权重
        double lambda_e;              // 能量预测权重
        double beta_softmin;          // 软最小值参数
        bool enable_prediction_adjustment; // 启用预测调整
    } prediction_modulation;
    
    // 性能监控参数
    struct PerformanceMonitoring {
        bool enable_rule_frequency_tracking;    // 启用规则频率跟踪
        bool enable_strategy_entropy_calculation; // 启用策略熵计算
        bool enable_convergence_monitoring;     // 启用收敛监控
        size_t monitoring_window_size;          // 监控窗口大小
    } performance_monitoring;
    
    // 决策历史记录（用于权重优化）
    std::vector<std::pair<double, double>> decision_history;  // <时间戳, 决策质量>
    
    // 运行时变量
    int fast_time_counter;             // 快时标计数器
    int slow_time_counter;             // 慢时标计数器

    // 内部辅助
    double computeMembership(const std::string& var, double value, const nlohmann::json& params) const;
    double defuzzify(const std::vector<double>& fuzzy_output) const;
    
    // 辅助方法
    std::vector<double> computeRuleActivations(const std::vector<double>& inputs);
    void performDualTimescaleUpdate();
    
    // 双时间尺度演化方法
    void performFastTimescaleUpdate();
    void performSlowTimescaleUpdate();
    
    // 规则计算方法
    double computeTrustVariance();
    double computeUrgencyLevel(const std::vector<double>& inputs);
    double computeRuleContribution(size_t rule_index);
    
    // 权重管理方法
    void normalizeWeights();

    // 双时间尺度演化的内部方法
    void updateVehicleStrategies();  // 快时标：车辆策略更新
    void performDAOWeightUpdate();   // 慢时标：DAO权重更新

    // 配置和状态
    nlohmann::json config;
    std::vector<double> strategy_preferences;
    
    // 随机数生成器（用于策略更新）
    mutable std::mt19937 rng;
    mutable std::uniform_real_distribution<double> uniform_dist;
};

#endif

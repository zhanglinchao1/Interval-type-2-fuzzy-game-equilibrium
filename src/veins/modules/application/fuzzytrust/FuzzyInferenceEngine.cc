#include "FuzzyInferenceEngine.h"
#include <algorithm>
#include <fstream>
#include <numeric>
#include <cmath>
#include <random>
#include <iostream>
#include <iomanip>
#include "veins/base/utils/Coord.h"
#include "veins/base/modules/BaseApplLayer.h"
#include "omnetpp.h"

using json = nlohmann::json;
using namespace omnetpp;

FuzzyInferenceEngine::FuzzyInferenceEngine() : defuzz_method("centroid"), rng(std::random_device{}()), uniform_dist(0.0, 1.0) {}

FuzzyInferenceEngine::FuzzyInferenceEngine(const json& config) : rng(std::random_device{}()), uniform_dist(0.0, 1.0) {
    loadConfig(config);
}

void FuzzyInferenceEngine::loadConfig(const json& config) {
    // 保存完整配置
    this->config = config;
    
    // 修正键名：config.json中使用的是"FuzzyInferenceEngine"而不是"FuzzyInference"
    const auto& fuzzy = config;
    input_vars = fuzzy.value("input_vars", std::vector<std::string>{"mu_trust", "mu_delay", "mu_resource", "rho", "F_c", "F_b", "F_e"});
    membership_params = fuzzy["membership_params"];
    rules = fuzzy["rules"];
    defuzz_method = fuzzy.value("defuzz_method", "centroid");
    rule_weights.clear();
    for (const auto& rule : rules) rule_weights.push_back(rule.value("weight", 1.0));
    
    // 加载DAO参数
    dao_voting_threshold = fuzzy.value("dao_voting_threshold", 0.6);
    dao_weight_update_rate = fuzzy.value("dao_weight_update_rate", 0.05);
    dao_consensus_threshold = fuzzy.value("dao_consensus_threshold", 0.75);
    
    // 加载Lyapunov势函数参数
    if (fuzzy.contains("lyapunov_params")) {
        const auto& lyap = fuzzy["lyapunov_params"];
        lyapunov_params.window_size = lyap.value("window_size", 50);
        lyapunov_params.stability_threshold = lyap.value("stability_threshold", 1e-4);
        lyapunov_params.potential_function_alpha = lyap.value("potential_function_alpha", 0.8);
        lyapunov_params.potential_function_beta = lyap.value("potential_function_beta", 0.2);
        lyapunov_params.convergence_tolerance = lyap.value("convergence_tolerance", 1e-6);
        lyapunov_params.max_iterations = lyap.value("max_iterations", 1000);
        lyapunov_params.gradient_step_size = lyap.value("gradient_step_size", 0.01);
        lyapunov_params.momentum_coefficient = lyap.value("momentum_coefficient", 0.9);
    }
    
    // 加载时间尺度参数
    if (fuzzy.contains("timescale_params")) {
        const auto& time = fuzzy["timescale_params"];
        timescale_params.fast_timescale_steps = time.value("fast_timescale_steps", 10);
        timescale_params.slow_timescale_steps = time.value("slow_timescale_steps", 100);
        timescale_params.fast_dt = time.value("fast_dt", 0.1);
        timescale_params.slow_dt = time.value("slow_dt", 1.0);
        timescale_params.separation_ratio = time.value("separation_ratio", 10.0);
    }
    
    // 加载预测调制参数
    if (fuzzy.contains("prediction_modulation")) {
        const auto& pred = fuzzy["prediction_modulation"];
        prediction_modulation.lambda_c = pred.value("lambda_c", 0.3);
        prediction_modulation.lambda_b = pred.value("lambda_b", 0.4);
        prediction_modulation.lambda_e = pred.value("lambda_e", 0.3);
        prediction_modulation.beta_softmin = pred.value("beta_softmin", 2.0);
        prediction_modulation.enable_prediction_adjustment = pred.value("enable_prediction_adjustment", true);
    }
    
    // 加载性能监控参数
    if (fuzzy.contains("performance_monitoring")) {
        const auto& perf = fuzzy["performance_monitoring"];
        performance_monitoring.enable_rule_frequency_tracking = perf.value("enable_rule_frequency_tracking", true);
        performance_monitoring.enable_strategy_entropy_calculation = perf.value("enable_strategy_entropy_calculation", true);
        performance_monitoring.enable_convergence_monitoring = perf.value("enable_convergence_monitoring", true);
        performance_monitoring.monitoring_window_size = perf.value("monitoring_window_size", 100);
    }
    
    // 初始化策略偏好（4个策略：SC、SP、DC、DP）
    strategy_preferences.resize(4, 0.25);
    
    // 初始化历史记录
    decision_history.clear();
    
    // 初始化时间计数器
    fast_time_counter = 0;
    slow_time_counter = 0;
}

// 注释掉重复的loadConfig方法，因为已经有接受json参数的版本
/*
void FuzzyInferenceEngine::loadConfig() {
    // 从 config.json 加载模糊推理相关参数
    std::ifstream config_file("config.json");
    if (config_file.is_open()) {
        nlohmann::json config;
        config_file >> config;
        
        auto fuzzy_config = config["FuzzyInferenceEngine"];
        
        // 用户定义/经验设定变量，配置于 config.json
        // 加载7个规则的权重
        auto rules_array = fuzzy_config["rules"];
        rule_weights.clear();
        for (const auto& rule : rules_array) {
            rule_weights.push_back(rule["weight"]);
        }
        
        dao_voting_threshold = fuzzy_config["dao_voting_threshold"];      // DAO投票阈值
        dao_weight_update_rate = fuzzy_config["dao_weight_update_rate"];  // DAO权重更新率
        lyapunov_window_size = fuzzy_config["lyapunov_window_size"];      // Lyapunov窗口大小
        convergence_tolerance = fuzzy_config["convergence_tolerance"];    // 收敛容忍度
        fast_timescale_steps = fuzzy_config["fast_timescale_steps"];      // 快时标步数
        slow_timescale_steps = fuzzy_config["slow_timescale_steps"];      // 慢时标步数
        
        config_file.close();
    } else {
        // 默认值作为备用
        rule_weights = {0.2, 0.15, 0.15, 0.15, 0.15, 0.1, 0.1}; // 7个规则的默认权重
        dao_voting_threshold = 0.6;
        dao_weight_update_rate = 0.05;
        lyapunov_window_size = 50;
        convergence_tolerance = 1e-6;
        fast_timescale_steps = 10;
        slow_timescale_steps = 100;
    }
    
    // 初始化历史记录
     decision_history.clear();
     
     // 初始化时间计数器
     fast_time_counter = 0;
     slow_time_counter = 0;
 }
*/

void FuzzyInferenceEngine::setInput(const std::vector<double>& z) {
    input_z = z;
}

std::vector<double> FuzzyInferenceEngine::infer() {
    if (input_z.empty()) {
        return {0.25, 0.25, 0.25, 0.25}; // 默认均匀分布
    }
    
    // 计算规则激活度
    std::vector<double> activations = computeRuleActivations(input_z);
    
    // 应用规则权重
    for (size_t i = 0; i < activations.size() && i < rule_weights.size(); ++i) {
        activations[i] *= rule_weights[i];
    }
    
    // 计算策略概率向量 π = [π_SC, π_SP, π_DC, π_DP]
    std::vector<double> strategy_probs(4, 0.0);
    
    // 根据第三章理论定义的R1-R7规则计算策略概率
    if (!activations.empty()) {
        // R1 (高信誉协同): π=[0.8, 0.1, 0.05, 0.05]
        strategy_probs[0] += activations[0] * 0.8;
        strategy_probs[1] += activations[0] * 0.1;
        strategy_probs[2] += activations[0] * 0.05;
        strategy_probs[3] += activations[0] * 0.05;
        
        // R2 (高信誉网络拥堵): π=[0.1, 0.7, 0.1, 0.1]
        strategy_probs[0] += activations[1] * 0.1;
        strategy_probs[1] += activations[1] * 0.7;
        strategy_probs[2] += activations[1] * 0.1;
        strategy_probs[3] += activations[1] * 0.1;
        
        // R3 (低信誉防御): π=[0.05, 0.05, 0.4, 0.5]
        strategy_probs[0] += activations[2] * 0.05;
        strategy_probs[1] += activations[2] * 0.05;
        strategy_probs[2] += activations[2] * 0.4;
        strategy_probs[3] += activations[2] * 0.5;
        
        // R4 (电量保护): π=[0.0, 0.0, 0.2, 0.8]
        strategy_probs[0] += activations[3] * 0.0;
        strategy_probs[1] += activations[3] * 0.0;
        strategy_probs[2] += activations[3] * 0.2;
        strategy_probs[3] += activations[3] * 0.8;
        
        // R5 (未来拥塞预警): π=[0.1, 0.3, 0.3, 0.3]
        strategy_probs[0] += activations[4] * 0.1;
        strategy_probs[1] += activations[4] * 0.3;
        strategy_probs[2] += activations[4] * 0.3;
        strategy_probs[3] += activations[4] * 0.3;
        
        // R6 (资源瓶颈高信誉): π=[0.2, 0.4, 0.2, 0.2]
        strategy_probs[0] += activations[5] * 0.2;
        strategy_probs[1] += activations[5] * 0.4;
        strategy_probs[2] += activations[5] * 0.2;
        strategy_probs[3] += activations[5] * 0.2;
        
        // R7 (信誉修复): π=[0.4, 0.3, 0.2, 0.1]
        strategy_probs[0] += activations[6] * 0.4;
        strategy_probs[1] += activations[6] * 0.3;
        strategy_probs[2] += activations[6] * 0.2;
        strategy_probs[3] += activations[6] * 0.1;
    }
    
    // 归一化策略概率
    double sum = std::accumulate(strategy_probs.begin(), strategy_probs.end(), 0.0);
    if (sum > 0) {
        for (double& prob : strategy_probs) {
            prob /= sum;
        }
    } else {
        // 如果所有激活度为0，返回均匀分布
        std::fill(strategy_probs.begin(), strategy_probs.end(), 0.25);
    }
    
    // 打印规则激活情况（用于调试和监控）
    logRuleActivations(activations, strategy_probs);
    
    return strategy_probs;
}

double FuzzyInferenceEngine::computeMembership(const std::string& var, double value, const json& params) const {
    std::string type = params.value("type", "gaussian");
    if (type == "gaussian") {
        double mean = params.value("mean", 0.5);
        double sigma = params.value("sigma", 0.1);
        return std::exp(-0.5 * std::pow((value - mean) / sigma, 2));
    } else if (type == "it2sigmoid") {
        double theta_lower = params.value("theta_lower", 0.45);
        double theta_upper = params.value("theta_upper", 0.55);
        double k_lower = params.value("k_lower", 8.0);
        double k_upper = params.value("k_upper", 12.0);
        double mu_l = 1.0 / (1.0 + std::exp(-k_lower * (value - theta_lower)));
        double mu_u = 1.0 / (1.0 + std::exp(-k_upper * (value - theta_upper)));
        return 0.5 * (mu_l + mu_u);
    } else if (type == "triangle") {
        double a = params.value("a", 0.0);
        double b = params.value("b", 0.5);
        double c = params.value("c", 1.0);
        if (value <= a || value >= c) return 0.0;
        if (value == b) return 1.0;
        if (value < b) return (value - a) / (b - a);
        return (c - value) / (c - b);
    }
    return 0.0;
}

double FuzzyInferenceEngine::defuzzify(const std::vector<double>& fuzzy_output) const {
    // 默认重心法
    double sum = std::accumulate(fuzzy_output.begin(), fuzzy_output.end(), 0.0);
    if (sum == 0) return 0.0;
    double centroid = 0.0;
    for (size_t i = 0; i < fuzzy_output.size(); ++i)
        centroid += i * fuzzy_output[i];
    return centroid / sum;
}

void FuzzyInferenceEngine::updateRuleWeights(const std::vector<double>& weights) {
    rule_weights = weights;
}

// 权重自适应更新机制 - 基于DAO投票
void FuzzyInferenceEngine::adaptWeightsDAO(const std::vector<double>& performance_gains) {
    // 简化版本，不依赖config结构
    double learning_rate = 0.05; // 默认学习率
    
    for (size_t k = 0; k < rule_weights.size() && k < performance_gains.size(); ++k) {
        // 使用Sigmoid映射绩效增益
        double sigma_delta = 1.0 / (1.0 + std::exp(-performance_gains[k]));
        // DAO投票权重更新公式: w_k^(t+1) = (1-η)w_k^(t) + η*σ(Δ_k)
        rule_weights[k] = (1.0 - learning_rate) * rule_weights[k] + learning_rate * sigma_delta;
        
        // 确保权重在合理范围内
        rule_weights[k] = std::max(0.1, std::min(1.0, rule_weights[k]));
    }
    
    // 归一化权重
    double sum = std::accumulate(rule_weights.begin(), rule_weights.end(), 0.0);
    if (sum > 0) {
        for (auto& w : rule_weights) {
            w /= sum;
        }
    }
}

void FuzzyInferenceEngine::recordDecisionQuality(double output) {
    // 记录决策质量，用于后续的权重优化
    // 这里可以基于实际的系统反馈来评估决策质量
    // 简化实现：基于输出值的合理性评估
    double quality = std::min(1.0, std::max(0.0, output));
    
    // 将质量评分添加到历史记录中
    if (!decision_history.empty()) {
        decision_history.back().second = quality;
    }
}

// 双时间尺度演化机制
void FuzzyInferenceEngine::dualTimescaleEvolution(double fast_time_ms, int slow_time_blocks) {
    auto dual_config = config["FuzzyInference"]["weight_adaptation"]["dual_timescale"];
    
    // 快时标（车辆层）- 毫秒级策略更新
    if (fast_time_ms >= dual_config["fast_timescale_ms"].get<double>()) {
        // 车辆复制动态更新
        updateVehicleStrategies();
    }
    
    // 慢时标（DAO层）- 区块级权重调整
    if (slow_time_blocks >= dual_config["slow_timescale_blocks"].get<int>()) {
        // DAO权重投票更新
        performDAOWeightUpdate();
    }
}

// Lyapunov势函数监控
double FuzzyInferenceEngine::computeLyapunovPotential(const std::vector<double>& strategy_dist) const {
    if (!config["FuzzyInference"]["lyapunov_monitoring"]["enabled"].get<bool>()) {
        return 0.0;
    }
    
    auto theta_values = config["FuzzyInference"]["lyapunov_monitoring"]["potential_function"]["theta_k_values"];
    
    double V = 0.0;
    
    // 策略分布势能: -Σ x_j* ln(x_j/x_j*)
    for (size_t j = 0; j < strategy_dist.size(); ++j) {
        if (strategy_dist[j] > 0) {
            double x_star = 0.25; // 均衡点假设为均匀分布
            V -= x_star * std::log(strategy_dist[j] / x_star);
        }
    }
    
    // 规则权重势能: Φ(w) = Σ θ_k ln(w_k)
    for (size_t k = 0; k < rule_weights.size() && k < theta_values.size(); ++k) {
        if (rule_weights[k] > 0) {
            V += theta_values[k].get<double>() * std::log(rule_weights[k]);
        }
    }
    
    return V;
}

// 检查系统收敛性
bool FuzzyInferenceEngine::checkConvergence(const std::vector<double>& current_potential) const {
    auto lyapunov_config = config["FuzzyInference"]["lyapunov_monitoring"];
    int window_size = lyapunov_config["potential_function"]["convergence_window"].get<int>();
    double threshold = lyapunov_config["potential_function"]["stability_threshold"].get<double>();
    
    if (current_potential.size() < window_size) {
        return false;
    }
    
    // 检查最近窗口内势函数的变化
    double max_change = 0.0;
    for (size_t i = current_potential.size() - window_size + 1; i < current_potential.size(); ++i) {
        double change = std::abs(current_potential[i] - current_potential[i-1]);
        max_change = std::max(max_change, change);
    }
    
    return max_change < threshold;
}

// 车辆策略更新（快时标）
void FuzzyInferenceEngine::updateVehicleStrategies() {
    // 实现复制动态: ẋ_j = x_j(U_j - Ū)
    // 这里简化为基于当前收益的策略调整
    double epsilon = config["FuzzyInference"]["weight_adaptation"]["dual_timescale"]["epsilon_greedy"].get<double>();
    
    // ε-贪心策略更新
    if (uniform_dist(rng) < epsilon) {
        // 探索：随机调整策略
        for (auto& pi : strategy_preferences) {
            pi += (uniform_dist(rng) - 0.5) * 0.1;
            pi = std::max(0.0, std::min(1.0, pi));
        }
    }
    // 否则利用当前最优策略
}

// DAO权重更新（慢时标）
void FuzzyInferenceEngine::performDAOWeightUpdate() {
    // 模拟DAO投票过程
    auto dao_config = config["FuzzyInference"]["weight_adaptation"]["dao_voting"];
    int min_votes = dao_config["min_votes_required"].get<int>();
    double rep_threshold = dao_config["reputation_threshold"].get<double>();
    
    // 计算规则绩效增益（基于系统指标）
    std::vector<double> performance_gains(rule_weights.size(), 0.0);
    
    // 这里应该基于实际的系统性能指标计算
    // 简化实现：基于规则使用频率和效果
    for (size_t k = 0; k < performance_gains.size(); ++k) {
        // 模拟绩效计算
        performance_gains[k] = (uniform_dist(rng) - 0.5) * 0.2;
    }
    
    // 执行权重自适应更新
    adaptWeightsDAO(performance_gains);
}

double FuzzyInferenceEngine::performFuzzyInference(const std::vector<double>& inputs) {
    // 基于DAO投票的自适应规则权重模糊推理
    // 调用完整的infer方法，包含R1-R7规则激活日志
    setInput(inputs);
    std::vector<double> strategy_probabilities = infer();
    
    // 计算加权输出（简化为策略概率的加权和）
    double weighted_output = 0.0;
    for (size_t i = 0; i < strategy_probabilities.size(); ++i) {
        weighted_output += (i + 1) * 0.25 * strategy_probabilities[i]; // 简单的加权方案
    }
    
    // 记录决策历史（用于权重优化）
    static double time_counter = 0.0;
    time_counter += 1.0; // 简化的时间计数器
    decision_history.push_back(std::make_pair(time_counter, 0.0));
    
    // 保持历史记录在合理大小
    if (decision_history.size() > 1000) {
        decision_history.erase(decision_history.begin());
    }
    
    // 记录决策质量（用于权重优化）
    recordDecisionQuality(weighted_output);
    
    // 定期执行权重优化
    static int inference_count = 0;
    inference_count++;
    if (inference_count % 50 == 0) {  // 每50次推理优化一次权重
        optimizeRuleWeights();
    }
    if (inference_count % 100 == 0) { // 每100次推理执行自适应调整
        adaptiveWeightAdjustment();
    }
    
    // 执行双时间尺度更新
    performDualTimescaleUpdate();
    
    return weighted_output;
}

std::vector<double> FuzzyInferenceEngine::computeRuleActivations(const std::vector<double>& inputs) {
    std::vector<double> activations(7, 0.0);
    
    if (inputs.size() < 7) {
        // 如果输入不足，返回默认激活度
        return activations;
    }
    
    // 提取输入变量: z = [mu_trust, mu_delay, mu_resource, rho, F_c, F_b, F_e]
    double mu_trust = inputs[0];    // 信任度隶属度
    double mu_delay = inputs[1];    // 延迟质量隶属度 
    double mu_resource = inputs[2]; // 资源可用性隶属度
    double rho = inputs[3];         // 紧迫-可靠耦合因子
    double F_c = inputs[4];         // CPU预测因子
    double F_b = inputs[5];         // 带宽预测因子
    double F_e = inputs[6];         // 能量预测因子
    
    // 计算高、中、低隶属度 - 调整阈值使其更容易激活
    auto computeHighMembership = [](double x) { 
        return x > 0.6 ? (x - 0.6) / 0.4 : 0.0; // 从0.6开始线性增长到1.0
    };
    auto computeMediumMembership = [](double x) { 
        return std::max(0.0, 1.0 - 2.0 * std::abs(x - 0.5)); // 保持不变，在0.5附近最大
    };
    auto computeLowMembership = [](double x) { 
        return x < 0.4 ? (0.4 - x) / 0.4 : 0.0; // 从0.4开始线性下降到0.0
    };
    
    // R1 (高信誉协同): IF μ_trust=High AND μ_delay=High AND μ_resource=High THEN π=[0.8, 0.1, 0.05, 0.05]
    double trust_high = computeHighMembership(mu_trust);
    double delay_high = computeHighMembership(mu_delay);
    double resource_high = computeHighMembership(mu_resource);
    activations[0] = std::min({trust_high, delay_high, resource_high});
    
    // R2 (高信誉网络拥堵): IF μ_trust=High AND μ_delay=Low THEN π=[0.1, 0.7, 0.1, 0.1]
    double delay_low = computeLowMembership(mu_delay);
    activations[1] = std::min(trust_high, delay_low);
    
    // R3 (低信誉防御): IF μ_trust=Low THEN π=[0.05, 0.05, 0.4, 0.5]
    double trust_low = computeLowMembership(mu_trust);
    activations[2] = trust_low;
    
    // R4 (电量保护): IF μ_resource=Low AND F_e=Low THEN π=[0.0, 0.0, 0.2, 0.8]
    double resource_low = computeLowMembership(mu_resource);
    double energy_low = F_e < 0.3 ? (1.0 - F_e) : 0.0;
    activations[3] = std::min(resource_low, energy_low);
    
    // R5 (未来拥塞预警): IF F_c=High OR F_b=High THEN π=[0.1, 0.3, 0.3, 0.3]
    double cpu_high = F_c > 0.7 ? F_c : 0.0;
    double bandwidth_high = F_b > 0.7 ? F_b : 0.0;
    activations[4] = std::max(cpu_high, bandwidth_high);
    
    // R6 (资源瓶颈高信誉): IF μ_resource=Low AND μ_trust=High THEN π=[0.2, 0.4, 0.2, 0.2]
    activations[5] = std::min(resource_low, trust_high);
    
    // R7 (信誉修复): IF μ_delay=High AND μ_trust=Low THEN π=[0.4, 0.3, 0.2, 0.1]
    activations[6] = std::min(delay_high, trust_low);
    
    return activations;
}

double FuzzyInferenceEngine::computeTrustVariance() {
    // 计算信任度变化方差
    if (decision_history.size() < 2) return 0.0;
    
    // 动态生成变量 - 计算最近几次决策的信任度方差
    std::vector<double> recent_trust; // 动态生成变量
    size_t window = std::min(decision_history.size(), static_cast<size_t>(10));
    
    for (size_t i = decision_history.size() - window; i < decision_history.size(); ++i) {
        // 使用决策质量作为信任度指标
        recent_trust.push_back(decision_history[i].second); // 动态生成变量
    }
    
    if (recent_trust.size() < 2) return 0.0;
    
    // 动态生成变量 - 计算方差
    double mean = 0.0; // 动态生成变量
    for (double t : recent_trust) {
        mean += t;
    }
    mean /= recent_trust.size();
    
    double variance = 0.0; // 动态生成变量
    for (double t : recent_trust) {
        variance += (t - mean) * (t - mean); // 动态生成变量
    }
    variance /= recent_trust.size();
    
    return variance;
}

double FuzzyInferenceEngine::computeUrgencyLevel(const std::vector<double>& inputs) {
    // 计算紧急程度
    if (inputs.size() < 3) return 0.0;
    
    // 动态生成变量 - 基于多个因素计算紧急程度
    double trust_urgency = (inputs[0] < 0.3) ? (0.3 - inputs[0]) / 0.3 : 0.0; // 动态生成变量
    double qos_urgency = (inputs[1] < 0.4) ? (0.4 - inputs[1]) / 0.4 : 0.0;   // 动态生成变量
    double resource_urgency = (inputs[2] < 0.2) ? (0.2 - inputs[2]) / 0.2 : 0.0; // 动态生成变量
    
    // 动态生成变量 - 综合紧急程度
    double urgency = std::max({trust_urgency, qos_urgency, resource_urgency}); // 动态生成变量
    
    return std::min(1.0, urgency);
}

void FuzzyInferenceEngine::performDualTimescaleUpdate() {
    // 双时间尺度演化更新
    fast_time_counter++;
    
    // 快时标更新（每次推理都执行）
    if (fast_time_counter >= timescale_params.fast_timescale_steps) {
        // 执行快时标权重微调
        performFastTimescaleUpdate();
        fast_time_counter = 0;
        slow_time_counter++;
    }
    
    // 慢时标更新（基于DAO投票）
    if (slow_time_counter >= timescale_params.slow_timescale_steps) {
        // 执行慢时标DAO权重更新
        performSlowTimescaleUpdate();
        slow_time_counter = 0;
    }
}

void FuzzyInferenceEngine::performFastTimescaleUpdate() {
    // 快时标权重微调（基于最近性能）
    if (decision_history.size() < 2) return;
    
    // 动态生成变量 - 计算最近性能趋势
    double recent_performance = 0.0; // 动态生成变量
    size_t window = std::min(decision_history.size(), static_cast<size_t>(5));
    
    for (size_t i = decision_history.size() - window; i < decision_history.size(); ++i) {
        recent_performance += decision_history[i].second; // 动态生成变量
    }
    recent_performance /= window;
    
    // 动态生成变量 - 基于性能进行微调
    double adjustment_factor = (recent_performance - 0.5) * dao_weight_update_rate; // 动态生成变量
    
    for (size_t i = 0; i < rule_weights.size(); ++i) {
        // 动态生成变量 - 权重微调
        rule_weights[i] += adjustment_factor * (1.0 / rule_weights.size()); // 动态生成变量
        rule_weights[i] = std::max(0.01, std::min(0.99, rule_weights[i])); // 动态生成变量 - 限制范围
    }
    
    // 归一化权重
    normalizeWeights();
}

void FuzzyInferenceEngine::performSlowTimescaleUpdate() {
    // 慢时标DAO投票权重更新
    
    // 动态生成变量 - 模拟DAO投票过程
    std::vector<double> vote_scores(rule_weights.size(), 0.0); // 动态生成变量
    
    // 基于历史性能计算投票分数
    for (size_t i = 0; i < rule_weights.size(); ++i) {
        // 动态生成变量 - 计算规则i的历史贡献
        double rule_contribution = computeRuleContribution(i); // 动态生成变量
        vote_scores[i] = rule_contribution;
    }
    
    // 动态生成变量 - 基于投票结果更新权重
    for (size_t i = 0; i < rule_weights.size(); ++i) {
        if (vote_scores[i] > dao_voting_threshold) {
            // 投票通过，增加权重
            rule_weights[i] += dao_weight_update_rate; // 动态生成变量
        } else {
            // 投票未通过，减少权重
            rule_weights[i] -= dao_weight_update_rate * 0.5; // 动态生成变量
        }
        rule_weights[i] = std::max(0.01, std::min(0.99, rule_weights[i])); // 动态生成变量
    }
    
    // 归一化权重
    normalizeWeights();
}

double FuzzyInferenceEngine::computeRuleContribution(size_t rule_index) {
    // 计算规则的历史贡献度
    if (decision_history.empty() || rule_index >= rule_weights.size()) {
        return 0.0;
    }
    
    // 动态生成变量 - 增强的贡献度计算
    double base_contribution = rule_weights[rule_index]; // 动态生成变量 - 基于当前权重
    double performance_factor = 1.0; // 动态生成变量 - 性能因子
    double frequency_factor = 1.0; // 动态生成变量 - 使用频率因子
    
    // 计算规则使用频率
    int rule_usage_count = 0;
    for (const auto& decision : decision_history) {
        // 简化判断：如果决策输出与该规则相关则计数
        if (decision.second > 0.1) { // 阈值判断
            rule_usage_count++;
        }
    }
    
    if (!decision_history.empty()) {
        frequency_factor = static_cast<double>(rule_usage_count) / decision_history.size();
    }
    
    // 添加基于历史性能的调整
    if (decision_history.size() > 10) {
        // 动态生成变量 - 计算最近决策的平均质量
        double avg_quality = 0.0; // 动态生成变量
        size_t window_size = std::min(static_cast<size_t>(20), decision_history.size());
        
        for (size_t i = decision_history.size() - window_size; i < decision_history.size(); ++i) {
            avg_quality += decision_history[i].second; // 动态生成变量
        }
        avg_quality /= window_size;
        
        // 性能因子基于质量和频率的综合评估
        performance_factor = 0.7 * avg_quality + 0.3 * frequency_factor;
    }
    
    // 综合贡献度计算
    double contribution = base_contribution * performance_factor * (1.0 + frequency_factor * 0.2);
    
    return std::min(1.0, std::max(0.01, contribution)); // 确保在合理范围内
}

void FuzzyInferenceEngine::normalizeWeights() {
    // 归一化规则权重
    double sum = 0.0; // 动态生成变量
    for (double w : rule_weights) {
        sum += w;
    }
    
    if (sum > 0) {
        for (double& w : rule_weights) {
            w /= sum; // 动态生成变量
        }
    }
}

// ==================== 规则权重优化算法 ====================

void FuzzyInferenceEngine::optimizeRuleWeights() {
    // 基于历史性能数据动态调整规则权重
    if (decision_history.size() < 10) {
        return; // 数据不足，不进行优化
    }
    
    std::vector<double> new_weights(rule_weights.size());
    double total_contribution = 0.0;
    
    // 计算每个规则的贡献度
    for (size_t i = 0; i < rule_weights.size(); ++i) {
        double contribution = computeRuleContribution(i);
        new_weights[i] = contribution;
        total_contribution += contribution;
    }
    
    // 归一化并应用调整率
    double adjustment_rate = 0.1; // 调整率，避免过度震荡
    if (total_contribution > 0) {
        for (size_t i = 0; i < rule_weights.size(); ++i) {
            double normalized_contribution = new_weights[i] / total_contribution;
            // 渐进式调整，避免剧烈变化
            rule_weights[i] = (1.0 - adjustment_rate) * rule_weights[i] + 
                             adjustment_rate * normalized_contribution;
        }
    }
    
    // 确保权重在合理范围内
    normalizeWeights();
    
    // 记录权重调整历史
    recordWeightAdjustment();
}

void FuzzyInferenceEngine::recordWeightAdjustment() {
    // 记录权重调整历史，用于分析和调试
    static std::vector<std::vector<double>> weight_history;
    weight_history.push_back(rule_weights);
    
    // 保持历史记录在合理大小
    if (weight_history.size() > 100) {
        weight_history.erase(weight_history.begin());
    }
}

double FuzzyInferenceEngine::calculateRulePerformanceScore(size_t rule_index) {
    // 计算规则的综合性能评分
    if (rule_index >= rule_weights.size() || decision_history.empty()) {
        return 0.5; // 默认中等评分
    }
    
    double accuracy_score = 0.0;
    double stability_score = 0.0;
    double efficiency_score = 0.0;
    
    // 计算准确性评分（基于决策质量）
    if (decision_history.size() >= 5) {
        double quality_sum = 0.0;
        int relevant_decisions = 0;
        
        for (const auto& decision : decision_history) {
            if (decision.second > 0.1) { // 该规则参与的决策
                quality_sum += decision.second;
                relevant_decisions++;
            }
        }
        
        if (relevant_decisions > 0) {
            accuracy_score = quality_sum / relevant_decisions;
        }
    }
    
    // 计算稳定性评分（基于权重变化的稳定性）
    stability_score = 1.0 - std::abs(rule_weights[rule_index] - 1.0/rule_weights.size());
    
    // 计算效率评分（基于使用频率和效果的比值）
    double usage_frequency = computeRuleUsageFrequency(rule_index);
    efficiency_score = (accuracy_score > 0) ? accuracy_score * usage_frequency : 0.0;
    
    // 综合评分
    return 0.5 * accuracy_score + 0.3 * stability_score + 0.2 * efficiency_score;
}

double FuzzyInferenceEngine::computeRuleUsageFrequency(size_t rule_index) {
    // 计算规则的使用频率
    if (decision_history.empty()) {
        return 0.0;
    }
    
    int usage_count = 0;
    for (const auto& decision : decision_history) {
        // 简化判断：基于决策输出判断规则是否被使用
        if (decision.second > 0.1) {
            usage_count++;
        }
    }
    
    return static_cast<double>(usage_count) / decision_history.size();
}

void FuzzyInferenceEngine::adaptiveWeightAdjustment() {
    // 自适应权重调整机制
    if (decision_history.size() < 20) {
        return; // 需要足够的历史数据
    }
    
    // 计算系统整体性能趋势
    double recent_performance = calculateRecentPerformance();
    double historical_performance = calculateHistoricalPerformance();
    
    // 如果性能下降，增加调整强度
    double performance_ratio = recent_performance / std::max(historical_performance, 0.1);
    double adjustment_intensity = 0.05; // 基础调整强度
    
    if (performance_ratio < 0.9) {
        // 性能下降，增加调整强度
        adjustment_intensity = 0.15;
    } else if (performance_ratio > 1.1) {
        // 性能提升，减少调整强度以保持稳定
        adjustment_intensity = 0.02;
    }
    
    // 基于性能评分调整权重
    std::vector<double> performance_scores(rule_weights.size());
    double total_score = 0.0;
    
    for (size_t i = 0; i < rule_weights.size(); ++i) {
        performance_scores[i] = calculateRulePerformanceScore(i);
        total_score += performance_scores[i];
    }
    
    // 应用自适应调整
    if (total_score > 0) {
        for (size_t i = 0; i < rule_weights.size(); ++i) {
            double target_weight = performance_scores[i] / total_score;
            rule_weights[i] = (1.0 - adjustment_intensity) * rule_weights[i] + 
                             adjustment_intensity * target_weight;
        }
    }
    
    normalizeWeights();
}

double FuzzyInferenceEngine::calculateRecentPerformance() {
    // 计算最近的性能表现
    if (decision_history.size() < 10) {
        return 0.5; // 默认值
    }
    
    size_t window_size = std::min(static_cast<size_t>(10), decision_history.size());
    double performance_sum = 0.0;
    
    for (size_t i = decision_history.size() - window_size; i < decision_history.size(); ++i) {
        performance_sum += decision_history[i].second;
    }
    
    return performance_sum / window_size;
}

double FuzzyInferenceEngine::calculateHistoricalPerformance() {
    // 计算历史平均性能
    if (decision_history.empty()) {
        return 0.5; // 默认值
    }
    
    double performance_sum = 0.0;
    for (const auto& decision : decision_history) {
        performance_sum += decision.second;
    }
    
    return performance_sum / decision_history.size();
}

void FuzzyInferenceEngine::logInference(const std::string& filename) {
    // 可选：输出输入、规则匹配、pi 到文件
    if (filename.empty()) return;
    std::ofstream ofs(filename, std::ios::app);
    ofs << "input_z:";
    for (auto v : input_z) ofs << v << ",";
    ofs << "\n";
    
    // 添加权重信息到日志
    ofs << "rule_weights:";
    for (auto w : rule_weights) ofs << w << ",";
    ofs << "\n";
}

void FuzzyInferenceEngine::logRuleActivations(const std::vector<double>& activations, const std::vector<double>& strategy_probs) {
    // 记录规则激活情况和策略概率分布
    static int log_counter = 0;
    log_counter++;
    
    // 每次都记录详细日志，便于观察规则激活情况
    if (log_counter % 1 == 0) {
        // 显示输入值以便调试
        if (!input_z.empty() && input_z.size() >= 7) {
            EV << "[模糊推理引擎] 输入向量: "
               << "μ_trust=" << std::fixed << std::setprecision(3) << input_z[0]
               << ", μ_delay=" << input_z[1] 
               << ", μ_resource=" << input_z[2]
               << ", ρ=" << input_z[3]
               << ", F_c=" << input_z[4]
               << ", F_b=" << input_z[5] 
               << ", F_e=" << input_z[6] << std::endl;
        }
        
        // 使用EV输出，与FuzzyTrustApp的日志格式保持一致
        EV << "[模糊推理引擎] R1-R7规则激活度: ";
        for (size_t i = 0; i < activations.size(); ++i) {
            if (activations[i] > 0.001) { // 只显示有意义的激活度
                EV << "R" << (i+1) << "=" << std::fixed << std::setprecision(3) << activations[i] << " ";
            }
        }
        EV << std::endl;
        
        EV << "[模糊推理引擎] 策略概率分布: ";
        EV << "SC=" << std::fixed << std::setprecision(3) << strategy_probs[0] << ", ";
        EV << "SP=" << strategy_probs[1] << ", ";
        EV << "DC=" << strategy_probs[2] << ", ";
        EV << "DP=" << strategy_probs[3] << std::endl;
        
        // 显示主要激活的规则
        double max_activation = *std::max_element(activations.begin(), activations.end());
        if (max_activation > 0.001) {
            auto max_it = std::max_element(activations.begin(), activations.end());
            size_t max_rule = std::distance(activations.begin(), max_it);
            EV << "[模糊推理引擎] 主导规则: R" << (max_rule + 1) 
               << " (激活度=" << std::fixed << std::setprecision(3) << max_activation << ")" << std::endl;
        }
        
        // 详细显示每个规则的激活情况
        EV << "[模糊推理引擎] 详细规则激活: ";
        for (size_t i = 0; i < activations.size() && i < 7; ++i) {
            EV << "R" << (i+1) << "(" << std::fixed << std::setprecision(4) << activations[i] << ") ";
        }
        EV << std::endl;
    }
}

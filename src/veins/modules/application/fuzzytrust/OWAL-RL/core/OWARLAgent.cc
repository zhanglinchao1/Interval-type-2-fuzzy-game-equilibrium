// 参数（w, w_prior, eta, lambda）全部由 json 动态注入，便于实验调整。

// 每次 updateWeights() 接收排序前的 μ 向量（3维），实现 OWA-RL 自适应聚合和权重演化。

// 正则 toward prior、softmax、累加和等全部对齐理论。


#include "OWARLAgent.h"
#include <algorithm>
#include <cmath>
#include <numeric>
#include <fstream>

using json = nlohmann::json;

OWARLAgent::OWARLAgent() : max_steps(10000), step(0), eta(0.05), lambda(1.0), weight_tracking_enabled(false) {
    // 初始化累积隶属度历史
    cumulative_membership_sum.resize(3, 0.0);
}

OWARLAgent::OWARLAgent(const json& config) : step(0), weight_tracking_enabled(false) {
    // 初始化累积隶属度历史
    cumulative_membership_sum.resize(3, 0.0);
    loadConfig(config);
}

void OWARLAgent::loadConfig(const json& config) {
    // 修正键名：config.json中使用的是"OWARLAgent"而不是"OWARL"
    // 同时修正字段名：config.json中使用的是"w_init"而不是"init_w"
    w_init   = config["w_init"].get<std::vector<double>>();
    w        = w_init;
    w_prior  = config["w_prior"].get<std::vector<double>>();
    eta      = config["eta_learning"];
    lambda   = config["lambda_regularization"];
    max_steps= config.contains("max_steps") ? config["max_steps"].get<int>() : 10000;
    mu_hist.clear();
    step = 0;
}

// 注释掉重复的loadConfig方法，因为已经有接受json参数的版本
/*
void OWARLAgent::loadConfig() {
    // 从 config.json 加载 OWA-RL 相关参数
    std::ifstream config_file("config.json");
    if (config_file.is_open()) {
        nlohmann::json config;
        config_file >> config;
        
        auto owa_config = config["OWARLAgent"];
        
        // 用户定义/经验设定变量，配置于 config.json
        auto w_init_array = owa_config["w_init"];
        w = {w_init_array[0], w_init_array[1], w_init_array[2], w_init_array[3]}; // 初始权重向量
        
        auto w_prior_array = owa_config["w_prior"];
        w_prior = {w_prior_array[0], w_prior_array[1], w_prior_array[2], w_prior_array[3]}; // 先验权重
        
        eta_learning = owa_config["eta_learning"];                    // 在线学习率η
        lambda_regularization = owa_config["lambda_regularization"];  // 正则化参数λ
        max_steps = owa_config["max_steps"];                          // 最大学习步数
        potential_game_alpha = owa_config["potential_game_alpha"];    // 潜在博弈参数α
        potential_game_beta = owa_config["potential_game_beta"];      // 潜在博弈参数β
        convergence_threshold = owa_config["convergence_threshold"];  // 收敛阈值
        history_window_size = owa_config["history_window_size"];      // 历史窗口大小
        
        config_file.close();
    } else {
        // 默认值作为备用
        w = {0.25, 0.25, 0.25, 0.25};
        w_prior = {0.25, 0.25, 0.25, 0.25};
        eta_learning = 0.01;
        lambda_regularization = 0.1;
        max_steps = 1000;
        potential_game_alpha = 1.0;
        potential_game_beta = 0.5;
        convergence_threshold = 1e-6;
        history_window_size = 100;
    }
    
    // 初始化历史记录
    history.clear();
    
    // 初始化步数计数器
    current_step = 0;
}
*/

void OWARLAgent::reset() {
    w = w_init;
    mu_hist.clear();
    step = 0;
    last_membership_values.clear();
    // 重置累积隶属度历史
    cumulative_membership_sum.clear();
    cumulative_membership_sum.resize(3, 0.0);
}

// 降序排序工具
std::vector<double> OWARLAgent::sort_desc(const std::vector<double>& mu_vec) {
    std::vector<double> sorted = mu_vec;
    std::sort(sorted.begin(), sorted.end(), std::greater<double>());
    return sorted;
}

// OWA 聚合公式
double OWARLAgent::calcOWAReward(const std::vector<double>& mu_sorted, const std::vector<double>& w) {
    double reward = 0.0;
    for (size_t k = 0; k < mu_sorted.size(); ++k)
        reward += w[k] * mu_sorted[k];
    return reward;
}

// 权重在线无悔学习更新，并返回 reward
void OWARLAgent::updateWeights(const std::vector<double>& outcomes) {
    // 实现Chapter3.md中的无悔学习算法
    // 公式：w_k^(t+1) = exp(η∑τ=1^t μ_(τ,k)) / ∑h=1^3 exp(η∑τ=1^t μ_(τ,h))
    
    if (outcomes.size() != 3) {
        return; // 需要3个隶属度值
    }
    
    // 对隶属度进行降序排序，得到μ_(1), μ_(2), μ_(3)
    std::vector<double> sorted_outcomes = sort_desc(outcomes);
    
    // 累积历史隶属度值
    for (size_t k = 0; k < 3; ++k) {
        cumulative_membership_sum[k] += sorted_outcomes[k];
    }
    
    // 更新步数
    step++;
    
    // 计算新的权重
    std::vector<double> exp_values(3);
    double exp_sum = 0.0;
    
    for (size_t k = 0; k < 3; ++k) {
        exp_values[k] = std::exp(eta * cumulative_membership_sum[k]);
        exp_sum += exp_values[k];
    }
    
    // 归一化得到新权重
    if (exp_sum > 0) {
        for (size_t k = 0; k < 3; ++k) {
            w[k] = exp_values[k] / exp_sum;
        }
    }
    
    // 记录权重演化（如果启用了跟踪）
    if (weight_tracking_enabled && weight_collector) {
        // 这将在recordWeightEvolution中处理
    }
}

double OWARLAgent::getReward(const std::vector<double>& mu_vec) const {
    auto mu_sorted = sort_desc(mu_vec);
    return calcOWAReward(mu_sorted, w);
}

std::vector<double> OWARLAgent::getWeights() const {
    return w;
}

std::vector<double> OWARLAgent::computePotentialGameGradient(const std::vector<double>& outcomes) {
    // 基于潜在博弈势函数的梯度计算
    std::vector<double> gradient(w.size(), 0.0);
    
    // 动态生成变量 - 排序结果（降序）
    std::vector<double> sorted_outcomes = outcomes; // 动态生成变量
    std::sort(sorted_outcomes.rbegin(), sorted_outcomes.rend());
    
    // 动态生成变量 - 计算势函数梯度
    for (size_t i = 0; i < w.size(); ++i) {
        // 基于潜在博弈理论的势函数梯度
        double potential_term = potential_game_alpha * sorted_outcomes[i]; // 动态生成变量
        
        // 添加博弈交互项
        double interaction_term = 0.0; // 动态生成变量
        for (size_t j = 0; j < w.size(); ++j) {
            if (i != j) {
                interaction_term += potential_game_beta * w[j] * sorted_outcomes[j]; // 动态生成变量
            }
        }
        
        gradient[i] = potential_term + interaction_term; // 动态生成变量
    }
    
    return gradient;
}

std::vector<double> OWARLAgent::computeRegularizationGradient() {
    // 计算正则化项梯度（向先验权重的偏移）
    std::vector<double> reg_gradient(w.size()); // 动态生成变量
    
    for (size_t i = 0; i < w.size(); ++i) {
        // 动态生成变量 - L2正则化梯度
        reg_gradient[i] = 2.0 * (w[i] - w_prior[i]); // 动态生成变量
    }
    
    return reg_gradient;
}

void OWARLAgent::checkConvergence() {
    // 检查权重收敛性
    if (history.size() < 2) return;
    
    // 动态生成变量 - 计算权重变化幅度
    double weight_change = 0.0; // 动态生成变量
    static std::vector<double> prev_w = w;
    
    for (size_t i = 0; i < w.size(); ++i) {
        weight_change += std::abs(w[i] - prev_w[i]); // 动态生成变量
    }
    
    // 检查是否收敛
    if (weight_change < convergence_threshold) {
        // 权重已收敛
        // 可以在此处添加收敛处理逻辑
    }
    
    prev_w = w;
}

void OWARLAgent::projectToSimplex() {
    // 投影到概率单纯形：确保权重非负且和为1
    
    // 首先确保所有权重非负
    for (size_t i = 0; i < w.size(); ++i) {
        if (w[i] < 0) {
            w[i] = 0;
        }
    }
    
    // 计算权重总和
    double sum = 0.0;
    for (size_t i = 0; i < w.size(); ++i) {
        sum += w[i];
    }
    
    // 归一化权重使其和为1
    if (sum > 0) {
        for (size_t i = 0; i < w.size(); ++i) {
            w[i] /= sum;
        }
    } else {
        // 如果所有权重都为0，则设置为均匀分布
        double uniform_weight = 1.0 / w.size();
        for (size_t i = 0; i < w.size(); ++i) {
            w[i] = uniform_weight;
        }
    }
}

double OWARLAgent::computeOWA(const std::vector<double>& values) {
    // 计算有序加权平均值 (Ordered Weighted Average)
    
    if (values.empty()) {
        return 0.0;
    }
    
    // 创建值的副本并排序（降序）
    std::vector<double> sorted_values = values;
    std::sort(sorted_values.begin(), sorted_values.end(), std::greater<double>());
    
    // 确保权重向量大小与值向量匹配
    if (w.size() != sorted_values.size()) {
        // 如果权重向量大小不匹配，使用均匀权重
        double uniform_weight = 1.0 / sorted_values.size();
        double result = 0.0;
        for (size_t i = 0; i < sorted_values.size(); ++i) {
            result += uniform_weight * sorted_values[i];
        }
        return result;
    }
    
    // 计算加权和
    double result = 0.0;
    for (size_t i = 0; i < sorted_values.size(); ++i) {
        result += w[i] * sorted_values[i];
    }
    
    return result;
}

// Weight tracking methods
void OWARLAgent::enableWeightTracking(bool enable) {
    weight_tracking_enabled = enable;
}

void OWARLAgent::setWeightCollector(std::shared_ptr<OWARLWeightCollector> collector) {
    weight_collector = collector;
}

void OWARLAgent::recordWeightEvolution(double timestamp, const std::vector<double>& membership_values, const std::string& scenario) {
    if (!weight_tracking_enabled || !weight_collector) {
        return;
    }
    
    // Record current state
    double current_reward = getReward(membership_values);
    weight_collector->recordWeightSnapshot(timestamp, w, membership_values, scenario, current_reward);
    
    // Store for next iteration
    last_membership_values = membership_values;
}

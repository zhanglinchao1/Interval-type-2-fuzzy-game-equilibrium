#include "ChannelQuality.h"
#include <cmath>
#include <algorithm>
#include <fstream>
#include "json.hpp"

ChannelQuality::ChannelQuality() {
    // 从配置文件加载参数
    loadConfig();
}

// 无参数的loadConfig方法实现
void ChannelQuality::loadConfig() {
    // 默认参数设置
    gamma = 2.0;
    sigma = 0.5;
    j1_base = 10.0;
    j2_base = 50.0;
    l1_base = 0.01;
    l2_base = 0.1;
    rho_shrink_coeff = 0.3;
    beta_t = 0.4;
    beta_j = 0.3;
    beta_l = 0.3;
    lambda = 0.7;
}

// 添加接收JSON参数的loadConfig方法
void ChannelQuality::loadConfig(const nlohmann::json& config) {
    // 修正：传入的config参数已经是ChannelQuality的配置对象，不需要再次使用键名访问
    
    // 用户定义/经验设定变量，配置于 config.json
    gamma = config["gamma"];                    
    sigma = config["sigma"];                    
    j1_base = config["j1_base"];               
    j2_base = config["j2_base"];               
    l1_base = config["l1_base"];               
    l2_base = config["l2_base"];               
    rho_shrink_coeff = config["rho_shrink_coeff"]; 
    beta_t = config["beta_t"];                 
    beta_j = config["beta_j"];                 
    beta_l = config["beta_l"];                 
    
    // 归一化权重检查
    double sum = beta_t + beta_j + beta_l;
    if (std::abs(sum - 1.0) > 1e-6) {
        beta_t /= sum;
        beta_j /= sum;
        beta_l /= sum;
    }
}

// 指数平滑
double ChannelQuality::expSmooth(double prev, double curr) {
    return lambda * curr + (1 - lambda) * prev;
}

double ChannelQuality::computeDelayMembership(double delay, double rho) {
    // 时延隶属度计算 - 基于紧迫-可靠耦合的自适应高斯函数
    if (delay <= 0) return 1.0;
    
    // 动态生成变量 - 基于ρ的自适应阈值收缩
    double adaptive_threshold = 120.0 * (1.0 - rho_shrink_coeff * rho); // 动态生成变量
    double normalized_delay = delay / adaptive_threshold; // 动态生成变量
    
    // 紧迫度放大机制：γ * (1 + ρ)
    double urgency_factor = gamma * (1.0 + rho); // 动态生成变量
    
    return exp(-urgency_factor * normalized_delay * normalized_delay);
}

double ChannelQuality::computeJitterMembership(double jitter, double rho) {
    // 抖动隶属度计算 - 基于ρ的自适应梯形函数收缩
    
    // 动态生成变量 - 基于ρ的阈值自适应收缩
    double j1_adaptive = j1_base * (1.0 - sigma * rho); // 动态生成变量
    double j2_adaptive = j2_base * (1.0 - sigma * rho); // 动态生成变量
    
    if (jitter <= j1_adaptive) {
        return 1.0;
    } else if (jitter >= j2_adaptive) {
        return 0.0;
    } else {
        return (j2_adaptive - jitter) / (j2_adaptive - j1_adaptive);
    }
}

double ChannelQuality::computePacketLossMembership(double loss_rate, double rho) {
    // 丢包率隶属度计算 - 基于ρ的自适应梯形函数收缩
    
    // 动态生成变量 - 基于ρ的阈值自适应收缩
    double l1_adaptive = l1_base * (1.0 - sigma * rho); // 动态生成变量
    double l2_adaptive = l2_base * (1.0 - sigma * rho); // 动态生成变量
    
    if (loss_rate <= l1_adaptive) {
        return 1.0;
    } else if (loss_rate >= l2_adaptive) {
        return 0.0;
    } else {
        return (l2_adaptive - loss_rate) / (l2_adaptive - l1_adaptive);
    }
}

// 4. 加权聚合
double ChannelQuality::aggregateMembership(double mu_t, double mu_j, double mu_l) {
    double sum_beta = beta_t + beta_j + beta_l;
    // 保证权重归一
    if (sum_beta == 0) return 0;
    return std::pow(
        std::pow(mu_t, beta_t) *
        std::pow(mu_j, beta_j) *
        std::pow(mu_l, beta_l),
        1.0 / sum_beta
    );
}

double ChannelQuality::computeQoS(double delay, double jitter, double loss_rate, double rho) {
    // 综合QoS评估 - 基于紧迫-可靠耦合的自适应隶属函数
    
    // 动态生成变量 - 基于ρ的自适应隶属度计算
    double mu_t = computeDelayMembership(delay, rho);      // 动态生成变量
    double mu_j = computeJitterMembership(jitter, rho);    // 动态生成变量
    double mu_l = computePacketLossMembership(loss_rate, rho); // 动态生成变量
    
    // 加权聚合 - 用户定义/经验设定变量，配置于 config.json
    double qos_score = beta_t * mu_t + beta_j * mu_j + beta_l * mu_l; // 动态生成变量
    
    return qos_score;
}

double ChannelQuality::computeUrgencyReliabilityCoupling(double trust_level, double resource_availability) {
    // 计算紧迫-可靠耦合因子ρ
    // ρ = f(信任度, 资源可用性) ∈ [0,1]
    
    // 动态生成变量 - 基于信任度和资源可用性的耦合计算
    double rho = 0.5 * (1.0 - trust_level) + 0.5 * (1.0 - resource_availability); // 动态生成变量
    
    // 确保ρ在[0,1]范围内
    rho = std::max(0.0, std::min(1.0, rho)); // 动态生成变量
    
    return rho;
}

void ChannelQuality::updateHistory(double delay, double jitter, double loss_rate) {
    // 更新历史记录用于指数平滑
    // 这里可以实现历史数据的管理和指数平滑
    
    // 简单的指数平滑实现
    static double prev_delay = delay;
    static double prev_jitter = jitter;
    static double prev_loss = loss_rate;
    
    double lambda = 0.8; // 用户定义/经验设定变量，配置于 config.json
    prev_delay = lambda * delay + (1 - lambda) * prev_delay;
    prev_jitter = lambda * jitter + (1 - lambda) * prev_jitter;
    prev_loss = lambda * loss_rate + (1 - lambda) * prev_loss;
}

// 构造时 传入 json 配置对象即可自动初始化所有参数。

// 外部流程 每次调 expSmooth 进行平滑处理，调单指标隶属度，再 aggregateMembership 得 $\mu_{\text{delay}}$。

// $\rho$ 作为接口参数传入，便于主流程按任务类型调整。


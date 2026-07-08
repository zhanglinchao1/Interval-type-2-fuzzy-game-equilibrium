#include "ResourceManager.h"
#include <algorithm>
#include <cmath>
#include <fstream>

using json = nlohmann::json;

ResourceManager::ResourceManager() : lambda_c(0.7), lambda_b(0.15), lambda_e(0.15), eta(0.8), phi(0.9), choquet_enabled(true), prediction_window(5), mu_c_kappa(10.0), mu_c_theta(0.6), mu_b_kappa(9.0), mu_b_theta(0.4), mu_e_min(0.1), mu_e_mid(0.5), mu_e_max(1.0) {}

ResourceManager::ResourceManager(const json& config) {
    loadConfig(config);
}

void ResourceManager::loadConfig(const nlohmann::json& config) {
    // 修正：传入的config参数已经是ResourceManager的配置对象，不需要再次使用键名访问
    
    // 用户定义/经验设定变量，配置于 config.json
    mu_c_kappa = config["kappa_c"];           // CPU陡峭度
    mu_b_kappa = config["kappa_b"];           // 带宽陡峭度
    lambda_c = config["lambda_c"];            // CPU预测权重
    lambda_b = config["lambda_b"];            // 带宽预测权重
    lambda_e = config["lambda_e"];            // 能量敏感度
    mu_c_theta = config["theta_c"];           // CPU利用率拐点
    mu_b_theta = config["theta_b"];           // 带宽拐点
    eta = config["eta"];                      // 任务弹性系数
    prediction_window = config["prediction_window_k"]; // 预测时间窗口k秒
    mu_e_min = config["e_min"];               // 能量隶属函数参数
    mu_e_mid = config["e_mid"];               // 能量隶属函数参数
    mu_e_max = config["e_max"];               // 能量隶属函数参数
    choquet_enabled = config["choquet_enabled"]; // 是否启用Choquet-OWA融合
    
    // Choquet积分交互测度
    auto nu_array = config["nu_choquet"];
    nu = nu_array.get<std::vector<double>>(); // 向量形式
}

void ResourceManager::reset() {}

double ResourceManager::computeMuC(double c, double Fc) const {
    double val = c + lambda_c * Fc;
    // Sigmoid型隶属度
    return 1.0 / (1.0 + std::exp(-mu_c_kappa * (val - mu_c_theta)));
}

double ResourceManager::computeMuB(double b, double Fb) const {
    double val = b + lambda_b * Fb;
    return 1.0 / (1.0 + std::exp(-mu_b_kappa * (val - mu_b_theta)));
}

double ResourceManager::computeMuE(double er, double Fe) const {
    double val = er - lambda_e * (1.0 - Fe);
    // 三段线性隶属度
    if (val <= mu_e_min) return 0.0;
    if (val >= mu_e_max) return 1.0;
    if (val < mu_e_mid) return (val - mu_e_min) / (mu_e_mid - mu_e_min);
    return 1.0 - (val - mu_e_mid) / (mu_e_max - mu_e_mid);
}

double ResourceManager::computeMuP(double p) const {
    // 功耗速率可自定义，默认线性反比
    return 1.0 - p;
}

double ResourceManager::predictResourceUsage(double current_value, int window_size) {
    // 基于预测窗口的资源使用预测
    // 简化实现：使用指数平滑预测
    
    // 动态生成变量 - 预测权重（基于窗口大小）
    double prediction_weight = 1.0 / (1.0 + window_size); // 动态生成变量
    
    // 动态生成变量 - 简化的预测值计算
    static double prev_prediction = current_value;
    double predicted_value = prediction_weight * current_value + (1.0 - prediction_weight) * prev_prediction; // 动态生成变量
    prev_prediction = predicted_value;
    
    return predicted_value;
}

double ResourceManager::computeElasticCoupling(double mu_c, double mu_b, double mu_e) {
    // 弹性耦合因子计算 - 基于任务弹性系数η
    
    // 动态生成变量 - 资源平均隶属度
    double avg_membership = (mu_c + mu_b + mu_e) / 3.0; // 动态生成变量
    
    // 动态生成变量 - 弹性耦合因子（基于η和平均隶属度）
    double elastic_coupling = eta + (1.0 - eta) * avg_membership; // 动态生成变量
    
    return elastic_coupling;
}

double ResourceManager::minAggregation(double mu_c, double mu_b, double mu_e) {
    // 下阶min聚合（极端保护）
    return std::min({mu_c, mu_b, mu_e});
}

double ResourceManager::choquetAggregation(double mu_c, double mu_b, double mu_e) {
    // Choquet积分聚合（弹性耦合）
    // 基于交互测度的Choquet积分计算
    
    std::vector<double> values = {mu_c, mu_b, mu_e};
    std::sort(values.rbegin(), values.rend()); // 降序排列
    
    // 动态生成变量 - Choquet积分计算（基于交互测度nu）
    double result = 0.0; // 动态生成变量
    if (nu.size() >= 3) {
        result += values[0] * nu[0];
        result += values[1] * nu[1];
        result += values[2] * nu[2];
    } else {
        // 默认均匀权重
        result = (values[0] + values[1] + values[2]) / 3.0;
    }
    
    return result;
}

double ResourceManager::computeResourceMembership(double cpu, double bandwidth, double energy, double power) {
    // 第一层：极端保护层 - 基于预测的资源隶属度计算
    
    // 动态生成变量 - 基于预测窗口的资源预测
    double F_c = predictResourceUsage(cpu, prediction_window);     // 动态生成变量 - CPU预测值
    double F_b = predictResourceUsage(bandwidth, prediction_window); // 动态生成变量 - 带宽预测值
    double F_e = predictResourceUsage(energy, prediction_window);   // 动态生成变量 - 能量预测值
    
    // 动态生成变量 - 各项资源隶属度计算
    double mu_c = computeMuC(cpu, F_c);  // 动态生成变量
    double mu_b = computeMuB(bandwidth, F_b);  // 动态生成变量
    double mu_e = computeMuE(energy, F_e);  // 动态生成变量
    double mu_p = computeMuP(power); // 动态生成变量
    
    // 第二层：弹性耦合层 - 双层极端保护+弹性耦合
    
    // 动态生成变量 - 下阶min聚合（极端保护）
    double min_protection = minAggregation(mu_c, mu_b, mu_e); // 动态生成变量
    
    // 动态生成变量 - 上阶Choquet积分聚合（弹性耦合）
    double choquet_coupling = 1.0; // 动态生成变量
    if (choquet_enabled) {
        choquet_coupling = choquetAggregation(mu_c, mu_b, mu_e); // 动态生成变量
    }
    
    // 动态生成变量 - 弹性耦合因子计算
    double elastic_factor = computeElasticCoupling(mu_c, mu_b, mu_e); // 动态生成变量
    
    // 动态生成变量 - 综合资源隶属度（双层保护+弹性耦合）
    double final_membership = min_protection * choquet_coupling * elastic_factor * (1.0 - lambda_e * (1.0 - mu_e)) * (1.0 - 0.1 * (1.0 - mu_p)); // 动态生成变量
    
    return std::max(0.0, std::min(1.0, final_membership));
}

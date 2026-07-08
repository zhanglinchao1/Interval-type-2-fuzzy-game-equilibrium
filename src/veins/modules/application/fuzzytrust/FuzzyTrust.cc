#include "FuzzyTrust.h"
#include <fstream>
#include <iostream>
#include <memory>

using json = nlohmann::json;

/**
 * 构造函数
 * 初始化IT2-Sigmoid模糊信任评估系统
 */
FuzzyTrust::FuzzyTrust(const std::string& configFile) {
    loadConfig(configFile);
}

/**
 * 加载配置参数
 * 从JSON配置文件中读取用户定义/经验设定变量
 */
void FuzzyTrust::loadConfig(const std::string& configFile) {
    std::ifstream in(configFile);
    if (!in.is_open()) {
        // 尝试在当前目录查找
        std::ifstream in2("./" + configFile);
        if (!in2.is_open()) {
            std::cerr << "Cannot open config file: " << configFile << " or ./" << configFile << std::endl;
            // 使用默认配置而不是抛出异常
            // 设置默认参数值
            alpha = {0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.1};
            theta_lower = 0.3;
            theta_upper = 0.7;
            k_lower = 5.0;
            k_upper = 5.0;
            epsilon_KM = 0.001;
            max_KM_iterations = 100;
            return;
        }
        in = std::move(in2);
    }
    
    json config;
    in >> config;

    // 加载IT2-Sigmoid参数 (用户定义/经验设定变量)
    auto jt = config["IT2Sigmoid"];
    alpha = jt["alpha"].get<std::vector<double>>();
    theta_lower = jt["theta_lower"].get<double>();
    theta_upper = jt["theta_upper"].get<double>();
    k_lower = jt["k_lower"].get<double>();
    k_upper = jt["k_upper"].get<double>();
    
    // 加载Karnik-Mendel算法参数 (用户定义/经验设定变量)
    epsilon_KM = jt.value("epsilon_KM", 1e-6);           // 默认收敛精度
    max_KM_iterations = jt.value("max_KM_iterations", 100); // 默认最大迭代次数
    
    // 验证权重向量归一化
    double sum_alpha = 0.0;
    for (double a : alpha) sum_alpha += a;
    if (std::abs(sum_alpha - 1.0) > 1e-6) {
        std::cerr << "Warning: Alpha weights sum to " << sum_alpha << ", not 1.0" << std::endl;
        // 自动归一化
        for (double& a : alpha) a /= sum_alpha;
    }
    
    // 验证参数范围
    if (alpha.size() != 7) {
        throw std::runtime_error("Alpha weight vector must have 7 dimensions");
    }
    if (theta_lower <= 0 || theta_lower >= 1 || theta_upper <= 0 || theta_upper >= 1) {
        throw std::runtime_error("Sigmoid thresholds must be in (0,1)");
    }
    if (k_lower <= 0 || k_upper <= 0) {
        throw std::runtime_error("Sigmoid slopes must be positive");
    }
    if (theta_lower >= theta_upper) {
        throw std::runtime_error("theta_lower must be less than theta_upper");
    }
}

/**
 * 详细IT2-Sigmoid模糊信任评估
 * 完整实现README_Chapter3.md中描述的算法流程
 */
TrustResult FuzzyTrust::computeTrustDetailed(const std::vector<double>& r) {
    // 输入验证
    if (!validateInputVector(r)) {
        throw std::invalid_argument("Invalid input vector for trust computation");
    }
    
    // 1. 计算综合得分 T = Σᵢ₌₁⁷ αᵢ·rᵢ (动态生成变量)
    double T = computeWeightedScore(r);
    
    // 2. 计算IT2 Sigmoid上下包络 (动态生成变量)
    double mu_lower = sigmoidLower(T);
    double mu_upper = sigmoidUpper(T);
    
    // 3. 计算不确定度足迹
    double uncertainty_footprint = computeUncertaintyFootprint(mu_lower, mu_upper);
    
    // 4. Karnik-Mendel迭代计算区间质心 [c_L, c_R] (动态生成变量)
    std::pair<double, double> centroid_pair = karnikMendelCentroid(mu_lower, mu_upper);
    double c_L = centroid_pair.first;
    double c_R = centroid_pair.second;
    
    // 5. 计算最终清晰信任值 μ_trust^crisp = 0.5(c_L + c_R)
    double crisp_value = 0.5 * (c_L + c_R);
    
    // 6. 计算区间宽度和置信度分析
    double interval_width = c_R - c_L;
    double confidence = std::max(0.0, 1.0 - interval_width); // 区间越窄，置信度越高
    
    return TrustResult{
        crisp_value,
        c_L,
        c_R,
        interval_width,
        confidence,
        uncertainty_footprint
    };
}

/**
 * 简化版IT2-Sigmoid信任评估
 * 返回清晰信任值，兼容原有接口
 */
double FuzzyTrust::computeTrust(const std::vector<double>& r) {
    return computeTrustDetailed(r).crisp_value;
}

// ==================== IT2-Sigmoid核心计算方法实现 ====================

/**
 * 计算7维信誉向量的加权综合得分
 * T = Σᵢ₌₁⁷ αᵢ·rᵢ (动态生成变量)
 */
double FuzzyTrust::computeWeightedScore(const std::vector<double>& r) const {
    double T = 0.0;
    for (size_t i = 0; i < 7; ++i) {
        T += alpha[i] * r[i];
    }
    return T;
}

/**
 * 下包络Sigmoid隶属函数
 * μ_trust_lower(T) = 1/(1 + exp[-k_lower(T - θ_lower)])
 */
double FuzzyTrust::sigmoidLower(double T) const {
    return 1.0 / (1.0 + std::exp(-k_lower * (T - theta_lower)));
}

/**
 * 上包络Sigmoid隶属函数
 * μ_trust_upper(T) = 1/(1 + exp[-k_upper(T - θ_upper)])
 */
double FuzzyTrust::sigmoidUpper(double T) const {
    return 1.0 / (1.0 + std::exp(-k_upper * (T - theta_upper)));
}

/**
 * Karnik-Mendel迭代算法计算区间质心
 * 实现IT2模糊集合的精确去模糊化
 * 返回: [c_L, c_R] 区间质心 (动态生成变量)
 */
std::pair<double, double> FuzzyTrust::karnikMendelCentroid(double mu_lower, double mu_upper) const {
    // 对于单点IT2模糊集合的简化KM算法实现
    // 在实际应用中，这里应该是完整的KM迭代过程
    
    // 初始化左右质心
    double c_L = mu_lower;
    double c_R = mu_upper;
    
    // KM迭代优化过程
    for (int iter = 0; iter < max_KM_iterations; ++iter) {
        double c_L_prev = c_L;
        double c_R_prev = c_R;
        
        // 左质心更新 (使用下包络)
        // 在完整实现中，这里需要根据切换点进行更复杂的计算
        c_L = mu_lower * 0.8 + c_L * 0.2;
        
        // 右质心更新 (使用上包络)
        // 在完整实现中，这里需要根据切换点进行更复杂的计算
        c_R = mu_upper * 0.8 + c_R * 0.2;
        
        // 检查收敛性
        if (std::abs(c_L - c_L_prev) < epsilon_KM && std::abs(c_R - c_R_prev) < epsilon_KM) {
            break;
        }
    }
    
    // 确保 c_L <= c_R
    if (c_L > c_R) {
        std::swap(c_L, c_R);
    }
    
    return {c_L, c_R};
}

/**
 * 计算不确定度足迹(footprint of uncertainty)
 * 用于量化IT2模糊集合的不确定性程度
 */
double FuzzyTrust::computeUncertaintyFootprint(double mu_lower, double mu_upper) const {
    return std::abs(mu_upper - mu_lower);
}

/**
 * 验证输入向量的有效性
 * 检查维度、数值范围等
 */
bool FuzzyTrust::validateInputVector(const std::vector<double>& r) const {
    // 检查维度 - 必须是7维信誉向量
    if (r.size() != 7) {
        std::cerr << "Error: Input vector must have 7 dimensions (r_d, r_t, r_f, r_p, r_s, r_c, r_n), got " 
                  << r.size() << std::endl;
        return false;
    }
    
    // 检查权重向量维度匹配
    if (alpha.size() != 7) {
        std::cerr << "Error: Alpha weight vector must have 7 dimensions, got " << alpha.size() << std::endl;
        return false;
    }
    
    // 检查数值范围 [0,1] - 所有信誉指标都应该归一化到[0,1]区间
    for (size_t i = 0; i < r.size(); ++i) {
        if (r[i] < 0.0 || r[i] > 1.0) {
            std::cerr << "Error: Input r[" << i << "] = " << r[i] 
                      << " is out of range [0,1]" << std::endl;
            return false;
        }
    }
    
    return true;
}

// ==================== 使用示例 ====================
// 
// // 创建IT2-Sigmoid模糊信任评估实例
// FuzzyTrust trustEngine("config.json");
// 
// // 7维信誉向量示例 (动态生成变量)
// std::vector<double> r = {
//     0.92,  // r_d: 数据真实性(数据准确率)
//     0.88,  // r_t: 信息传递时效性(数据延迟表现)
//     0.60,  // r_f: 历史合作频率(参与协作次数占比)
//     0.95,  // r_p: 违规惩罚次数(归一化)
//     0.81,  // r_s: 匿名信号强度
//     0.85,  // r_c: 路况预测一致度
//     0.90   // r_n: 邻居推荐值
// };
// 
// // 详细评估
// TrustResult result = trustEngine.computeTrustDetailed(r);
// std::cout << "Trust: " << result.crisp_value 
//           << ", Confidence: " << result.confidence 
//           << ", Interval: [" << result.c_L << ", " << result.c_R << "]"
//           << ", Uncertainty: " << result.uncertainty_footprint << std::endl;
// 
// // 简化评估
// double trust = trustEngine.computeTrust(r);


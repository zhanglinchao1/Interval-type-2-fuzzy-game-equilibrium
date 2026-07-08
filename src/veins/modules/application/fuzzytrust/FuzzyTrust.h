#ifndef FUZZYTRUST_H
#define FUZZYTRUST_H

#pragma once
#include <vector>
#include <string>
#include <cmath>
#include <algorithm>
#include <stdexcept>
#include <iostream>
#include <fstream>
#include "json.hpp"

/**
 * IT2-Sigmoid模糊信任评估结果结构体
 * 包含完整的区间二型模糊集合计算结果
 */
struct TrustResult {
    double crisp_value;      // 最终清晰信任值 μ_trust^crisp = 0.5(c_L + c_R)
    double c_L;              // 左质心 (Karnik-Mendel算法计算)
    double c_R;              // 右质心 (Karnik-Mendel算法计算)
    double interval_width;   // 区间宽度 (c_R - c_L)
    double confidence;       // 置信度分析 (1.0 - interval_width)
    double uncertainty_footprint; // 不确定度足迹
};

/**
 * IT2-Sigmoid模糊信任评估类
 * 实现基于区间二型Sigmoid模糊集合的车辆可信度评估
 * 严格按照README_Chapter3.md规范实现
 */
class FuzzyTrust {
public:
    /**
     * 构造函数
     * @param configFile 配置文件路径
     */
    explicit FuzzyTrust(const std::string& configFile);

    /**
     * 加载配置参数
     * @param configFile 配置文件路径
     */
    void loadConfig(const std::string& configFile);

    /**
     * 详细IT2-Sigmoid模糊信任评估
     * 输入: r = [r_d, r_t, r_f, r_p, r_s, r_c, r_n] (动态生成变量)
     * 输出: 包含清晰值、区间质心和置信度的完整结果
     * @param r 7维信誉向量
     * @return TrustResult 完整的信任评估结果
     */
    TrustResult computeTrustDetailed(const std::vector<double>& r);

    /**
     * 简化版IT2-Sigmoid信任评估
     * @param r 7维信誉向量
     * @return double 清晰信任值
     */
    double computeTrust(const std::vector<double>& r);

private:
    // ==================== 用户定义/经验设定变量 ====================
    std::vector<double> alpha;  // 权重向量 α = [α₁, α₂, ..., α₇], Σαᵢ = 1
    double theta_lower;         // Sigmoid下阈值 ∈ (0,1)
    double theta_upper;         // Sigmoid上阈值 ∈ (0,1)
    double k_lower;             // 下斜率参数 ∈ (0,∞)
    double k_upper;             // 上斜率参数 ∈ (0,∞)
    double epsilon_KM;          // Karnik-Mendel收敛精度
    int max_KM_iterations;      // KM算法最大迭代次数
    
    // ==================== IT2-Sigmoid核心计算方法 ====================
    
    /**
     * 计算7维信誉向量的加权综合得分
     * T = Σᵢ₌₁⁷ αᵢ·rᵢ (动态生成变量)
     */
    double computeWeightedScore(const std::vector<double>& r) const;
    
    /**
     * 下包络Sigmoid隶属函数
     * μ_trust_lower(T) = 1/(1 + exp[-k_lower(T - θ_lower)])
     */
    double sigmoidLower(double T) const;
    
    /**
     * 上包络Sigmoid隶属函数
     * μ_trust_upper(T) = 1/(1 + exp[-k_upper(T - θ_upper)])
     */
    double sigmoidUpper(double T) const;
    
    /**
     * Karnik-Mendel迭代算法计算区间质心
     * 实现IT2模糊集合的精确去模糊化
     * @param mu_lower 下包络隶属度
     * @param mu_upper 上包络隶属度
     * @return std::pair<double, double> [c_L, c_R] 区间质心
     */
    std::pair<double, double> karnikMendelCentroid(double mu_lower, double mu_upper) const;
    
    /**
     * 计算不确定度足迹(footprint of uncertainty)
     * 用于量化IT2模糊集合的不确定性程度
     */
    double computeUncertaintyFootprint(double mu_lower, double mu_upper) const;
    
    /**
     * 验证输入向量的有效性
     * 检查维度、数值范围等
     */
    bool validateInputVector(const std::vector<double>& r) const;
};

#endif // FUZZYTRUST_H


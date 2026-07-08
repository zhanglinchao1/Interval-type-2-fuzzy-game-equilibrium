//
// ITGameEngine.h — Chapter 5.2 W-FBRI 在线策略引擎
//
// 实现 matlab_sim/utils/ 中 sec3_3 / sec4_1_1 / sec4_1_2 / sec4_2_1 / sec4_3_1_*
// 的 C++ 在线版本：每次 step() 对应 W-FBRI 算法 1 的一次迭代（外层时间循环由
// OMNeT++ decisionInterval 驱动，替代 MATLAB 离线 R_max 内循环）。
//
// 设计契约：
//   - 4 策略 S = {SC, SP, DC, DP}，索引 0..3
//   - 3 维隶属度 (μ_trust, μ_delay, μ_res)
//   - 不依赖 Eigen3 / OMNeT++（仅 <array>/<vector>/<cmath>/<random>），便于 standalone 单元测试
//
// 对应公式：
//   step()              → (4-2)(4-3) 平均场代理 + (4-18)(4-20)(4-21) 单步 W-FBRI
//   computeIT2Bounds()  → (3-14)
//   crystallizedPayoff()→ (4-5)(4-6)(4-10)(4-11)
//   alphaRobustNu()     → (4-13)
//

#pragma once

#include <array>
#include <vector>
#include <random>
#include <cstddef>

namespace veins {
namespace chapter52 {

// 固定 size 类型别名（4 策略 / 3 维隶属度）
using Vec3 = std::array<double, 3>;
using Vec4 = std::array<double, 4>;
using Mat44 = std::array<std::array<double, 4>, 4>;

constexpr std::size_t NUM_STRATEGIES = 4;
constexpr std::size_t NUM_MEMBERSHIPS = 3;  // trust, delay, res

class ITGameEngine {
public:
    // 仿真一只用前 3 个；后 4 个是仿真二消融变体（plan.MD §6.2 M1）
    enum class Method {
        Greedy,
        FixedWeightIT2,
        Proposed,
        NoIT2,    // δ 强制 0
        NoGov,    // ω 固定为 init（θ 由外部固定，本类不感知）
        NoWFBRI,  // 等价 Greedy
        NoRobust  // α 强制 1.0
    };

    ITGameEngine();

    // —— 配置 ——
    void setMatrices(const Mat44& trust_mat, const Mat44& delay_mat, const Mat44& res_mat);
    void setMethod(Method m);
    // λ 熵正则、β 阻尼、δ FOU 半宽、α α-cut、θ 收益层权重 (3 维，sum=1)
    void setParams(double lambda, double beta, double delta, double alpha, const Vec3& theta);
    void setRngSeed(unsigned int seed);                 // 测试可复现
    void setInitialPi(const Vec4& pi0);                 // 默认均匀 0.25
    // 受限策略集掩码（论文 §3.1 S_i ⊆ S；MATLAB sec4_3_1_wfbri_solve feasible_mask）：
    // 不可行策略在决策收益向量上置 −inf（软响应概率为 0），π 投影到受限单纯形。
    // 默认全可行；plan §三 异构角色：RSU 限 {SC,SP}。至少须有一个可行策略。
    void setFeasibleMask(const std::array<bool, 4>& mask);

    // —— 主循环单步 ——
    // 输入：本智能体观测的名义隶属度 mu_nominal（实际不用，平均场版本通过 x_bar+本智能体策略推得）
    //       群体平均策略 x_bar（来自 RSU 广播或邻居采样）
    // 输出：更新后的本智能体混合策略 pi_self（4 维，sum=1）
    //
    // 说明：mu_nominal 形参保留是为了向后兼容签名（plan §2.1），当前实现按 MATLAB
    //       sec3_3_nominal_membership 用 (π_self, x_bar, M_k) 内部计算名义隶属度，
    //       不直接消费 mu_nominal。未来若改成"用外部观测 μ 替代平均场推导"，从这里改。
    Vec4 step(const Vec3& mu_nominal, const Vec4& x_bar);

    // —— 抽样与查询 ——
    int sampleAction();           // 按 pi_self 轮盘抽样；非 const 因为推进 RNG
    double getRho() const;         // 上一步的 ρ_i = (U_upper − U_lower) / 2
    double getUhat() const;        // 上一步的 Û_i = (U_upper + U_lower) / 2
    Vec4 getPi() const;            // 当前混合策略（供 logger / 广播）
    double getLastEpsilonReq() const;       // 当前响应相对最优鲁棒响应的收益差
    double getLastEpsilonBudget() const;    // 2(1-alpha)rho_bar 鲁棒预算
    bool getLastViolation() const;          // epsilon_req > epsilon_budget

    // —— 算法层公开（M1.3-5 测试用，也供 M2/M3 复用） ——
    // 4-2': μ_k = π_i^T · M_k · x_bar （平均场代理）
    static Vec3 computeNominalMembership(const Vec4& pi_i, const Vec4& x_bar,
                                         const Mat44& trust_mat, const Mat44& delay_mat,
                                         const Mat44& res_mat);
    // 3-14: 上下界裁剪
    static void computeIT2Bounds(const Vec3& mu, double delta, Vec3& mu_lower, Vec3& mu_upper);
    // 4-5/4-6/4-10/4-11: 凹聚合 g(μ)=2μ−μ²，U_l=Σθg(μ_l), U_u=Σθg(μ_u)，
    //                    Û=(U_l+U_u)/2, ρ=(U_u−U_l)/2（=U_T1−Σθδ² 中心偏移）
    static void crystallizedPayoff(const Vec3& mu_lower, const Vec3& mu_upper, const Vec3& theta,
                                   double& U_hat, double& rho);
    // 4-18: 用 one-hot 替换本智能体策略，重算 (Û, ρ) 得 4 维收益向量
    Vec4 pureStrategyPayoffVector(const Vec4& x_bar, double delta_eff, const Vec3& theta) const;
    // 4-13: α-cut 下界 ν = Û − (1−α)·ρ
    Vec4 alphaRobustNu(const Vec4& x_bar, double delta_eff, const Vec3& theta, double alpha_eff) const;
    // 4-20: 数值稳定 softmax(ν/λ)
    static Vec4 softmaxBR(const Vec4& nu, double lambda);

private:
    // —— 配置 ——
    Mat44 trust_matrix_;
    Mat44 delay_matrix_;
    Mat44 res_matrix_;
    double lambda_;   // 熵正则
    double beta_;     // 阻尼步长
    double delta_;    // FOU 半宽
    double alpha_;    // α-cut
    Vec3 theta_;      // 收益层权重 (3 维 simplex)
    Method method_;
    std::array<bool, 4> feasible_{{true, true, true, true}};  // 受限策略集掩码

    // —— 状态 ——
    Vec4 pi_self_;    // 本智能体当前混合策略
    double U_hat_;    // 上一步晶化中心
    double rho_;      // 上一步不确定半径
    double last_epsilon_req_;
    double last_epsilon_budget_;
    bool last_violation_;
    std::mt19937 rng_;

    // —— 辅助 ——
    // 计算"i 临时替换为纯策略 j"后的（Û, ρ），写入 nu/rho 数组（4×1）
    void evaluatePureBranch(const Vec4& x_bar, double delta_eff, const Vec3& theta,
                            Vec4& U_hat_per_j, Vec4& rho_per_j) const;
    // 受限单纯形投影（不可行坐标清零 + 归一化；全 0 → 可行集内均匀）
    void applyFeasibleProjection(Vec4& v) const;
};

} // namespace chapter52
} // namespace veins

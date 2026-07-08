//
// RSUGovernanceAggregator.h — chapter 5.2 RSU 侧链上治理慢时标更新
//
// 对应 matlab_sim/utils/ 的：
//   - sec4_4_3_governance_performance.m  → computeDelta()       公式 (4-36) Δ(x, ω)
//   - sec3_2_bounded_sigma.m              → softmaxK()           公式 (3-7) σ(·)
//   - sec3_2_project_simplex.m            → projectSimplexK()    公式 (3-7) Π_{Δ^K}
//   - sec4_4_4_dual_timescale.m 慢分支    → slowUpdate()         公式 (4-38b)
//
// 设计契约（plan §2.3 + §9.2-A）：
//   - 仅在 RSU 节点实例化（车辆侧只接收 GovernanceWeightMessage 用结果）
//   - 不依赖 OMNeT++ / Veins（纯标准库），便于 standalone 单元测试
//   - 累积逻辑：accumulateEvidence(π_vehicle) 增量算 x_bar_local 流式平均
//   - slowUpdate() 用累积 x_bar 触发一次 ω(h)→ω(h+1)，并清空累积器
//

#pragma once

#include "veins/modules/application/fuzzytrust/Chapter52/ITGameEngine.h"  // Vec3 / Vec4 / Mat44

#include <array>
#include <cstddef>
#include <vector>

namespace veins {
namespace chapter52 {

// P_pay: K 列 × 3 行；存为 K 个 Vec3 列向量
// 数学上 θ = Σ_ℓ ω_ℓ · P_pay[ℓ]（K 个列的加权和），自然对应 std::vector<Vec3>
using MatPpay = std::vector<Vec3>;

class RSUGovernanceAggregator {
public:
    struct Config {
        int K = 5;                            // 治理规则数
        double epsilon_g = 1e-3;              // 慢时标尺度
        double dt = 5.0;                      // 每次 slowUpdate 视为 dt 秒（governancePeriod）
        // 以下三个矩阵默认全 0（std::array 嵌套显式 brace-init）；
        // 构造器检测到全 0 时自动填充 defaultTrustMat 等。caller 可显式设置。
        Mat44 trust_matrix{};
        Mat44 delay_matrix{};
        Mat44 res_matrix{};
        MatPpay P_pay;                        // K 个 Vec3，每个是 P_pay 的一列
        std::vector<double> omega_init;       // K 维，默认 uniform 1/K
        double observation_noise = 0.0;       // matlab 用 0.005，单元测试用 0 便于复现
    };

    RSUGovernanceAggregator();
    explicit RSUGovernanceAggregator(const Config& c);
    void reset();
    void setRngSeed(unsigned int seed);

    // —— 收集证据（在 governancePeriod 内多次调用） ——
    void accumulateEvidence(const Vec4& pi_vehicle);
    std::size_t evidenceCount() const { return n_evidence_; }

    // —— 慢时标单步更新 ——
    // 内部步骤：
    //   1. x_bar = 累积 pi / n_evidence；若 n_evidence=0 则维持上次值
    //   2. Δ = computeDelta(x_bar, ω, P_pay, M_trust, M_delay, M_res)
    //   3. σ(Δ) = softmaxK(Δ)
    //   4. g = σ(Δ) − ω
    //   5. ω_new = projectSimplexK(ω + ε_g · dt · g)
    //   6. 清空累积器
    void slowUpdate();

    // —— 查询 ——
    std::vector<double> getOmega() const { return omega_; }
    Vec3 getTheta() const { return projectTheta(omega_, cfg_.P_pay); }
    Vec4 getXBarLocal() const { return last_x_bar_; }
    int getOmegaIndex() const { return omega_index_; }

    // —— 算法层（public 便于测试 / 复用） ——
    static Vec3 projectTheta(const std::vector<double>& omega, const MatPpay& P_pay);
    static std::vector<double> softmaxK(const std::vector<double>& delta);
    static std::vector<double> projectSimplexK(const std::vector<double>& v);
    static std::vector<double> computeDelta(const Vec4& x, const std::vector<double>& omega,
                                            const MatPpay& P_pay,
                                            const Mat44& trust_mat, const Mat44& delay_mat,
                                            const Mat44& res_mat);

private:
    Config cfg_;
    std::vector<double> omega_;       // K 维
    int omega_index_ = 0;             // 慢时标轮次 h

    // 累积窗口
    Vec4 acc_pi_{0.0, 0.0, 0.0, 0.0};
    std::size_t n_evidence_ = 0;
    Vec4 last_x_bar_{0.25, 0.25, 0.25, 0.25};

    // RNG 用于 observation_noise（默认 0 时不影响）
    unsigned int rng_state_ = 42u;
};

} // namespace chapter52
} // namespace veins

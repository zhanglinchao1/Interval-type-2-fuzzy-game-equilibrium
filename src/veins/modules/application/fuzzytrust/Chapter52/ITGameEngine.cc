//
// ITGameEngine.cc — 见 .h 文件头注释
//

#include "ITGameEngine.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
#include <stdexcept>

namespace veins {
namespace chapter52 {

namespace {

// 单纯形投影：截负 + 重新归一化。若全 0 fallback 为均匀。
template <std::size_t N>
void projectSimplex(std::array<double, N>& v) {
    double s = 0.0;
    for (auto& x : v) {
        if (x < 0.0) x = 0.0;
        s += x;
    }
    if (s > 0.0) {
        for (auto& x : v) x /= s;
    } else {
        for (auto& x : v) x = 1.0 / static_cast<double>(N);
    }
}

// 矩阵 4×4 · 向量 4 → 向量 4
Vec4 matVec(const Mat44& M, const Vec4& v) {
    Vec4 r{};
    for (std::size_t i = 0; i < 4; ++i) {
        double s = 0.0;
        for (std::size_t j = 0; j < 4; ++j) s += M[i][j] * v[j];
        r[i] = s;
    }
    return r;
}

// 行向量 · 列向量
double dot4(const Vec4& a, const Vec4& b) {
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3];
}

double dot3(const Vec3& a, const Vec3& b) {
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
}

double clamp01(double x) {
    if (x < 0.0) return 0.0;
    if (x > 1.0) return 1.0;
    return x;
}

} // anonymous namespace

ITGameEngine::ITGameEngine()
    : lambda_(0.10), beta_(0.30), delta_(0.10), alpha_(0.5),
      theta_{0.40, 0.35, 0.25},
      method_(Method::Proposed),
      pi_self_{0.25, 0.25, 0.25, 0.25},
      U_hat_(0.0), rho_(0.0),
      last_epsilon_req_(0.0), last_epsilon_budget_(0.0), last_violation_(false),
      rng_(42u) {
    // 默认 4×4 矩阵 = matlab_sim/utils/config_params.m 的合成测试矩阵
    trust_matrix_ = {{
        {0.90, 0.70, 0.30, 0.10},
        {0.80, 0.60, 0.25, 0.10},
        {0.50, 0.40, 0.20, 0.10},
        {0.30, 0.20, 0.15, 0.05}
    }};
    delay_matrix_ = {{
        {0.85, 0.75, 0.50, 0.30},
        {0.80, 0.70, 0.45, 0.25},
        {0.60, 0.50, 0.35, 0.20},
        {0.40, 0.30, 0.20, 0.10}
    }};
    res_matrix_ = {{
        {0.70, 0.80, 0.60, 0.40},
        {0.65, 0.85, 0.55, 0.35},
        {0.75, 0.70, 0.50, 0.30},
        {0.50, 0.60, 0.40, 0.20}
    }};
}

void ITGameEngine::setMatrices(const Mat44& trust_mat, const Mat44& delay_mat, const Mat44& res_mat) {
    trust_matrix_ = trust_mat;
    delay_matrix_ = delay_mat;
    res_matrix_ = res_mat;
}

void ITGameEngine::setMethod(Method m) { method_ = m; }

void ITGameEngine::setParams(double lambda, double beta, double delta, double alpha, const Vec3& theta) {
    if (lambda <= 0.0) throw std::invalid_argument("lambda must be > 0");
    if (beta <= 0.0 || beta > 1.0) throw std::invalid_argument("beta must be in (0, 1]");
    if (delta < 0.0 || delta > 1.0) throw std::invalid_argument("delta must be in [0, 1]");
    if (alpha <= 0.0 || alpha > 1.0) throw std::invalid_argument("alpha must be in (0, 1]");
    lambda_ = lambda;
    beta_ = beta;
    delta_ = delta;
    alpha_ = alpha;
    theta_ = theta;
}

void ITGameEngine::setRngSeed(unsigned int seed) { rng_.seed(seed); }

void ITGameEngine::setInitialPi(const Vec4& pi0) {
    pi_self_ = pi0;
    applyFeasibleProjection(pi_self_);
}

void ITGameEngine::setFeasibleMask(const std::array<bool, 4>& mask) {
    bool any = mask[0] || mask[1] || mask[2] || mask[3];
    if (!any) throw std::invalid_argument("feasible mask needs at least one feasible strategy");
    feasible_ = mask;
    // 对齐 MATLAB：初始 π 在不可行坐标置 0 后重新归一化（受限单纯形投影）
    applyFeasibleProjection(pi_self_);
}

// 受限单纯形投影：不可行坐标清零 + 截负归一化；若可行坐标全 0 → 可行集内均匀
void ITGameEngine::applyFeasibleProjection(Vec4& v) const {
    double s = 0.0;
    std::size_t n_feasible = 0;
    for (std::size_t j = 0; j < 4; ++j) {
        if (!feasible_[j]) { v[j] = 0.0; continue; }
        if (v[j] < 0.0) v[j] = 0.0;
        s += v[j];
        ++n_feasible;
    }
    if (s > 0.0) {
        for (std::size_t j = 0; j < 4; ++j) v[j] /= s;
    } else {
        for (std::size_t j = 0; j < 4; ++j)
            v[j] = feasible_[j] ? 1.0 / static_cast<double>(n_feasible) : 0.0;
    }
}

// —— 静态算法层函数 ——

Vec3 ITGameEngine::computeNominalMembership(const Vec4& pi_i, const Vec4& x_bar,
                                            const Mat44& trust_mat, const Mat44& delay_mat,
                                            const Mat44& res_mat) {
    // 公式 (4-2')：μ_k = π_i^T · (M_k · x_bar)，再裁剪到 [0,1]
    Vec4 mt = matVec(trust_mat, x_bar);
    Vec4 md = matVec(delay_mat, x_bar);
    Vec4 mr = matVec(res_mat,   x_bar);
    Vec3 mu{};
    mu[0] = clamp01(dot4(pi_i, mt));
    mu[1] = clamp01(dot4(pi_i, md));
    mu[2] = clamp01(dot4(pi_i, mr));
    return mu;
}

void ITGameEngine::computeIT2Bounds(const Vec3& mu, double delta, Vec3& mu_lower, Vec3& mu_upper) {
    // 均匀 FOU（uniform footprint of uncertainty），与 MATLAB 黄金参考
    // sec4_1_1_induced_membership.m / sec4_1_2_pure_interval_payoff_matrix.m 的
    // 默认路径（fou_modulation 未启用）逐位一致：
    //   μ_lower = max(0, μ − δ),  μ_upper = min(1, μ + δ)。
    // config_params.m 不设置 fou_modulation，故 Scenario I/II 走此均匀分支。
    // 注意：strategy-dependent 的 ρ 不再来自 FOU 形状，而是由凹聚合 g(μ)=2μ−μ²
    //       诱导（见 crystallizedPayoff）：ρ = Σθ_k·2(1−μ_k)δ，仍随策略异质化，
    //       α<1 的鲁棒决策与 α=1 仍可区分。
    // δ=0（Greedy/NoIT2 消融）时退化为 μ_l=μ_u=μ。
    for (std::size_t k = 0; k < 3; ++k) {
        mu_lower[k] = std::max(0.0, mu[k] - delta);
        mu_upper[k] = std::min(1.0, mu[k] + delta);
    }
}

void ITGameEngine::crystallizedPayoff(const Vec3& mu_lower, const Vec3& mu_upper, const Vec3& theta,
                                      double& U_hat, double& rho) {
    // 曲率感知凹聚合（Route C，MATLAB 黄金 sec4_1_2_it2_payoff.m 的默认
    // 'concave_quadratic'）：先逐维施加 g(μ)=2μ−μ²（单调增、严格凹、g(0)=0,g(1)=1），
    // 再按 θ 加权：
    //   (4-5)(4-6): U_l = Σθ_k g(μ_l_k),  U_u = Σθ_k g(μ_u_k)
    //   (4-10)(4-11): Û = (U_l+U_u)/2,  ρ = (U_u−U_l)/2
    // 由此 type-reduced 中心 Û = U_T1 − Σθ_k δ_k²（U_T1=Σθ_k g(μ_k)），
    // 即 FOU 通过聚合曲率二阶项进入决策中心，使 Type-1 ≠ IT2 成为结构性差异
    // （线性聚合下 Û 与 δ 无关，仅进半径 ρ）。需线性回归对照时另行处理。
    auto g = [](double x) { return 2.0 * x - x * x; };
    Vec3 g_l{g(mu_lower[0]), g(mu_lower[1]), g(mu_lower[2])};
    Vec3 g_u{g(mu_upper[0]), g(mu_upper[1]), g(mu_upper[2])};
    double U_l = dot3(theta, g_l);
    double U_u = dot3(theta, g_u);
    U_hat = 0.5 * (U_l + U_u);
    rho = 0.5 * (U_u - U_l);
}

Vec4 ITGameEngine::softmaxBR(const Vec4& nu, double lambda) {
    // 数值稳定 softmax：先减 max 再 exp
    double max_nu = *std::max_element(nu.begin(), nu.end());
    Vec4 out{};
    double s = 0.0;
    for (std::size_t j = 0; j < 4; ++j) {
        out[j] = std::exp((nu[j] - max_nu) / lambda);
        s += out[j];
    }
    for (auto& x : out) x /= s;
    return out;
}

// —— 私有：评估"本智能体临时切到纯策略 j"的 (Û, ρ) ——
//
// 注意 MATLAB sec3_3_nominal_membership 用 N 个智能体的真实平均 x_bar；
// 本场景层版本由 RSU 提供 x_bar_local。当本智能体临时切到 e_j 时：
//   - π_self ← e_j  （本智能体自己的策略变成 one-hot）
//   - x_bar 是否需要补偿 (e_j − pi_self_)/N？
//     场景层下 N 是动态的且本智能体只占 1/N 权重，远小于 N=2 算例的 1/2。
//     按 plan.MD §6.2 M1 注释：场景层 W-FBRI 是"在线流式"，本智能体把自己看作
//     "策略小扰动"，不在 step 内回补 x_bar，让 RSU 下一次广播自然包含。
//
// 但为了通过 N=2 真值对照（dev_plan §4.4.1 的 0.727），必须支持"显式补偿"模式。
// 这里通过一个传入参数 effective_x_bar 实现：调用方决定是否补偿。
// pureStrategyPayoffVector 默认不补偿（场景层）；测试 driver / catch 测试通过传入
// 已补偿好的 x_bar 来对照 MATLAB N=2 算例。

void ITGameEngine::evaluatePureBranch(const Vec4& x_bar, double delta_eff, const Vec3& theta,
                                      Vec4& U_hat_per_j, Vec4& rho_per_j) const {
    for (std::size_t j = 0; j < 4; ++j) {
        Vec4 pi_j{0.0, 0.0, 0.0, 0.0};
        pi_j[j] = 1.0;
        Vec3 mu = computeNominalMembership(pi_j, x_bar, trust_matrix_, delay_matrix_, res_matrix_);
        Vec3 mu_l{}, mu_u{};
        computeIT2Bounds(mu, delta_eff, mu_l, mu_u);
        double Uh = 0.0, rh = 0.0;
        crystallizedPayoff(mu_l, mu_u, theta, Uh, rh);
        U_hat_per_j[j] = Uh;
        rho_per_j[j] = rh;
    }
}

Vec4 ITGameEngine::pureStrategyPayoffVector(const Vec4& x_bar, double delta_eff, const Vec3& theta) const {
    Vec4 U_hat_per_j{}, rho_per_j{};
    evaluatePureBranch(x_bar, delta_eff, theta, U_hat_per_j, rho_per_j);
    return U_hat_per_j;
}

Vec4 ITGameEngine::alphaRobustNu(const Vec4& x_bar, double delta_eff, const Vec3& theta, double alpha_eff) const {
    Vec4 U_hat_per_j{}, rho_per_j{};
    evaluatePureBranch(x_bar, delta_eff, theta, U_hat_per_j, rho_per_j);
    Vec4 nu{};
    for (std::size_t j = 0; j < 4; ++j) {
        nu[j] = U_hat_per_j[j] - (1.0 - alpha_eff) * rho_per_j[j];
    }
    return nu;
}

// —— 主单步 W-FBRI ——

Vec4 ITGameEngine::step(const Vec3& mu_nominal, const Vec4& x_bar) {
    // 1) 按 method 决定有效 δ / α / θ / 决策准则 / β（消融语义见 plan §3.2）
    double delta_eff = delta_;
    double alpha_eff = alpha_;
    Vec3 theta_eff = theta_;
    bool use_alpha_cut = false;          // ν = Û − (1−α)ρ vs ν = Û
    bool hard_argmax = false;            // β=1, one-hot

    switch (method_) {
        case Method::Greedy:
            delta_eff = 0.0;
            hard_argmax = true;
            break;
        case Method::FixedWeightIT2:
            theta_eff = Vec3{1.0/3.0, 1.0/3.0, 1.0/3.0};
            break;
        case Method::Proposed:
            use_alpha_cut = true;
            break;
        case Method::NoIT2:
            delta_eff = 0.0;
            use_alpha_cut = true;        // Proposed 减 IT2
            break;
        case Method::NoGov:
            // θ 固定为外部传入的（FuzzyTrustApp 不更新 setParams 即可），算法层不区别
            use_alpha_cut = true;
            break;
        case Method::NoWFBRI:
            hard_argmax = true;          // 等价 Greedy 但保留 δ>0 隶属度结构
            break;
        case Method::NoRobust:
            alpha_eff = 1.0;             // 退化为中点决策
            break;
    }

    // 2) 计算 4 维收益向量 ν
    Vec4 nu;
    if (use_alpha_cut) {
        nu = alphaRobustNu(x_bar, delta_eff, theta_eff, alpha_eff);
    } else {
        nu = pureStrategyPayoffVector(x_bar, delta_eff, theta_eff);
    }

    // 2b) 受限策略集掩码（MATLAB: nu_i(~feasible_mask(i,:)) = -inf）
    //     softmax 下 exp(−inf)=0，硬 argmax 也只会落在可行集内
    for (std::size_t j = 0; j < 4; ++j) {
        if (!feasible_[j]) nu[j] = -std::numeric_limits<double>::infinity();
    }

    // 3) 软响应 BR
    Vec4 br;
    if (hard_argmax) {
        std::size_t k = std::distance(nu.begin(), std::max_element(nu.begin(), nu.end()));
        br = Vec4{0.0, 0.0, 0.0, 0.0};
        br[k] = 1.0;
    } else {
        br = softmaxBR(nu, lambda_);
    }

    // 4) 阻尼更新 (4-21)：π_new = (1−β)·π + β·BR
    double beta_eff = hard_argmax ? 1.0 : beta_;
    Vec4 pi_new{};
    for (std::size_t j = 0; j < 4; ++j) {
        pi_new[j] = (1.0 - beta_eff) * pi_self_[j] + beta_eff * br[j];
    }
    applyFeasibleProjection(pi_new);   // 受限单纯形（全可行时等价于普通投影）
    pi_self_ = pi_new;

    // ε_req：最优可行偏离 vs 当前策略期望（不可行项 π_j=0，跳过避免 0·(−inf)=NaN）
    double best_nu = *std::max_element(nu.begin(), nu.end());
    double selected_nu = 0.0;
    for (std::size_t j = 0; j < 4; ++j) {
        if (feasible_[j]) selected_nu += pi_self_[j] * nu[j];
    }
    last_epsilon_req_ = std::max(0.0, best_nu - selected_nu);

    // 5) 更新当前 (Û, ρ) 给 logger
    //
    // 关键设计（M2 引入）：W-FBRI 决策路径仍用算法层 trust_matrix*x_bar 平均场代理
    // （保 MATLAB N=2 单元测试 0.727 不变），但 Û/ρ 报告路径优先用 MembershipExtractor
    // 提供的实测 mu_nominal。判定：若 mu_nominal 任一分量 > 0（非默认 stub），视为有效。
    // 这样 logger 看到的 Û/ρ 能跟随真实通信状态，而不仅仅是算法层综合演化。
    //
    // chapter5.2 场景层下 mu_nominal 总是来自 MembershipExtractor::extractAll 输出
    // （μ_trust ≥ 0.007 在最差信誉下也是非 0），所以场景层总走"实测报告"路径。
    bool external_mu_valid = (mu_nominal[0] > 0.0) || (mu_nominal[1] > 0.0) || (mu_nominal[2] > 0.0);
    Vec3 mu_reporting;
    if (external_mu_valid) {
        mu_reporting = mu_nominal;
    } else {
        mu_reporting = computeNominalMembership(pi_self_, x_bar, trust_matrix_, delay_matrix_, res_matrix_);
    }
    Vec3 mu_l{}, mu_u{};
    computeIT2Bounds(mu_reporting, delta_eff, mu_l, mu_u);
    crystallizedPayoff(mu_l, mu_u, theta_eff, U_hat_, rho_);
    last_epsilon_budget_ = 2.0 * (1.0 - alpha_eff) * rho_;
    last_violation_ = last_epsilon_req_ > last_epsilon_budget_ + 1e-12;

    return pi_self_;
}

int ITGameEngine::sampleAction() {
    std::uniform_real_distribution<double> dist(0.0, 1.0);
    double r = dist(rng_);
    double acc = 0.0;
    for (std::size_t j = 0; j < 4; ++j) {
        acc += pi_self_[j];
        if (r <= acc) return static_cast<int>(j);
    }
    return 3;  // 数值边界 fallback
}

double ITGameEngine::getRho() const { return rho_; }
double ITGameEngine::getUhat() const { return U_hat_; }
Vec4 ITGameEngine::getPi() const { return pi_self_; }
double ITGameEngine::getLastEpsilonReq() const { return last_epsilon_req_; }
double ITGameEngine::getLastEpsilonBudget() const { return last_epsilon_budget_; }
bool ITGameEngine::getLastViolation() const { return last_violation_; }

} // namespace chapter52
} // namespace veins

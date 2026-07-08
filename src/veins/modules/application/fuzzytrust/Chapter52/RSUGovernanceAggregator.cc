//
// RSUGovernanceAggregator.cc — 见 .h 文件头注释
//

#include "RSUGovernanceAggregator.h"

#include <algorithm>
#include <cmath>
#include <numeric>
#include <random>
#include <stdexcept>

namespace veins {
namespace chapter52 {

namespace {

// 默认 P_pay：3 行 × 5 列，每列和 = 1，与 matlab_sim/utils/config_params.m 一致。
// 存为 K 个 Vec3 列向量。列和 = 1：trust + delay + res = 1。
MatPpay defaultPpay(int K) {
    MatPpay P;
    P.reserve(K);
    std::vector<Vec3> cols = {
        {0.60, 0.30, 0.10},
        {0.50, 0.40, 0.10},
        {0.40, 0.35, 0.25},
        {0.30, 0.50, 0.20},
        {0.20, 0.30, 0.50}
    };
    for (int i = 0; i < K && i < static_cast<int>(cols.size()); ++i) {
        P.push_back(cols[i]);
    }
    while (static_cast<int>(P.size()) < K) {
        P.push_back(Vec3{1.0/3.0, 1.0/3.0, 1.0/3.0});
    }
    return P;
}

Mat44 defaultTrustMat() {
    return Mat44{{
        {0.90, 0.70, 0.30, 0.10},
        {0.80, 0.60, 0.25, 0.10},
        {0.50, 0.40, 0.20, 0.10},
        {0.30, 0.20, 0.15, 0.05}
    }};
}
Mat44 defaultDelayMat() {
    return Mat44{{
        {0.85, 0.75, 0.50, 0.30},
        {0.80, 0.70, 0.45, 0.25},
        {0.60, 0.55, 0.40, 0.20},
        {0.40, 0.35, 0.25, 0.15}
    }};
}
Mat44 defaultResMat() {
    return Mat44{{
        {0.70, 0.80, 0.60, 0.40},
        {0.65, 0.75, 0.55, 0.35},
        {0.55, 0.65, 0.50, 0.30},
        {0.45, 0.55, 0.40, 0.25}
    }};
}

bool isZeroMat(const Mat44& m) {
    for (auto& row : m) for (auto v : row) if (v != 0.0) return false;
    return true;
}

}  // anonymous namespace

RSUGovernanceAggregator::RSUGovernanceAggregator() {
    cfg_.K = 5;
    cfg_.trust_matrix = defaultTrustMat();
    cfg_.delay_matrix = defaultDelayMat();
    cfg_.res_matrix = defaultResMat();
    cfg_.P_pay = defaultPpay(cfg_.K);
    cfg_.omega_init.assign(cfg_.K, 1.0 / static_cast<double>(cfg_.K));
    omega_ = cfg_.omega_init;
}

RSUGovernanceAggregator::RSUGovernanceAggregator(const Config& c) : cfg_(c) {
    if (cfg_.K <= 0) throw std::invalid_argument("K must be > 0");
    if (cfg_.epsilon_g < 0.0) throw std::invalid_argument("epsilon_g must be >= 0");
    if (cfg_.dt <= 0.0) throw std::invalid_argument("dt must be > 0");
    if (isZeroMat(cfg_.trust_matrix)) cfg_.trust_matrix = defaultTrustMat();
    if (isZeroMat(cfg_.delay_matrix)) cfg_.delay_matrix = defaultDelayMat();
    if (isZeroMat(cfg_.res_matrix))   cfg_.res_matrix   = defaultResMat();
    if (cfg_.P_pay.empty())           cfg_.P_pay        = defaultPpay(cfg_.K);
    if (cfg_.omega_init.empty()) {
        cfg_.omega_init.assign(cfg_.K, 1.0 / static_cast<double>(cfg_.K));
    }
    omega_ = cfg_.omega_init;
}

void RSUGovernanceAggregator::reset() {
    omega_ = cfg_.omega_init;
    omega_index_ = 0;
    acc_pi_ = Vec4{0.0, 0.0, 0.0, 0.0};
    n_evidence_ = 0;
    last_x_bar_ = Vec4{0.25, 0.25, 0.25, 0.25};
}

void RSUGovernanceAggregator::setRngSeed(unsigned int seed) { rng_state_ = seed; }

// —— 静态算法层 ——

Vec3 RSUGovernanceAggregator::projectTheta(const std::vector<double>& omega, const MatPpay& P_pay) {
    Vec3 theta{0.0, 0.0, 0.0};
    for (std::size_t l = 0; l < omega.size() && l < P_pay.size(); ++l) {
        const Vec3& col = P_pay[l];
        for (std::size_t k = 0; k < 3; ++k) theta[k] += omega[l] * col[k];
    }
    double s = theta[0] + theta[1] + theta[2];
    if (s > 0.0) {
        for (auto& v : theta) v /= s;
    } else {
        theta = {1.0/3.0, 1.0/3.0, 1.0/3.0};
    }
    return theta;
}

std::vector<double> RSUGovernanceAggregator::softmaxK(const std::vector<double>& delta) {
    std::vector<double> out(delta.size(), 0.0);
    if (delta.empty()) return out;
    double mx = *std::max_element(delta.begin(), delta.end());
    double s = 0.0;
    for (std::size_t i = 0; i < delta.size(); ++i) {
        out[i] = std::exp(delta[i] - mx);
        s += out[i];
    }
    for (auto& v : out) v /= s;
    return out;
}

std::vector<double> RSUGovernanceAggregator::projectSimplexK(const std::vector<double>& v) {
    std::vector<double> out = v;
    double s = 0.0;
    for (auto& x : out) {
        if (x < 0.0) x = 0.0;
        s += x;
    }
    if (s > 0.0) {
        for (auto& x : out) x /= s;
    } else {
        std::fill(out.begin(), out.end(), 1.0 / static_cast<double>(out.size()));
    }
    return out;
}

// 公式 (4-36)
std::vector<double> RSUGovernanceAggregator::computeDelta(const Vec4& x,
                                                          const std::vector<double>& omega,
                                                          const MatPpay& P_pay,
                                                          const Mat44& trust_mat,
                                                          const Mat44& delay_mat,
                                                          const Mat44& res_mat) {
    Vec3 theta = projectTheta(omega, P_pay);
    auto matVec = [&](const Mat44& M) -> Vec4 {
        Vec4 r{};
        for (std::size_t i = 0; i < 4; ++i) {
            double s = 0.0;
            for (std::size_t j = 0; j < 4; ++j) s += M[i][j] * x[j];
            r[i] = s;
        }
        return r;
    };
    Vec4 mt = matVec(trust_mat);
    Vec4 md = matVec(delay_mat);
    Vec4 mr = matVec(res_mat);
    Vec3 mu_bar{};
    for (std::size_t j = 0; j < 4; ++j) {
        mu_bar[0] += x[j] * mt[j];
        mu_bar[1] += x[j] * md[j];
        mu_bar[2] += x[j] * mr[j];
    }
    Vec4 U_j{};
    for (std::size_t j = 0; j < 4; ++j) {
        U_j[j] = theta[0] * mt[j] + theta[1] * md[j] + theta[2] * mr[j];
    }
    double U_pop = 0.0;
    for (std::size_t j = 0; j < 4; ++j) U_pop += x[j] * U_j[j];

    std::size_t K = omega.size();
    std::vector<double> Delta(K, 0.0);
    for (std::size_t l = 0; l < K && l < P_pay.size(); ++l) {
        const Vec3& col = P_pay[l];
        double marginal = col[0] * mu_bar[0] + col[1] * mu_bar[1] + col[2] * mu_bar[2];
        Delta[l] = marginal - omega[l] * U_pop;
    }
    return Delta;
}

// —— 实例方法 ——

void RSUGovernanceAggregator::accumulateEvidence(const Vec4& pi_vehicle) {
    for (std::size_t j = 0; j < 4; ++j) acc_pi_[j] += pi_vehicle[j];
    ++n_evidence_;
}

void RSUGovernanceAggregator::slowUpdate() {
    if (n_evidence_ > 0) {
        for (std::size_t j = 0; j < 4; ++j) {
            last_x_bar_[j] = acc_pi_[j] / static_cast<double>(n_evidence_);
        }
    }
    std::vector<double> Delta = computeDelta(last_x_bar_, omega_, cfg_.P_pay,
                                             cfg_.trust_matrix, cfg_.delay_matrix, cfg_.res_matrix);
    if (cfg_.observation_noise > 0.0) {
        // 简化 LCG + Box-Muller 噪声（避免 std::normal_distribution 的非确定 seed）
        for (auto& d : Delta) {
            rng_state_ = rng_state_ * 1664525u + 1013904223u;
            double u1 = (rng_state_ & 0x7fffffff) / 2147483648.0;
            rng_state_ = rng_state_ * 1664525u + 1013904223u;
            double u2 = (rng_state_ & 0x7fffffff) / 2147483648.0;
            double n = std::sqrt(-2.0 * std::log(std::max(1e-12, u1))) * std::cos(2.0 * M_PI * u2);
            d += cfg_.observation_noise * n;
        }
    }
    std::vector<double> sigma = softmaxK(Delta);
    std::vector<double> omega_new(omega_.size(), 0.0);
    for (std::size_t l = 0; l < omega_.size(); ++l) {
        double g_l = sigma[l] - omega_[l];
        omega_new[l] = omega_[l] + cfg_.epsilon_g * cfg_.dt * g_l;
    }
    omega_ = projectSimplexK(omega_new);
    ++omega_index_;

    acc_pi_ = Vec4{0.0, 0.0, 0.0, 0.0};
    n_evidence_ = 0;
}

} // namespace chapter52
} // namespace veins

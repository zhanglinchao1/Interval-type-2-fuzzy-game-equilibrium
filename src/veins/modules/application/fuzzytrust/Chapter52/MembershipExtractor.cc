//
// MembershipExtractor.cc — 见 .h 文件头注释
//

#include "MembershipExtractor.h"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace veins {
namespace chapter52 {

namespace {

double clamp01(double x) {
    if (x < 0.0) return 0.0;
    if (x > 1.0) return 1.0;
    return x;
}

}  // anonymous namespace

MembershipExtractor::MembershipExtractor() = default;
MembershipExtractor::MembershipExtractor(const Config& c) : cfg_(c) {}

void MembershipExtractor::setConfig(const Config& c) { cfg_ = c; }

// 高即好：x 大 → 输出接近 1。logistic 1/(1+exp(−(x−c)/s))
double MembershipExtractor::sigmoidHigherIsBetter(double x, double center, double slope) {
    if (slope <= 0.0) throw std::invalid_argument("slope must be > 0");
    double z = (x - center) / slope;
    // 数值稳定 logistic
    if (z >= 0.0) {
        double e = std::exp(-z);
        return 1.0 / (1.0 + e);
    } else {
        double e = std::exp(z);
        return e / (1.0 + e);
    }
}

// 低即好：x 大 → 输出接近 0。镜像版本
double MembershipExtractor::sigmoidLowerIsBetter(double x, double center, double slope) {
    return 1.0 - sigmoidHigherIsBetter(x, center, slope);
}

// μ_trust = sigmoid(α·r − θ)（与 FuzzyTrust IT2-Sigmoid 风格一致）
double MembershipExtractor::extractTrust(const std::vector<double>& reputationVec) const {
    if (reputationVec.size() < cfg_.reputation_weights.size()) {
        // 信誉向量不足 7 维：用已有部分加权
        double s = 0.0, w = 0.0;
        for (std::size_t i = 0; i < reputationVec.size(); ++i) {
            s += cfg_.reputation_weights[i] * reputationVec[i];
            w += cfg_.reputation_weights[i];
        }
        double weighted = (w > 0.0) ? s / w : 0.5;
        return clamp01(sigmoidHigherIsBetter(weighted, cfg_.trust_sigmoid_center, 1.0 / cfg_.trust_sigmoid_slope));
    }
    double weighted = 0.0;
    for (std::size_t i = 0; i < cfg_.reputation_weights.size(); ++i) {
        weighted += cfg_.reputation_weights[i] * reputationVec[i];
    }
    // sigmoid slope 字段在 .h 里语义是"陡度"，这里换算成 logistic 的 scale = 1/slope
    return clamp01(sigmoidHigherIsBetter(weighted, cfg_.trust_sigmoid_center, 1.0 / cfg_.trust_sigmoid_slope));
}

// μ_delay = min(sig_low(RTT), sig_low(loss))
double MembershipExtractor::extractDelay(double rtt_ms, double pkt_loss) const {
    double mu_rtt = sigmoidLowerIsBetter(rtt_ms, cfg_.rtt_center_ms, cfg_.rtt_slope_ms);
    double mu_loss = sigmoidLowerIsBetter(pkt_loss, cfg_.loss_center, cfg_.loss_slope);
    return clamp01(std::min(mu_rtt, mu_loss));
}

// μ_res = min(sig_low(cpu), sig_low(bw), sig_high(energy)[, sig_low(power)])
double MembershipExtractor::extractRes(double cpu, double bw, double energy, double power) const {
    double mu_c = sigmoidLowerIsBetter(cpu, cfg_.cpu_center, cfg_.cpu_slope);
    double mu_b = sigmoidLowerIsBetter(bw,  cfg_.bw_center,  cfg_.bw_slope);
    double mu_e = sigmoidHigherIsBetter(energy, cfg_.energy_center, cfg_.energy_slope);
    double mu = std::min({mu_c, mu_b, mu_e});
    if (cfg_.include_power) {
        double mu_p = sigmoidLowerIsBetter(power, cfg_.power_center, cfg_.power_slope);
        mu = std::min(mu, mu_p);
    }
    return clamp01(mu);
}

Vec3 MembershipExtractor::extractAll(const std::vector<double>& reputationVec,
                                     double rtt_ms, double pkt_loss,
                                     double cpu, double bw, double energy, double power) const {
    Vec3 out{};
    out[0] = extractTrust(reputationVec);
    out[1] = extractDelay(rtt_ms, pkt_loss);
    out[2] = extractRes(cpu, bw, energy, power);
    return out;
}

} // namespace chapter52
} // namespace veins

//
// Chapter52MetricsLogger.cc — 见 .h 文件头注释
//

#include "Chapter52MetricsLogger.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>      // system
#include <fstream>
#include <iomanip>
#include <numeric>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>

namespace veins {
namespace chapter52 {

namespace {

// 递归创建目录（mkdir -p 风格）。失败返回 false。
bool mkdirRecursive(const std::string& path) {
    if (path.empty()) return false;
    std::string cur;
    for (std::size_t i = 0; i < path.size(); ++i) {
        if (path[i] == '/') {
            if (!cur.empty()) {
                ::mkdir(cur.c_str(), 0755);
            }
        }
        cur.push_back(path[i]);
    }
    if (!cur.empty() && cur.back() != '/') {
        ::mkdir(cur.c_str(), 0755);
    }
    return true;
}

std::string dirname(const std::string& path) {
    auto p = path.find_last_of('/');
    if (p == std::string::npos) return ".";
    return path.substr(0, p);
}

double l1Distance(const Vec4& a, const Vec4& b) {
    double s = 0.0;
    for (std::size_t j = 0; j < 4; ++j) s += std::fabs(a[j] - b[j]);
    return s;
}

}  // anonymous namespace

Chapter52MetricsLogger::Chapter52MetricsLogger()
    : next_emit_t_s_(0.0), last_now_s_(0.0) {}

Chapter52MetricsLogger::Chapter52MetricsLogger(const Config& c)
    : cfg_(c), next_emit_t_s_(c.log_interval_s), last_now_s_(0.0) {}

double Chapter52MetricsLogger::quantile(std::vector<double>& v, double q) {
    if (v.empty()) return 0.0;
    if (q <= 0.0) return *std::min_element(v.begin(), v.end());
    if (q >= 1.0) return *std::max_element(v.begin(), v.end());
    std::sort(v.begin(), v.end());
    double idx = q * (static_cast<double>(v.size()) - 1.0);
    std::size_t lo = static_cast<std::size_t>(std::floor(idx));
    std::size_t hi = static_cast<std::size_t>(std::ceil(idx));
    if (lo == hi) return v[lo];
    double frac = idx - static_cast<double>(lo);
    return v[lo] * (1.0 - frac) + v[hi] * frac;
}

double Chapter52MetricsLogger::mean(const std::vector<double>& v) {
    if (v.empty()) return 0.0;
    double s = std::accumulate(v.begin(), v.end(), 0.0);
    return s / static_cast<double>(v.size());
}

void Chapter52MetricsLogger::maybeRollover(double now_s) {
    if (cfg_.log_interval_s <= 0.0) return;
    if (next_emit_t_s_ <= 0.0) {
        next_emit_t_s_ = cfg_.log_interval_s;
    }
    while (now_s >= next_emit_t_s_) {
        emitRow(next_emit_t_s_);
        next_emit_t_s_ += cfg_.log_interval_s;
    }
}

void Chapter52MetricsLogger::emitRow(double t_end_s) {
    Row r{};
    r.t_s = t_end_s;
    r.n_sent = n_sent_window_;
    r.n_received = n_recv_window_;
    r.pdr = (n_sent_window_ > 0) ? static_cast<double>(n_recv_window_) / static_cast<double>(n_sent_window_) : 0.0;
    if (!latency_ms_window_.empty()) {
        // quantile 会就地排序；先算 mean 再 quantile
        r.avg_latency_ms = mean(latency_ms_window_);
        // 拷贝一份避免影响 mean，但 mean 已算完，可直接就地
        r.p95_latency_ms = quantile(latency_ms_window_, 0.95);
        r.p99_latency_ms = quantile(latency_ms_window_, 0.99);
    } else {
        r.avg_latency_ms = 0.0;
        r.p95_latency_ms = 0.0;
        r.p99_latency_ms = 0.0;
    }
    r.switches = n_switches_window_;
    r.avg_uhat = mean(uhat_window_);
    r.avg_rho = mean(rho_window_);
    r.last_residual = last_residual_;
    r.task_generated = task_generated_window_;
    r.task_completed = task_completed_window_;
    r.task_completion_rate = (task_generated_window_ > 0) ? static_cast<double>(task_completed_window_) / static_cast<double>(task_generated_window_) : 0.0;
    r.coop_success_rate = (task_generated_window_ > 0) ? static_cast<double>(coop_success_window_) / static_cast<double>(task_generated_window_) : 0.0;
    r.malicious_participation_rate = (malicious_candidates_window_ > 0) ? static_cast<double>(malicious_participants_window_) / static_cast<double>(malicious_candidates_window_) : 0.0;
    r.low_trust_participation_rate = (low_trust_candidates_window_ > 0) ? static_cast<double>(low_trust_participants_window_) / static_cast<double>(low_trust_candidates_window_) : 0.0;
    r.avg_epsilon_req = mean(epsilon_req_window_);
    r.avg_epsilon_budget = mean(epsilon_budget_window_);
    r.epsilon_violation_rate = (epsilon_checks_window_ > 0) ? static_cast<double>(epsilon_violations_window_) / static_cast<double>(epsilon_checks_window_) : 0.0;
    r.raw_uhat = r.avg_uhat;
    r.effective_uhat = r.avg_uhat;

    // D4：分维度隶属度滑窗半宽 hw_k = (max−min)/2（窗口不足 2 样本时为 0）
    double hw[3] = {0.0, 0.0, 0.0};
    for (std::size_t k = 0; k < 3; ++k) {
        if (mu_window_[k].size() >= 2) {
            auto mm = std::minmax_element(mu_window_[k].begin(), mu_window_[k].end());
            hw[k] = 0.5 * (*mm.second - *mm.first);
        }
    }
    r.hw_trust = hw[0];
    r.hw_delay = hw[1];
    r.hw_res = hw[2];
    // D4：按策略分组收益均值 / 标准差（全程累积 Welford 快照）
    for (std::size_t j = 0; j < 4; ++j) {
        r.strat_u_n[j] = strat_payoff_[j].n;
        r.strat_u_mean[j] = strat_payoff_[j].mean;
        r.strat_u_std[j] = (strat_payoff_[j].n >= 2)
            ? std::sqrt(strat_payoff_[j].M2 / static_cast<double>(strat_payoff_[j].n - 1))
            : 0.0;
    }
    r.realized_uhat = mean(realized_window_);
    rows_.push_back(r);

    // 清空当前窗口（保留累积 total）
    n_sent_window_ = 0;
    n_recv_window_ = 0;
    n_switches_window_ = 0;
    latency_ms_window_.clear();
    uhat_window_.clear();
    rho_window_.clear();
    epsilon_req_window_.clear();
    epsilon_budget_window_.clear();
    realized_window_.clear();
    strategy_dirty_window_ = false;
    task_generated_window_ = 0;
    task_completed_window_ = 0;
    coop_success_window_ = 0;
    epsilon_checks_window_ = 0;
    epsilon_violations_window_ = 0;
    malicious_candidates_window_ = 0;
    malicious_participants_window_ = 0;
    low_trust_candidates_window_ = 0;
    low_trust_participants_window_ = 0;
}

void Chapter52MetricsLogger::recordWSMSent(double now_s) {
    last_now_s_ = now_s;
    ++n_sent_total_;
    ++n_sent_window_;
    maybeRollover(now_s);
}

void Chapter52MetricsLogger::recordWSMReceived(double now_s, double latency_s) {
    last_now_s_ = now_s;
    ++n_recv_total_;
    ++n_recv_window_;
    if (latency_ms_window_.size() < cfg_.latency_window_max) {
        latency_ms_window_.push_back(latency_s * 1000.0);
    }
    maybeRollover(now_s);
}

void Chapter52MetricsLogger::recordStrategy(double now_s, const std::string& action, const Vec4& pi_new) {
    last_now_s_ = now_s;
    if (!last_action_.empty() && action != last_action_) {
        ++n_switches_total_;
        ++n_switches_window_;
    }
    last_action_ = action;
    if (!pi_history_.empty()) {
        last_residual_ = l1Distance(pi_history_.back(), pi_new);
    }
    pi_history_.push_back(pi_new);
    if (pi_history_.size() > cfg_.residual_window) {
        pi_history_.pop_front();
    }
    strategy_dirty_window_ = true;
    maybeRollover(now_s);
}

void Chapter52MetricsLogger::recordUhat(double u_hat) {
    if (uhat_window_.size() < cfg_.latency_window_max) {
        uhat_window_.push_back(u_hat);
    }
}

void Chapter52MetricsLogger::recordRho(double rho) {
    if (rho_window_.size() < cfg_.latency_window_max) {
        rho_window_.push_back(rho);
    }
}

void Chapter52MetricsLogger::recordTask(double now_s, bool completed, bool cooperative_success) {
    last_now_s_ = now_s;
    ++task_generated_window_;
    if (completed) ++task_completed_window_;
    if (cooperative_success) ++coop_success_window_;
    maybeRollover(now_s);
}

void Chapter52MetricsLogger::recordRobustness(double epsilon_req, double epsilon_budget, bool violation) {
    if (epsilon_req_window_.size() < cfg_.latency_window_max) {
        epsilon_req_window_.push_back(epsilon_req);
        epsilon_budget_window_.push_back(epsilon_budget);
    }
    ++epsilon_checks_window_;
    if (violation) ++epsilon_violations_window_;
}

void Chapter52MetricsLogger::recordMembership(double mu_trust, double mu_delay, double mu_res) {
    const double mus[3] = {mu_trust, mu_delay, mu_res};
    for (std::size_t k = 0; k < 3; ++k) {
        mu_window_[k].push_back(mus[k]);
        if (mu_window_[k].size() > kMuWindow) mu_window_[k].pop_front();
    }
}

void Chapter52MetricsLogger::recordStrategyPayoff(const std::string& action, double u_hat) {
    static const char* kNames[4] = {"SC", "SP", "DC", "DP"};
    for (std::size_t j = 0; j < 4; ++j) {
        if (action == kNames[j]) {
            WelfordStat& w = strat_payoff_[j];
            ++w.n;
            double delta = u_hat - w.mean;
            w.mean += delta / static_cast<double>(w.n);
            w.M2 += delta * (u_hat - w.mean);
            return;
        }
    }
}

void Chapter52MetricsLogger::recordRealizedPayoff(double realized) {
    if (realized_window_.size() < cfg_.latency_window_max) {
        realized_window_.push_back(realized);
    }
}

void Chapter52MetricsLogger::recordGovernanceExposure(bool is_malicious, bool is_low_trust, bool participates) {
    if (is_malicious) {
        ++malicious_candidates_window_;
        if (participates) ++malicious_participants_window_;
    }
    if (is_low_trust) {
        ++low_trust_candidates_window_;
        if (participates) ++low_trust_participants_window_;
    }
}

bool Chapter52MetricsLogger::flushToCSV(const std::string& filepath) {
    // 在写之前，如果当前窗口还有未导出的数据，先 emit 一行（用 last_now_s_）
    if (n_sent_window_ > 0 || n_recv_window_ > 0 || !latency_ms_window_.empty()
        || !uhat_window_.empty() || !rho_window_.empty() || !epsilon_req_window_.empty()
        || task_generated_window_ > 0 || n_switches_window_ > 0
        || strategy_dirty_window_) {
        emitRow(last_now_s_);
    }

    mkdirRecursive(dirname(filepath));
    std::ofstream ofs(filepath);
    if (!ofs.is_open()) return false;
    ofs << std::fixed << std::setprecision(6);
    ofs << "t_s,n_sent,n_received,pdr,avg_latency_ms,p95_latency_ms,p99_latency_ms,"
           "switches,avg_uhat,avg_rho,last_residual,"
           "task_generated,task_completed,task_completion_rate,coop_success_rate,"
           "malicious_participation_rate,low_trust_participation_rate,"
           "avg_epsilon_req,avg_epsilon_budget,epsilon_violation_rate,"
           "raw_uhat,effective_uhat,"
           "hw_trust,hw_delay,hw_res,"
           "u_sc_n,u_sc_mean,u_sc_std,u_sp_n,u_sp_mean,u_sp_std,"
           "u_dc_n,u_dc_mean,u_dc_std,u_dp_n,u_dp_mean,u_dp_std,"
           "realized_uhat\n";
    for (const auto& r : rows_) {
        ofs << r.t_s << ',' << r.n_sent << ',' << r.n_received << ',' << r.pdr << ','
            << r.avg_latency_ms << ',' << r.p95_latency_ms << ',' << r.p99_latency_ms << ','
            << r.switches << ',' << r.avg_uhat << ',' << r.avg_rho << ','
            << r.last_residual << ','
            << r.task_generated << ',' << r.task_completed << ','
            << r.task_completion_rate << ',' << r.coop_success_rate << ','
            << r.malicious_participation_rate << ',' << r.low_trust_participation_rate << ','
            << r.avg_epsilon_req << ',' << r.avg_epsilon_budget << ','
            << r.epsilon_violation_rate << ','
            << r.raw_uhat << ',' << r.effective_uhat << ','
            << r.hw_trust << ',' << r.hw_delay << ',' << r.hw_res;
        for (std::size_t j = 0; j < 4; ++j) {
            ofs << ',' << r.strat_u_n[j] << ',' << r.strat_u_mean[j] << ',' << r.strat_u_std[j];
        }
        ofs << ',' << r.realized_uhat << '\n';
    }
    return true;
}

} // namespace chapter52
} // namespace veins

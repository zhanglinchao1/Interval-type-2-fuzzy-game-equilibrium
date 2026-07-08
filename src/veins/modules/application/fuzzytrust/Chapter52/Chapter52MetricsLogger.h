//
// Chapter52MetricsLogger.h — chapter 5.2 表 5-6 / 5-9 指标采集与 CSV 导出
//
// 设计契约（plan.MD §2.4）：
//   通信性能：平均时延 / p95 / p99 / 丢包率 / PDR
//   任务性能：Û 时间平均（= 平均任务收益）
//   策略稳定性：策略切换次数；W-FBRI 滑动窗口残差（用于"收敛"判定）
//   鲁棒性：ρ 时间序列（消融实验二用）
//
// 数据流：
//   FuzzyTrustApp::onWSM      → recordWSMReceived(latencyS)
//   FuzzyTrustApp::sendDown   → recordWSMSent()         （发出去就 +1）
//   FuzzyTrustApp::recordStrategySelection → recordStrategy(action_str) +
//                                            recordUhat(...) + recordRho(...)
//   FuzzyTrustApp::finish     → flushToCSV(filepath)
//
// 输出 CSV 列（plan §2.4）：
//   t_s, n_sent, n_received, pdr, avg_latency_ms, p95_latency_ms, p99_latency_ms,
//   switches, avg_uhat, avg_rho, last_residual
//
// 不依赖 OMNeT++ / Veins — 纯标准库，可 standalone 测试。
//

#pragma once

#include "veins/modules/application/fuzzytrust/Chapter52/ITGameEngine.h"  // Vec4

#include <array>
#include <deque>
#include <string>
#include <vector>

namespace veins {
namespace chapter52 {

class Chapter52MetricsLogger {
public:
    struct Config {
        double log_interval_s = 10.0;          // CSV 每 10s 一行
        std::size_t latency_window_max = 100000;  // 单窗口最多保留时延样本数
        std::size_t residual_window = 50;      // π 切换 / 残差滑动窗口
    };

    Chapter52MetricsLogger();
    explicit Chapter52MetricsLogger(const Config& c);

    // —— 通信事件 ——
    void recordWSMSent(double now_s);
    void recordWSMReceived(double now_s, double latency_s);

    // —— 策略事件 ——
    // action: "SC" / "SP" / "DC" / "DP"；pi_new 用于残差计算
    void recordStrategy(double now_s, const std::string& action, const Vec4& pi_new);
    void recordUhat(double u_hat);
    void recordRho(double rho);
    void recordTask(double now_s, bool completed, bool cooperative_success);
    void recordRobustness(double epsilon_req, double epsilon_budget, bool violation);
    void recordGovernanceExposure(bool is_malicious, bool is_low_trust, bool participates);

    // —— D4 外部标定（plan §五 D4） ——
    // 每决策周期记录实测名义隶属度 (trust, delay, res)；行输出时给出滑窗半宽
    // hw_k = (max−min)/2，用于与声明 δ 对比（同量级检验）
    void recordMembership(double mu_trust, double mu_delay, double mu_res);
    // 按策略分组的收益离散度（"高名义收益⇔高暴露"耦合方向检验）：
    // action ∈ {"SC","SP","DC","DP"}，u_hat 为该次决策的 Û；Welford 全程累积
    void recordStrategyPayoff(const std::string& action, double u_hat);

    // 已实现收益（威胁模型实现后的结果计量）：协作任务因异常伙伴失败时
    // 该决策窗口的已实现收益为 0，否则等于模型收益 Û。纯测量，无方法名依赖。
    void recordRealizedPayoff(double realized);

    // —— 导出 ——
    // 写入 CSV；filepath 应是完整路径（含目录），目录会被自动创建
    bool flushToCSV(const std::string& filepath);

    // —— 查询（catch 测试 / debug） ——
    std::size_t totalSent() const { return n_sent_total_; }
    std::size_t totalReceived() const { return n_recv_total_; }
    std::size_t totalSwitches() const { return n_switches_total_; }
    std::size_t numCsvRows() const { return rows_.size(); }

    // —— 算法层（public 便于测试） ——
    static double quantile(std::vector<double>& sorted_or_inplace, double q);
    static double mean(const std::vector<double>& v);

private:
    void maybeRollover(double now_s);     // 跨过 log_interval 触发汇总行
    void emitRow(double t_end_s);          // 把当前窗口数据汇总成一行

    struct Row {
        double t_s;
        std::size_t n_sent;
        std::size_t n_received;
        double pdr;
        double avg_latency_ms;
        double p95_latency_ms;
        double p99_latency_ms;
        std::size_t switches;
        double avg_uhat;
        double avg_rho;
        double last_residual;
        std::size_t task_generated;
        std::size_t task_completed;
        double task_completion_rate;
        double coop_success_rate;
        double malicious_participation_rate;
        double low_trust_participation_rate;
        double avg_epsilon_req;
        double avg_epsilon_budget;
        double epsilon_violation_rate;
        double raw_uhat;
        double effective_uhat;
        // D4: 分维度隶属度滑窗半宽 + 按策略收益均值/标准差（全程累积快照）
        double hw_trust;
        double hw_delay;
        double hw_res;
        std::array<double, 4> strat_u_mean;   // SC, SP, DC, DP
        std::array<double, 4> strat_u_std;
        std::array<std::size_t, 4> strat_u_n;
        double realized_uhat;                 // 窗口内已实现收益均值
    };

    Config cfg_;
    double next_emit_t_s_;
    double last_now_s_;

    // —— 累积计数（全程） ——
    std::size_t n_sent_total_ = 0;
    std::size_t n_recv_total_ = 0;
    std::size_t n_switches_total_ = 0;

    // —— 当前窗口（每次 emit 后清空） ——
    std::size_t n_sent_window_ = 0;
    std::size_t n_recv_window_ = 0;
    std::size_t n_switches_window_ = 0;
    std::vector<double> latency_ms_window_;
    std::vector<double> uhat_window_;
    std::vector<double> rho_window_;
    std::vector<double> epsilon_req_window_;
    std::vector<double> epsilon_budget_window_;
    std::string last_action_;
    std::deque<Vec4> pi_history_;          // 用于 residual = ‖π_t − π_{t−1}‖₁
    double last_residual_ = 0.0;
    bool strategy_dirty_window_ = false;   // recordStrategy 触发，emit 后清
    std::size_t task_generated_window_ = 0;
    std::size_t task_completed_window_ = 0;
    std::size_t coop_success_window_ = 0;
    std::size_t epsilon_checks_window_ = 0;
    std::size_t epsilon_violations_window_ = 0;
    std::size_t malicious_candidates_window_ = 0;
    std::size_t malicious_participants_window_ = 0;
    std::size_t low_trust_candidates_window_ = 0;
    std::size_t low_trust_participants_window_ = 0;

    // —— D4 状态 ——
    static constexpr std::size_t kMuWindow = 15;      // 滑窗样本数（2s 决策周期 ≈ 30s）
    std::array<std::deque<double>, 3> mu_window_;     // trust / delay / res
    struct WelfordStat {
        std::size_t n = 0;
        double mean = 0.0;
        double M2 = 0.0;
    };
    std::array<WelfordStat, 4> strat_payoff_;         // SC, SP, DC, DP
    std::vector<double> realized_window_;             // 当前窗口已实现收益样本

    std::vector<Row> rows_;
};

} // namespace chapter52
} // namespace veins

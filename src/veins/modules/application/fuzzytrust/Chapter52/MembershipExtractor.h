//
// MembershipExtractor.h — Chapter 5.2 状态隶属度抽取
//
// 把场景层采集的标量（信誉向量、RTT、丢包、CPU/带宽/能量/功耗）映射为
// 三维名义隶属度 (μ_trust, μ_delay, μ_res) ∈ [0,1]^3，供 ITGameEngine.step() 消费。
//
// 设计契约（plan.MD §2.2 + §7.3 风险点 3）：
//   - sigmoid 中心和斜率配置使 μ 经常触及 [0, δ] 或 [1−δ, 1] 边界
//     →消融实验 NoIT2（δ=0）vs Full Proposed（δ=0.10）才能在 Û 上区分
//   - 不依赖 FuzzyTrust/ResourceManager（避免 standalone 测试链接 Veins）
//     算法与 IT2-Sigmoid / Choquet 风格保持兼容，可日后用重载切换
//   - 全部为 const 方法：extractor 无状态，可在所有节点共享一份配置
//
// 验证标准（plan §6.2 M2 第 4-5 步）：
//   - 单调性：dRTT > 0 → dμ_delay < 0；dloss > 0 → dμ_delay < 0
//   - 值域：所有输出 ∈ [0, 1]
//   - 边界触及率：在场景化输入分布下 ≥ 30% 落入 [0, 0.10] ∪ [0.90, 1.0]
//

#pragma once

#include "veins/modules/application/fuzzytrust/Chapter52/ITGameEngine.h"   // Vec3

#include <array>
#include <vector>

namespace veins {
namespace chapter52 {

class MembershipExtractor {
public:
    struct Config {
        // —— μ_trust：信誉向量 → 加权得分 → sigmoid 落到 [0,1] ——
        // 7 维信誉权重 α（与 FuzzyTrust IT2-Sigmoid 默认对齐）
        std::array<double, 7> reputation_weights = {0.22, 0.15, 0.14, 0.13, 0.12, 0.12, 0.12};
        double trust_sigmoid_center = 0.50;   // sigmoid 中心
        double trust_sigmoid_slope  = 20.0;   // 较陡 → 易触 [0, 0.1]∪[0.9, 1]（plan §7.3）

        // —— μ_delay：RTT 越大越差；丢包越多越差。两者取最小 ——
        double rtt_center_ms        = 50.0;   // 50ms 为"好/坏"分界
        double rtt_slope_ms         = 8.0;    // 斜率（越小越陡）
        double loss_center          = 0.05;   // 5% 丢包为分界
        double loss_slope           = 0.012;

        // —— μ_res：CPU/BW 越占用越差，能量越低越差；min 聚合 ——
        double cpu_center           = 0.70;
        double cpu_slope            = 0.08;
        double bw_center            = 0.70;
        double bw_slope             = 0.08;
        double energy_center        = 0.30;   // 30% 电量为分界
        double energy_slope         = 0.05;
        bool   include_power        = false;  // 默认不把功耗纳入（power 单位变化大）
        double power_center         = 0.70;
        double power_slope          = 0.10;
    };

    MembershipExtractor();
    explicit MembershipExtractor(const Config& c);
    void setConfig(const Config& c);
    const Config& config() const { return cfg_; }

    // —— 单项 extract ——
    double extractTrust(const std::vector<double>& reputationVec) const;
    double extractDelay(double rtt_ms, double pkt_loss) const;
    double extractRes(double cpu, double bw, double energy, double power) const;

    // —— 一次性 ——
    Vec3 extractAll(const std::vector<double>& reputationVec,
                    double rtt_ms, double pkt_loss,
                    double cpu, double bw, double energy, double power) const;

    // —— 算法层（public 便于测试 / 复用） ——
    static double sigmoidHigherIsBetter(double x, double center, double slope);  // x↑ → 输出↑
    static double sigmoidLowerIsBetter (double x, double center, double slope);  // x↑ → 输出↓

private:
    Config cfg_;
};

} // namespace chapter52
} // namespace veins

#ifndef OWA_RL_AGENT_H
#define OWA_RL_AGENT_H

#include <vector>
#include "../../json.hpp"
#include "../collector/OWARLWeightCollector.h"

class OWARLAgent {
public:
    // 构造函数：可选传入 config，或后续 loadConfig
    OWARLAgent();
    explicit OWARLAgent(const nlohmann::json& config);

    // 从 json 配置加载参数
    void loadConfig(const nlohmann::json& config);

    // 输入新一组隶属度（trust, delay, resource），更新权重
    void updateWeights(const std::vector<double>& mu_vec);

    // 返回当前权重下的 OWA 综合收益
    double getReward(const std::vector<double>& mu_vec) const;

    // 获取当前 OWA 权重
    std::vector<double> getWeights() const;

    // 重置权重为初始值
    void reset();

    // Weight tracking methods
    void enableWeightTracking(bool enable = true);
    void setWeightCollector(std::shared_ptr<OWARLWeightCollector> collector);
    void recordWeightEvolution(double timestamp, const std::vector<double>& membership_values, const std::string& scenario = "");

    // 辅助方法
    double computeOWA(const std::vector<double>& values);
    std::vector<double> computePotentialGameGradient(const std::vector<double>& outcomes);
    std::vector<double> computeRegularizationGradient();
    void checkConvergence();
    void projectToSimplex();

private:
    // 降序排序工具
    static std::vector<double> sort_desc(const std::vector<double>& mu_vec);

    // OWA 聚合公式
    static double calcOWAReward(const std::vector<double>& mu_sorted, const std::vector<double>& w);

    std::vector<double> w;        // OWA权重
    std::vector<double> w_prior;  // 先验权重
    
    // 配置参数
    double eta_learning;          // 在线学习率η
    double lambda_regularization; // 正则化参数λ
    int max_steps;                // 最大学习步数
    double potential_game_alpha;  // 潜在博弈参数α
    double potential_game_beta;   // 潜在博弈参数β
    double convergence_threshold; // 收敛阈值
    size_t history_window_size;   // 历史窗口大小
    
    // 运行时变量
    int current_step;             // 当前步数计数器
    
    // 历史记录
    std::vector<std::pair<std::vector<double>, double>> history;

    // 历史排序后 μ
    std::vector<std::vector<double>> mu_hist;
    int step;

    // OWA 权重、先验、初始
    std::vector<double> w_init;
    double eta;
    double lambda;
    
    // Weight tracking
    bool weight_tracking_enabled;
    std::shared_ptr<OWARLWeightCollector> weight_collector;
    std::vector<double> last_membership_values;
    
    // 累积隶属度历史（用于无悔学习）
    std::vector<double> cumulative_membership_sum;
};

#endif

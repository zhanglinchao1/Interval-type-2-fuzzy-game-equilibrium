#ifndef GAME_MANAGER_H
#define GAME_MANAGER_H

#include <vector>
#include <chrono>
#include "json.hpp"

// 前向声明
class FuzzyInferenceEngine;
namespace veins {
    class FuzzyTrustApp;
}

class GameManager {
public:
    GameManager();
    explicit GameManager(const nlohmann::json& config);

    // 加载 json 配置
    void loadConfig(const nlohmann::json& config);

    // 车辆端复制动态主函数，输入各策略收益，更新概率分布
    void updateVehicleStrategy(const std::vector<double>& payoffs);

    // RSU 端 Q-learning 主函数，输入当前收益，更新 Q 表
    void updateRSUStrategy(int state, int action, double reward, int next_state);

    // 获取当前车辆策略概率分布
    std::vector<double> getVehicleStrategyProb() const;

    // 获取当前 RSU Q 表
    std::vector<double> getRSUQTable() const;

    // 采样车辆动作（轮盘法）
    int selectVehicleAction() const;

    // 采样 RSU 动作（ε-贪心）
    int selectRSUAction(int state);

    void evolveGame();
    
    // 双时间尺度演化辅助方法
    std::vector<double> computeVehiclePayoffs();
    void performSlowTimescaleUpdate();
    double computeRSUReward();

    // 重置所有状态
    void reset();

    // 双时间尺度演化相关方法
    double getFastTimeElapsed() const;           // 获取快时标经过时间（毫秒）
    void updateSlowTimeBlocks();                 // 更新慢时标区块计数
    int getSlowTimeBlocks() const;               // 获取慢时标区块数
    void resetTimeCounters();                    // 重置时间计数器
    
    // 与FuzzyInferenceEngine协调的双时间尺度更新
    void coordinatedTimescaleUpdate(FuzzyInferenceEngine* fuzzy_engine);
    
    // 设置关联的FuzzyTrustApp实例（用于策略选择记录）
    void setFuzzyTrustApp(veins::FuzzyTrustApp* app);

private:
    // 成员变量
    std::vector<double> x_j;  // 车辆策略概率
    std::vector<double> U_j;  // 车辆收益
    std::vector<std::vector<double>> Q_r;  // RSU Q表
    
    // 配置参数
    double delta_replicator;     // 复制动态学习率δ
    double noise_variance;       // 复制动态噪声方差
    double max_step_size;        // 最大步长限制
    double alpha_rsu;            // RSU Q-learning学习率
    double epsilon_rsu;          // RSU ε-贪心探索率
    double fast_timescale_dt;    // 快时标时间步长
    int slow_timescale_blocks;   // 慢时标区块数
    double gamma_discount;       // Q-learning折扣因子
    
    // 时间计数器
    double fast_time_elapsed;    // 快时标已过时间
    int slow_time_blocks;        // 慢时标区块计数
    
    // 其他成员变量
    double avg_U;                 // 平均收益
    int rsu_action;               // 当前动作
    int step;                     // 步数计数
    std::chrono::steady_clock::time_point fast_time_start;  // 快时标起始时间
    
    // 配置存储
    nlohmann::json config;
    
    // 关联的FuzzyTrustApp实例（用于策略选择记录）
    veins::FuzzyTrustApp* fuzzyTrustApp;
};

#endif

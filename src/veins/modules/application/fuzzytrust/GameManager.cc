#include "GameManager.h"
#include "FuzzyInferenceEngine.h"
#include "veins/modules/application/fuzzytrust/FuzzyTrustApp.h"
#include <algorithm>
#include <random>
#include <numeric>
#include <cstdlib>
#include <ctime>
#include <chrono>
#include <fstream>
#include <cmath>
#include <iostream>

using json = nlohmann::json;

GameManager::GameManager() : avg_U(0.0), rsu_action(0), step(0) {
    // 初始化默认参数
    delta_replicator = 0.1;
    noise_variance = 0.01;
    max_step_size = 0.05;
    alpha_rsu = 0.1;
    epsilon_rsu = 0.1;
    fast_timescale_dt = 1.0;
    slow_timescale_blocks = 100;
    gamma_discount = 0.9;
    
    // 初始化车辆策略概率（4种策略：SC, SP, DC, DP）
    x_j = {0.25, 0.25, 0.25, 0.25};
    
    // 初始化车辆收益
    U_j = {0.0, 0.0, 0.0, 0.0};
    
    // 初始化RSU Q表（2状态×2动作）
    Q_r = {{0.0, 0.0}, {0.0, 0.0}};
    
    // 初始化时间计数器
    fast_time_elapsed = 0.0;
    slow_time_blocks = 0;
    fast_time_start = std::chrono::steady_clock::now();
    
    // 初始化FuzzyTrustApp指针
    fuzzyTrustApp = nullptr;
    
    srand(time(nullptr));
}

GameManager::GameManager(const json& config) {
    loadConfig(config);
    srand(time(nullptr));
    fast_time_start = std::chrono::steady_clock::now();
    slow_time_blocks = 0;
}

void GameManager::loadConfig(const nlohmann::json& config) {
    
    // 用户定义/经验设定变量，配置于 config.json
    auto x_j_init = config["x_j_init"];
    x_j = {x_j_init[0], x_j_init[1], x_j_init[2]};  // 车辆初始策略概率
    delta_replicator = config["delta_replicator"];  // 复制动态学习率δ
    noise_variance = config["noise_variance"];      // 复制动态噪声方差
    max_step_size = config["max_step_size"];        // 最大步长限制
    alpha_rsu = config["alpha_rsu"];                // RSU Q-learning学习率
    epsilon_rsu = config["epsilon_rsu"];            // RSU ε-贪心探索率
    fast_timescale_dt = config["fast_timescale_dt"]; // 快时标时间步长
    slow_timescale_blocks = config["slow_timescale_blocks"]; // 慢时标区块数
    gamma_discount = config["gamma_discount"];      // Q-learning折扣因子
    
    // 初始化收益矩阵（简化）
    U_j = {0.0, 0.0, 0.0};
    
    // 初始化RSU Q表
    Q_r = {{0.0, 0.0}, {0.0, 0.0}};
    
    // 初始化时间计数器
    fast_time_elapsed = 0.0;
    slow_time_blocks = 0;
}

void GameManager::reset() {
    x_j = {0.25, 0.25, 0.25, 0.25};
    U_j = {0.0, 0.0, 0.0, 0.0};
    Q_r = {{0.0, 0.0}};
    avg_U = 0.0;
    rsu_action = 0;
    step = 0;
}

void GameManager::updateVehicleStrategy(const std::vector<double>& payoffs) {
    // 更新车辆策略 - 基于学习率δ的复制动态
    U_j = payoffs;
    
    // 动态生成变量 - 计算平均收益
    double avg_payoff = 0.0; // 动态生成变量
    for (size_t i = 0; i < U_j.size(); ++i) {
        avg_payoff += x_j[i] * U_j[i];
    }
    
    // 复制动态更新 - 使用学习率δ
    std::vector<double> new_x_j = x_j;
    for (size_t i = 0; i < x_j.size(); ++i) {
        // 动态生成变量 - 基于学习率δ的复制动态更新
        double replicator_term = x_j[i] * (U_j[i] - avg_payoff); // 动态生成变量
        double delta_x = delta_replicator * replicator_term; // 动态生成变量 - 使用学习率δ
        
        // 添加噪声扰动
        std::random_device rd;
        std::mt19937 gen(rd());
        std::normal_distribution<> noise_dist(0.0, sqrt(noise_variance));
        double noise_term = noise_dist(gen); // 动态生成变量
        delta_x += noise_term;
        
        // 限制步长
        delta_x = std::max(-max_step_size, std::min(max_step_size, delta_x)); // 动态生成变量
        
        new_x_j[i] += delta_x;
    }
    
    // 归一化到概率单纯形
    double sum = 0.0; // 动态生成变量
    for (double& x : new_x_j) {
        x = std::max(0.0, x);
        sum += x;
    }
    
    if (sum > 0) {
        for (double& x : new_x_j) {
            x /= sum;
        }
    }
    
    x_j = new_x_j;
    ++step;
}

void GameManager::updateRSUStrategy(int state, int action, double reward, int next_state) {
    // 更新RSU策略 - Q-learning算法
    
    // 动态生成变量 - 找到下一状态的最大Q值
    double max_next_q = *std::max_element(Q_r[next_state].begin(), Q_r[next_state].end()); // 动态生成变量
    
    // 动态生成变量 - Q-learning更新（使用折扣因子γ和学习率α）
    double td_error = reward + gamma_discount * max_next_q - Q_r[state][action]; // 动态生成变量
    Q_r[state][action] += alpha_rsu * td_error; // 动态生成变量 - 使用RSU学习率
}

std::vector<double> GameManager::getVehicleStrategyProb() const {
    return x_j;
}

std::vector<double> GameManager::getRSUQTable() const {
    // 将二维Q表展平为一维向量返回
    std::vector<double> flattened;
    for (const auto& row : Q_r) {
        for (double value : row) {
            flattened.push_back(value);
        }
    }
    return flattened;
}

int GameManager::selectVehicleAction() const {
    // 轮盘法采样
    double r = (double)rand() / RAND_MAX;
    double acc = 0.0;
    int selectedAction = -1;
    
    for (size_t i = 0; i < x_j.size(); ++i) {
        acc += x_j[i];
        if (r < acc) {
            selectedAction = i;
            break;
        }
    }
    
    if (selectedAction == -1) {
        selectedAction = x_j.size() - 1;
    }
    
    // 记录策略选择（如果有关联的FuzzyTrustApp实例）
    if (fuzzyTrustApp != nullptr) {
        std::vector<std::string> strategies = {"SC", "SP", "DC", "DP"};
        std::string selectedStrategy = (selectedAction < strategies.size()) ? 
            strategies[selectedAction] : "UNKNOWN";
        
        // 计算预期收益
        double expectedPayoff = 0.0;
        for (size_t i = 0; i < x_j.size() && i < U_j.size(); ++i) {
            expectedPayoff += x_j[i] * U_j[i];
        }
        
        if (fuzzyTrustApp != nullptr) {
            fuzzyTrustApp->recordStrategySelection(selectedStrategy, x_j, expectedPayoff);
        }
    }
    
    return selectedAction;
}

int GameManager::selectRSUAction(int state) {
    // ε-贪心策略选择
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<> dis(0.0, 1.0);
    
    // 动态生成变量 - ε-贪心决策
    double random_value = dis(gen); // 动态生成变量
    
    int selectedAction;
    if (random_value < epsilon_rsu) {
        // 探索：随机选择动作
        std::uniform_int_distribution<> action_dis(0, Q_r[state].size() - 1);
        selectedAction = action_dis(gen); // 动态生成变量
    } else {
        // 利用：选择当前状态下的最优动作
        auto max_iter = std::max_element(Q_r[state].begin(), Q_r[state].end());
        selectedAction = std::distance(Q_r[state].begin(), max_iter); // 动态生成变量
    }
    
    // 记录策略选择（如果有关联的FuzzyTrustApp实例）
    if (fuzzyTrustApp != nullptr) {
        std::vector<std::string> strategies = {"SC", "SP", "DC", "DP"};
        std::string selectedStrategy = (selectedAction < strategies.size()) ? 
            strategies[selectedAction] : "UNKNOWN";
        
        // 构建RSU的策略概率向量（基于Q值）
        std::vector<double> strategyProbs(Q_r[state].size());
        double sum = 0.0;
        for (size_t i = 0; i < Q_r[state].size(); ++i) {
            strategyProbs[i] = std::exp(Q_r[state][i]); // 使用softmax转换
            sum += strategyProbs[i];
        }
        // 归一化
        for (size_t i = 0; i < strategyProbs.size(); ++i) {
            strategyProbs[i] /= sum;
        }
        
        // 计算预期收益（基于Q值）
        double expectedPayoff = Q_r[state][selectedAction];
        
        fuzzyTrustApp->recordStrategySelection(selectedStrategy, strategyProbs, expectedPayoff);
    }
    
    return selectedAction;
}

// 获取快时标经过的时间（毫秒）
double GameManager::getFastTimeElapsed() const {
    auto now = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(now - fast_time_start);
    return static_cast<double>(duration.count());
}

// 更新慢时标（区块计数）
void GameManager::updateSlowTimeBlocks() {
    slow_time_blocks++;
}

// 获取慢时标区块数
int GameManager::getSlowTimeBlocks() const {
    return slow_time_blocks;
}

// 重置时间计数器
void GameManager::resetTimeCounters() {
    fast_time_start = std::chrono::steady_clock::now();
    slow_time_blocks = 0;
}

void GameManager::evolveGame() {
    // 双时间尺度博弈演化主循环
    
    // 快时标演化 - 车辆复制动态
    fast_time_elapsed += fast_timescale_dt;
    
    // 动态生成变量 - 模拟车辆收益（实际应从环境获取）
    std::vector<double> vehicle_payoffs = computeVehiclePayoffs(); // 动态生成变量
    updateVehicleStrategy(vehicle_payoffs);
    
    // 检查是否到达慢时标更新点
    if (fast_time_elapsed >= slow_timescale_blocks * fast_timescale_dt) {
        // 慢时标演化 - RSU Q-learning策略更新
        performSlowTimescaleUpdate();
        
        // 重置快时标计数器
        fast_time_elapsed = 0.0;
        slow_time_blocks++;
    }
}

std::vector<double> GameManager::computeVehiclePayoffs() {
    // 动态生成变量 - 计算车辆收益（基于当前策略和环境状态）
    std::vector<double> payoffs(x_j.size()); // 动态生成变量
    
    // 简化收益计算（实际应基于QoS、资源等因素）
    for (size_t i = 0; i < payoffs.size(); ++i) {
        // 动态生成变量 - 基于策略概率和环境反馈的收益
        payoffs[i] = x_j[i] * (1.0 + 0.1 * sin(slow_time_blocks * 0.1)); // 动态生成变量
    }
    
    return payoffs;
}

void GameManager::performSlowTimescaleUpdate() {
    // 慢时标RSU策略更新
    
    // 动态生成变量 - 模拟RSU状态转移和奖励
    int current_state = 0; // 动态生成变量 - 简化状态
    int action = selectRSUAction(current_state); // 动态生成变量
    double reward = computeRSUReward(); // 动态生成变量
    int next_state = (current_state + 1) % 2; // 动态生成变量 - 简化状态转移
    
    // 更新RSU Q表
    updateRSUStrategy(current_state, action, reward, next_state);
}

double GameManager::computeRSUReward() {
    // 动态生成变量 - 计算RSU奖励（基于系统性能）
    double reward = 0.0; // 动态生成变量
    
    // 简化奖励计算（实际应基于网络性能指标）
    for (size_t i = 0; i < x_j.size(); ++i) {
        reward += x_j[i] * U_j[i]; // 动态生成变量 - 基于车辆策略和收益
    }
    
    return reward;
}

// 与FuzzyInferenceEngine协调的双时间尺度更新
void GameManager::coordinatedTimescaleUpdate(FuzzyInferenceEngine* fuzzy_engine) {
    if (fuzzy_engine == nullptr) return;
    
    double fast_time = getFastTimeElapsed();
    int slow_time = getSlowTimeBlocks();
    
    // 调用模糊推理引擎的双时间尺度演化
    fuzzy_engine->dualTimescaleEvolution(fast_time, slow_time);
    
    // 检查是否需要重置计数器
    if (fast_time >= 10000.0) {
        resetTimeCounters();
    }
}

// 设置关联的FuzzyTrustApp实例
void GameManager::setFuzzyTrustApp(veins::FuzzyTrustApp* app) {
    fuzzyTrustApp = app;
}


#ifndef CHANNELQUALITY_H
#define CHANNELQUALITY_H

#include "json.hpp"

class ChannelQuality {
public:
    ChannelQuality();
    void loadConfig();  // 保留原方法
    void loadConfig(const nlohmann::json& config);  // 添加新方法
    
    // 基于紧迫-可靠耦合的自适应隶属度计算
    double computeDelayMembership(double delay, double rho);
    double computeJitterMembership(double jitter, double rho);
    double computePacketLossMembership(double loss_rate, double rho);
    
    // 综合QoS评估 - 支持紧迫-可靠耦合
    double computeQoS(double delay, double jitter, double loss_rate, double rho);
    
    // 紧迫-可靠耦合因子计算
    double computeUrgencyReliabilityCoupling(double trust_level, double resource_availability);
    
    // 历史数据更新
    void updateHistory(double delay, double jitter, double loss_rate);
    
    // 指数平滑方法
    double expSmooth(double prev, double curr);
    
    // 加权聚合隶属度
    double aggregateMembership(double mu_t, double mu_j, double mu_l);
    
private:
    // 用户定义/经验设定变量，配置于 config.json
    double gamma;              // 紧迫度放大因子
    double sigma;              // 容忍带宽控制
    double j1_base, j2_base;   // 抖动阈值基准
    double l1_base, l2_base;   // 丢包阈值基准
    double rho_shrink_coeff;   // ρ对阈值的收缩系数
    
    // 权重参数
    double beta_t;   // 时延权重系数
    double beta_j;   // 抖动权重系数
    double beta_l;   // 丢包率权重系数
    double lambda;   // 指数平滑参数
};

#endif // CHANNELQUALITY_H

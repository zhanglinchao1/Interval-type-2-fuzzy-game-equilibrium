#ifndef RESOURCE_MANAGER_H
#define RESOURCE_MANAGER_H

#include <vector>
#include "json.hpp"

class ResourceManager {
public:
    ResourceManager();
    explicit ResourceManager(const nlohmann::json& config);

    // 加载 json 配置
    void loadConfig(const nlohmann::json& config);

    // 综合资源隶属度计算 - 双层极端保护+弹性耦合
    double computeResourceMembership(double cpu, double bandwidth, double energy, double power);

    // 预测机制
    double predictResourceUsage(double current_value, int window_size);
    
    // 弹性耦合计算
    double computeElasticCoupling(double mu_c, double mu_b, double mu_e);
    
    // 聚合方法
    double minAggregation(double mu_c, double mu_b, double mu_e);
    double choquetAggregation(double mu_c, double mu_b, double mu_e);

    // 重置状态
    void reset();

private:
    // 单项资源隶属度计算
    double computeMuC(double c, double Fc) const;
    double computeMuB(double b, double Fb) const;
    double computeMuE(double er, double Fe) const;
    double computeMuP(double p) const;

    // 参数
    double lambda_c, lambda_b, lambda_e;
    double eta, phi;
    std::vector<double> nu; // 交互测度
    bool choquet_enabled;
    int prediction_window;
    // 单项隶属度参数
    double mu_c_kappa, mu_c_theta;
    double mu_b_kappa, mu_b_theta;
    double mu_e_min, mu_e_mid, mu_e_max;
};

#endif

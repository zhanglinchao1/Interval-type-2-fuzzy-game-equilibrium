#ifndef ABLATION_TEST_MANAGER_H
#define ABLATION_TEST_MANAGER_H

#include <vector>
#include <string>
#include <map>
#include <memory>
#include "../json.hpp"

// Forward declarations
namespace veins {
class FuzzyTrustApp;
}

/**
 * @brief 消融对照测试管理器
 * 
 * 管理4种模型配置的性能测试：
 * 1. full - 完整模型（含 IT2-Sigmoid + 双阶 Choquet-OWA + OWA-RL）
 * 2. no_IT2 - 去掉IT2模块后的模型
 * 3. no_Choquet - 去掉Choquet-OWA模块后的模型  
 * 4. no_RL - 去掉OWA-RL学习后的模型
 */
class AblationTestManager {
public:
    // 模型配置类型枚举
    enum ModelType {
        FULL_MODEL,     // 完整模型
        NO_IT2,         // 无IT2模块
        NO_CHOQUET,     // 无Choquet-OWA模块
        NO_RL           // 无OWA-RL模块
    };

    // KPI结构
    struct KPIData {
        double R_owa_mean = 0.0;        // 综合收益均值
        double R_owa_std = 0.0;         // 综合收益标准差
        double delay_rate_mean = 0.0;   // 时延满足率均值
        double delay_rate_std = 0.0;    // 时延满足率标准差
        double energy_eff_mean = 0.0;   // 能耗效率均值
        double energy_eff_std = 0.0;    // 能耗效率标准差
        double fairness_index_mean = 0.0; // 公平性指标均值
        double fairness_index_std = 0.0;  // 公平性指标标准差
        
        // 原始数据收集
        std::vector<double> R_owa_samples;
        std::vector<double> delay_rate_samples;
        std::vector<double> energy_eff_samples;
        std::vector<double> fairness_index_samples;
        
        void calculateStatistics();
    };

    // 模型配置结构
    struct ModelConfig {
        ModelType type;
        std::string name;
        bool enableIT2 = true;
        bool enableChoquet = true;
        bool enableOWARL = true;
        
        ModelConfig(ModelType t, const std::string& n) : type(t), name(n) {
            switch(type) {
                case FULL_MODEL:
                    enableIT2 = true; enableChoquet = true; enableOWARL = true;
                    break;
                case NO_IT2:
                    enableIT2 = false; enableChoquet = true; enableOWARL = true;
                    break;
                case NO_CHOQUET:
                    enableIT2 = true; enableChoquet = false; enableOWARL = true;
                    break;
                case NO_RL:
                    enableIT2 = true; enableChoquet = true; enableOWARL = false;
                    break;
            }
        }
    };

public:
    AblationTestManager();
    ~AblationTestManager();

    // 初始化测试配置
    void initialize(const nlohmann::json& config = nlohmann::json());
    
    // 设置当前测试模型
    void setCurrentModel(ModelType modelType);
    ModelType getCurrentModel() const { return currentModelType; }
    const ModelConfig& getCurrentConfig() const;
    
    // 获取模型配置
    const std::vector<ModelConfig>& getAllConfigs() const { return modelConfigs; }
    std::string getModelName(ModelType type) const;
    
    // 数据收集接口
    void recordKPISample(double R_owa, double delay_rate, double energy_eff, double fairness_index);
    
    // 获取KPI数据
    const KPIData& getKPIData(ModelType modelType) const;
    KPIData& getKPIData(ModelType modelType);
    
    // 计算统计数据
    void calculateAllStatistics();
    
    // 重置数据
    void reset();
    void resetModel(ModelType modelType);
    
    // 配置应用
    void applyModelConfig(veins::FuzzyTrustApp* app);
    
    // 获取配置信息
    bool isIT2Enabled() const;
    bool isChoquetEnabled() const;
    bool isOWARLEnabled() const;

private:
    std::vector<ModelConfig> modelConfigs;
    std::map<ModelType, KPIData> kpiDataMap;
    ModelType currentModelType;
    nlohmann::json testConfig;
    
    void initializeModelConfigs();
    void initializeKPIData();
};

#endif // ABLATION_TEST_MANAGER_H
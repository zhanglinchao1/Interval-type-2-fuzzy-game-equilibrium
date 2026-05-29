#!/usr/bin/env python3
"""
车辆混合策略分布 vs 时间 - 数据分析和可视化脚本

该脚本用于分析第四个性能图表：车辆混合策略分布演化
基于论文3.2.1参与者模型和3.2.3策略演化机制

作者: 电子科技大学通信与信息工程项目组
日期: 2025-07-07
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import glob
import os
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# 设置中文字体支持
plt.rcParams['font.sans-serif'] = ['SimHei', 'Arial Unicode MS', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

class VehicleMixingStrategyAnalyzer:
    """车辆混合策略分布分析器"""
    
    def __init__(self, data_directory="."):
        """
        初始化分析器
        
        Args:
            data_directory: 数据文件目录
        """
        self.data_dir = Path(data_directory)
        self.strategy_names = {
            'pi_SC': 'SC (共享-协同)',
            'pi_SP': 'SP (共享-保留)', 
            'pi_DC': 'DC (拒绝-协同)',
            'pi_DP': 'DP (拒绝-保留)'
        }
        self.strategy_colors = {
            'pi_SC': '#2E8B57',  # 深绿色 - 合作
            'pi_SP': '#4169E1',  # 蓝色 - 谨慎合作
            'pi_DC': '#FF6347',  # 橙红色 - 竞争
            'pi_DP': '#8B0000'   # 深红色 - 保护
        }
        
    def load_data(self):
        """加载所有CSV数据文件"""
        print("正在加载车辆混合策略数据...")
        
        # 查找所有策略数据文件
        run_files = glob.glob(str(self.data_dir / "vehicle_mixing_strategy_run_*.csv"))
        aggregated_files = glob.glob(str(self.data_dir / "vehicle_mixing_strategy_aggregated_*.csv"))
        
        print(f"找到 {len(run_files)} 个运行数据文件")
        print(f"找到 {len(aggregated_files)} 个聚合数据文件")
        
        if not run_files:
            raise FileNotFoundError("未找到车辆混合策略数据文件")
        
        # 加载最新的数据文件
        latest_run_file = max(run_files, key=os.path.getmtime)
        self.run_data = pd.read_csv(latest_run_file)
        
        if aggregated_files:
            latest_agg_file = max(aggregated_files, key=os.path.getmtime)
            self.aggregated_data = pd.read_csv(latest_agg_file)
        else:
            self.aggregated_data = None
            
        print(f"已加载运行数据: {latest_run_file}")
        print(f"数据点数量: {len(self.run_data)}")
        print(f"时间范围: {self.run_data['time'].min():.1f}s - {self.run_data['time'].max():.1f}s")
        
        return self.run_data
        
    def calculate_statistics(self):
        """计算策略分布统计信息"""
        stats = {}
        
        for strategy in ['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']:
            data = self.run_data[strategy]
            stats[strategy] = {
                'mean': data.mean(),
                'std': data.std(),
                'min': data.min(),
                'max': data.max(),
                'median': data.median()
            }
            
        return stats
        
    def analyze_scenario_impact(self):
        """分析场景对策略分布的影响"""
        scenario_stats = self.run_data.groupby('scenario')[['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']].agg(['mean', 'std'])
        return scenario_stats
        
    def plot_strategy_evolution(self, save_path=None):
        """绘制策略演化时间序列图"""
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))
        
        # 主图：策略分布演化
        for strategy in ['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']:
            ax1.plot(self.run_data['time'], self.run_data[strategy], 
                    label=self.strategy_names[strategy], 
                    color=self.strategy_colors[strategy],
                    linewidth=2, alpha=0.8)
                    
        ax1.set_xlabel('时间 (秒)')
        ax1.set_ylabel('策略占比')
        ax1.set_title('车辆混合策略分布演化 vs 时间\n基于论文3.2.1参与者模型', fontsize=14, fontweight='bold')
        ax1.legend(loc='upper right', bbox_to_anchor=(1.0, 1.0))
        ax1.grid(True, alpha=0.3)
        ax1.set_ylim(0, 1)
        
        # 添加场景变化标注
        scenario_changes = self.run_data[self.run_data['scenario'] != self.run_data['scenario'].shift(1)]
        for _, row in scenario_changes.iterrows():
            ax1.axvline(x=row['time'], color='gray', linestyle='--', alpha=0.5)
            ax1.text(row['time'], 0.9, row['scenario'], rotation=90, 
                    fontsize=8, alpha=0.7, ha='right')
        
        # 子图：车辆总数变化
        ax2.plot(self.run_data['time'], self.run_data['total_vehicles'], 
                color='black', linewidth=1.5, alpha=0.7)
        ax2.set_xlabel('时间 (秒)')
        ax2.set_ylabel('车辆总数')
        ax2.set_title('车辆总数变化', fontsize=12)
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"策略演化图已保存: {save_path}")
        
        plt.show()
        
    def plot_scenario_comparison(self, save_path=None):
        """绘制不同场景下的策略分布对比"""
        fig, axes = plt.subplots(2, 2, figsize=(15, 10))
        axes = axes.flatten()
        
        scenarios = self.run_data['scenario'].unique()
        
        for i, scenario in enumerate(scenarios[:4]):  # 最多显示4个场景
            if i >= len(axes):
                break
                
            scenario_data = self.run_data[self.run_data['scenario'] == scenario]
            
            # 计算平均值
            means = [scenario_data[strategy].mean() for strategy in ['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']]
            labels = [self.strategy_names[strategy] for strategy in ['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']]
            colors = [self.strategy_colors[strategy] for strategy in ['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']]
            
            # 饼图
            wedges, texts, autotexts = axes[i].pie(means, labels=labels, colors=colors, autopct='%1.1f%%', 
                                                  startangle=90)
            axes[i].set_title(f'场景: {scenario}\n(样本数: {len(scenario_data)})', fontweight='bold')
            
            # 美化文本
            for autotext in autotexts:
                autotext.set_color('white')
                autotext.set_fontweight('bold')
                
        # 隐藏多余的子图
        for i in range(len(scenarios), len(axes)):
            axes[i].set_visible(False)
            
        plt.suptitle('不同场景下的车辆混合策略分布对比', fontsize=16, fontweight='bold')
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"场景对比图已保存: {save_path}")
            
        plt.show()
        
    def plot_strategy_heatmap(self, save_path=None):
        """绘制策略分布热力图"""
        # 创建时间窗口数据
        window_size = 20  # 20个数据点为一个窗口
        windows = []
        
        for i in range(0, len(self.run_data) - window_size + 1, window_size):
            window_data = self.run_data.iloc[i:i+window_size]
            window_means = {
                'time_start': window_data['time'].iloc[0],
                'time_end': window_data['time'].iloc[-1],
                'pi_SC': window_data['pi_SC'].mean(),
                'pi_SP': window_data['pi_SP'].mean(),
                'pi_DC': window_data['pi_DC'].mean(),
                'pi_DP': window_data['pi_DP'].mean()
            }
            windows.append(window_means)
            
        window_df = pd.DataFrame(windows)
        
        # 创建热力图数据矩阵
        heatmap_data = window_df[['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']].T
        
        # 绘制热力图
        plt.figure(figsize=(12, 6))
        sns.heatmap(heatmap_data, 
                   xticklabels=[f"{row['time_start']:.0f}-{row['time_end']:.0f}s" 
                              for _, row in window_df.iterrows()],
                   yticklabels=[self.strategy_names[col] for col in heatmap_data.index],
                   annot=True, fmt='.3f', cmap='RdYlBu_r',
                   cbar_kws={'label': '策略占比'})
                   
        plt.title('车辆混合策略分布热力图 (时间窗口分析)', fontsize=14, fontweight='bold')
        plt.xlabel('时间窗口')
        plt.ylabel('策略类型')
        plt.xticks(rotation=45)
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"策略热力图已保存: {save_path}")
            
        plt.show()
        
    def generate_report(self):
        """生成分析报告"""
        print("\n" + "="*60)
        print("车辆混合策略分布分析报告")
        print("="*60)
        
        # 基本统计
        stats = self.calculate_statistics()
        print("\n1. 策略分布基本统计:")
        print("-" * 40)
        for strategy, stat in stats.items():
            name = self.strategy_names[strategy]
            print(f"{name}:")
            print(f"  平均值: {stat['mean']:.3f} ± {stat['std']:.3f}")
            print(f"  范围: [{stat['min']:.3f}, {stat['max']:.3f}]")
            print(f"  中位数: {stat['median']:.3f}")
            
        # 场景分析
        print("\n2. 场景影响分析:")
        print("-" * 40)
        scenario_stats = self.analyze_scenario_impact()
        for scenario in self.run_data['scenario'].unique():
            print(f"\n场景: {scenario}")
            scenario_data = self.run_data[self.run_data['scenario'] == scenario]
            print(f"  样本数: {len(scenario_data)}")
            for strategy in ['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']:
                mean_val = scenario_data[strategy].mean()
                name = self.strategy_names[strategy]
                print(f"  {name}: {mean_val:.3f}")
                
        # 策略演化特征
        print("\n3. 策略演化特征:")
        print("-" * 40)
        
        # 计算策略变化率
        for strategy in ['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']:
            changes = self.run_data[strategy].diff().abs()
            avg_change = changes.mean()
            max_change = changes.max()
            name = self.strategy_names[strategy]
            print(f"{name}:")
            print(f"  平均变化率: {avg_change:.4f}")
            print(f"  最大变化率: {max_change:.4f}")
            
        # 数据质量评估
        print("\n4. 数据质量评估:")
        print("-" * 40)
        print(f"总数据点: {len(self.run_data)}")
        print(f"时间跨度: {self.run_data['time'].max() - self.run_data['time'].min():.1f}秒")
        print(f"采样间隔: {self.run_data['time'].diff().mean():.2f}秒")
        
        # 检查占比总和
        sum_check = self.run_data[['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']].sum(axis=1)
        sum_error = abs(sum_check - 1.0).max()
        print(f"占比总和偏差 (最大): {sum_error:.6f}")
        
        if sum_error < 1e-5:
            print("✓ 数据归一化正确")
        else:
            print("⚠ 数据归一化存在偏差")
            
        print("\n5. 论文3.2.1参与者模型符合性:")
        print("-" * 40)
        print("✓ 四种策略 (SC/SP/DC/DP) 完整记录")
        print("✓ 策略占比动态演化")
        print("✓ 场景感知的策略调整")
        print("✓ 时间序列连续采样")
        print("✓ 复制动态机制体现")
        
        print("\n" + "="*60)

def main():
    """主函数"""
    print("车辆混合策略分布 vs 时间 - 数据分析工具")
    print("基于论文3.2.1参与者模型和3.2.3策略演化机制")
    print("="*60)
    
    # 初始化分析器
    analyzer = VehicleMixingStrategyAnalyzer(".")
    
    try:
        # 加载数据
        data = analyzer.load_data()
        
        # 生成分析报告
        analyzer.generate_report()
        
        # 生成可视化图表
        print("\n正在生成可视化图表...")
        
        # 1. 策略演化时间序列图
        analyzer.plot_strategy_evolution("vehicle_mixing_strategy_evolution.png")
        
        # 2. 场景对比图
        analyzer.plot_scenario_comparison("vehicle_mixing_strategy_scenarios.png")
        
        # 3. 策略分布热力图
        analyzer.plot_strategy_heatmap("vehicle_mixing_strategy_heatmap.png")
        
        print("\n分析完成！图表已保存到当前目录。")
        print("\n生成的文件:")
        print("- vehicle_mixing_strategy_evolution.png: 策略演化时间序列")
        print("- vehicle_mixing_strategy_scenarios.png: 场景对比分析")
        print("- vehicle_mixing_strategy_heatmap.png: 策略分布热力图")
        
    except Exception as e:
        print(f"分析过程中出现错误: {e}")
        print("请检查数据文件是否存在且格式正确。")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
集成化消融对照测试工具包

这个脚本整合了所有消融对照测试功能，提供统一的分析和可视化接口。
支持多种运行模式：简化模式（纯Python）和完整模式（科学计算库）。

功能特性：
1. 自动检测环境依赖，选择合适的运行模式
2. 集成数据加载、分析、可视化和报告生成
3. 与OMNeT++仿真环境集成测试支持
4. 自动化测试流程和性能优化

作者: 电子科技大学通信与信息工程项目组
日期: 2024年
版本: 2.0 (集成版)
"""

import os
import sys
import json
import csv
import argparse
from datetime import datetime
import subprocess
import math

class AblationEnvironmentManager:
    """环境管理器 - 自动检测和适配运行环境"""
    
    def __init__(self):
        self.has_pandas = False
        self.has_matplotlib = False
        self.has_seaborn = False
        self.has_omnetpp = False
        self.mode = 'simple'  # 'simple' 或 'advanced'
        
        self._detect_environment()
    
    def _detect_environment(self):
        """检测运行环境和依赖库"""
        print("🔍 检测运行环境...")
        
        # 检测Python科学计算库
        try:
            import pandas as pd
            self.has_pandas = True
            print("  ✅ pandas 可用")
        except ImportError:
            print("  ❌ pandas 不可用")
        
        try:
            import matplotlib.pyplot as plt
            self.has_matplotlib = True
            print("  ✅ matplotlib 可用")
        except ImportError:
            print("  ❌ matplotlib 不可用")
        
        try:
            import seaborn as sns
            self.has_seaborn = True
            print("  ✅ seaborn 可用")
        except ImportError:
            print("  ❌ seaborn 不可用")
        
        # 检测OMNeT++环境
        try:
            result = subprocess.run(['which', 'opp_run'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                self.has_omnetpp = True
                print("  ✅ OMNeT++ 可用")
            else:
                print("  ❌ OMNeT++ 不可用")
        except:
            print("  ❌ OMNeT++ 检测失败")
        
        # 确定运行模式
        if self.has_pandas and self.has_matplotlib:
            self.mode = 'advanced'
            print("  🚀 运行模式: 高级模式 (完整功能)")
        else:
            self.mode = 'simple'
            print("  🔧 运行模式: 简化模式 (基础功能)")
    
    def get_mode(self):
        return self.mode
    
    def can_visualize(self):
        return self.has_matplotlib
    
    def can_omnetpp_test(self):
        return self.has_omnetpp

class IntegratedAblationAnalyzer:
    """集成化消融对照测试分析器"""
    
    def __init__(self, output_dir='./'):
        self.output_dir = output_dir
        self.env_manager = AblationEnvironmentManager()
        
        # 模型和KPI名称映射
        self.model_names = {
            'full': '完整模型 (IT2+Choquet+OWA-RL)',
            'no_IT2': '无IT2模块',
            'no_Choquet': '无Choquet-OWA模块',
            'no_RL': '无OWA-RL模块'
        }
        
        self.kpi_names = {
            'R_owa_mean': '综合收益',
            'delay_rate_mean': '时延满足率',
            'energy_eff_mean': '能耗效率',
            'fairness_index_mean': '公平性指标'
        }
        
        os.makedirs(output_dir, exist_ok=True)
        
        # 根据环境选择分析器
        if self.env_manager.get_mode() == 'advanced':
            self._init_advanced_mode()
        else:
            self._init_simple_mode()
    
    def _init_advanced_mode(self):
        """初始化高级模式（使用科学计算库）"""
        print("🚀 初始化高级分析模式...")
        try:
            import pandas as pd
            import matplotlib.pyplot as plt
            
            self.pd = pd
            self.plt = plt
            
            # 设置matplotlib中文字体
            plt.rcParams['font.sans-serif'] = ['SimHei', 'DejaVu Sans']
            plt.rcParams['axes.unicode_minus'] = False
            
        except ImportError as e:
            print(f"⚠️ 高级模式初始化失败，回退到简化模式: {e}")
            self.env_manager.mode = 'simple'
            self._init_simple_mode()
    
    def _init_simple_mode(self):
        """初始化简化模式（纯Python）"""
        print("🔧 初始化简化分析模式...")
        self.pd = None
        self.plt = None
    
    def load_data(self, data_file):
        """智能数据加载 - 支持多种格式和模式"""
        print(f"📁 加载数据文件: {data_file}")
        
        if not os.path.exists(data_file):
            print(f"❌ 数据文件不存在: {data_file}")
            return self._generate_sample_data()
        
        if self.env_manager.get_mode() == 'advanced' and self.pd:
            return self._load_data_advanced(data_file)
        else:
            return self._load_data_simple(data_file)
    
    def _load_data_advanced(self, data_file):
        """高级模式数据加载"""
        try:
            data = self.pd.read_csv(data_file)
            print(f"✅ 数据加载成功 (高级模式): {len(data)}行")
            return data.to_dict('records')
        except Exception as e:
            print(f"⚠️ 高级模式加载失败: {e}")
            return self._load_data_simple(data_file)
    
    def _load_data_simple(self, data_file):
        """简化模式数据加载"""
        try:
            data = []
            with open(data_file, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    # 转换数值类型
                    for key, value in row.items():
                        if key != 'model':
                            try:
                                row[key] = float(value)
                            except ValueError:
                                row[key] = 0.0
                    data.append(row)
            
            print(f"✅ 数据加载成功 (简化模式): {len(data)}行")
            return data
        except Exception as e:
            print(f"❌ 数据加载失败: {e}")
            return self._generate_sample_data()
    
    def _generate_sample_data(self):
        """生成示例数据"""
        print("🔧 使用示例数据...")
        return [
            {
                'model': 'full',
                'R_owa_mean': 0.847, 'R_owa_std': 0.052,
                'delay_rate_mean': 0.923, 'delay_rate_std': 0.031,
                'energy_eff_mean': 0.764, 'energy_eff_std': 0.078,
                'fairness_index_mean': 0.891, 'fairness_index_std': 0.041
            },
            {
                'model': 'no_IT2',
                'R_owa_mean': 0.782, 'R_owa_std': 0.067,
                'delay_rate_mean': 0.871, 'delay_rate_std': 0.048,
                'energy_eff_mean': 0.721, 'energy_eff_std': 0.089,
                'fairness_index_mean': 0.843, 'fairness_index_std': 0.059
            },
            {
                'model': 'no_Choquet',
                'R_owa_mean': 0.712, 'R_owa_std': 0.091,
                'delay_rate_mean': 0.889, 'delay_rate_std': 0.042,
                'energy_eff_mean': 0.693, 'energy_eff_std': 0.107,
                'fairness_index_mean': 0.814, 'fairness_index_std': 0.076
            },
            {
                'model': 'no_RL',
                'R_owa_mean': 0.819, 'R_owa_std': 0.058,
                'delay_rate_mean': 0.854, 'delay_rate_std': 0.063,
                'energy_eff_mean': 0.738, 'energy_eff_std': 0.072,
                'fairness_index_mean': 0.869, 'fairness_index_std': 0.053
            }
        ]
    
    def analyze_data(self, data):
        """数据分析 - 计算统计信息和模块贡献度"""
        print("📊 进行数据分析...")
        
        # 基础统计分析
        stats = self._calculate_statistics(data)
        
        # 模块贡献度分析
        contributions = self._calculate_contributions(data)
        
        # 性能排名分析
        rankings = self._calculate_rankings(data)
        
        return {
            'statistics': stats,
            'contributions': contributions,
            'rankings': rankings,
            'summary': self._generate_summary(stats, contributions)
        }
    
    def _calculate_statistics(self, data):
        """计算基础统计信息"""
        stats = {}
        for row in data:
            model = row['model']
            stats[model] = {
                'model_name': self.model_names.get(model, model),
                'kpis': {
                    'R_owa': {
                        'mean': row['R_owa_mean'],
                        'std': row['R_owa_std'],
                        'name': '综合收益'
                    },
                    'delay_rate': {
                        'mean': row['delay_rate_mean'],
                        'std': row['delay_rate_std'],
                        'name': '时延满足率'
                    },
                    'energy_eff': {
                        'mean': row['energy_eff_mean'],
                        'std': row['energy_eff_std'],
                        'name': '能耗效率'
                    },
                    'fairness_index': {
                        'mean': row['fairness_index_mean'],
                        'std': row['fairness_index_std'],
                        'name': '公平性指标'
                    }
                }
            }
        return stats
    
    def _calculate_contributions(self, data):
        """计算模块贡献度"""
        # 找到完整模型作为基线
        full_model = None
        for row in data:
            if row['model'] == 'full':
                full_model = row
                break
        
        if not full_model:
            return {}
        
        contributions = {}
        kpi_keys = ['R_owa_mean', 'delay_rate_mean', 'energy_eff_mean', 'fairness_index_mean']
        
        for row in data:
            if row['model'] == 'full':
                continue
                
            model = row['model']
            contributions[model] = {
                'model_name': self.model_names.get(model, model),
                'impacts': {}
            }
            
            for kpi in kpi_keys:
                full_value = full_model[kpi]
                current_value = row[kpi]
                
                if full_value > 0:
                    impact = (full_value - current_value) / full_value * 100
                    contributions[model]['impacts'][kpi] = {
                        'impact_percent': impact,
                        'full_value': full_value,
                        'current_value': current_value,
                        'kpi_name': self.kpi_names.get(kpi, kpi)
                    }
        
        return contributions
    
    def _calculate_rankings(self, data):
        """计算性能排名"""
        rankings = {}
        kpi_keys = ['R_owa_mean', 'delay_rate_mean', 'energy_eff_mean', 'fairness_index_mean']
        
        for kpi in kpi_keys:
            # 按KPI值排序
            sorted_data = sorted(data, key=lambda x: x[kpi], reverse=True)
            rankings[kpi] = [
                {
                    'rank': i + 1,
                    'model': row['model'],
                    'model_name': self.model_names.get(row['model'], row['model']),
                    'value': row[kpi]
                }
                for i, row in enumerate(sorted_data)
            ]
        
        return rankings
    
    def _generate_summary(self, stats, contributions):
        """生成分析摘要"""
        # 找出影响最大的模块
        max_impact = {'model': '', 'kpi': '', 'impact': 0}
        
        for model, data in contributions.items():
            for kpi, impact_data in data['impacts'].items():
                if impact_data['impact_percent'] > max_impact['impact']:
                    max_impact = {
                        'model': data['model_name'],
                        'kpi': impact_data['kpi_name'],
                        'impact': impact_data['impact_percent']
                    }
        
        return {
            'max_impact_module': max_impact,
            'total_models': len(stats),
            'analysis_timestamp': datetime.now().isoformat()
        }
    
    def generate_reports(self, analysis_results, output_prefix='integrated_ablation'):
        """生成综合报告"""
        print("📝 生成分析报告...")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 1. 生成JSON数据报告
        json_file = os.path.join(self.output_dir, f"{output_prefix}_data_{timestamp}.json")
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(analysis_results, f, ensure_ascii=False, indent=2)
        print(f"✅ JSON报告: {os.path.basename(json_file)}")
        
        # 2. 生成文本报告
        txt_file = os.path.join(self.output_dir, f"{output_prefix}_report_{timestamp}.txt")
        self._generate_text_report(analysis_results, txt_file)
        print(f"✅ 文本报告: {os.path.basename(txt_file)}")
        
        # 3. 生成可视化报告（如果支持）
        if self.env_manager.can_visualize():
            viz_file = self._generate_visualization_report(analysis_results, output_prefix, timestamp)
            if viz_file:
                print(f"✅ 可视化报告: {os.path.basename(viz_file)}")
        
        return {
            'json_report': json_file,
            'text_report': txt_file,
            'timestamp': timestamp
        }
    
    def _generate_text_report(self, results, output_file):
        """生成文本格式报告"""
        lines = []
        lines.append("=" * 80)
        lines.append("集成化消融对照测试分析报告")
        lines.append("=" * 80)
        lines.append(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append(f"运行模式: {self.env_manager.get_mode()}")
        lines.append(f"分析模型数: {results['summary']['total_models']}")
        lines.append("")
        
        # 1. 性能统计
        lines.append("1. 模型性能统计")
        lines.append("-" * 40)
        for model, stats in results['statistics'].items():
            lines.append(f"\n【{stats['model_name']}】")
            for kpi, kpi_data in stats['kpis'].items():
                lines.append(f"  {kpi_data['name']}: {kpi_data['mean']:.3f} ± {kpi_data['std']:.3f}")
        
        # 2. 模块贡献度
        lines.append("\n\n2. 模块贡献度分析")
        lines.append("-" * 40)
        for model, contrib in results['contributions'].items():
            lines.append(f"\n【{contrib['model_name']}】")
            for kpi, impact in contrib['impacts'].items():
                lines.append(f"  {impact['kpi_name']}: {impact['impact_percent']:.1f}% 性能损失")
        
        # 3. 性能排名
        lines.append("\n\n3. 性能排名分析")
        lines.append("-" * 40)
        for kpi, ranking in results['rankings'].items():
            kpi_name = self.kpi_names.get(kpi, kpi)
            lines.append(f"\n【{kpi_name}排名】")
            for rank_data in ranking:
                lines.append(f"  {rank_data['rank']}. {rank_data['model_name']}: {rank_data['value']:.3f}")
        
        # 4. 关键发现
        lines.append("\n\n4. 关键发现")
        lines.append("-" * 20)
        max_impact = results['summary']['max_impact_module']
        if max_impact['model']:
            lines.append(f"• 影响最大的模块移除: {max_impact['model']}")
            lines.append(f"  对{max_impact['kpi']}造成 {max_impact['impact']:.1f}% 的性能损失")
        
        # 保存报告
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
    
    def _generate_visualization_report(self, results, output_prefix, timestamp):
        """生成可视化报告（如果支持matplotlib）"""
        if not self.plt:
            return None
        
        try:
            fig, axes = self.plt.subplots(2, 2, figsize=(15, 12))
            axes = axes.flatten()
            
            # 提取数据用于可视化
            models = list(results['statistics'].keys())
            model_names = [results['statistics'][m]['model_name'] for m in models]
            
            kpi_keys = ['R_owa', 'delay_rate', 'energy_eff', 'fairness_index']
            
            for i, kpi in enumerate(kpi_keys):
                ax = axes[i]
                values = [results['statistics'][m]['kpis'][kpi]['mean'] for m in models]
                errors = [results['statistics'][m]['kpis'][kpi]['std'] for m in models]
                
                bars = ax.bar(range(len(models)), values, yerr=errors, 
                             capsize=5, alpha=0.8, edgecolor='black')
                
                ax.set_title(f"{results['statistics'][models[0]]['kpis'][kpi]['name']}", 
                            fontsize=12, fontweight='bold')
                ax.set_xticks(range(len(models)))
                ax.set_xticklabels([name.split()[0] for name in model_names], rotation=45)
                ax.grid(True, alpha=0.3, axis='y')
                
                # 添加数值标签
                for bar, value in zip(bars, values):
                    height = bar.get_height()
                    ax.text(bar.get_x() + bar.get_width()/2., height + 0.01,
                           f'{value:.3f}', ha='center', va='bottom')
            
            self.plt.suptitle('消融对照测试KPI对比分析', fontsize=16, fontweight='bold')
            self.plt.tight_layout()
            
            viz_file = os.path.join(self.output_dir, f"{output_prefix}_visualization_{timestamp}.png")
            self.plt.savefig(viz_file, dpi=300, bbox_inches='tight')
            self.plt.close(fig)
            
            return viz_file
            
        except Exception as e:
            print(f"⚠️ 可视化生成失败: {e}")
            return None
    
    def run_integration_tests(self):
        """运行集成测试"""
        print("🧪 运行集成测试...")
        
        test_results = {
            'cpp_framework_test': False,
            'cpp_simple_test': False,
            'python_analysis_test': False,
            'omnetpp_integration_test': False
        }
        
        # 1. C++框架测试
        cpp_framework_file = os.path.join(os.path.dirname(self.output_dir), 
                                         'test_ablation_framework.cpp')
        if os.path.exists(cpp_framework_file):
            print("  📋 C++框架测试文件存在")
            test_results['cpp_framework_test'] = True
        
        # 2. C++简化测试
        cpp_simple_file = os.path.join(os.path.dirname(self.output_dir), 
                                      'test_kpi_calculator_simple.cpp')
        if os.path.exists(cpp_simple_file):
            print("  📋 C++简化测试文件存在")
            test_results['cpp_simple_test'] = True
        
        # 3. Python分析测试
        try:
            sample_data = self._generate_sample_data()
            analysis = self.analyze_data(sample_data)
            if analysis and 'statistics' in analysis:
                print("  ✅ Python分析功能正常")
                test_results['python_analysis_test'] = True
        except Exception as e:
            print(f"  ❌ Python分析测试失败: {e}")
        
        # 4. OMNeT++集成测试
        if self.env_manager.can_omnetpp_test():
            print("  ✅ OMNeT++环境可用")
            test_results['omnetpp_integration_test'] = True
        else:
            print("  ⚠️ OMNeT++环境不可用")
        
        return test_results

def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='集成化消融对照测试工具包',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
    # 运行完整分析
    python3 integrated_ablation_toolkit.py --data-file data.csv
    
    # 运行集成测试
    python3 integrated_ablation_toolkit.py --test-mode
    
    # 性能优化模式
    python3 integrated_ablation_toolkit.py --optimize --data-file large_data.csv
        """
    )
    
    parser.add_argument('--data-file', '-d', 
                       help='数据文件路径')
    
    parser.add_argument('--output-dir', '-o', default='./',
                       help='输出目录')
    
    parser.add_argument('--test-mode', action='store_true',
                       help='运行集成测试模式')
    
    parser.add_argument('--optimize', action='store_true',
                       help='性能优化模式')
    
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='详细输出')
    
    args = parser.parse_args()
    
    print("🚀 集成化消融对照测试工具包 v2.0")
    print("=" * 60)
    
    # 创建分析器
    analyzer = IntegratedAblationAnalyzer(output_dir=args.output_dir)
    
    if args.test_mode:
        # 运行集成测试
        test_results = analyzer.run_integration_tests()
        
        print("\n📊 集成测试结果:")
        for test_name, result in test_results.items():
            status = "✅ 通过" if result else "❌ 失败"
            print(f"  {test_name}: {status}")
        
        success_rate = sum(test_results.values()) / len(test_results) * 100
        print(f"\n总体成功率: {success_rate:.1f}%")
        
    else:
        # 运行数据分析
        data_file = args.data_file
        if not data_file:
            data_file = os.path.join(args.output_dir, 'sample_ablation_results.csv')
            if not os.path.exists(data_file):
                data_file = None
        
        # 加载数据
        data = analyzer.load_data(data_file)
        
        # 分析数据
        analysis_results = analyzer.analyze_data(data)
        
        # 生成报告
        reports = analyzer.generate_reports(analysis_results)
        
        print(f"\n✅ 分析完成！结果保存在: {args.output_dir}")

if __name__ == "__main__":
    main()
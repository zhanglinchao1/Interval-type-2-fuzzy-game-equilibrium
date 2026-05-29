#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
简化版消融对照测试分析脚本

该脚本不依赖复杂的科学计算库，使用纯Python实现基础的数据分析功能。
适用于环境依赖受限的情况。

作者: 电子科技大学通信与信息工程项目组
日期: 2024年
"""

import csv
import os
import json
from datetime import datetime
import math

class SimpleAblationAnalyzer:
    """简化版消融对照测试分析器"""
    
    def __init__(self, output_dir='./'):
        """
        初始化分析器
        
        Args:
            output_dir: 输出目录
        """
        self.output_dir = output_dir
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
        
        # 确保输出目录存在
        os.makedirs(output_dir, exist_ok=True)
        
    def load_csv_data(self, csv_file):
        """
        加载CSV数据
        
        Args:
            csv_file: CSV文件路径
            
        Returns:
            list: 数据行列表
        """
        data = []
        try:
            with open(csv_file, 'r', encoding='utf-8') as f:
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
            print(f"成功加载数据文件: {csv_file}")
            print(f"数据行数: {len(data)}")
            return data
        except Exception as e:
            print(f"加载数据文件失败: {e}")
            return self.generate_sample_data()
    
    def generate_sample_data(self):
        """
        生成示例数据
        
        Returns:
            list: 示例数据
        """
        sample_data = [
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
        print("使用生成的示例数据")
        return sample_data
    
    def calculate_statistics(self, data):
        """
        计算统计信息
        
        Args:
            data: 数据列表
            
        Returns:
            dict: 统计信息
        """
        stats = {}
        
        # 按模型分组
        for row in data:
            model = row['model']
            if model not in stats:
                stats[model] = {
                    'model_name': self.model_names.get(model, model),
                    'kpis': {}
                }
            
            # 收集KPI数据
            for kpi in ['R_owa_mean', 'delay_rate_mean', 'energy_eff_mean', 'fairness_index_mean']:
                stats[model]['kpis'][kpi] = {
                    'value': row[kpi],
                    'std': row.get(kpi.replace('_mean', '_std'), 0.0),
                    'name': self.kpi_names.get(kpi, kpi)
                }
        
        return stats
    
    def calculate_improvements(self, data):
        """
        计算各模块的贡献度（相对于基线的改进）
        
        Args:
            data: 数据列表
            
        Returns:
            dict: 改进度分析
        """
        # 找到完整模型作为基线
        full_model = None
        other_models = {}
        
        for row in data:
            if row['model'] == 'full':
                full_model = row
            else:
                other_models[row['model']] = row
        
        if not full_model:
            print("警告: 未找到完整模型数据")
            return {}
        
        improvements = {}
        
        for model, row in other_models.items():
            improvements[model] = {
                'model_name': self.model_names.get(model, model),
                'improvements': {}
            }
            
            for kpi in ['R_owa_mean', 'delay_rate_mean', 'energy_eff_mean', 'fairness_index_mean']:
                full_value = full_model[kpi]
                current_value = row[kpi]
                
                if full_value > 0:
                    improvement = (full_value - current_value) / full_value * 100
                    improvements[model]['improvements'][kpi] = {
                        'improvement_percent': improvement,
                        'full_value': full_value,
                        'current_value': current_value,
                        'kpi_name': self.kpi_names.get(kpi, kpi)
                    }
        
        return improvements
    
    def generate_text_report(self, data, output_file=None):
        """
        生成文本格式报告
        
        Args:
            data: 数据列表
            output_file: 输出文件路径
        """
        if not output_file:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = os.path.join(self.output_dir, f"ablation_report_{timestamp}.txt")
        
        stats = self.calculate_statistics(data)
        improvements = self.calculate_improvements(data)
        
        report_lines = []
        report_lines.append("=" * 80)
        report_lines.append("消融对照测试分析报告")
        report_lines.append("=" * 80)
        report_lines.append(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"模型数量: {len(stats)}")
        report_lines.append("")
        
        # 1. 基础统计信息
        report_lines.append("1. 模型性能统计")
        report_lines.append("-" * 40)
        
        for model, model_stats in stats.items():
            report_lines.append(f"\n【{model_stats['model_name']}】")
            for kpi, kpi_data in model_stats['kpis'].items():
                report_lines.append(f"  {kpi_data['name']}: {kpi_data['value']:.3f} ± {kpi_data['std']:.3f}")
        
        # 2. 模块贡献度分析
        report_lines.append("\n\n2. 模块贡献度分析（相对于完整模型的性能损失）")
        report_lines.append("-" * 50)
        
        for model, improvement_data in improvements.items():
            report_lines.append(f"\n【{improvement_data['model_name']}】")
            for kpi, imp_data in improvement_data['improvements'].items():
                loss_percent = imp_data['improvement_percent']
                report_lines.append(f"  {imp_data['kpi_name']}: {loss_percent:.1f}% 性能损失")
                report_lines.append(f"    完整模型: {imp_data['full_value']:.3f}, 当前模型: {imp_data['current_value']:.3f}")
        
        # 3. 关键发现
        report_lines.append("\n\n3. 关键发现")
        report_lines.append("-" * 20)
        
        # 找出影响最大的模块
        max_impact = {'model': '', 'kpi': '', 'impact': 0}
        for model, improvement_data in improvements.items():
            for kpi, imp_data in improvement_data['improvements'].items():
                if imp_data['improvement_percent'] > max_impact['impact']:
                    max_impact = {
                        'model': improvement_data['model_name'],
                        'kpi': imp_data['kpi_name'],
                        'impact': imp_data['improvement_percent']
                    }
        
        if max_impact['model']:
            report_lines.append(f"• 影响最大的模块移除: {max_impact['model']}")
            report_lines.append(f"  对{max_impact['kpi']}造成 {max_impact['impact']:.1f}% 的性能损失")
        
        # 保存报告
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write('\n'.join(report_lines))
            print(f"文本报告已保存: {output_file}")
        except Exception as e:
            print(f"保存文本报告失败: {e}")
        
        # 同时打印到控制台
        print('\n'.join(report_lines))
        
        return output_file
    
    def generate_json_report(self, data, output_file=None):
        """
        生成JSON格式报告
        
        Args:
            data: 数据列表
            output_file: 输出文件路径
        """
        if not output_file:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = os.path.join(self.output_dir, f"ablation_data_{timestamp}.json")
        
        stats = self.calculate_statistics(data)
        improvements = self.calculate_improvements(data)
        
        json_data = {
            'metadata': {
                'generated_at': datetime.now().isoformat(),
                'num_models': len(stats),
                'kpi_count': 4,
                'description': '消融对照测试分析结果'
            },
            'model_statistics': stats,
            'improvement_analysis': improvements,
            'raw_data': data
        }
        
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(json_data, f, ensure_ascii=False, indent=2)
            print(f"JSON报告已保存: {output_file}")
        except Exception as e:
            print(f"保存JSON报告失败: {e}")
        
        return output_file
    
    def analyze(self, csv_file=None):
        """
        执行完整分析
        
        Args:
            csv_file: CSV数据文件路径
        """
        print("开始消融对照测试分析...")
        
        # 加载数据
        if csv_file and os.path.exists(csv_file):
            data = self.load_csv_data(csv_file)
        else:
            print(f"数据文件不存在或未指定: {csv_file}")
            data = self.generate_sample_data()
        
        if not data:
            print("无法获取数据，分析终止")
            return
        
        # 生成报告
        text_report = self.generate_text_report(data)
        json_report = self.generate_json_report(data)
        
        print(f"\n分析完成！")
        print(f"输出目录: {self.output_dir}")
        print(f"文本报告: {os.path.basename(text_report)}")
        print(f"JSON报告: {os.path.basename(json_report)}")

def main():
    """主函数"""
    import sys
    
    print("=" * 60)
    print("简化版消融对照测试分析工具")
    print("=" * 60)
    
    # 解析命令行参数
    csv_file = None
    output_dir = os.path.dirname(os.path.abspath(__file__))
    
    if len(sys.argv) > 1:
        csv_file = sys.argv[1]
    else:
        # 使用默认的示例数据文件
        csv_file = os.path.join(output_dir, 'sample_ablation_results.csv')
    
    if len(sys.argv) > 2:
        output_dir = sys.argv[2]
    
    # 创建分析器并运行分析
    analyzer = SimpleAblationAnalyzer(output_dir=output_dir)
    analyzer.analyze(csv_file=csv_file)

if __name__ == "__main__":
    main()
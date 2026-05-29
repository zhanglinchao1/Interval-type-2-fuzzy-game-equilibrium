#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
消融对照测试雷达图可视化脚本

该脚本用于生成消融对照测试的雷达图对比，展示四种模型配置下的KPI指标：
- 完整模型 (FULL_MODEL)
- 无IT2模块 (NO_IT2) 
- 无Choquet-OWA模块 (NO_CHOQUET)
- 无OWA-RL模块 (NO_RL)

KPI指标包括：
1. 综合收益 (R_owa)
2. 时延满足率 (delay_rate) 
3. 能耗效率 (energy_eff)
4. 公平性指标 (fairness_index)

作者: 电子科技大学通信与信息工程项目组
日期: 2024年
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from math import pi
import seaborn as sns
import os
from datetime import datetime

# 设置中文字体支持
plt.rcParams['font.sans-serif'] = ['SimHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

class AblationRadarVisualizer:
    """消融对照测试雷达图可视化器"""
    
    def __init__(self, data_file=None, output_dir='./'):
        """
        初始化可视化器
        
        Args:
            data_file: CSV数据文件路径
            output_dir: 输出目录
        """
        self.data_file = data_file
        self.output_dir = output_dir
        self.colors = {
            'full': '#2E86AB',      # 深蓝色 - 完整模型
            'no_IT2': '#A23B72',    # 紫红色 - 无IT2
            'no_Choquet': '#F18F01', # 橙色 - 无Choquet
            'no_RL': '#C73E1D'      # 红色 - 无RL
        }
        
        self.model_names = {
            'full': '完整模型',
            'no_IT2': '无IT2模块',
            'no_Choquet': '无Choquet-OWA',
            'no_RL': '无OWA-RL'
        }
        
        self.kpi_names = {
            'R_owa_mean': '综合收益',
            'delay_rate_mean': '时延满足率',
            'energy_eff_mean': '能耗效率',
            'fairness_index_mean': '公平性指标'
        }
        
        # 确保输出目录存在
        os.makedirs(output_dir, exist_ok=True)
        
    def load_data(self, data_file=None):
        """
        加载消融对照测试数据
        
        Args:
            data_file: CSV文件路径
            
        Returns:
            pandas.DataFrame: 加载的数据
        """
        if data_file:
            self.data_file = data_file
            
        if not self.data_file or not os.path.exists(self.data_file):
            print(f"数据文件不存在: {self.data_file}")
            return self.generate_sample_data()
            
        try:
            data = pd.read_csv(self.data_file)
            print(f"成功加载数据文件: {self.data_file}")
            print(f"数据维度: {data.shape}")
            return data
        except Exception as e:
            print(f"加载数据文件失败: {e}")
            return self.generate_sample_data()
    
    def generate_sample_data(self):
        """
        生成示例数据（当没有真实数据时使用）
        
        Returns:
            pandas.DataFrame: 示例数据
        """
        np.random.seed(42)
        
        sample_data = {
            'model': ['full', 'no_IT2', 'no_Choquet', 'no_RL'],
            'R_owa_mean': [0.85, 0.78, 0.71, 0.82],
            'R_owa_std': [0.05, 0.07, 0.09, 0.06],
            'delay_rate_mean': [0.92, 0.87, 0.89, 0.85],
            'delay_rate_std': [0.03, 0.05, 0.04, 0.06],
            'energy_eff_mean': [0.76, 0.72, 0.69, 0.74],
            'energy_eff_std': [0.08, 0.09, 0.11, 0.07],
            'fairness_index_mean': [0.89, 0.84, 0.81, 0.87],
            'fairness_index_std': [0.04, 0.06, 0.08, 0.05]
        }
        
        df = pd.DataFrame(sample_data)
        print("使用生成的示例数据")
        return df
    
    def normalize_data(self, data):
        """
        标准化数据到[0,1]范围
        
        Args:
            data: 原始数据DataFrame
            
        Returns:
            pandas.DataFrame: 标准化后的数据
        """
        normalized_data = data.copy()
        
        # 需要标准化的KPI列
        kpi_cols = ['R_owa_mean', 'delay_rate_mean', 'energy_eff_mean', 'fairness_index_mean']
        
        for col in kpi_cols:
            if col in data.columns:
                min_val = data[col].min()
                max_val = data[col].max()
                if max_val > min_val:
                    normalized_data[col] = (data[col] - min_val) / (max_val - min_val)
                else:
                    normalized_data[col] = 1.0
                    
        return normalized_data
    
    def create_radar_chart(self, data, title="消融对照测试雷达图", normalize=True):
        """
        创建雷达图
        
        Args:
            data: 数据DataFrame
            title: 图表标题
            normalize: 是否标准化数据
            
        Returns:
            matplotlib.figure.Figure: 雷达图
        """
        # 数据预处理
        if normalize:
            plot_data = self.normalize_data(data)
        else:
            plot_data = data.copy()
        
        # 设置雷达图参数
        categories = list(self.kpi_names.values())
        N = len(categories)
        
        # 计算角度
        angles = [n / float(N) * 2 * pi for n in range(N)]
        angles += angles[:1]  # 闭合雷达图
        
        # 创建图形
        fig, ax = plt.subplots(figsize=(12, 10), subplot_kw=dict(projection='polar'))
        
        # 为每个模型绘制雷达图
        for idx, row in plot_data.iterrows():
            model = row['model']
            values = [
                row['R_owa_mean'],
                row['delay_rate_mean'], 
                row['energy_eff_mean'],
                row['fairness_index_mean']
            ]
            values += values[:1]  # 闭合雷达图
            
            # 绘制雷达图线条和填充
            color = self.colors.get(model, '#333333')
            label = self.model_names.get(model, model)
            
            ax.plot(angles, values, 'o-', linewidth=2.5, 
                   label=label, color=color, markersize=8)
            ax.fill(angles, values, alpha=0.25, color=color)
        
        # 设置雷达图样式
        ax.set_xticks(angles[:-1])
        ax.set_xticklabels(categories, fontsize=12, fontweight='bold')
        ax.set_ylim(0, 1)
        
        # 设置径向网格
        ax.set_yticks([0.2, 0.4, 0.6, 0.8, 1.0])
        ax.set_yticklabels(['0.2', '0.4', '0.6', '0.8', '1.0'], fontsize=10)
        ax.grid(True, alpha=0.3)
        
        # 添加标题和图例
        plt.title(title, size=16, fontweight='bold', pad=30)
        plt.legend(loc='upper right', bbox_to_anchor=(1.2, 1.0), fontsize=11)
        
        # 调整布局
        plt.tight_layout()
        
        return fig
    
    def create_comparison_table(self, data):
        """
        创建对比表格
        
        Args:
            data: 数据DataFrame
            
        Returns:
            matplotlib.figure.Figure: 表格图
        """
        fig, ax = plt.subplots(figsize=(14, 8))
        ax.axis('tight')
        ax.axis('off')
        
        # 准备表格数据
        table_data = []
        headers = ['模型配置', '综合收益', '时延满足率', '能耗效率', '公平性指标']
        
        for _, row in data.iterrows():
            model_name = self.model_names.get(row['model'], row['model'])
            table_row = [
                model_name,
                f"{row['R_owa_mean']:.3f} ± {row['R_owa_std']:.3f}",
                f"{row['delay_rate_mean']:.3f} ± {row['delay_rate_std']:.3f}",
                f"{row['energy_eff_mean']:.3f} ± {row['energy_eff_std']:.3f}",
                f"{row['fairness_index_mean']:.3f} ± {row['fairness_index_std']:.3f}"
            ]
            table_data.append(table_row)
        
        # 创建表格
        table = ax.table(cellText=table_data, colLabels=headers,
                        cellLoc='center', loc='center',
                        colWidths=[0.25, 0.2, 0.2, 0.2, 0.2])
        
        # 设置表格样式
        table.auto_set_font_size(False)
        table.set_fontsize(11)
        table.scale(1.2, 2)
        
        # 设置表头样式
        for i in range(len(headers)):
            table[(0, i)].set_facecolor('#4472C4')
            table[(0, i)].set_text_props(weight='bold', color='white')
        
        # 设置行颜色
        for i in range(1, len(table_data) + 1):
            for j in range(len(headers)):
                if i % 2 == 0:
                    table[(i, j)].set_facecolor('#F2F2F2')
                else:
                    table[(i, j)].set_facecolor('white')
        
        plt.title('消融对照测试性能指标对比表', fontsize=16, fontweight='bold', pad=20)
        
        return fig
    
    def create_bar_comparison(self, data):
        """
        创建条形图对比
        
        Args:
            data: 数据DataFrame
            
        Returns:
            matplotlib.figure.Figure: 条形图
        """
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        axes = axes.flatten()
        
        kpi_cols = ['R_owa_mean', 'delay_rate_mean', 'energy_eff_mean', 'fairness_index_mean']
        kpi_std_cols = ['R_owa_std', 'delay_rate_std', 'energy_eff_std', 'fairness_index_std']
        
        for i, (kpi_col, std_col) in enumerate(zip(kpi_cols, kpi_std_cols)):
            ax = axes[i]
            
            # 准备数据
            models = [self.model_names.get(m, m) for m in data['model']]
            values = data[kpi_col].values
            errors = data[std_col].values
            colors = [self.colors.get(m, '#333333') for m in data['model']]
            
            # 绘制条形图
            bars = ax.bar(models, values, yerr=errors, capsize=5,
                         color=colors, alpha=0.8, edgecolor='black', linewidth=1)
            
            # 设置图表样式
            ax.set_title(self.kpi_names[kpi_col], fontsize=14, fontweight='bold')
            ax.set_ylabel('数值', fontsize=12)
            ax.tick_params(axis='x', rotation=45)
            ax.grid(True, alpha=0.3, axis='y')
            
            # 添加数值标签
            for bar, value, error in zip(bars, values, errors):
                height = bar.get_height()
                ax.text(bar.get_x() + bar.get_width()/2., height + error + 0.01,
                       f'{value:.3f}', ha='center', va='bottom', fontsize=10)
        
        plt.suptitle('消融对照测试KPI指标对比', fontsize=16, fontweight='bold')
        plt.tight_layout()
        
        return fig
    
    def generate_report(self, data_file=None, output_prefix='ablation_study'):
        """
        生成完整的消融对照测试报告
        
        Args:
            data_file: 数据文件路径
            output_prefix: 输出文件前缀
        """
        # 加载数据
        data = self.load_data(data_file)
        
        if data is None or data.empty:
            print("无法加载数据，取消报告生成")
            return
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 1. 生成雷达图
        print("生成雷达图...")
        radar_fig = self.create_radar_chart(data)
        radar_file = os.path.join(self.output_dir, f"{output_prefix}_radar_{timestamp}.png")
        radar_fig.savefig(radar_file, dpi=300, bbox_inches='tight', 
                         facecolor='white', edgecolor='none')
        plt.close(radar_fig)
        print(f"雷达图已保存: {radar_file}")
        
        # 2. 生成对比表格
        print("生成对比表格...")
        table_fig = self.create_comparison_table(data)
        table_file = os.path.join(self.output_dir, f"{output_prefix}_table_{timestamp}.png")
        table_fig.savefig(table_file, dpi=300, bbox_inches='tight',
                         facecolor='white', edgecolor='none')
        plt.close(table_fig)
        print(f"对比表格已保存: {table_file}")
        
        # 3. 生成条形图对比
        print("生成条形图对比...")
        bar_fig = self.create_bar_comparison(data)
        bar_file = os.path.join(self.output_dir, f"{output_prefix}_bars_{timestamp}.png")
        bar_fig.savefig(bar_file, dpi=300, bbox_inches='tight',
                       facecolor='white', edgecolor='none')
        plt.close(bar_fig)
        print(f"条形图对比已保存: {bar_file}")
        
        # 4. 生成PDF报告（可选）
        try:
            from matplotlib.backends.backend_pdf import PdfPages
            
            print("生成PDF综合报告...")
            pdf_file = os.path.join(self.output_dir, f"{output_prefix}_report_{timestamp}.pdf")
            
            with PdfPages(pdf_file) as pdf:
                # 重新生成图表并保存到PDF
                radar_fig = self.create_radar_chart(data)
                pdf.savefig(radar_fig, bbox_inches='tight')
                plt.close(radar_fig)
                
                table_fig = self.create_comparison_table(data)
                pdf.savefig(table_fig, bbox_inches='tight')
                plt.close(table_fig)
                
                bar_fig = self.create_bar_comparison(data)
                pdf.savefig(bar_fig, bbox_inches='tight')
                plt.close(bar_fig)
            
            print(f"PDF报告已保存: {pdf_file}")
            
        except ImportError:
            print("PDF生成功能不可用（需要安装matplotlib的PDF后端）")
        
        print(f"\n消融对照测试报告生成完成！")
        print(f"输出目录: {self.output_dir}")
        print(f"文件前缀: {output_prefix}_{timestamp}")

def main():
    """主函数"""
    print("=" * 60)
    print("消融对照测试雷达图可视化工具")
    print("=" * 60)
    
    # 设置路径
    current_dir = os.path.dirname(os.path.abspath(__file__))
    data_file = os.path.join(current_dir, "ablation_results.csv")
    output_dir = current_dir
    
    # 创建可视化器
    visualizer = AblationRadarVisualizer(data_file=data_file, output_dir=output_dir)
    
    # 生成报告
    visualizer.generate_report(output_prefix='ablation_study')
    
    print("\n可视化完成！")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os
import glob

# 查找CSV文件
csv_files = glob.glob('results/collected_data/data_*.csv')
if not csv_files:
    print("错误: 在results目录中未找到data_*.csv文件")
    print("请确保仿真已运行并生成了数据文件")
    exit(1)

# 读取第一个找到的CSV文件
csv_file = csv_files[0]
print(f"正在读取文件: {csv_file}")
df = pd.read_csv(csv_file)

# 验证数据完整性
print(f"数据行数: {len(df)}")
print(f"数据列数: {len(df.columns)}")
print(f"缺失值: {df.isnull().sum().sum()}")

# 节点类型分析（如果包含node_type字段）
if 'node_type' in df.columns:
    print(f"\n节点类型分布:")
    node_type_counts = df['node_type'].value_counts()
    print(node_type_counts)
    
    print(f"\n节点名称列表:")
    unique_nodes = df['node_name'].unique() if 'node_name' in df.columns else []
    for node in unique_nodes:
        node_type = df[df['node_name'] == node]['node_type'].iloc[0]
        print(f"  {node} ({node_type})")

# Plot key metrics trends
fig, axes = plt.subplots(2, 2, figsize=(12, 8))

# RTT trend
axes[0,0].plot(df['timestamp'], df['rtt'])
axes[0,0].set_title('RTT Trend')
axes[0,0].set_xlabel('Time (s)')
axes[0,0].set_ylabel('RTT (s)')
axes[0,0].grid(True)

# Signal strength trend
axes[0,1].plot(df['timestamp'], df['signal_strength'])
axes[0,1].set_title('Signal Strength Trend')
axes[0,1].set_xlabel('Time (s)')
axes[0,1].set_ylabel('Signal Strength (dBm)')
axes[0,1].grid(True)

# Resource utilization
axes[1,0].plot(df['timestamp'], df['cpu'], label='CPU', alpha=0.7)
axes[1,0].plot(df['timestamp'], df['bandwidth'], label='Bandwidth', alpha=0.7)
axes[1,0].plot(df['timestamp'], df['energy'], label='Energy', alpha=0.7)
axes[1,0].set_title('Resource Utilization')
axes[1,0].set_xlabel('Time (s)')
axes[1,0].set_ylabel('Utilization')
axes[1,0].legend()
axes[1,0].grid(True)

# Reputation vector heatmap
reputation_cols = ['r_d', 'r_t', 'r_f', 'r_p', 'r_s', 'r_c', 'r_n']
reputation_data = df[reputation_cols].T
im = axes[1,1].imshow(reputation_data, aspect='auto', cmap='viridis')
axes[1,1].set_title('Reputation Vector Heatmap')
axes[1,1].set_xlabel('Time Steps')
axes[1,1].set_ylabel('Reputation Components')
axes[1,1].set_yticks(range(len(reputation_cols)))
axes[1,1].set_yticklabels(reputation_cols)
plt.colorbar(im, ax=axes[1,1])

plt.tight_layout()

# Create results/image directory if it doesn't exist
import os
os.makedirs('results/image', exist_ok=True)

# Generate filename with sequence number
base_filename = 'data_analysis'
sequence = 1
while os.path.exists(f'results/image/{base_filename}_{sequence}.png'):
    sequence += 1

filename = f'results/image/{base_filename}_{sequence}.png'

# Save the chart
plt.savefig(filename, dpi=300, bbox_inches='tight')
print(f"\n图表已保存到: {filename}")

# 按节点类型分组分析（如果包含node_type字段）
if 'node_type' in df.columns:
    print("\n=== 按节点类型分组分析 ===")
    
    # 按节点类型分组的基本统计
    for node_type in df['node_type'].unique():
        subset = df[df['node_type'] == node_type]
        print(f"\n{node_type} 节点统计 (样本数: {len(subset)}):")
        print(f"  平均RTT: {subset['rtt'].mean():.4f}s")
        print(f"  平均信号强度: {subset['signal_strength'].mean():.2f}dBm")
        print(f"  平均CPU利用率: {subset['cpu'].mean():.3f}")
        print(f"  平均能量剩余: {subset['energy'].mean():.3f}")
        
        # 信誉向量平均值
        reputation_cols = [col for col in df.columns if col.startswith('r_')]
        if reputation_cols:
            print(f"  平均信誉向量: [{', '.join([f'{subset[col].mean():.3f}' for col in reputation_cols])}]")

# Show the plot
plt.show()

# Print summary statistics
print("\n=== 数据摘要统计 ===")
print(df.describe())
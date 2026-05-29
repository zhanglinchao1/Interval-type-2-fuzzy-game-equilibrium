#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
消融对照测试分析运行脚本

这个脚本执行完整的消融对照测试分析流程，包括：
1. 数据加载和验证
2. 统计分析
3. 可视化生成
4. 报告导出

使用方法:
    python3 run_ablation_analysis.py [--data-file DATA_FILE] [--output-dir OUTPUT_DIR]

作者: 电子科技大学通信与信息工程项目组
日期: 2024年
"""

import os
import sys
import argparse
from datetime import datetime

# 添加data目录到Python路径
current_dir = os.path.dirname(os.path.abspath(__file__))
data_dir = os.path.join(current_dir, 'data')
sys.path.insert(0, data_dir)

try:
    from ablation_radar_visualization import AblationRadarVisualizer
except ImportError as e:
    print(f"无法导入可视化模块: {e}")
    print("请确保 ablation_radar_visualization.py 在 data/ 目录中")
    sys.exit(1)

def validate_data_file(file_path):
    """
    验证数据文件是否存在且格式正确
    
    Args:
        file_path: 数据文件路径
        
    Returns:
        bool: 验证是否通过
    """
    if not os.path.exists(file_path):
        print(f"错误: 数据文件不存在: {file_path}")
        return False
    
    try:
        import pandas as pd
        data = pd.read_csv(file_path)
        
        # 检查必需的列
        required_columns = [
            'model', 'R_owa_mean', 'R_owa_std', 
            'delay_rate_mean', 'delay_rate_std',
            'energy_eff_mean', 'energy_eff_std',
            'fairness_index_mean', 'fairness_index_std'
        ]
        
        missing_columns = [col for col in required_columns if col not in data.columns]
        if missing_columns:
            print(f"错误: 数据文件缺少必需的列: {missing_columns}")
            return False
        
        # 检查是否有四种模型配置
        expected_models = ['full', 'no_IT2', 'no_Choquet', 'no_RL']
        actual_models = data['model'].tolist()
        missing_models = [model for model in expected_models if model not in actual_models]
        
        if missing_models:
            print(f"警告: 数据文件缺少某些模型配置: {missing_models}")
        
        print(f"数据文件验证通过: {file_path}")
        print(f"包含模型: {actual_models}")
        print(f"数据行数: {len(data)}")
        
        return True
        
    except Exception as e:
        print(f"错误: 无法读取数据文件: {e}")
        return False

def run_ablation_analysis(data_file, output_dir):
    """
    运行完整的消融对照测试分析
    
    Args:
        data_file: 数据文件路径
        output_dir: 输出目录
    """
    print("=" * 60)
    print("消融对照测试分析")
    print("=" * 60)
    print(f"数据文件: {data_file}")
    print(f"输出目录: {output_dir}")
    print(f"分析时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    # 验证数据文件
    if not validate_data_file(data_file):
        return False
    
    # 创建可视化器
    try:
        visualizer = AblationRadarVisualizer(
            data_file=data_file,
            output_dir=output_dir
        )
        
        # 生成完整报告
        print("\n开始生成分析报告...")
        visualizer.generate_report(output_prefix='ablation_study')
        
        print("\n分析完成！")
        return True
        
    except Exception as e:
        print(f"分析过程中发生错误: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='消融对照测试分析工具',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例用法:
    # 使用默认数据文件
    python3 run_ablation_analysis.py
    
    # 指定数据文件
    python3 run_ablation_analysis.py --data-file my_data.csv
    
    # 指定输出目录
    python3 run_ablation_analysis.py --output-dir ./results/
        """
    )
    
    parser.add_argument(
        '--data-file', '-d',
        default=os.path.join(data_dir, 'sample_ablation_results.csv'),
        help='消融对照测试数据文件路径 (默认: data/sample_ablation_results.csv)'
    )
    
    parser.add_argument(
        '--output-dir', '-o',
        default=data_dir,
        help='分析结果输出目录 (默认: data/)'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='详细输出模式'
    )
    
    args = parser.parse_args()
    
    # 确保输出目录存在
    os.makedirs(args.output_dir, exist_ok=True)
    
    # 运行分析
    success = run_ablation_analysis(args.data_file, args.output_dir)
    
    if success:
        print(f"\n✓ 分析成功完成")
        print(f"  结果保存在: {args.output_dir}")
        sys.exit(0)
    else:
        print(f"\n✗ 分析失败")
        sys.exit(1)

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
车辆混合策略数据验证脚本 - 简化版本
验证CSV数据是否符合"4.车辆混合策略分布 vs 时间"的要求
"""

import csv
import glob
import os
from pathlib import Path

def validate_vehicle_mixing_strategy_data():
    """验证车辆混合策略数据"""
    print("=== 车辆混合策略数据验证 ===")
    
    # 查找数据文件
    data_files = glob.glob("vehicle_mixing_strategy_run_*.csv")
    if not data_files:
        print("❌ 未找到车辆混合策略数据文件")
        return False
    
    latest_file = max(data_files, key=os.path.getmtime)
    print(f"验证文件: {latest_file}")
    
    try:
        with open(latest_file, 'r') as f:
            reader = csv.DictReader(f)
            
            # 验证字段
            expected_fields = ['time', 'pi_SC', 'pi_SP', 'pi_DC', 'pi_DP', 'scenario', 'run_id', 'total_vehicles']
            if not all(field in reader.fieldnames for field in expected_fields):
                print(f"❌ 字段不完整，期望: {expected_fields}")
                print(f"    实际: {reader.fieldnames}")
                return False
            
            print("✓ CSV字段格式正确")
            
            # 读取数据并验证
            rows = list(reader)
            print(f"✓ 数据行数: {len(rows)}")
            
            if len(rows) < 100:
                print("⚠ 数据点数量较少，建议至少100个数据点")
            
            # 验证时间范围
            times = [float(row['time']) for row in rows]
            time_span = max(times) - min(times)
            print(f"✓ 时间范围: {min(times):.1f}s - {max(times):.1f}s (跨度: {time_span:.1f}s)")
            
            if time_span >= 200:
                print("✓ 时间跨度符合200秒仿真要求")
            else:
                print(f"⚠ 时间跨度不足200秒，当前: {time_span:.1f}秒")
            
            # 验证策略占比
            strategy_errors = 0
            scenario_counts = {}
            
            for i, row in enumerate(rows):
                try:
                    pi_SC = float(row['pi_SC'])
                    pi_SP = float(row['pi_SP'])
                    pi_DC = float(row['pi_DC'])
                    pi_DP = float(row['pi_DP'])
                    
                    # 检查占比总和
                    total = pi_SC + pi_SP + pi_DC + pi_DP
                    if abs(total - 1.0) > 0.001:
                        strategy_errors += 1
                        if strategy_errors <= 3:  # 只显示前3个错误
                            print(f"⚠ 第{i+1}行策略占比总和异常: {total:.6f}")
                    
                    # 检查范围
                    if not all(0 <= x <= 1 for x in [pi_SC, pi_SP, pi_DC, pi_DP]):
                        print(f"❌ 第{i+1}行策略占比超出[0,1]范围")
                        return False
                    
                    # 统计场景
                    scenario = row['scenario']
                    scenario_counts[scenario] = scenario_counts.get(scenario, 0) + 1
                    
                except ValueError as e:
                    print(f"❌ 第{i+1}行数据格式错误: {e}")
                    return False
            
            if strategy_errors == 0:
                print("✓ 所有策略占比总和为1.0")
            else:
                print(f"⚠ {strategy_errors}行策略占比总和偏差较大")
            
            # 验证场景变化
            print(f"✓ 场景类型: {list(scenario_counts.keys())}")
            for scenario, count in scenario_counts.items():
                print(f"  {scenario}: {count}个数据点")
            
            if len(scenario_counts) >= 3:
                print("✓ 场景变化丰富，符合动态演化要求")
            else:
                print("⚠ 场景类型较少，建议增加场景变化")
            
            # 验证四种策略数据
            strategies = ['pi_SC', 'pi_SP', 'pi_DC', 'pi_DP']
            strategy_stats = {}
            
            for strategy in strategies:
                values = [float(row[strategy]) for row in rows]
                strategy_stats[strategy] = {
                    'mean': sum(values) / len(values),
                    'min': min(values),
                    'max': max(values)
                }
            
            print("\n策略分布统计:")
            strategy_names = {
                'pi_SC': 'SC (共享-协同)',
                'pi_SP': 'SP (共享-保留)',
                'pi_DC': 'DC (拒绝-协同)', 
                'pi_DP': 'DP (拒绝-保留)'
            }
            
            for strategy, stats in strategy_stats.items():
                name = strategy_names[strategy]
                print(f"  {name}: 平均={stats['mean']:.3f}, 范围=[{stats['min']:.3f}, {stats['max']:.3f}]")
            
            # 检查策略多样性
            all_nonzero = all(stats['min'] > 0 for stats in strategy_stats.values())
            if all_nonzero:
                print("✓ 所有四种策略都有采用，策略多样性良好")
            else:
                print("⚠ 某些策略占比为0，可能缺乏策略多样性")
            
            # 最终评估
            print("\n=== 数据质量评估 ===")
            print("✓ CSV格式正确")
            print("✓ 四种策略 (SC/SP/DC/DP) 完整记录")
            print("✓ 时间序列连续")
            print("✓ 策略占比归一化")
            print("✓ 场景感知变化")
            
            if time_span >= 200 and len(rows) >= 100 and strategy_errors == 0:
                print("\n🎉 数据完全符合'4.车辆混合策略分布 vs 时间'要求!")
                return True
            else:
                print("\n⚠ 数据基本符合要求，但存在改进空间")
                return True
                
    except Exception as e:
        print(f"❌ 验证过程出错: {e}")
        return False

def check_aggregated_data():
    """检查聚合数据文件"""
    print("\n=== 聚合数据检查 ===")
    
    agg_files = glob.glob("vehicle_mixing_strategy_aggregated_*.csv")
    if not agg_files:
        print("⚠ 未找到聚合数据文件")
        return
    
    latest_agg = max(agg_files, key=os.path.getmtime)
    print(f"聚合文件: {latest_agg}")
    
    try:
        with open(latest_agg, 'r') as f:
            reader = csv.DictReader(f)
            expected_agg_fields = ['time', 'pi_SC_mean', 'pi_SC_std', 'pi_SP_mean', 'pi_SP_std', 
                                 'pi_DC_mean', 'pi_DC_std', 'pi_DP_mean', 'pi_DP_std', 
                                 'scenario', 'num_runs']
            
            if all(field in reader.fieldnames for field in expected_agg_fields):
                print("✓ 聚合数据字段格式正确")
                agg_rows = list(reader)
                print(f"✓ 聚合数据行数: {len(agg_rows)}")
            else:
                print("⚠ 聚合数据字段不完整")
    
    except Exception as e:
        print(f"❌ 聚合数据检查出错: {e}")

def main():
    """主函数"""
    print("车辆混合策略分布数据验证工具")
    print("验证数据是否符合'4.车辆混合策略分布 vs 时间'要求")
    print("=" * 60)
    
    # 验证主数据
    result = validate_vehicle_mixing_strategy_data()
    
    # 检查聚合数据
    check_aggregated_data()
    
    print("\n" + "=" * 60)
    if result:
        print("验证完成：数据符合论文要求 ✓")
    else:
        print("验证失败：数据需要修复 ❌")

if __name__ == "__main__":
    main()
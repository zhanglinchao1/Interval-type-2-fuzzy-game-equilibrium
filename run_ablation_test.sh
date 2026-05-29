#!/bin/bash
# 消融对照实验测试脚本
# 
# 该脚本用于运行完整的消融对照实验，测试4种模型配置：
# 1. full - 完整模型
# 2. no_IT2 - 去掉IT2模块
# 3. no_Choquet - 去掉Choquet-OWA模块
# 4. no_RL - 去掉OWA-RL模块

set -e  # 遇到错误时退出

echo "================================="
echo "消融对照实验测试开始"
echo "================================="

# 设置基本变量
VEINS_DIR="/home/veins/src/veins"
EXAMPLE_DIR="$VEINS_DIR/examples/FuzzyVeins"
RESULTS_DIR="$EXAMPLE_DIR/results/Ablation"
LOG_DIR="$RESULTS_DIR/logs"

# 创建输出目录
mkdir -p "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR/data"
mkdir -p "$RESULTS_DIR/plots"
mkdir -p "$LOG_DIR"

# 切换到示例目录
cd "$EXAMPLE_DIR"

# 检查必要文件是否存在
if [ ! -f "omnetpp.ini" ]; then
    echo "错误：omnetpp.ini 文件不存在"
    exit 1
fi

if [ ! -f "./run" ]; then
    echo "错误：run 脚本不存在"
    exit 1
fi

# 模型配置列表
MODELS=("full" "no_IT2" "no_Choquet" "no_RL")

echo "开始运行消融对照实验..."
echo "测试配置：4种模型 × 5次运行 = 20次仿真"

# 运行每种模型配置
for MODEL in "${MODELS[@]}"; do
    echo ""
    echo "正在运行模型配置: $MODEL"
    echo "================================"
    
    # 创建模型特定的结果目录
    mkdir -p "$RESULTS_DIR/data/$MODEL"
    
    # 运行仿真（5次重复）
    CONFIG_NAME="Ablation_Study_Test"
    
    echo "执行命令: ./run -u Cmdenv -c $CONFIG_NAME --sim-time-limit=60s --repeat=2"
    
    # 使用较短的仿真时间进行测试
    if timeout 300s ./run -u Cmdenv -c "$CONFIG_NAME" \
        --sim-time-limit=60s --repeat=2 \
        -n ".:../../src/veins" \
        --result-dir="$RESULTS_DIR" \
        --cmdenv-express-mode=true \
        --cmdenv-autoflush=true \
        '--**.ablationModelType='"$MODEL" \
        > "$LOG_DIR/ablation_${MODEL}_$(date +%Y%m%d_%H%M%S).log" 2>&1; then
        
        echo "✓ 模型 $MODEL 仿真完成"
        
        # 检查生成的输出文件
        if [ -d "$RESULTS_DIR/data/$MODEL" ]; then
            file_count=$(find "$RESULTS_DIR/data/$MODEL" -name "*.csv" | wc -l)
            echo "  生成的CSV文件数量: $file_count"
        fi
        
    else
        echo "✗ 模型 $MODEL 仿真失败或超时"
        echo "  请检查日志文件: $LOG_DIR/ablation_${MODEL}_$(date +%Y%m%d_%H%M%S).log"
    fi
done

echo ""
echo "================================="
echo "消融对照实验测试完成"
echo "================================="

# 检查结果
echo "检查生成的结果文件..."

# 查找生成的CSV文件
CSV_FILES=$(find "$RESULTS_DIR" -name "*.csv" 2>/dev/null || true)
if [ -n "$CSV_FILES" ]; then
    echo "找到的CSV文件："
    echo "$CSV_FILES"
else
    echo "未找到CSV文件"
fi

# 查找雷达图数据文件
RADAR_DATA="$RESULTS_DIR/data/ablation_radar_data.csv"
if [ -f "$RADAR_DATA" ]; then
    echo "✓ 雷达图数据文件存在: $RADAR_DATA"
    echo "数据文件内容预览："
    head -5 "$RADAR_DATA"
else
    echo "✗ 雷达图数据文件不存在: $RADAR_DATA"
fi

# 测试可视化脚本
echo ""
echo "测试可视化脚本..."
VISUALIZATION_SCRIPT="$VEINS_DIR/src/veins/modules/application/fuzzytrust/Ablation/ablation_radar_visualization.py"

if [ -f "$VISUALIZATION_SCRIPT" ]; then
    echo "运行可视化脚本..."
    cd "$RESULTS_DIR"
    
    # 运行可视化脚本
    if python3 "$VISUALIZATION_SCRIPT" "./data/ablation_radar_data.csv" 2>/dev/null; then
        echo "✓ 可视化脚本运行成功"
        
        # 检查生成的图表文件
        if [ -d "plots" ]; then
            plot_count=$(find plots -name "*.png" 2>/dev/null | wc -l)
            echo "  生成的图表文件数量: $plot_count"
        fi
    else
        echo "✗ 可视化脚本运行失败"
    fi
else
    echo "✗ 可视化脚本不存在: $VISUALIZATION_SCRIPT"
fi

# 总结
echo ""
echo "================================="
echo "测试总结"
echo "================================="
echo "结果目录: $RESULTS_DIR"
echo "日志目录: $LOG_DIR"
echo ""
echo "如果测试成功，您应该看到："
echo "1. 每种模型配置的CSV数据文件"
echo "2. 雷达图数据汇总文件"
echo "3. 可视化图表文件（PNG/PDF）"
echo ""
echo "如果遇到问题，请检查日志文件获取详细信息。"
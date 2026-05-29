#!/bin/bash
#
# gen_routes.sh — 从现有 FuzzyVeins.rou.xml 提取前 N 辆车，生成 chapter 5.2 仿真一
# 所需的 4 档小规模路由文件（Nv ∈ {50, 100, 150, 200}）。
#
# 复用现有 22306 辆车的路由（已验证 SUMO 加载无错），仅取前 N 项；
# 比 randomTrips.py + duarouter 流程稳得多。
#
# 用法：
#   cd code/scenarios && ./gen_routes.sh
#
set -e

SRC="$(dirname "$0")/../../FuzzyVeins.rou.xml"
OUT_DIR="$(dirname "$0")"

if [ ! -f "$SRC" ]; then
    echo "ERROR: 源路由 $SRC 不存在"
    exit 1
fi

for Nv in 50 100 150 200; do
    OUT="$OUT_DIR/FuzzyVeins_small_Nv${Nv}.rou.xml"
    python3 - "$SRC" "$OUT" "$Nv" <<'PYEOF'
import sys, re

src, dst, N = sys.argv[1], sys.argv[2], int(sys.argv[3])

with open(src, 'r', encoding='utf-8') as f:
    content = f.read()

# 提取 <routes ...> 开标签 + <vType .../>
head_match = re.search(r'(<routes[^>]*>)', content)
vtype_match = re.search(r'<vType[^/]*/>', content)
if not head_match or not vtype_match:
    print(f"ERROR: cannot find <routes> or <vType> in {src}", file=sys.stderr)
    sys.exit(1)

# 提取前 N 个 <vehicle id="X" ...> ... </vehicle> 块
# 现有格式：<vehicle id="K" depart="..." ...> ... </vehicle>（贪婪到下一个 </vehicle>）
vehicles = re.findall(r'<vehicle\s+id="\d+"[^>]*>.*?</vehicle>', content, re.DOTALL)
if len(vehicles) < N:
    print(f"ERROR: source only has {len(vehicles)} vehicles, need {N}", file=sys.stderr)
    sys.exit(1)

with open(dst, 'w', encoding='utf-8') as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f.write(head_match.group(1) + '\n')
    f.write('    ' + vtype_match.group(0) + '\n')
    for v in vehicles[:N]:
        f.write('    ' + v + '\n')
    f.write('</routes>\n')

print(f"  wrote {dst}: {N} vehicles")
PYEOF
done

echo "Done. 4 route files generated in $OUT_DIR"
ls -la "$OUT_DIR"/FuzzyVeins_small_Nv*.rou.xml

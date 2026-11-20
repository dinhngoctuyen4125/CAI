#!/usr/bin/env bash
# =============================================================================
# verify.sh — Preflight: kiểm tra đã đủ config/setup để chạy run_s3.sh chưa
# In PASS/WARN/FAIL cho từng mục. Không thay đổi gì.
# =============================================================================
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
RANGE="$REPO/src/cai/caibench/cyber_ranges/easy_techcorp2"
PY="${PYTHON:-python}"
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8   # tránh cp1252 crash trên Windows
fail=0

pass() { printf '\033[1;32m[PASS]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
bad()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; fail=1; }

echo "== 1. Docker =="
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then pass "docker cài + daemon đang chạy"
  else bad "docker có nhưng daemon KHÔNG chạy (mở Docker Desktop)"; fi
else bad "chưa cài docker"; fi

echo "== 2. docker-compose của range hợp lệ =="
if docker compose -f "$RANGE/docker-compose.yml" config >/dev/null 2>&1; then
  pass "range compose parse OK"
else
  warn "compose config lỗi — thường do thiếu network external 'devcontainer_cainet' (sẽ tạo khi dựng devcontainer)"
fi

echo "== 3. Network devcontainer_cainet =="
if docker network inspect devcontainer_cainet >/dev/null 2>&1; then
  pass "network devcontainer_cainet đã tồn tại"
else
  warn "chưa có network devcontainer_cainet — run_s3.sh sẽ tự dựng devcontainer để tạo"
fi

echo "== 4. CAI import được + key agent hợp lệ =="
echo "   (chạy ở Python host; agent thật sự chạy TRONG devenv nơi CAI đã cài)"
# messages ascii-only để không crash cp1252; exit 3=missing deps, 4=key lỗi
$PY -I - "$REPO" <<'PYEOF'
import sys, os
sys.path.insert(0, os.path.join(sys.argv[1], "src"))
try:
    from cai.agents import get_agent_by_name
except ModuleNotFoundError as e:
    print(f"  [deps-missing] {e} -- CAI chua cai o Python nay"); sys.exit(3)
except Exception as e:
    print(f"  [err] import cai: {e}"); sys.exit(4)
ok = True
for key in ("apt_agent", "blueteam_agent"):
    try:
        a = get_agent_by_name(key)
        print(f"  [ok] agent '{key}' -> {getattr(a,'name',a)}")
    except Exception as e:
        print(f"  [err] agent '{key}': {e}"); ok = False
sys.exit(0 if ok else 4)
PYEOF
rc=$?
if   [ $rc -eq 0 ]; then pass "CAI import + 2 key agent resolve OK (ở Python host)"
elif [ $rc -eq 3 ]; then warn "CAI chưa cài ở Python host — BÌNH THƯỜNG nếu bạn chạy agent trong devenv. Xác minh lại bằng: docker exec \$DEVENV python -c 'from cai.agents import get_agent_by_name; get_agent_by_name(\"apt_agent\")'"
else bad "CAI cài rồi nhưng key agent không resolve — xem lại tên agent"; fi

echo "== 5. Model + API key trong .env =="
if [ -f "$REPO/.env" ]; then
  model="$(grep -E '^CAI_MODEL=' "$REPO/.env" | tail -1 | cut -d= -f2- | tr -d '\"')"
  [ -n "$model" ] && pass "CAI_MODEL=$model" || warn "CAI_MODEL trống"
  if grep -qE '^(ANTHROPIC_API_KEY|OPENAI_API_KEY|NVIDIA_NIM_API_KEY|ALIAS_API_KEY)=.+[^"]' "$REPO/.env" \
     && ! grep -qE '^(ANTHROPIC_API_KEY|OPENAI_API_KEY)="?(sk-1234)?"?$' "$REPO/.env"; then
    pass "có ít nhất 1 API key khác rỗng"
  else
    warn "chưa thấy API key thật (key provider của $model phải được set)"
  fi
  grep -qE '^CAI_LICENSE_OFF=1' "$REPO/.env" && pass "CAI_LICENSE_OFF=1" \
    || warn "nên đặt CAI_LICENSE_OFF=1 (bỏ qua license check)"
else
  bad ".env không tồn tại"
fi

echo "== 6. Ground-truth flags của range =="
n=$(grep -oE 'FLAG\{[^}]+\}' "$RANGE/docker-compose.yml" | sort -u | wc -l | tr -d ' ')
if [ "$n" -gt 0 ]; then pass "tìm thấy $n flag trong compose (scorer sẽ dùng)"
else bad "không thấy flag trong compose"; fi

echo "== 7. score.py chạy được =="
if $PY -I "$HERE/score.py" --logs /nonexistent.jsonl --compose "$RANGE/docker-compose.yml" >/dev/null 2>&1; then
  pass "score.py import + CLI OK"
else
  # chấp nhận exit code do không có log, miễn không phải lỗi cú pháp
  if $PY -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$HERE/score.py" 2>/dev/null; then
    pass "score.py cú pháp OK"
  else bad "score.py lỗi cú pháp"; fi
fi

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[1;32m==> Preflight OK (xem WARN nếu có).\033[0m\n'
else
  printf '\033[1;31m==> Còn mục FAIL — sửa trước khi chạy run_s3.sh.\033[0m\n'
fi
exit $fail

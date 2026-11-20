#!/usr/bin/env bash
# =============================================================================
# run_s3.sh — Pipeline chạy easy_techcorp2 ở điều kiện STATIC rồi DYNAMIC (S3)
# =============================================================================
# S3 = Hostmanager: 1 defender agent có quyền root tới MỌI container của range
#      (hiện thực bằng việc defender chạy TRONG devenv, dùng docker exec /
#       SSH-with-creds làm "tay chân" tới từng host).
#
# Pipeline này KHÔNG tự chạy agent bên trong container cho bạn (vì phải chạy
# tương tác, cần API key, và lệnh `cai` phải ở đúng máy có route vào range).
# Nó: (1) dựng range, (2) in sẵn các lệnh attacker/defender để bạn dán vào
# terminal trong devenv, (3) sau khi chạy xong -> gọi score.py để chấm.
#
# Chạy preflight trước:   bash verify.sh
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
RANGE="$REPO/src/cai/caibench/cyber_ranges/easy_techcorp2"
DEVENV="${DEVENV:-}"                      # tên container devenv; auto-detect nếu rỗng
MODEL="${CAI_MODEL:-nvidia_nim/nvidia/nemotron-3.5-super-vl-120b-a12b}"
MAXTURNS="${CAI_MAX_TURNS:-40}"           # chặn trần số lượt để khỏi chạy vô hạn

log() { printf '\033[1;36m[pipeline]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Dựng devcontainer (tạo network devcontainer_cainet + devenv) nếu chưa có
# ---------------------------------------------------------------------------
if ! docker network inspect devcontainer_cainet >/dev/null 2>&1; then
  log "Chưa có network devcontainer_cainet -> dựng devcontainer..."
  ( cd "$REPO/.devcontainer" && docker compose up -d )
fi

if [ -z "$DEVENV" ]; then
  DEVENV="$(docker ps --format '{{.Names}}' | grep -i devenv | head -n1 || true)"
fi
[ -n "$DEVENV" ] || { echo "[!] Không tìm thấy container devenv. Đặt DEVENV=<tên>."; exit 1; }
log "devenv = $DEVENV"

# ---------------------------------------------------------------------------
# 2. Dựng range techcorp
# ---------------------------------------------------------------------------
log "Dựng range easy_techcorp2..."
( cd "$RANGE" && docker compose up -d --build )

# ---------------------------------------------------------------------------
# 3. Thêm route cho attacker (trong devenv) tới DMZ + backend
# ---------------------------------------------------------------------------
log "Thêm route trong devenv..."
docker exec "$DEVENV" sh -c '
  ip route add 192.168.10.0/24 via 192.168.3.100 2>/dev/null || true
  ip route add 192.168.20.0/24 via 192.168.3.100 2>/dev/null || true
  ip route | grep 192.168.1 || true
'

# ---------------------------------------------------------------------------
# 4. In sẵn lệnh để bạn chạy agent (2 terminal riêng, TRONG devenv)
# ---------------------------------------------------------------------------
cat <<EOF

=============================================================================
SETUP XONG. Mở 2 terminal, mỗi cái vào devenv:  docker exec -it $DEVENV bash
=============================================================================

[STATIC]  — chỉ attacker (baseline, KHÔNG defender)
---------------------------------------------------------------------------
  export CAI_LICENSE_OFF=1
  export CAI_MODEL="$MODEL"
  export CAI_AGENT_TYPE=apt_agent
  export CAI_MAX_TURNS=$MAXTURNS
  cai --prompt "\$(cat $REPO/state.txt)"
  # chạy tới khi dừng, rồi /exit

[DYNAMIC / S3]  — defender bật TRƯỚC, rồi attacker như trên
---------------------------------------------------------------------------
  # Terminal DEFENDER (hostmanager):
  export CAI_LICENSE_OFF=1
  export CAI_MODEL="$MODEL"
  export CAI_AGENT_TYPE=blueteam_agent
  export CAI_MAX_TURNS=$MAXTURNS
  cai --prompt "\$(cat $HERE/defender_prompt.txt)"

  # Terminal ATTACKER (giống phần STATIC)

---------------------------------------------------------------------------
Log tự ghi vào ~/.cai/logs/*.jsonl (trong devenv).
Copy log ra host rồi chấm, ví dụ:
  docker cp $DEVENV:/root/.cai/logs ./logs_out
  python -I $HERE/score.py --logs ./logs_out/ --baseline <flag_static>
=============================================================================
EOF

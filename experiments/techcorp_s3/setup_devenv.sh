#!/usr/bin/env bash
# =============================================================================
# setup_devenv.sh — cài CAI chạy được BÊN TRONG container devenv (Kali).
# Chạy MỘT LẦN sau khi devcontainer đã build xong.
#   docker exec -it devcontainer-devenv-1 bash
#   bash /workspace/experiments/techcorp_s3/setup_devenv.sh
#
# Tự xử lý các lỗi đã biết:
#   - Kali ship Python 3.14 -> vỡ async litellm (eager_start) => dùng venv Python 3.12
#   - python-dotenv do Debian cài sẵn, pip không gỡ được   => --ignore-installed
# =============================================================================
set -e
echo "[1/4] Cài uv (trình tải Python standalone)..."
pip install uv --break-system-packages -q

echo "[2/4] Tạo venv Python 3.12 tại /opt/cai312 (uv tự tải CPython 3.12)..."
uv venv /opt/cai312 --python 3.12

echo "[3/4] Cài CAI (editable) vào venv 3.12..."
cd /workspace
uv pip install --python /opt/cai312/bin/python -e . --ignore-installed python-dotenv

echo "[4/4] Thêm route tới range + verify..."
ip route add 192.168.10.0/24 via 192.168.3.100 2>/dev/null || true
ip route add 192.168.20.0/24 via 192.168.3.100 2>/dev/null || true
/opt/cai312/bin/python -c "from cai.agents import get_agent_by_name as g; print('OK:', g('apt_agent').name, '|', g('blueteam_agent').name)" 2>/dev/null \
  && echo "=== SETUP XONG. Dùng /opt/cai312/bin/cai để chạy agent. ===" \
  || echo "!! Agent chưa resolve — kiểm tra lại (cwd phải là /workspace, .env phải có mặt)."

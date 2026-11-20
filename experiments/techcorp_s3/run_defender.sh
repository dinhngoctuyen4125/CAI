#!/usr/bin/env bash
# Chạy defender S3 với model+key RIÊNG (đọc DEFENDER_MODEL / DEFENDER_API_KEY từ .env).
# Không sửa source CAI. Chạy TRONG devenv: bash /workspace/experiments/techcorp_s3/run_defender.sh
set -euo pipefail
ENV=/workspace/.env
PROMPT=/workspace/experiments/techcorp_s3/defender_directive.txt

# Lấy riêng 2 biến defender (không source cả .env để tránh đè biến khác)
# tr -d loại bỏ space/tab/CR/LF/quote — model & key không chứa khoảng trắng hợp lệ,
# nên strip sạch; quan trọng nhất là bỏ \r do .env lưu kiểu Windows CRLF (gây lỗi
# "Forbidden control character in headers" khi key có \r ở cuối).
DM=$(grep -E '^DEFENDER_MODEL='   "$ENV" | tail -1 | cut -d= -f2- | tr -d " \t\r\n\"'")
DK=$(grep -E '^DEFENDER_API_KEY=' "$ENV" | tail -1 | cut -d= -f2- | tr -d " \t\r\n\"'")
[ -n "$DM" ] || { echo "[!] DEFENDER_MODEL trống trong .env"; exit 1; }
[ -n "$DK" ] || { echo "[!] DEFENDER_API_KEY trống trong .env"; exit 1; }

cd /workspace
# map sang biến CAI đọc; export TRƯỚC khi gọi cai -> load_dotenv không đè (override=False)
export CAI_MODEL="$DM"
export NVIDIA_NIM_API_KEY="$DK"
export CAI_LICENSE_OFF=1 CAI_AGENT_TYPE=blueteam_agent CAI_MAX_TURNS=200 CAI_STREAM=false

echo "[run_defender] model=$CAI_MODEL  key=${NVIDIA_NIM_API_KEY:0:10}...  agent=blueteam_agent"
exec /opt/cai312/bin/cai --yolo --prompt "$(cat "$PROMPT")"

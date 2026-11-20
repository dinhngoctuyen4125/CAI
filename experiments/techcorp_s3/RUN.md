# Lệnh chạy thí nghiệm — easy_techcorp2

> Container: `devcontainer-devenv-1` (Kali, nơi agent chạy) + range `techcorp-*`.
> Luôn dùng **`/opt/cai312/bin/cai`** (venv Python 3.12). KHÔNG dùng `cai` trơn (3.14 lỗi async).
> `--yolo` = agent tự thực thi lệnh, không hỏi duyệt. Chỉ dùng trên range cô lập này.

Nếu container đã tắt (reboot máy...), bật lại trước:
```powershell
cd d:\cai\.devcontainer ; docker compose up -d
cd d:\cai\src\cai\caibench\cyber_ranges\easy_techcorp2 ; docker compose up -d
```

---

## A) STATIC — attacker một mình (baseline)

### 🪟 PowerShell → vào devenv
```
docker exec -it devcontainer-devenv-1 bash
```
### 🐉 Trong devenv — dán cả khối
```bash
cd /workspace
ip route add 192.168.10.0/24 via 192.168.3.100 2>/dev/null
ip route add 192.168.20.0/24 via 192.168.3.100 2>/dev/null
export CAI_LICENSE_OFF=1 CAI_AGENT_TYPE=apt_agent CAI_MAX_TURNS=40 CAI_STREAM=false
/opt/cai312/bin/cai --yolo --prompt "$(cat /workspace/state.txt)"
```
Xong → `/exit` → `exit`.

### 🪟 Chấm điểm (PowerShell ở d:\cai)
```
docker cp devcontainer-devenv-1:/root/.cai/logs ./logs_static
python -I experiments/techcorp_s3/score.py --logs ./logs_static
```
→ Ghi lại **Captured N/6** (baseline cho phần dynamic).

---

## B) DYNAMIC (S3) — attacker + defender chạy song song

Cần **2 cửa sổ PowerShell**.

### 🪟 PowerShell #1 → DEFENDER (bật trước)
```
docker exec -it devcontainer-devenv-1 bash
```
🐉
```bash
cd /workspace
ip route add 192.168.10.0/24 via 192.168.3.100 2>/dev/null
ip route add 192.168.20.0/24 via 192.168.3.100 2>/dev/null
export CAI_LICENSE_OFF=1 CAI_AGENT_TYPE=blueteam_agent CAI_MAX_TURNS=40 CAI_STREAM=false
/opt/cai312/bin/cai --yolo --prompt "$(cat /workspace/experiments/techcorp_s3/defender_prompt.txt)"
```

### 🪟 PowerShell #2 → ATTACKER (đợi defender ~1–2 phút rồi chạy)
```
docker exec -it devcontainer-devenv-1 bash
```
🐉
```bash
cd /workspace
export CAI_LICENSE_OFF=1 CAI_AGENT_TYPE=apt_agent CAI_MAX_TURNS=40 CAI_STREAM=false
/opt/cai312/bin/cai --yolo --prompt "$(cat /workspace/state.txt)"
```
Cả hai xong → `/exit`.

### 🪟 Chấm điểm + so sánh (PowerShell ở d:\cai)
```
docker cp devcontainer-devenv-1:/root/.cai/logs ./logs_dynamic
python -I experiments/techcorp_s3/score.py --logs ./logs_dynamic --baseline N
```
(N = số flag ở lần STATIC) → ra **Def. success %**.

---

## Lưu ý
- **Tách log**: copy ra `logs_static` và `logs_dynamic` NGAY sau mỗi lần chạy, kẻo lẫn.
- Route chỉ cần thêm 1 lần/đời container (các shell cùng container dùng chung); thêm lại không hại.
- Defender (S3) dùng `docker exec techcorp-*` làm "tay chân" tới mọi host — đã ghi trong `defender_prompt.txt`.
- Model đang là NVIDIA NIM `nemotron` (không phải Opus như paper) → kết quả phản ánh *phương pháp*, không khớp số liệu paper.

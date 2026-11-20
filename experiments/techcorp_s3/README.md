# easy_techcorp2 + S3 (Hostmanager) — pipeline chạy & chấm

Tái hiện *phương pháp* của paper **Dynamic Cyber Ranges** (static vs dynamic) trên
range đi kèm `easy_techcorp2`, với defender chiến lược **S3 (Hostmanager)**:
1 defender agent có quyền root tới mọi host của range.

> ⚠️ Đây là tái hiện *phương pháp*, **không** ra đúng số liệu paper
> (range nhỏ 6 host, thiếu lớp giám sát Wazuh/Velociraptor, model khác Opus 4.6).

## File
| File | Vai trò |
|---|---|
| `verify.sh` | Preflight: kiểm tra đủ config/setup chưa (không đổi gì) |
| `run_s3.sh` | Dựng range + route, in sẵn lệnh chạy attacker/defender |
| `defender_prompt.txt` | Operator-message cho defender S3 |
| `score.py` | Đọc log `.jsonl` → flag captured / time-to-flag / Def. success % |

## Quy trình
```bash
# 0. Bật Docker Desktop trước
bash experiments/techcorp_s3/verify.sh      # phải hết FAIL

# 1. Dựng range + in lệnh
bash experiments/techcorp_s3/run_s3.sh

# 2. STATIC: trong devenv chạy apt_agent (xem output run_s3.sh), đợi xong
# 3. DYNAMIC: bật blueteam_agent (S3) TRƯỚC rồi chạy lại apt_agent

# 4. Chấm (copy log từ devenv ra trước)
docker cp <devenv>:/root/.cai/logs ./logs_static
docker cp <devenv>:/root/.cai/logs ./logs_dynamic
python -I experiments/techcorp_s3/score.py --logs ./logs_static              # -> N flag (baseline)
python -I experiments/techcorp_s3/score.py --logs ./logs_dynamic --baseline N
```

`score.py` tự lấy 6 flag ground-truth từ `docker-compose.yml` của range và in
bảng từng flag + thời điểm (phút) + % defender chặn được so với baseline.

## Chỉ số ↔ paper (Table 2)
| Paper | score.py |
|---|---|
| Flags obtained | `Captured N/6` |
| Time to 1st flag | `1st flag ... phút` |
| Def. success % | `--baseline` → `Def. success %` |
| Cost ($) | đọc `~/.cai/usage.json` của defender (chưa gộp vào script) |

## Hạn chế đã biết
- Defender **mù** (không SIEM) → phải tự đọc log từng host; S3 vẫn ổn vì có root khắp nơi.
- S3 dễ cho kết quả cực đoan ("chặn 100%") vì chặn thô, không nhờ phát hiện tinh vi.
- Đo flag dựa trên việc flag **xuất hiện trong log** của attacker — nếu agent lấy flag
  nhưng không in ra text, sẽ bị tính thiếu (giới hạn cố hữu khi không có checker).

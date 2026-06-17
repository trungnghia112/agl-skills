---
description: How to use agl-skills — commands, flow, and the brain model
---

Show the user (in their language) this overview, adapted to their question
if `$ARGUMENTS` asks something specific:

## Commands

| Memory | |
|---|---|
| `/agl-init` | Dựng brain `.agl/` cho project |
| `/agl-recap` | Nhớ lại trạng thái — luôn đối chiếu git, không tin note cũ |
| `/agl-save` | Lưu phiên: session log + memory (mỗi fact 1 file) + STATE |

| Lifecycle | |
|---|---|
| `/agl-spec <ý tưởng>` | Phỏng vấn từng câu → spec có acceptance criteria |
| `/agl-plan` | Bẻ spec thành task nhỏ kiểm chứng được, tag rủi ro |
| `/agl-build` | TDD từng task: test đỏ → code xanh → suite → commit → dừng |
| `/agl-build auto` | Duyệt 1 lần → chạy cả plan, tự dừng ở task rủi ro |
| `/agl-test` | Vá lỗ hổng test + chạy suite + UAT sống khi cần |
| `/agl-review` | Review 5 trục, mỗi finding bị phản biện trước khi báo |
| `/agl-audit` | Security/deps/perf — risk-accept bắt buộc có trigger hẹn lại |
| `/agl-debug` | Reproduce → khoanh vùng → fix → test chặn tái phát |
| `/agl-ship` | Gate đủ bằng chứng → changelog → push → tự save brain |
| `/agl-next` | Gợi ý việc tiếp theo từ backlog (kiểm git trước khi gợi ý) |

## Typical day

```
sáng:  /agl-recap            → nhớ lại, chọn việc từ menu
làm:   /agl-spec → /agl-plan → /agl-build auto → /agl-review
xong:  /agl-ship             → brain tự lưu trong lúc ship
(/agl-save chỉ cần gọi riêng khi dừng giữa chừng không ship)
```

## Nguyên tắc lõi (luôn áp dụng trong mọi lệnh)

- Nêu giả định trước khi làm; bí thì DỪNG và hỏi, không đoán
- Được phép phản biện owner khi approach có vấn đề cụ thể
- "Trông có vẻ đúng" không bao giờ đủ — phải có bằng chứng (số test, build,
  UAT sống); UI/IPC bắt buộc kiểm tra trên app thật
- Đụng tiền / auth / xóa data / không-revert-được → dừng xin sign-off
- Brain: mỗi fact 1 file, update chứ không nhân bản, sai thì xóa,
  nhớ lại thì phải verify với code hiện tại trước khi tin

Brain format chi tiết: `references/brain-format.md` trong plugin này.

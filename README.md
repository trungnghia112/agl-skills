# agl-skills

Bộ skill `/agl-*` cho Claude Code: **bộ nhớ dự án bền vững** (state +
memory + sessions) gắn với **kỷ luật kỹ thuật senior engineer** (TDD,
bằng chứng bắt buộc, kiểm soát scope). Chỉ kích hoạt bằng lệnh tường minh
`/agl-*` — không có gì tự chạy nền.

## Triết lý

| Bộ nhớ dự án | Kỷ luật kỹ thuật |
|---|---|
| Brain xuyên session (recap/save) | TDD: test đỏ trước, code xanh sau |
| Backlog có ID, watchlist hẹn ngày | Bằng chứng bắt buộc, không "trông có vẻ đúng" |
| Menu số + đúng 1 gợi ý | Nêu giả định, dừng khi bí, dám phản biện |
| Giọng product-owner, tiếng của user | Kỷ luật scope, commit phẫu thuật, clean revert |
| `/agl-next` gợi việc từ backlog | `auto` mode 1 lần duyệt + hard stop ở task rủi ro |

## Brain v2 — O(1) recap

Mô hình theo Claude Memory, không dồn tất cả vào một file monolith:

- **`.agl/STATE.md`** — nhỏ (≤150 dòng), luôn đọc: đang làm gì, backlog, watchlist.
  Frontmatter có `last_commit` → recap chạy `git log <anchor>..HEAD`,
  **phát hiện stale bằng máy** thay vì tin note cũ.
- **`.agl/memory/`** — mỗi fact một file (gotcha/decision/learning/runbook/
  preference), có description để recall đúng lúc; update chứ không nhân bản,
  sai thì xóa. Index một-dòng-một-file ở `BRAIN.md`.
- **`.agl/sessions/`** — nhật ký append-only theo ngày; lịch sử nằm đây,
  không bao giờ phải đọc cả cụm.

→ Chi phí recap là **O(1)** bất kể project bao nhiêu tuổi.

## Cài & dùng

Cài qua marketplace:

```
/plugin marketplace add trungnghia112/agl-skills
/plugin install agl-skills@agl-skills
```

Sau khi cài: `/agl-init` trong project → `/agl-help` xem hướng dẫn. Tất cả
lệnh đều tường minh `/agl-*`, không có gì tự kích hoạt.

```
sáng:  /agl-recap
làm:   /agl-spec → /agl-plan → /agl-build auto → /agl-review
xong:  /agl-ship   (brain tự lưu khi ship; /agl-save khi dừng giữa chừng)
```

## Cấu trúc

```
agl-skills/
├── .claude-plugin/plugin.json
├── commands/        # 13 lệnh /agl-*  (chỉ load khi gọi — gần 0 token nền)
└── references/
    ├── core-behaviors.md   # quy tắc lõi mọi lệnh phải theo
    └── brain-format.md     # spec .agl/ + quy tắc memory
```

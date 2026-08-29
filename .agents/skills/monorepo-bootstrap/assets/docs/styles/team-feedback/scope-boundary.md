# Issue scope を超える指摘は scope 内で対応しない

> この文書は team-shared rule の 1 つ。scope 判定の基準と切り出しの経路のみを定め、Issue 起票の具体手順は `docs/harness/skills/create-issue.md` に書く。

Issue / PR の scope を超えるレビューコメント・修正要望は、既存 Issue への追記または新規 Issue 起票で追跡する。

## Why

scope 拡大は PR レビューサイクルの長期化と回帰リスクを生む。骨格 PR への大量指摘を全て scope 内で吸収すると、本来分割すべき改善が単一 PR に集中し、レビュアと実装者双方の認知負荷が上がる。Issue として切り出すと、適切な背景情報とテストを揃えた上で別 PR で対応できる。

## How to apply

scope 外と判定したコメントについて、次の順で処理する:

1. 関連する既存 Issue があれば、当該 Issue の本文または「追加スコープ」コメントとして追記する
2. 関連 Issue がなければ `/create-issue` で新規 Issue を起票する
3. PR には「scope 外のため別 Issue で追跡: #NNN」と返信して当該レビュー comment を close する
4. 設計判断として記録すべき内容なら `/create-adr` で ADR を記録する

scope 内 / scope 外の判定は次の基準で行う:

- 当該 Issue の受入条件に含まれているか → 含まれていれば scope 内
- 当該 Issue のモチベーションに直接寄与するか → 寄与すれば scope 内
- それ以外で「ついでに直したい」型の指摘 → scope 外

## 関連

- [review-comments](./review-comments.md) — レビューコメントの批判的評価
- `docs/harness/skills/handle-review.md` — レビュー対応 skill の正本（scope 判定を組み込み）
- `docs/harness/skills/create-issue.md` — Issue 起票 skill の正本
- `docs/harness/skills/create-adr.md` — ADR 記録 skill の正本

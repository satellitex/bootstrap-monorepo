# 自律実行の既定

> この文書は team-shared rule の 1 つ。自律実行中の判断の進め方のみを定める。自律実行の既定と承認が必須な操作の定義は `docs/harness/OPERATING_MODEL.md`「承認モデル」が正本であり、個別フローの手順は各 skill 正本に書く（本書には書かない）。

自律実行中の判断は、人間へ問い合わせず、既存 docs と一次情報から 1 案に確定して進める。

## Why

ハーネスは one-shot 自律実行を前提に設計されている。途中で人間に問い合わせると pipeline が分断され、人間は結局、最終成果物をレビューするタイミングで全体を再評価する必要が生じる。途中質問は人間の作業時間も AI の context 効率も浪費する。承認ポイントを「課金」と「秘密値」の 2 つに限定することで、人間の判断を本当に不可逆・高リスクな操作に集中させる。

## How to apply

### 自律実行の範囲

- 変更の実装・テスト・検証ゲート通過・ブランチ作成・open PR の提出までを、人間の中断なく自律的に行う
- 不確定要素は次の優先順で自律判断する: 既存 docs → 技術調査（research 系ドキュメント）→ 業界ベストプラクティス → 保守的 default
- 判断は 1 案に確定して書く（→ [single-solution](./single-solution.md)）。「Open Questions」「Gate チェックポイント」のような人間入力で停止するセクションを、計画にも PR 本文にも作らない
- 採用した判断はすべて PR 本文の「方針と却下案」節（→ `docs/harness/skills/shared/pr-creation.md`）に記録し、人間が最終レビュー時に一覧で確認できるようにする。人間引き渡し境界（`docs/harness/OPERATING_MODEL.md`「承認モデル」の「人間引き渡し境界」。既定: なし）に当たる案は、案と根拠を「人間承認推奨」として記録する。記録して続行するか、人間へ引き渡して終了するかは実行モードによる（→ 次節「無人実行（routine）」）

### 無人実行（routine）

routine などの無人 run では、質問・認可更新・許可外 tool の承認待ちに当たると、run が再開されないまま止まる。確認ゲートの扱いは実行モードによって異なり、その契約は `docs/harness/skills/shared/unattended-contract.md` が定める。課金と秘密値は無人 run でも人間の承認が必須であり、契約はこれを変えない。

### 人間の明示承認が必須な操作

定義は `docs/harness/OPERATING_MODEL.md`「承認モデル」に従う。それ以外の操作は、「念のため」の承認待ちにせず自律で実行する。承認が必須な操作は、実行の直前で止めて人間の承認を得る（無人 run では、内容と根拠を成果物に残して人間へ渡す）。

ラベル付与・Issue アサイン等の着手指示は承認ゲートではなく通常の作業依頼であり、承認が必須な操作とは別物である（例: `refactor:approved` は実装フローの起動条件であって承認ではない）。

## 関連

- [single-solution](./single-solution.md) — 解決策は 1 案に確定して書く
- [scope-boundary](./scope-boundary.md) — スコープ判断の自律ガイド
- [long-term-automation](./long-term-automation.md) — 自動化最優先方針
- `docs/harness/skills/shared/unattended-contract.md` — 無人 run の契約（確認ゲート別の扱い）
- [../../harness/OPERATING_MODEL.md](../../harness/OPERATING_MODEL.md) — 承認モデルを含むハーネス運用の正本

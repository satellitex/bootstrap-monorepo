# AGENTS.md

この repository は Codex / Claude 両対応の `monorepo-bootstrap` skill template です。Codex で作業する場合は、このファイルをルート入口として扱ってください。

## 既定方針

- ユーザとの会話、Issue、PR、ADR、review コメント、sync レポート、運用 docs は日本語を既定とする。
- コード識別子、API 名、package 名、commit type、標準エラー、外部仕様名は原文または英語のまま保持する。
- 公式 docs の引用タイトルやリンクタイトルは原文を保持し、要約は日本語にする。
- 課金、本番 deploy、破壊的 migration、外部公開を伴う判断は、必ず人間の明確な承認を得る。
- secret、token、credential は commit しない。

## Bootstrap skill

- 正本: `.agents/skills/monorepo-bootstrap/SKILL.md`
- Claude 側入口: `.claude/skills/monorepo-bootstrap/SKILL.md`

Codex で bootstrap を実行するときは `.agents/skills/monorepo-bootstrap/SKILL.md` を読み、そこに定義された Intake、技術調査、承認ゲート、ハーネス整備、実装、検証、完了報告の順に進める。

## 両対応の保守ルール

- `AGENTS.md` と `CLAUDE.md` は薄い adapter とし、詳細手順を二重管理しない。
- skill 本文や `references/` を変更する場合は、`.agents/skills/monorepo-bootstrap/` 側を編集する。
- `.claude/skills/monorepo-bootstrap/` 配下の link を実体ファイルに置き換えない。
- bootstrap 先 repository では、共通正本を `docs/harness/OPERATING_MODEL.md` など neutral な場所へ置き、`AGENTS.md` と `CLAUDE.md` から参照する。

## Git / quality

- 既存変更を勝手に revert しない。
- 変更前に repository 状態を確認し、関連ファイルだけを編集する。
- 作業は常に `origin/main` を基点に branch を切り、`main` や detached HEAD で直接編集しない。
- 実装変更では、影響範囲に応じて lint、typecheck、test、build、smoke test を実行する。
- 最新仕様に依存する判断は一次情報を確認し、調査結果を成果物に残す。

# CLAUDE.md

この repository は Codex / Claude 両対応の `monorepo-bootstrap` skill template です。Claude で作業する場合は、このファイルをルート入口として扱ってください。

## 既定方針

- ユーザとの会話、Issue、PR、ADR、review コメント、sync レポート、運用 docs は日本語を既定とする。
- コード識別子、API 名、package 名、commit type、標準エラー、外部仕様名は原文または英語のまま保持する。
- 公式 docs の引用タイトルやリンクタイトルは原文を保持し、要約は日本語にする。
- bootstrap 先の tool/runtime version 管理と local dev コマンド整備は `mise` を既定にする。
- 既定は自律実行とし、明示的な指示がない限り、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。
- 人間の明示承認が必須なのは次の 2 つのみ: (1) 課金が発生する操作（有償リソースの作成・プラン変更・外部サービス契約）、(2) 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）。
- bootstrap 先のブランチモデルは main = dev 環境 / release = prod 環境を既定とし、prod リリースのみ手順（main の安全性確認 → release への反映手順の確認）を踏む。
- secret、token、credential は commit しない。

## Bootstrap skill

- Claude 側入口: `.claude/skills/monorepo-bootstrap/SKILL.md`
- 正本: `.agents/skills/monorepo-bootstrap/SKILL.md`
- テンプレート資産の実体: `.agents/skills/monorepo-bootstrap/assets/`（台帳は `assets/MANIFEST.md`）

Claude で bootstrap を実行するときは `.claude/skills/monorepo-bootstrap/SKILL.md` を読み、そこに定義された Intake、技術調査、技術選定の確定、ハーネス整備、実装、検証、完了報告の順に進める。

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

# CLAUDE.md

この repository は Codex / Claude 両対応の monorepo 運用テンプレート（skills: `monorepo-bootstrap` / `harness-adopt`）です。Claude で作業する場合は、このファイルをルート入口として扱ってください。

## 既定方針

- ユーザとの会話、Issue、PR、ADR、review コメント、sync レポート、運用 docs は日本語を既定とする。
- コード識別子、API 名、package 名、commit type、標準エラー、外部仕様名は原文または英語のまま保持する。
- 公式 docs の引用タイトルやリンクタイトルは原文を保持し、要約は日本語にする。
- bootstrap / adopt 先の tool/runtime version 管理と local dev コマンド整備は `mise` を既定にする（導入先に既存の標準がある場合は既存を優先する）。
- 既定は自律実行とし、明示的な指示がない限り、変更の実装から open PR の提出までを自律的に行う。PR のマージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。
- 人間の明示承認が必須なのは次の 2 つのみ: (1) 課金が発生する操作（有償リソースの作成・プラン変更・外部サービス契約）、(2) 秘密値の挿入・変更（credential / API key / token を設定へ投入する操作）。
- bootstrap / adopt 先のブランチモデルは main = dev 環境 / release = prod 環境を既定とし、prod リリースのみ手順（main の安全性確認 → release への反映手順の確認）を踏む。導入先に既存の release フローがある場合は既存を優先する。
- secret、token、credential は commit しない。

## Skills

| Skill | 用途 | Claude 側入口 | 正本 |
|-------|------|---------------|------|
| `monorepo-bootstrap` | 0 から repo を作る（技術選定〜deploy 検証まで） | `.claude/skills/monorepo-bootstrap/SKILL.md` | `.agents/skills/monorepo-bootstrap/SKILL.md` |
| `harness-adopt` | 既存 repo へ運用ハーネスのみ導入（既存優先・非破壊マージ） | `.claude/skills/harness-adopt/SKILL.md` | `.agents/skills/harness-adopt/SKILL.md` |

テンプレート資産の実体は `.agents/skills/monorepo-bootstrap/assets/`（台帳は `assets/MANIFEST.md`）で、両 skill が共用する。
Claude で実行するときは各 Claude 側入口の SKILL.md を読み、定義された手順どおり進める。

## 両対応の保守ルール

- `AGENTS.md` と `CLAUDE.md` は薄い adapter とし、詳細手順を二重管理しない。
- skill 本文、`references/`、`assets/` を変更する場合は、`.agents/skills/` 側を編集する。
- `.claude/skills/` 配下の link を実体ファイルに置き換えない。
- bootstrap 先 repository では、共通正本を `docs/harness/OPERATING_MODEL.md` など neutral な場所へ置き、`AGENTS.md` と `CLAUDE.md` から参照する。

## Git / quality

- 既存変更を勝手に revert しない。
- 変更前に repository 状態を確認し、関連ファイルだけを編集する。
- 作業は常に `origin/main` を基点に branch を切り、`main` や detached HEAD で直接編集しない。
- 実装変更では、影響範囲に応じて lint、typecheck、test、build、smoke test を実行する。
- 最新仕様に依存する判断は一次情報を確認し、調査結果を成果物に残す。

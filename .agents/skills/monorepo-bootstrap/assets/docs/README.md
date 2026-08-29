# docs ナレッジハブ

> この文書は `docs/` 全体のディレクトリマップと横断運用ルール（INDEX 同時更新・命名規約）の正本である。
> 各ディレクトリの詳細運用は配下の README / INDEX に委譲し、ここには書かない。

## 使い方（最短）

1. まず本ファイルで置き場所を判断する。
2. 詳細は各ディレクトリの `README.md` / `INDEX.md` を読む。

## ディレクトリマップ

| パス | 用途 | 置いてよいもの |
| --- | --- | --- |
| `docs/harness/` | エージェント運用ハーネスの正本 | `OPERATING_MODEL.md`, `harness_authoring_guide.md`, `scheduled-operations.md`, `skills/` |
| `docs/adr/` | ADR（設計判断記録。置き場はここ 1 箇所のみ） | `ADR-*.md`, `INDEX.md`, `template.md` |
| `docs/issues/` | Issue 単位の計画・記録成果物 | `<number>_<scope>/`, `templates/` |
| `docs/product/` | プロダクト定義 | `ARCHITECTURE.md`, `TECH_STACK.md`, `TERMS.md`, `TEST_STRATEGY.md` |
| `docs/requirements/` | 要件定義の正本（人間管理・AI 編集対象外） | 要件本文, `INDEX.md` |
| `docs/styles/` | コーディング・文書規約 | `coding_guide/`, `refactoring_guide.md`, `team-feedback/` |
| `docs/runbooks/` | セットアップ・運用手順書 | `<topic>.md`, `INDEX.md` |
| `docs/notes/` | 内部メモ・開発調査 | `mtgs/`, `research/` |
| `docs/audit/` | セキュリティ監査レポート | `YYYY-MM-DD_SECURITY_REPORT.md` |
| `docs/customer/` | 顧客・関係者資料（opt-in:public-site） | `originals/`, `summaries/`, `runbooks/` |
| `docs/CUSTOMER_PUBLISH_POLICY.md` | 対外公開の判定基準と機械検査の正本（opt-in:public-site） | — |

> 任意拡張: 特定クラウドのインフラ設計正本（SSOT）が必要になったら `docs/<cloud>/`（例: `docs/aws/`, `docs/gcp/`）を追加してよい。追加時は本マップへ 1 行追記する。

## 運用ルール

- ファイルの追加・改名・削除時は、対応する `INDEX.md`（および本マップの該当行）を必ず同一 PR で更新する。
- 確定仕様は `docs/requirements/`、設計判断は `docs/adr/` に置き、`docs/notes/` には残さない。
- 受領した原本ファイルは `docs/customer/originals/` にのみ置く（opt-in:public-site 採用時）。
- `docs/requirements/` と `docs/customer/originals/` は人間が管理し、AI エージェントは編集しない。

## 命名規約

- ADR: `ADR-{YYYYMMDD}_{branch-slug}_{topic-slug}.md`
- Issue 成果物ディレクトリ: `<number>_<scope>/`
- 調査ノート: `<topic>.md`
- 会議ディレクトリ: `YYYY_MM_DD_mtg/`
- 顧客原本要約: `<topic>_summary.md`
- 監査レポート: `YYYY-MM-DD_SECURITY_REPORT.md`

## 追加時チェック

- 相対リンクが実在ファイルを指すことを確認する（例: `rg -n '\]\((\./|\.\./)[^)]+\)' docs --glob '*.md'` で列挙して目視確認）。

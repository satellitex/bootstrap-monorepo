# docs ナレッジハブ

> この文書は `docs/` 全体のディレクトリマップと横断運用ルール（INDEX の更新主体・命名規約）の正本である。
> 各ディレクトリの詳細運用は配下の README / INDEX に委譲し、ここには書かない。

## 使い方（最短）

1. まず本ファイルで置き場所を判断する。
2. 詳細は各ディレクトリの `README.md` / `INDEX.md` を読む。

## ディレクトリマップ

<!-- bootstrap 時の処理: 「opt-in」と付記した行の所属グループは MANIFEST のグループ節で確認し、採用しないグループの行を削除する。処理後にこのコメントを削除する。 -->

| パス                              | 用途                                          | 置いてよいもの                                                                                                                        |
| --------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/harness/`                   | エージェント運用ハーネスの正本                | `OPERATING_MODEL.md`, `harness_authoring_guide.md`, `scheduled-operations.md`, `skills/`                                              |
| `docs/adr/`                       | ADR（設計判断記録。置き場はここ 1 箇所のみ）  | `ADR-*.md`, `INDEX.md`, `template.md`                                                                                                 |
| `docs/product/`                   | プロダクト定義                                | `ARCHITECTURE.md`, `TECH_STACK.md`, `TERMS.md`, `TEST_STRATEGY.md`, `API_VERSIONING.md`（opt-in）, `PUBLIC_ARCHITECTURE.md`（opt-in） |
| `docs/product/tests/`             | 要件の受入条件とテストの対応 matrix（opt-in） | `README.md`, `traceability-matrix.example.yaml`, `<issue番号>_<scope>.traceability-matrix.yaml`                                       |
| `docs/requirements/`              | 要件定義の正本（人間管理・AI 編集対象外）     | 要件本文, `INDEX.md`                                                                                                                  |
| `docs/styles/`                    | コーディング・文書規約                        | `coding_guide/`, `refactoring_guide.md`, `team-feedback/`                                                                             |
| `docs/runbooks/`                  | セットアップ・運用手順書                      | `<topic>.md`, `README.md`（手順書の必須要素）, `INDEX.md`                                                                             |
| `docs/postmortems/`               | インシデントの作業記録と振り返り（opt-in）    | `<YYYY-MM-DD>_<slug>/`, `README.md`                                                                                                   |
| `docs/templates/`                 | 記録様式（opt-in）                            | `incident-timeline.md`, `postmortem.md`                                                                                               |
| `docs/notes/`                     | 内部メモ・開発調査                            | `mtgs/`, `research/`                                                                                                                  |
| `docs/audit/`                     | 外部監査・診断のレポート                      | `YYYY-MM-DD_<topic-slug>`                                                                                                             |
| `docs/customer/`                  | 顧客・関係者資料（opt-in）                    | `originals/`, `summaries/`, `runbooks/`                                                                                               |
| `docs/CUSTOMER_PUBLISH_POLICY.md` | 対外公開の判定基準と機械検査の正本（opt-in）  | —                                                                                                                                     |

> 任意拡張: 特定インフラ・外部サービスの設計正本（SSOT）が必要になったら `docs/<provider>/` を追加してよい。追加時は本マップへ 1 行追記する。

## 運用ルール

- `INDEX.md` はすべて共有集約ファイルとして扱う。更新主体の割当・経過措置・leaf 文書の要件は `docs/harness/skills/shared/index-writer-policy.md`、並列 PR の衝突を避ける理由と実装 PR の作法は `docs/styles/team-feedback/shared-aggregate-single-writer.md` に従う。
- 本マップの行は、ディレクトリの追加・削除と同一 PR で更新する。
- 確定仕様は `docs/requirements/`、設計判断は `docs/adr/` に置き、`docs/notes/` には残さない。
- 受領した原本ファイルは `docs/customer/originals/` にのみ置く（採用している場合）。
- `docs/requirements/` と `docs/customer/originals/` は人間が管理し、AI エージェントは編集しない。

## 命名規約

- ADR: → `docs/adr/README.md`「書き方」
- 調査ノート: `<topic>.md`
- 会議ディレクトリ: `YYYY_MM_DD_mtg/`
- 顧客原本要約: `<topic>_summary.md`
- 外部監査レポート: `YYYY-MM-DD_<topic-slug>`
- インシデント記録: `<YYYY-MM-DD>_<slug>/`
- traceability matrix: `<issue番号>_<scope>.traceability-matrix.yaml`

## 追加時チェック

- 相対リンクが実在ファイルを指すことを確認する（例: `rg -n '\]\((\./|\.\./)[^)]+\)' docs --glob '*.md'` で列挙して目視確認）。

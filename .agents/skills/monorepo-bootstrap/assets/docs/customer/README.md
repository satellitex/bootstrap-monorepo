<!-- opt-in:public-site — 公開区画グループ採用時のみ収録する。 -->

# customer

> この文書は `docs/customer/`（顧客・関係者向け資料の保管場所）の運用規約である。公開可否の判定基準は `docs/CUSTOMER_PUBLISH_POLICY.md` に委譲し、ここには書かない。
> `originals/` 配下の受領原本は **AI エージェントの編集対象外**（人間が管理する）。

## ディレクトリ構成

| ディレクトリ | 内容 | INDEX |
| --- | --- | --- |
| `originals/` | 顧客・関係者から受領した原本ファイル（PDF/XLSX/PPTX 等） | — |
| `summaries/` | `originals/` の整形済みサマリ | [summaries/INDEX.md](./summaries/INDEX.md) |
| `runbooks/` | 顧客（アプリ開発者等）向けの運用 runbook | [runbooks/INDEX.md](./runbooks/INDEX.md) |

## 配置ルール

- `originals/` には原本のみ配置する（PDF/XLSX/PPTX 等）。受領名は原則変更しない。
- 整形済みサマリは `summaries/` に作成する。`originals/` には置かない。
- 顧客向け運用手順書（API key 管理 / 障害対応 / 移行手順など）は `runbooks/` に作成する。

## 作業フロー

### 原本 → サマリ

1. 原本を `originals/` に配置する。
2. `summaries/` に対応する要約を作成する（1 原本 = 1 サマリ）。
3. `summaries/INDEX.md` に 1 行追加する。

### runbook 新規作成

1. `runbooks/<theme>.md` を作成する（テーマ単位で 1 ファイル）。
2. `runbooks/INDEX.md` に 1 行追加する（対象読者・関連 Issue を明記）。

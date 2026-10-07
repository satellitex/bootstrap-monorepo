# notes

> この文書は `docs/notes/`（調査層）の運用規約である。確定した仕様・決定は本ディレクトリに残さず、要件・ADR へ昇格させる。
> notes は「調査した時点の記録」であり、現状仕様の正本として参照しない。

## ファイル役割

- `mtgs/`: 会議メモ（`YYYY_MM_DD_mtg/` ディレクトリ単位で議事録を置く）
- `research/`: 技術選定の調査・開発調査・比較検討・外部規格サマリ（一覧は [`research/INDEX.md`](./research/INDEX.md)）

## ルール

- 会議メモは `mtgs/YYYY_MM_DD_mtg/` 配下に置く。
- 開発調査は `research/<topic>.md` に 1 トピック 1 ファイルで置く。冒頭に `#` 見出しとリード文（調査の目的と範囲）を書く。`research/INDEX.md` の行は更新主体が起こす（割当表 → `docs/harness/skills/shared/index-writer-policy.md`）。
- 技術選定の調査は、候補の比較と一次情報の URL・確認日を `research/<topic>.md` に残す。採用した選定は `docs/adr/`（1 領域 1 ADR）と `docs/product/TECH_STACK.md` に反映し、調査ノートには採用の宣言を書かない。
- 顧客原本由来の要約は、顧客資料の区画を採用している場合は `docs/customer/summaries/` に置き、`notes/` に混在させない。
- **確定仕様は `docs/requirements/` へ昇格し、`notes/` には残さない**（設計判断として残すべきものは `docs/adr/` へ）。

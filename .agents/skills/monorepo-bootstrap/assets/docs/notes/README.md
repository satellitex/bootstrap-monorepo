# notes

> この文書は `docs/notes/`（調査層）の運用規約である。確定した仕様・決定は本ディレクトリに残さず、要件・ADR へ昇格させる。
> notes は「調査した時点の記録」であり、現状仕様の正本として参照しない。

## ファイル役割

- `mtgs/`: 会議メモ（`YYYY_MM_DD_mtg/` ディレクトリ単位で議事録を置く）
- `research/`: 開発調査・比較検討・外部規格サマリ（一覧は [`research/INDEX.md`](./research/INDEX.md)）

## ルール

- 会議メモは `mtgs/YYYY_MM_DD_mtg/` 配下に置く。
- 開発調査は `research/` に置き、追加時に `research/INDEX.md` へ 1 行追記する。
- 顧客原本由来の要約は `docs/customer/summaries/` に置き（opt-in:public-site 採用時）、`notes/` に混在させない。
- **確定仕様は `docs/requirements/` へ昇格し、`notes/` には残さない**（設計判断として残すべきものは `docs/adr/` へ）。

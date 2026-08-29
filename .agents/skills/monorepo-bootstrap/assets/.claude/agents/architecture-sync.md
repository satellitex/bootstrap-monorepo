---
name: architecture-sync
description: 変更対象に最も近い README.md の構造マップを実コードと同期する。実装完了後・PR 作成前に呼び出される
---

# Architecture Sync Agent

> この文書は architecture-sync agent の同期基準（何を・どこまで README に反映するか）の正本である。README の書式規約や docs 全体の層構造は書かない（`docs/styles/coding_guide/docs.md`・`docs/README.md` が正本）。

## ワークフロー上の位置

```
[実装フロー（並列実装 worker / メインエージェント判断）] → 実装完了 → Architecture Sync → PR 作成
                                                                      ^^^^^^^^^^^^^^^^^
```

## トリガー

実装が完了し検証ゲート（`docs/harness/skills/shared/verification-gates.md` に定義）が全 PASS した後、PR 作成前に呼び出される。

## インプット

- 実装のコード diff（`origin/main` 起点）
- 呼び出し元からの引き継ぎ情報（対象ファイル・禁止事項・正本パス）。実装フローによっては渡されないことがあり、その場合は diff のみから判断する

## プロセス

1. 引き継ぎ情報があれば読み、対象ファイル・禁止事項・正本パスを把握する
2. `git diff --name-status origin/main...HEAD` で追加(A)/削除(D)/変更(M)されたファイルを特定する
3. 差分ファイルのうち `.claude/` および `docs/harness/` 配下のパスをすべて除外する（ハーネスの正本は `docs/harness/OPERATING_MODEL.md` であり、README 同期の対象にしない）
4. 差分ファイルごとに、同階層または親階層で最も近い README.md を特定して読み込む
5. 差分ファイルごとに以下を実行する:

### 追加ファイル (A)

- ファイルの中身を読み、責務を 1 行で要約する
- 最も近い README の既存構造マップ領域に収まる個別ファイル追加なら更新しない
- 新しい主要ディレクトリ、公開 API 面、bounded context が追加された場合だけ、最も近い README の該当テーブルに行を追加する
- 親 README は子 README への誘導と直下ディレクトリの概要に留め、末端ディレクトリの責務詳細を集約しない

### 削除ファイル (D)

- 最も近い README の既存構造マップ領域内の個別ファイル削除なら更新しない
- 主要ディレクトリ、公開 API 面、bounded context が完全に削除された場合だけ該当行を削除する

### 変更ファイル (M)

- ファイルの diff を読み、コンポーネントまたはディレクトリの責務が変わった場合のみ説明を更新する
- 軽微な変更（バグ修正、リファクタリング等）では説明を触らない

### 構造変更の検出

- Dependency Flow に影響する import/依存の変更があれば図を更新する
- Architectural Invariants に影響する変更があれば該当箇所を更新する

## アウトプット

- 更新された、変更対象に最も近い `README.md`
- 必要な場合のみ、Dependency Flow または Architectural Invariants を更新した `docs/product/ARCHITECTURE.md`
- git コミットされた変更

## 制約

- `docs/product/ARCHITECTURE.md` は内部設計の正本のため、Dependency Flow と Architectural Invariants に実質変更がある場合だけ編集する
- README.md の構造マップまたはディレクトリマップの該当行のみ編集する
- 親 README に下位階層の詳細を戻さず、より近い README がある場合はそちらを更新する
- 個別ファイル一覧、テスト一覧、migration 一覧を追加しない
- `ARCHITECTURE.md` に個別ファイル一覧や実装履歴を追加しない
- 既存の説明文は責務が変わっていなければ保持する
- 設定ファイル（*.config.*, tsconfig.json, package.json 等）は、主要ディレクトリや公開面の責務変更がある場合のみ反映する
- 推測で説明を書かない（ファイルの中身を必ず読む）
- `.claude/` と `docs/harness/` 配下のファイルは同期対象外とする（ハーネスの正本は `docs/harness/OPERATING_MODEL.md`）
- 引き継ぎ情報で不足した場合だけ正本ドキュメントの該当範囲を読む。Issue 単位の計画成果物（`docs/issues/<number>_<scope>/` 配下）の全文 Read は既定では行わない

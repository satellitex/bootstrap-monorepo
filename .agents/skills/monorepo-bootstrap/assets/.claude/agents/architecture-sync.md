---
name: architecture-sync
description: /multi-issue の仕上げ（Step 4）から起動された場合に使う。実装差分に最も近い README.md の構造マップを実コードと同期する。README 全体の定期点検は /readme-sync の担当
---

# Architecture Sync Agent

> 役割: 実装差分に最も近い README.md の構造マップを実コードと同期し、内部設計の正本（`docs/product/ARCHITECTURE.md`）は構造に実質変更がある場合だけ更新する。

> この文書は architecture-sync agent の同期基準（何を・どこまで README に反映するか）の正本である。README の書式規約や docs 全体の層構造は書かない（`docs/styles/coding_guide/docs.md`・`docs/README.md` が正本）。

## ワークフロー上の位置

```
[/multi-issue Step 4（仕上げ）] → Architecture Sync → PR 作成
                                  ^^^^^^^^^^^^^^^^^
```

## トリガー

`/multi-issue` の Step 4 で、実装が完了し検証ゲート（`docs/harness/skills/shared/verification-gates.md` に定義）が全て PASS した後、PR 作成前に呼び出される。

## インプット

- 実装のコード diff（`origin/main` 起点）
- 呼び出し元からの引き継ぎ情報（対象ファイル・禁止事項・正本パス）。渡されない場合は diff だけから判断する

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

- ファイルの diff を読み、コンポーネントまたはディレクトリの責務が変わった場合だけ説明を更新する
- 軽微な変更（バグ修正、リファクタリング等）では説明を触らない

### 構造変更の検出

- コンポーネント間の依存に影響する import/依存の変更があれば、`docs/product/ARCHITECTURE.md` の構成図を更新する
- 設計上の分離原則に影響する変更があれば、`docs/product/ARCHITECTURE.md` の該当箇所を更新する

## アウトプット

- 更新された、変更対象に最も近い `README.md`
- 必要な場合だけ、構成図または分離原則を更新した `docs/product/ARCHITECTURE.md`
- git コミットされた変更

## 制約

- `docs/product/ARCHITECTURE.md` は内部設計の正本のため、構成図と分離原則に実質変更がある場合だけ編集する
- README.md の編集は構造マップまたはディレクトリマップの該当行に限る
- 下位階層の詳細は、より近い README がある場合はそちらに書く（親 README に戻すと責務が重複するため）
- 構造マップは主要ディレクトリ・公開 API 面・bounded context の単位で書く。個別ファイル、テスト、migration は更新のたびに陳腐化するため一覧に載せない
- `ARCHITECTURE.md` も同様に、個別ファイル一覧や実装履歴を載せない
- 責務が変わっていない既存の説明文は保持する
- 設定ファイル（`*.config.*`, tsconfig.json, package.json 等）は、主要ディレクトリや公開面の責務変更がある場合だけ反映する
- 説明はファイルの中身を読んで書く（推測で書いた説明は README の信頼性を下げるため）
- `.claude/` と `docs/harness/` 配下のファイルは同期対象外とする（ハーネスの正本は `docs/harness/OPERATING_MODEL.md`）
- 引き継ぎ情報で不足した場合だけ、正本ドキュメントの該当範囲を読む（全文を読むとコンテキストを圧迫するため）

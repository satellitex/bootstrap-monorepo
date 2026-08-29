---
paths:
  - "infra/**/*"
---

# インフラ開発 rule（skeleton）

この文書はインフラコード（`infra/`）の編集時のみロードされる rule の skeleton である。IaC ツール確定後に正本 pointer とコマンドを埋める。**IaC を採用しないプロジェクトでは本ファイルを削除する。**

## 原則（正本ドキュメントとの同期義務）

- インフラアーキテクチャの正本ドキュメントを 1 つ定め、そこから参照する
  <!-- TODO(bootstrap 時): docs/product/ 配下にインフラ正本ドキュメントを作成し、ここへ pointer を記入する -->
- 正本ドキュメントが正であり、IaC コードは正本に記述されたアーキテクチャに準拠する
- `infra/` のリソースを変更したら、正本ドキュメントを**同一 PR で**同期更新する
- 有償リソースの作成・プラン変更を伴う apply は承認モデル（課金操作は人間の明示承認必須 → `docs/harness/OPERATING_MODEL.md`）に従う

横断的な team rule は [team-policy.md](team-policy.md) を参照。

## コマンド

<!-- TODO(bootstrap 時): IaC ツール確定後に fmt / validate / plan / apply の実行コマンドを記入する。
静的チェック（fmt / validate 相当）と、状態を変更する操作（plan / apply 相当）を分けて書くこと -->

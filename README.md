# bootstrap-monorepo

Codex / Claude 両対応の monorepo bootstrap skill template repository。

## 構成

- `AGENTS.md`: Codex 用のルート入口
- `CLAUDE.md`: Claude 用のルート入口
- `.agents/skills/monorepo-bootstrap/`: skill の正本
- `.agents/skills/monorepo-bootstrap/SKILL.md`: bootstrap の手順本体
- `.agents/skills/monorepo-bootstrap/references/`: 設計根拠と縮約判断の参照
- `.agents/skills/monorepo-bootstrap/assets/`: bootstrap 先へ copy する実体テンプレート資産。台帳は `assets/MANIFEST.md`
- `.claude/skills/monorepo-bootstrap/`: Claude 向け入口。中身は `.agents` 側へ link

## 目的

任意のプロダクト概要から、技術調査、技術選定の確定、モノレポ基盤、ハーネス、CI/CD、初期実装、deploy 検証までを自律実行するための bootstrap template を管理する。
人間の明示承認が必須なのは、課金が発生する操作と秘密値の挿入・変更の 2 つのみとする。

ハーネス・docs・CI の実体はスクラッチ生成せず、`assets/MANIFEST.md` を台帳として copy と placeholder 置換で展開する。

詳細な進め方は `monorepo-bootstrap/SKILL.md` を参照する。重複管理を避けるため、skill 本文と references と assets は `.agents` 側を正本にする。

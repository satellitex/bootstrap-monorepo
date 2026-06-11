# bootstrap-monorepo

Codex / Claude 両対応の monorepo bootstrap skill template repository。

## 構成

- `AGENTS.md`: Codex 用のルート入口
- `CLAUDE.md`: Claude 用のルート入口
- `.agents/skills/monorepo-bootstrap/`: skill の正本
- `.claude/skills/monorepo-bootstrap/`: Claude 向け入口。中身は `.agents` 側へ link

## 目的

任意のプロダクト概要から、技術調査、承認ゲート、モノレポ基盤、ハーネス、CI/CD、初期実装、deploy 検証までを段階実行するための bootstrap template を管理する。

詳細な進め方は `monorepo-bootstrap/SKILL.md` を参照する。重複管理を避けるため、skill 本文と references は `.agents` 側を正本にする。

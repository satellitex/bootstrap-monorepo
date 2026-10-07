# bootstrap-monorepo

Codex / Claude 両対応の monorepo 運用テンプレート repository。
「0 から repo を作る」bootstrap と、「既にある repo へ運用ハーネスを導入する」adopt の 2 つの入口 skill と、そのコピー元となる実体テンプレート資産を管理する。

## 使い方

### 前提（共通）

- この repository をローカルに clone する（skill と資産のコピー元になる）。
- `gh` CLI が認証済みであること（Issue / PR / repo 操作に使う）。
- 人間の明示承認が必須なのは「課金が発生する操作」と「秘密値の挿入・変更」のみ。それ以外は open PR の提出まで自律実行される（明示的に指示すればマージまで行う）。

### A. 0 から新しい repo を作る — `/monorepo-bootstrap`

技術選定・モノレポ基盤・ハーネス・CI/CD・初期実装・deploy 検証までを一気通貫で行う。

1. この repository で Claude Code（または Codex）を起動する。
2. `/monorepo-bootstrap <product overview>` を実行し、作成先（ローカルパス or GitHub repo 名）、制約（provider / DB / 納期など）、project language、deploy 目標を伝える。
3. 以降は自律実行される: 技術調査 → Gate A（選定を領域ごとの ADR と TECH_STACK に確定）→ 実装計画 → 基盤 scaffold → `assets/` からの copy + placeholder 置換 → 環境 / CI → 初期実装 → deploy 検証 → open PR。
4. 人間がやること: 課金・秘密値の承認、PR レビューとマージ、routine 登録（生成された `docs/harness/scheduled-operations.md` のカタログ参照）。

### B. 既にある repo に導入する — `/harness-adopt`

既存のスタック・コード・CI を維持したまま、運用ハーネス（docs 規約 / skills / agents / rules / hooks / 基礎 CI）だけを導入する。

1. この repository で Claude Code（または Codex）を起動する。Claude Code の場合は対象 repo を追加作業ディレクトリにする（例: `claude --add-dir /path/to/target-repo`）。
2. `/harness-adopt <対象 repo の絶対パス>` を実行する。必要なら project language と opt-in 採否（opt-in グループの一覧は `assets/MANIFEST.md`）を添える。
3. 以降は自律実行される: 現状棚卸し（棚卸し表を PR 本文に作成）→ 導入計画 → `assets/` からの copy + 既存資産との非破壊マージ（既存優先。既存ファイルの削除・移動はしない）→ 検証 → open PR。
4. 人間がやること: A と同じ（承認・レビュー・routine 登録・TODO 値の充填）。

### 使い分け

| 状況 | 入口 |
|------|------|
| 新規 repo / 既存 repo でも技術選定・基盤構築からやり直す | `/monorepo-bootstrap` |
| 既存スタックを維持して運用ハーネスだけ入れる | `/harness-adopt` |

## 構成

- `AGENTS.md`: Codex 用のルート入口
- `CLAUDE.md`: Claude 用のルート入口
- `.agents/skills/monorepo-bootstrap/`: bootstrap skill の正本
  - `SKILL.md`: bootstrap の手順本体
  - `references/`: 設計根拠と縮約判断の参照
  - `assets/`: bootstrap / adopt 先へ copy する実体テンプレート資産。台帳は `assets/MANIFEST.md`
  - `scripts/check-assets.sh`: テンプレート専用の整合検査。bootstrap / adopt 先へは配布しない
- `.agents/skills/harness-adopt/`: 既存 repo 導入 skill の正本（資産は monorepo-bootstrap の `assets/` を共用）
- `.claude/skills/`: Claude 向け入口。中身は `.agents` 側へ link

### テンプレートの整合検査

`assets/` を変更したら、次を実行する（bash と node が必要。引数はない）。

```bash
bash .agents/skills/monorepo-bootstrap/scripts/check-assets.sh
```

検査する内容:

- `assets/MANIFEST.md` の資産一覧と `assets/` の実ファイルが 1:1 であること
- skill 正本（`docs/harness/skills/*.md`）と adapter（`.claude/skills/*/SKILL.md`）が同名で 1:1 であること
- 二重波括弧の token が明示 token 4 種だけで、MANIFEST が列挙していること
- 固有語の denylist に一致する箇所がないこと
- `HARNESS_ROOT` を `assets/` に向けて、配布版の機械検査（`assets/tests/harness/`）が通ること

固有語の denylist は、固有語そのものを repo へ混入させないため、repo の外に置く。環境変数 `TEMPLATE_DENYLIST_FILE` にファイルのパスを渡す（1 行 1 パターンの拡張正規表現、`#` で始まる行はコメント、大文字小文字は区別しない）。未設定の場合、この検査は skip と表示される。
終了コードは、すべて通過（skip を含む）なら 0、1 つ以上失敗なら 1。

## 目的

任意のプロダクト概要から、技術調査、技術選定の確定、モノレポ基盤、ハーネス、CI/CD、初期実装、deploy 検証までを自律実行するための template を管理する。
人間の明示承認が必須なのは、課金が発生する操作と秘密値の挿入・変更の 2 つのみとする。

ハーネス・docs・CI の実体はスクラッチ生成せず、`assets/MANIFEST.md` を台帳として copy と placeholder 置換で展開する。

詳細な進め方は各 SKILL.md を参照する。重複管理を避けるため、skill 本文と references と assets は `.agents` 側を正本にする。

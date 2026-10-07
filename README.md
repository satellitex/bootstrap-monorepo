# bootstrap-monorepo

Codex / Claude 両対応の monorepo 運用テンプレート repository。
「0 から repo を作る」bootstrap と、「既にある repo へ運用ハーネスを導入する」adopt の 2 つの入口 skill と、そのコピー元となる実体テンプレート資産を管理する。

## 使い方

### インストール

Codex 同梱の skill-installer（`$skill-installer`）で、2 つの skill を 1 回のコマンドでまとめて install する。Codex に「satellitex/bootstrap-monorepo の `.agents/skills/monorepo-bootstrap` と `.agents/skills/harness-adopt` を install して」と頼んでもよいし、次のスクリプトを直接実行してもよい。

```bash
INSTALLER=~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py

# Codex（既定の install 先は $CODEX_HOME/skills）
python3 "$INSTALLER" --repo satellitex/bootstrap-monorepo \
  --path .agents/skills/monorepo-bootstrap .agents/skills/harness-adopt

# Claude Code（personal skills へ install）
python3 "$INSTALLER" --repo satellitex/bootstrap-monorepo \
  --path .agents/skills/monorepo-bootstrap .agents/skills/harness-adopt \
  --dest ~/.claude/skills
```

- Codex を導入していない（installer のスクリプトが無い）場合は、この repository を clone し、`.agents/skills/monorepo-bootstrap` と `.agents/skills/harness-adopt` を実体のまま `~/.claude/skills/` へコピーする（例: `cp -R .agents/skills/monorepo-bootstrap .agents/skills/harness-adopt ~/.claude/skills/`）。`.claude/skills/` 側は link なのでコピー元にしない。
- `--path` には `.agents/skills/` 側の実体を指定する。`.claude/skills/` 側は link なので指定しない。既定の download 方式では、link が「link 先のパスだけを書いたテキストファイル」として install され、エラーにならないまま skill として動かない（git 方式では installer が拒否する）。
- 2 つは必ず同じ `--dest` に install し、`--name` で改名しない。harness-adopt は兄弟ディレクトリ `../monorepo-bootstrap/` の `assets/` をコピー元に使う。
- install 後、Codex は次のターンから認識する（出ない場合は再起動する）。Claude Code はセッション中でも認識する。ただし `~/.claude/skills` がセッション開始時に無かった場合は `/reload-skills` を実行する。
- 呼び出しは、Claude Code では `/monorepo-bootstrap` `/harness-adopt`、Codex では `$monorepo-bootstrap` `$harness-adopt`。
- 更新: installer は install 先が既にあると中断し、上書きしない。古い 2 つのディレクトリを削除してから、同じコマンドで install し直す（例: `rm -rf ~/.claude/skills/monorepo-bootstrap ~/.claude/skills/harness-adopt`）。版を固定するときは `--ref <tag または commit>` を付ける。
- テンプレートを保守するときの注意: この repository 内で起動すると、repo の `.claude/skills/`（Claude Code）と `.agents/skills/`（Codex）の skill も読み込まれる。Claude Code では personal（`~/.claude/skills`）が project より優先されるため、install 済みの古い版が編集中の版を隠す。Codex では同名の skill が 2 つ並ぶ。保守中は install 済みの版を外すか、どちらの版が動いているかに注意する。

### 前提（共通）

- 2 つの skill を同じ skills ディレクトリへ install する（手順は「インストール」）。片方だけの install では harness-adopt が動かない。この repository の clone は、テンプレートを保守する場合だけ必要。
- `gh` CLI が認証済みであること（Issue / PR / repo 操作に使う）。
- 承認モデル: 人間の明示承認が必須なのは課金と秘密値のみで、それ以外は open PR の提出まで自律実行される（定義 → `.agents/skills/monorepo-bootstrap/assets/docs/harness/OPERATING_MODEL.md`「承認モデル」）。

### A. 0 から新しい repo を作る — `/monorepo-bootstrap`

技術選定・モノレポ基盤・ハーネス・CI/CD・初期実装・deploy 検証までを一気通貫で行う。

1. 作成先のディレクトリ（新規の空ディレクトリ、または作成先 repo の checkout）で Claude Code（または Codex）を起動する。
2. `/monorepo-bootstrap <product overview>` を実行し、作成先（ローカルパス or GitHub repo 名）、制約（provider / DB / 納期など）、project language、deploy 目標を伝える。
3. 以降は自律実行される: 技術調査 → Gate A（選定を領域ごとの ADR と TECH_STACK に確定）→ 実装計画 → 基盤 scaffold → `assets/` からの copy + placeholder 置換 → 環境 / CI → 初期実装 → deploy 検証 → open PR。
4. 人間がやること: 課金・秘密値の承認、PR レビューとマージ、routine 登録（生成された `docs/harness/scheduled-operations.md` のカタログ参照）。

### B. 既にある repo に導入する — `/harness-adopt`

既存のスタック・コード・CI を維持したまま、運用ハーネス（docs 規約 / skills / agents / rules / hooks / 基礎 CI）だけを導入する。

1. 導入先 repo の checkout で Claude Code（または Codex）を起動する。別の場所から起動する場合だけ、Claude Code では対象 repo を追加作業ディレクトリにする（例: `claude --add-dir /path/to/target-repo`）。
2. `/harness-adopt` を実行する（cwd が導入先なら引数は不要。別の場所から起動した場合だけ、対象 repo の絶対パスを渡す）。必要なら project language と opt-in 採否（opt-in グループの一覧は monorepo-bootstrap skill の `assets/MANIFEST.md`）を添える。
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
- `.claude/skills/`: この repository 内で使う Claude 向け入口。中身は `.agents` 側へ link（skill installer の `--path` には指定しない）

### テンプレートの整合検査

`SKILL.md`、`references/`、`assets/`、入口文書（`AGENTS.md` / `CLAUDE.md` / `README.md`）を変更したら、次を実行する（bash と node が必要。引数はない）。

```bash
bash .agents/skills/monorepo-bootstrap/scripts/check-assets.sh
```

検査項目と、固有語 denylist の形式は、スクリプト冒頭のコメント（`.agents/skills/monorepo-bootstrap/scripts/check-assets.sh`）が正本である。denylist は固有語そのものを repo へ混入させないため repo の外に置き、環境変数 `TEMPLATE_DENYLIST_FILE` にファイルのパスを渡す（未設定の場合、この検査は skip と表示される）。
終了コードは、すべて通過（skip を含む）なら 0、1 つ以上失敗なら 1。

## 目的

任意のプロダクト概要から、技術調査、技術選定の確定、モノレポ基盤、ハーネス、CI/CD、初期実装、deploy 検証までを自律実行するための template を管理する。

ハーネス・docs・CI の実体はスクラッチ生成せず、`assets/MANIFEST.md` を台帳として copy と placeholder 置換で展開する。

詳細な進め方は各 SKILL.md を参照する。重複管理を避けるため、skill 本文と references と assets は `.agents` 側を正本にする。

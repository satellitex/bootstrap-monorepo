---
name: harness-adopt
description: 既存 repository に運用テンプレート（docs 規約 / skills / agents / rules / hooks / 基礎 CI）を導入する。既存スタック・既存規約を優先し、非破壊マージで assets を展開して open PR まで自律実行する。人間承認が必須なのは課金と秘密値のみ
user_invocable: true
---

# Harness Adopt Skill (Codex / Claude)

この文書は「既に動いている repository」へ運用テンプレート資産一式を導入する手順の正本である。
技術選定・モノレポ基盤の scaffold・初期実装は行わない（それらが必要な場合は `monorepo-bootstrap` Skill を使う）。

## monorepo-bootstrap との使い分け

| 状況 | 使う Skill |
|------|-----------|
| 新規 repo を 0 から作る / 既存 repo でも技術選定・基盤構築からやり直す | `monorepo-bootstrap` |
| 既存のスタック・コード・CI を維持したまま、運用ハーネスだけ導入する | `harness-adopt`（本 Skill） |

## 前提

- 本 Skill はテンプレート repo（この repository）の checkout から実行し、対象 repo への書き込みアクセスを持つこと（Claude Code では対象 repo を追加作業ディレクトリにする）。
- 資産のコピー元は `../monorepo-bootstrap/assets/`、台帳は `../monorepo-bootstrap/assets/MANIFEST.md`（以下 MANIFEST）。
- 対象 repo は git 管理下にあり、既定 branch へ PR を出せること。
- git / gh 操作はすべて対象 repo を作業ディレクトリとして実行する（`git -C <target>` / `gh -R <owner>/<repo>`）。テンプレート repo 側には commit / branch / PR を作らない。

## 入力

| 項目 | 必須 | 説明 | 例 |
|------|------|------|----|
| Target repo path | Yes | 導入先 repository の絶対パス | `/path/to/existing-repo` |
| Project language | No | Issue / PR / docs の既定言語。未指定なら既存 docs から推定 | `日本語` |
| Token 値 | No | `{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` の値。未指定なら repo から推定して確認提示 | — |
| Opt-in 採否 | No | `opt-in:renovate` / `opt-in:public-site` / `opt-in:submodule` / `opt-in:traceability` | `renovate のみ採用` |
| 導入範囲 | No | 全 core（既定）か、段階導入（Phase 指定）か | `Phase 1 のみ` |

入力が足りない場合は、作業を止めずに対象 repo の観察から推定し、仮定を明示して進める。

## 承認モデル（要旨）

既定は自律実行とし、導入の実装から open PR の提出までを自律的に行う。マージは人間の操作だが、明示的に指示された場合はマージまで行ってよい。
人間の明示承認が必須なのは次の 2 つのみ: (1) 課金が発生する操作、(2) 秘密値の挿入・変更。
本 Skill の通常フローにはどちらも含まれない（routine 登録・webhook 設定は完了報告の TODO として人間に引き継ぐ）。

## 成果物

| 成果物 | 配置 | 内容 |
|--------|------|------|
| `adoption-map.md` | 対象 repo の `docs/issues/000_harness_adopt/` | 既存資産の棚卸し、衝突一覧、マージ判断、opt-in 採否、token 値 |
| `adoption-report.md` | 同上 | 導入結果、検証結果、スキップした資産と理由、残 TODO（routine 登録・TODO 値の充填） |

配置は既定パスであり、導入先に既存の Issue 成果物置き場がある場合はそちらを優先し、配置理由を `adoption-map.md` に残す。

## フロー図

```text
harness-adopt <target repo path>
  +-- 1. Intake と現状棚卸し（adoption-map.md 作成）
  +-- 2. 導入計画（opt-in 採否・衝突ごとのマージ方針を確定）
  +-- 3. copy + 置換 + 非破壊マージ（MANIFEST 手順 + 本書のマージ規則）
  +-- 4. 検証（hooks テスト・検証ゲート・Self-check）
  +-- 5. 完了処理と open PR（routine 登録 TODO の引き継ぎ）
```

## Step 1: Intake と現状棚卸し

対象 repo で以下を観察し、`adoption-map.md` に「既存の状態」「導入資産との関係（衝突 / 併存 / 不在）」を表で記録する。

| 棚卸し対象 | 見るもの |
|-----------|---------|
| 入口 adapter | `AGENTS.md` / `CLAUDE.md` の有無と内容、既存の運用規約 |
| docs 構造 | `docs/` の層構造、ADR 置き場、Issue 成果物置き場、styles/規約文書の有無 |
| .claude ハーネス | `settings.json`（hook 配線・permissions）、既存 skills / agents / rules |
| hooks | 既存の pre-commit / pre-push 相当（husky、lefthook、git hooks 直置き等を含む） |
| CI | 既存 workflow の一覧、実行 check（format / lint / typecheck / test / build 相当の有無） |
| コマンド契約 | package manager、root scripts 名、task runner、tool version 管理（mise / 他） |
| ブランチモデル | 既定 branch、release フロー、branch protection、deploy トリガ |
| GitHub 運用 | ラベル体系、Project / Milestone の有無、Issue テンプレート |

secret・credential・個人情報は棚卸し結果に転記しない（存在の有無と置き場所のみ記録する）。

## Step 2: 導入計画

`adoption-map.md` に以下を確定して記録する。

1. **opt-in 採否**: 対象 repo の実態から判定する（公開 docs サイトなし → `opt-in:public-site` 不採用、renovate.json なし → `opt-in:renovate` 不採用、が既定）。
2. **core だが実態次第で不採用/要調整の資産**: `docs/harness/skills/deploy-verify.md`（対象 repo に確立した deploy 手順が既にあるなら、骨格のまま入れず既存手順を wrap する形で具体化するか不採用）と `.claude/rules/infra-development.md`（IaC が無ければ不採用）の採否を判断して記録する。
3. **衝突ごとのマージ方針**: Step 3 のマージ規則を既定とし、逸脱する場合は理由を記録する。
4. **導入範囲**: 既定は core 全部を 1 PR。対象 repo が大きく差分が読みにくい場合のみ Phase 分割する。

| Phase | 内容 |
|-------|------|
| 1 | 入口 adapter・`docs/harness/`（OPERATING_MODEL / authoring guide / scheduled-operations）・`.claude/rules/`・docs 規約層（`docs/README.md` / `docs/styles/` / `docs/adr/` / `docs/issues/`） |
| 2 | skill 正本（`docs/harness/skills/` + shared）・`.claude/skills/` adapter + profile・`.claude/agents/` |
| 3 | hooks + tests + `.claude/bin/`（hooks 共通ユーティリティ）+ `settings.json` 配線・コマンド契約（scripts / `.mise.toml`）・基礎 CI |

表に列挙していない MANIFEST core 資産（`DEVELOPMENT.md`、`.gitignore`、`docs/requirements/`、`docs/product/` 骨格、`docs/runbooks/`、`docs/notes/`、`docs/audit/` 等）は Phase 1 に含める。

導入原則（全 Phase 共通）:

- **既存優先**: 対象 repo の既存規約・既存ファイルとテンプレートが矛盾する場合、既存を書き換えず、テンプレート側の導入方法を調整する。置き換えた方がよいと判断した場合も、置き換えは提案（PR 内の別コミット + PR body で明示）に留める。
- **非破壊**: 既存ファイルの削除・移動・リネームをしない。既存文書の一括改稿をしない。
- **新規約は今後の文書へ**: 4 層モデル・3 原則・INDEX 規約は「導入後に作る文書」に適用する。既存文書の移行は別 Issue に切り出す（`create-issue` 導入後に起票してよい）。

## Step 3: copy + 置換 + 非破壊マージ

MANIFEST の「使い方」手順（copy → token 置換 → TODO 充填 → Self-check）を基本とし、既存資産と衝突する場合のみ以下のマージ規則を適用する。

| 衝突対象 | マージ規則 |
|----------|-----------|
| 既存 `AGENTS.md` / `CLAUDE.md` | 上書きしない。「運用正本」節（`docs/harness/OPERATING_MODEL.md` への pointer + 承認モデル 1 行 + secret 非 commit 1 行）を追記する。既存記述と矛盾する場合は既存優先とし、矛盾点を `adoption-map.md` と PR body に列挙する |
| 片方の adapter のみ存在 | 無い側を assets の雛形から新規作成し、両者の重要ルールを対称にする |
| 既存 `.claude/settings.json` | 既存の hook 配線・permissions を保持したまま、テンプレートの hook 配線を追記マージする。同一イベント・同一 matcher に既存 hook がある場合は既存を先に実行する順で併記する |
| 既存 `.claude/skills/` / `.claude/rules/` / `.claude/agents/` に同名あり | 導入をスキップし、`adoption-report.md` に「同名スキップ」と記録する（既存優先）。別名で内容が重複する場合は併存させ、統合提案のみ残す |
| 既存 `package.json` / `turbo.json` / `.gitignore` がある | 上書きしない。不足している script 名・pipeline 定義・ignore パターンのみを追記マージし、既存の dependencies / packageManager / 既存設定はすべて保持する |
| 既存の root scripts 名が 6 契約（build / test / lint / typecheck / format / format:check）と異なる | 既存 scripts を rename しない。`docs/harness/skills/shared/verification-gates.md` と hooks 冒頭のコマンド変数を既存名に合わせて書き換える。契約に無い check（例: typecheck が無い）は「未導入」と verification-gates に明記する |
| package manager が pnpm 以外 / task runner が turbo 以外 | MANIFEST「既定スタックと差し替え点」に従い、hooks / ci.yml / verification-gates のコマンドを既存スタックへ差し替える。`package.json` / `turbo.json` の雛形は copy しない |
| workspace レイアウトが `apps/*` / `packages/*` でない | `.claude/bin/hook-utils.sh` の 2 つのパス prefix と `.claude/rules/product-development.md` の `paths:` を既存レイアウトへ書き換える。単一 package repo なら package 解決を root 固定にする（放置すると post-edit-check の package 単位検査が黙って skip される） |
| 既存 CI がある | `ci.yml` を無条件に追加しない。(a) 既存 workflow に format / test / build 相当が揃っているなら、hooks テスト（`.claude/hooks/tests/run-all.sh`）の step 追加だけを既存 workflow に提案する。(b) 揃っていないなら不足 check を既存 workflow へ追加するか `ci.yml` を併設するかを `adoption-map.md` で判断する |
| 既存の git hooks 機構（husky 等）がある | 既存機構を残す。`.claude/hooks/` は Claude Code セッション用として併存導入し、同一検査の二重実行が問題になる場合のみ既存側との分担を `adoption-map.md` に記録する |
| 既存 ADR / Issue 成果物置き場がある | 既存置き場を正本として維持するか `docs/adr/` / `docs/issues/` へ切り替えるかを判断して記録する。切り替える場合も既存文書は移動せず、「この日以降の新規文書は新置き場」と README に注記する。既存文書の移行は別 Issue |
| tool version 管理（mise 不在・別ツールあり） | mise 不在なら `.mise.toml` を導入する。asdf 等の既存ツールがあるなら既存を優先し、`.mise.toml` は導入せず hooks の mise 依存区画を既存ツールに合わせて調整する |
| ブランチモデルが main=dev / release=prod と異なる | 既存フローを優先し、ブランチモデル記述を持つ全資産を導入先の実態で置換する: `.claude/rules/team-policy.md`（常時ロードのため最重要）、`docs/harness/OPERATING_MODEL.md`、`docs/styles/team-feedback/autonomous-flow.md` と同 `INDEX.md`、`DEVELOPMENT.md`、`docs/styles/coding_guide/docs.md`、`docs/harness/skills/deploy-verify.md`（テンプレート既定を押し付けない） |

置換 token（`{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}`）は対象 repo の実値で置換する。`TODO(取得方法: ...)` の magic value（Project ID・webhook 等）は実環境で検証できた値のみ埋め、残りは TODO のまま残して `adoption-report.md` に列挙する。

導入しなかった skill（同名スキップ・不採用 opt-in・不採用 core）の行は、`docs/harness/OPERATING_MODEL.md` の skill コマンド一覧から削除する（デッド参照を導入初日から作らない。`harness-development.md` rule の「skill 増減時は一覧を同一 PR で更新」と同じ扱い）。

## Step 4: 検証

1. `.claude/hooks/tests/run-all.sh` を対象 repo で実行し green を確認する（hooks を導入した場合）。
2. verification-gates に記載した check を実際に実行し、既存 scripts 名とのマッピングが正しいことを確認する（fail する check は「既存の失敗」か「導入起因」かを切り分け、導入起因のみ修正する）。
3. MANIFEST の Self-check を実施する（token 置換 / opt-in 採否 / skill 1:1 / hooks 外部契約 / hooks テスト / routine 登録 TODO）。
4. 導入固有の check: 既存ファイルを削除・移動していないこと（`git -C <対象 repo> status` で D / R が無い）、既存 adapter の既存記述が保持されていること、post-edit-check が対象 repo の実ファイルで package を解決できること。

## Step 5: 完了処理と open PR

1. `adoption-report.md` を確定する（導入資産一覧、スキップ一覧と理由、検証結果、残 TODO）。
2. 対象 repo の既定 branch を基点に導入 branch を切り、Conventional Commits で commit する（既存規約があればそれに従う）。
3. open PR を作成する（既定の完了形）。PR body に adoption-map の要約、マージ判断、検証結果、残 TODO を記載する。
4. 完了報告に人間への引き継ぎを明記する: routine 登録（対象 repo の `docs/harness/scheduled-operations.md` のカタログ参照）、TODO のままの magic value、秘密値が必要な設定（webhook 等）。

## 制約

- 既定は自律実行。導入から open PR までを自律的に行い、マージは明示指示があった場合のみ行う。
- 人間の明示承認が必須なのは、課金が発生する操作と秘密値の挿入・変更の 2 つのみ。
- 対象 repo の既存ファイルを削除・移動・一括改稿しない（置き換えは提案に留める）。
- 対象 repo の既存規約とテンプレートが矛盾する場合は既存規約を優先する。
- テンプレート資産をスクラッチで再作成しない。必ず `../monorepo-bootstrap/assets/` から copy する。
- secrets、tokens、個人情報を成果物・棚卸し結果に書かない。

## Self-check

- [ ] `adoption-map.md` に棚卸し、衝突一覧、マージ判断、opt-in 採否、token 値がある
- [ ] 既存ファイルの削除・移動・リネームが無い（`git -C <対象 repo> status` に D / R が無い）
- [ ] 既存 adapter の既存記述が保持され、pointer 節の追記のみである（新規作成の場合は両 adapter が対称）
- [ ] 既存の `package.json` / `turbo.json` / `.gitignore` を上書きしておらず、追記マージのみである
- [ ] `.claude/skills/*/SKILL.md` と `docs/harness/skills/*.md` の 1:1 対応が導入分について成立している
- [ ] `docs/harness/OPERATING_MODEL.md` の skill コマンド一覧が導入した skill と一致している（未導入 skill の行が残っていない）
- [ ] 導入資産に導入先と異なるブランチモデル記述が残っていない（team-policy / OPERATING_MODEL / autonomous-flow / DEVELOPMENT / docs.md / deploy-verify）
- [ ] verification-gates と hooks のコマンドが対象 repo の実 scripts 名と一致し、実行して確認済み
- [ ] hooks を導入した場合、`.claude/hooks/tests/run-all.sh` が green で、post-edit-check の package 解決が対象 repo のレイアウトで動作する
- [ ] 不採用 opt-in グループ・不採用 core 資産（deploy-verify / infra-development 等の判断分）が copy されていない
- [ ] `adoption-report.md` にスキップ資産と理由、残 TODO（routine 登録・TODO 値・秘密値が必要な設定）がある
- [ ] PR が対象 repo 側に作成されており、body に adoption-map 要約、マージ判断、検証結果、残 TODO がある

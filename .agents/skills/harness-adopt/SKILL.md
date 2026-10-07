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
| Project language | No | Issue / PR / docs の既定言語。未指定なら既存 docs から推定。assets の運用文書は日本語で収録されており、既存 docs が日本語以外でも収録言語のまま導入する。翻訳は明示された場合のみ行い、決定を PR 本文に記録する（`../monorepo-bootstrap/SKILL.md` の Language Policy） | `日本語` |
| Token 値 | No | `{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` の値。未指定なら repo から推定して確認提示 | — |
| Opt-in 採否 | No | opt-in グループ（一覧は MANIFEST）の採否 | `renovate のみ採用` |
| 導入範囲 | No | 全 core（既定）か、段階導入（Phase 指定）か | `Phase 1 のみ` |

入力が足りない場合は、作業を止めずに対象 repo の観察から推定し、仮定を明示して進める。

## 承認モデル（要旨）

既定は自律実行とし、人間の明示承認が必須なのは課金と秘密値のみ（→ `../monorepo-bootstrap/assets/docs/harness/OPERATING_MODEL.md`「承認モデル」）。
本 Skill の通常フローにはどちらも含まれない（routine 登録・webhook 設定は完了報告の TODO として人間に引き継ぐ）。

## 成果物

導入の成果物は、専用のディレクトリやファイルとして作らない。棚卸し、マージ判断、スキップ一覧、残 TODO は PR 本文の節に書く。
Step 1・2 の間は、PR 本文を commit しない作業用ファイルとして書き進め、Step 5 で `gh pr create --body-file` へ渡す。対象 repo に PR テンプレートがある場合は、その節に標準節を対応づける。
PR 本文の節構成は、標準節と、導入の PR に加える 2 節（承認ログ（課金・秘密値） / 移管先の文書）である。定義は `../monorepo-bootstrap/assets/docs/harness/skills/shared/pr-creation.md`「PR 本文の標準節」「bootstrap / adopt の PR に加える節」が正本、節ごとの書き方は `../monorepo-bootstrap/references/bootstrap-artifacts.md` にある。

| 成果物 | PR 本文の節 | 内容 |
|--------|-------------|------|
| 棚卸し表 | 背景 | 既存資産の状態と導入資産との関係（衝突 / 併存 / 不在）、token 値、opt-in 採否 |
| マージ判断 | 方針と却下案 | 衝突ごとのマージ方針と、既存優先にした判断の理由。既存規約とテンプレートが矛盾して既存優先にした判断は、ADR（`docs/adr/`）に 1 本記録して PR 本文から参照する |
| スキップ一覧 | スコープ外 | 同名スキップ、不採用の opt-in グループ、不採用の core 資産と理由。既存文書の移行は別 Issue として起票し、番号を書く |
| 検証結果 | 検証結果 | hooks テスト、検証ゲート、ハーネスの機械検査、既存の失敗と導入起因の切り分け、導入した検査が起動することの確認 |
| 残 TODO | リスク | routine 登録、TODO のままの値（`TODO(` の一覧）、秘密値が必要な設定、required check への登録 |
| 承認ログ | 承認ログ（課金・秘密値） | 承認必須 2 種に該当する操作があれば、その承認。通常フローには含まれないため「該当なし」と書く |
| 導入した文書 | 移管先の文書 | 追加・追記した文書のパスと、1 行要約。既存文書は追記のみ |

## フロー図

```text
harness-adopt <target repo path>
  +-- 1. Intake と現状棚卸し（棚卸し表を PR 本文の作業用ファイルに作成）
  +-- 2. 導入計画（opt-in 採否・衝突ごとのマージ方針を確定）
  +-- 3. copy + 置換 + 非破壊マージ（MANIFEST 手順 + 本書のマージ規則）
  +-- 4. 検証（hooks テスト・機械検査・検証ゲート・Self-check）
  +-- 5. 完了処理と open PR（routine 登録 TODO の引き継ぎ）
```

## Step 1: Intake と現状棚卸し

対象 repo で以下を観察し、PR 本文の「背景」に「既存の状態」「導入資産との関係（衝突 / 併存 / 不在）」を表で記録する。

| 棚卸し対象 | 見るもの |
|-----------|---------|
| 入口 adapter | `AGENTS.md` / `CLAUDE.md` の有無と内容、既存の運用規約 |
| Claude 入口の置き場 | ルートの `CLAUDE.md` と `.claude/CLAUDE.md` のどちらにあるか（両方にあるか）。Claude Code は project instructions を `./CLAUDE.md` または `./.claude/CLAUDE.md` から読む（公式 docs「How Claude remembers your project」、確認日 2026-10-07）。入口が 2 か所にあると、更新漏れで内容が食い違うため、追記先を 1 か所に決める材料にする |
| docs 構造 | `docs/` の層構造、ADR 置き場、Issue ごとの計画・成果物の置き場、調査ノートの置き場、styles/規約文書の有無 |
| .claude ハーネス | `settings.json`（hook 配線・permissions）、既存 skills / agents / rules |
| hooks | 既存の pre-commit / pre-push 相当（husky、lefthook、git hooks 直置き等を含む） |
| CI | 既存 workflow の一覧、実行 check（format / lint / typecheck / test / build 相当の有無） |
| 既存 CI の実行条件 | trigger filter（`on` の paths / paths-ignore / branches）と、job の `if`・変更検出 job への `needs`・matrix の skip・task runner の cache を別項目で記録する。workflow ごと止める filter は required check が報告されないまま待ち状態になり、job の `if` による skip は Skipped（成功扱い）になる。required check の設定も見る |
| 既存の検査の現状 | 各 check（format / lint / typecheck / test / build 相当）の pass / fail と違反件数。既存違反があると、pre-push hook は検査が 1 つでも失敗した時点で push を止める |
| コマンド契約 | package manager、root scripts 名、task runner、tool version 管理（mise / 他） |
| ブランチモデル | 既定 branch、release フロー、branch protection、deploy トリガ |
| GitHub 運用 | ラベル体系、Project / Milestone の有無、Issue テンプレート |

secret・credential・個人情報は棚卸し結果に転記しない（存在の有無と置き場所のみ記録する）。

## Step 2: 導入計画

PR 本文に以下を確定して記録する（棚卸し表は「背景」、判断は「方針と却下案」）。

1. **opt-in 採否**: 対象 repo の実態から判定する。各グループの採否基準は MANIFEST のグループ節にある。対応する surface が実在しないグループは不採用が既定である（例: 公開 docs サイトなし → 公開区画のグループは不採用、renovate.json なし → 依存自動化のグループは不採用）。
2. **core だが実態次第で不採用/要調整の資産**: `docs/harness/skills/deploy-verify.md`（対象 repo に確立した deploy 手順が既にあるなら、骨格のまま入れず既存手順を wrap する形で具体化するか不採用。release 反映の節は main = dev / release = prod を前提にしており、導入先のフローが異なる場合は既存フローに合わせて書き換えるか、節を除く。release 用の別 skill は無い）と `.claude/rules/infra-development.md`（IaC が無ければ不採用）の採否を判断して記録する。
3. **衝突ごとのマージ方針**: Step 3 のマージ規則を既定とし、逸脱する場合は理由を記録する。
4. **導入範囲**: 既定は core 全部を 1 PR。対象 repo が大きく差分が読みにくい場合のみ Phase 分割する。

| Phase | 内容 |
|-------|------|
| 1 | 入口 adapter・`docs/harness/`（OPERATING_MODEL / authoring guide / scheduled-operations）・`.claude/rules/`・docs 規約層（`docs/README.md` / `docs/styles/` / `docs/adr/`） |
| 2 | skill 正本（`docs/harness/skills/` + shared）・`.claude/skills/` adapter + profile・`.claude/agents/` |
| 3 | hooks + hooks のテスト + `tests/harness/`（ハーネスの機械検査）+ `.claude/bin/`（hooks 共通ユーティリティ）+ `settings.json` 配線・コマンド契約（scripts / `.mise.toml`）・基礎 CI |

表に列挙していない MANIFEST core 資産（`DEVELOPMENT.md`、`.gitignore`、`docs/requirements/`、`docs/product/` 骨格、`docs/runbooks/`、`docs/notes/`、`docs/audit/` 等）は Phase 1 に含める。

導入原則（全 Phase 共通）:

- **既存優先**: 対象 repo の既存規約・既存ファイルとテンプレートが矛盾する場合、既存を書き換えず、テンプレート側の導入方法を調整する。置き換えた方がよいと判断した場合も、置き換えは提案（PR 内の別コミット + PR 本文で明示）に留める。
- **非破壊**: 既存ファイルの削除・移動・リネームをしない。既存文書の一括改稿をしない。
- **新規約は今後の文書へ**: 4 層モデル・3 原則・INDEX 規約は「導入後に作る文書」に適用する。既存文書の移行は別 Issue に切り出す（`create-issue` 導入後に起票してよい）。

## Step 3: copy + 置換 + 非破壊マージ

MANIFEST の「使い方」手順（copy → token 置換 → TODO 充填 → Self-check）を基本とし、既存資産と衝突する場合のみ以下のマージ規則を適用する。
導入先の実態に依存する関心事の置換は、MANIFEST の「導入先依存の関心事の索引」（branch-model / default-branch / root-config / hook-wiring / entry-adapters）と、「既定スタックと差し替え点」の表（コマンド契約・workspace・tool version・`PROJ_` prefix など）に従い、載っている全資産を対象にする。資産のファイル名は本書に書かず、この 2 つを正本にする。

| 衝突対象 | マージ規則 |
|----------|-----------|
| 既存 `AGENTS.md` / `CLAUDE.md` | 上書きしない（索引の entry-adapters）。assets の `AGENTS.md` / `CLAUDE.md` の箇条書き（運用正本への pointer、作業ブランチ、承認モデルの要旨、言語ポリシー、secret 非 commit）を、既存の入口へ「運用正本」節として逐語で追記する。作業ブランチ行の既定ブランチ名は導入先に合わせる。既存記述と矛盾する場合は既存優先とし、矛盾点を PR 本文に列挙する。正本と矛盾した場合に正本を優先する旨の 1 文は、既存の adapter には足さない。ルートの `README.md` は、既存があれば「開発スタイル」の pointer だけを追記し、無い場合だけ骨格を新規作成する |
| Claude の入口が `.claude/CLAUDE.md` にある | pointer 節を `.claude/CLAUDE.md` へ追記し、ルートの `CLAUDE.md` を新規作成しない。ルートと `.claude/` の両方に `CLAUDE.md` がある場合は、どちらも改変せず、重複を PR 本文に記録する |
| 片方の adapter のみ存在 | 無い側を assets の雛形から新規作成し、両者の重要ルールを対称にする。既存の `AGENTS.md` があり `CLAUDE.md` を新規作成する場合は、`CLAUDE.md` が存在すると Claude Code は既定では `AGENTS.md` を読まないため、新規の `CLAUDE.md` に `@AGENTS.md` の import 行を含める（挙動は Claude Code の版により異なるため、導入時に公式 docs「How Claude remembers your project」の AGENTS.md の節で確認する） |
| 既存 `.claude/settings.json`（索引の hook-wiring） | 既存の hook 配線・permissions を保持したまま、テンプレートの hook 配線を追記マージする。同一イベント・同一 matcher に既存 hook がある場合は既存を先に実行する順で併記する。pre-push の `if` に既存の `Bash(git push *)` がある場合は、`Bash(git -C *)` の条件を追加する。commit 系の hook（pre-format-check と、採用していれば pre-commit-submodule-guard）も同じ理由で `Bash(git commit *)` に加えて `Bash(git -C *)` の条件を併記する（`if` は `git -C <dir> <subcommand>` の形を `git push *` や `git commit *` と照合しないため） |
| 既存 `.claude/skills/` / `.claude/rules/` / `.claude/agents/` に同名あり | 導入をスキップし、PR 本文の「スコープ外」に「同名スキップ」と記録する（既存優先）。別名で内容が重複する場合は併存させ、統合提案のみ残す |
| 既存のルート設定（索引の root-config に載るファイル） | 上書きしない。不足している script 名・pipeline 定義・ignore パターン・設定項目のみを追記マージし、既存の dependencies / packageManager / 既存設定はすべて保持する。`.gitleaks.toml` の雛形は `[allowlist]` をコメントアウトした形であり、空の `[allowlist]` を持つ設定は gitleaks が設定エラーにするため、コメントアウトのまま追記する |
| 既存の docs 規約文書（`docs/README.md` / `docs/runbooks/README.md` / `docs/audit/README.md` / `docs/adr/template.md`） | 上書きしない。assets の節を節単位で追記マージする。`docs/README.md` のマップへは、導入した資産のディレクトリ行を追記し、不採用グループの行は追記しない |
| 既存の root scripts 名が 6 契約（build / test / lint / typecheck / format / format:check）と異なる | 既存 scripts を rename しない。「既定スタックと差し替え点」の pnpm + turbo の行に従い、検証ゲートの定義と hooks を既存名に合わせて書き換える。契約に無い check（例: typecheck が無い）は「未導入」と `docs/harness/skills/shared/verification-gates.md` に明記する |
| package manager が pnpm 以外 / task runner が turbo 以外 | MANIFEST「既定スタックと差し替え点」に従い、hooks / ci.yml / verification-gates のコマンドを既存スタックへ差し替える。`package.json` / `turbo.json` / `pnpm-workspace.yaml` の雛形は copy しない |
| workspace レイアウトが `apps/*` / `packages/*` でない | 「既定スタックと差し替え点」の pnpm workspace の行に従い、hooks の package 解決と領域別 rule の `paths:` を既存レイアウトへ書き換える。単一 package repo なら package 解決を root 固定にする（放置すると post-edit-check の package 単位検査が黙って skip される） |
| 既存 CI がある | `ci.yml` を無条件に追加しない。test 相当の job が無条件に起動する場合は、hooks のテスト（`.claude/hooks/tests/run-all.sh`）とハーネスの機械検査（`pnpm harness:test`）の step をその workflow へ追加する提案にとどめる。format / test / build 相当が揃っていない場合は、不足 check を既存 workflow へ追加するか `ci.yml` を併設するかを判断して記録する。test 相当の job が条件付き（trigger filter、job の `if`、変更検出 job への `needs`、matrix の skip、cache）の場合は、step をその job に入れず、paths 条件を持たない単独 job・単独 check 名の専用 workflow を併設し、既存 workflow は変更しない（条件付きの job に足すと、検査入力だけを変えた PR で検査が無言で skip されるため）。専用 workflow の check 名は required check に登録されるまで強制にならない。登録は branch protection の設定変更なので PR に含めず、PR 本文の「リスク」に人間への引き継ぎとして書く |
| 導入先に既存違反がある（既存 check が fail する） | 検査を無効にして導入しない。次のどちらかを選び、判断を PR 本文の「方針と却下案」に記録する（承認は不要）。(a) 違反件数を機械的に数えられる検査（違反単位で列挙でき、安定して diff 比較できる出力）は、baseline ratchet で導入する（`../monorepo-bootstrap/references/ci-cd-runner-deploy.md` §2.4）。baseline と検査 script は導入先固有の実装で、assets からは copy できない。(b) 数えられない検査は「未導入」として `verification-gates.md` に記録し、pre-push の step から外す。外すときは、hook の `CI_CHECK_STEPS`、`verification-gates.md`、hook のテストを同時に更新する |
| 既存の git hooks 機構（husky 等）がある | 既存機構を残す。`.claude/hooks/` は Claude Code セッション用として併存導入し、同一検査の二重実行が問題になる場合のみ既存側との分担を PR 本文に記録する |
| ハーネスの機械検査（`tests/harness/`） | 導入先の `package.json` に `harness:test` が無ければ `"harness:test": "node tests/harness/run.mjs"` を追記する（Node 22 以上が前提）。pnpm 以外、または `package.json` が無い導入先は、既存 CI から `node tests/harness/run.mjs` を直接呼ぶ。導入先に既存違反がある検査は、`tests/harness/README.md` の除外定数表（`SIZE_ALLOWLIST` / `MISSING_PATH_EXCLUSIONS` / `DIRECT_COMMAND_ALLOWED`）へ理由付きで登録して green の状態で導入するか、不要な検査の `*.test.mjs` を削除する。導入先のルートに別用途の `MANIFEST.md` が既にある場合、検査はルートをテンプレート資産とみなして未置換 token の検査を緩めるため、置換漏れは `rg` で手動確認する |
| 既存 ADR の置き場、Issue ごとの計画・成果物の置き場がある | 既存の置き場を維持する。ADR は、既存置き場を正本として維持するか `docs/adr/` へ切り替えるかを判断して記録し、切り替える場合も既存文書は移動せず、「この日以降の新規文書は新置き場」と README に注記する。既存文書の移行は別 Issue。assets は Issue ごとの成果物ファイルを持たない（計画と検証結果は PR 本文に置く）旨を PR 本文に注記する |
| tool version 管理（mise 不在・別ツールあり） | mise 不在なら `.mise.toml` を導入する。asdf 等の既存ツールがあるなら既存を優先し、`.mise.toml` は導入せず、hooks の mise 依存区画を既存ツールに合わせて調整する（「既定スタックと差し替え点」の gitleaks + mise の行） |
| ブランチモデルが main=dev / release=prod と異なる | 既存フローを優先し、索引の branch-model に載る全資産（`deploy-verify` の release 反映の節を含む）を導入先の実態で置換する（テンプレート既定を押し付けない）。既定ブランチ名が `main` でない場合は、索引の default-branch に載る資産も置換する。置換後、索引の検索コマンドで取り残しが無いことを確認する |

置換 token（`{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}`）は対象 repo の実値で置換する。TODO は MANIFEST「TODO 記法」に従って充填し、埋められなかった TODO は残して、PR 本文の「リスク」に列挙する。

`docs/README.md` を新規に copy する場合は、「opt-in」と付記したマップ行のうち不採用グループの行を削除し、表の直前の HTML コメントも削除する（所属グループは MANIFEST のグループ節で確認する）。

不採用の opt-in グループと、不採用にした core 資産（`deploy-verify` / infra 向け rule など）は copy しない。core 側に残る参照は、MANIFEST の「グループ除去チェックリスト」で処理する（既存の文書は編集せず、導入した資産の側だけを直す）。

導入しなかった skill（同名スキップ・不採用 opt-in・不採用 core）の行は、`docs/harness/OPERATING_MODEL.md` の skill コマンド一覧から削除する（デッド参照を導入初日から作らない。`harness-development.md` rule の「skill 増減時は一覧を同一 PR で更新」と同じ扱い）。導入しなかった rule（IaC が無い場合の infra 向け rule など）の行も、`OPERATING_MODEL.md` の「領域別 rule の読み場面」表から削除する。

## Step 4: 検証

1. `.claude/hooks/tests/run-all.sh` を対象 repo で実行し green を確認する（hooks を導入した場合）。
2. `pnpm harness:test`（`pnpm` を使わない導入先は `node tests/harness/run.mjs`）を実行し green を確認する。失敗の読み方は `../monorepo-bootstrap/assets/tests/harness/README.md`「検査一覧」に従う。導入起因は直し、既存違反は Step 3 の規則で扱う。
3. `docs/harness/skills/shared/verification-gates.md` の `gate:commit` を実際に実行し、既存 scripts 名とのマッピングが正しいことを確認する（fail する check は「既存の失敗」か「導入起因」かを切り分け、導入起因のみ修正する）。
4. MANIFEST の Self-check を全項目実施する。
5. 導入固有の check: 既存ファイルを削除・移動していないこと（`git -C <対象 repo> status` で D / R が無い）、既存 adapter の既存記述が保持されていること、Claude の入口が 1 か所のみであること、post-edit-check が対象 repo の実ファイルで package を解決できること。
6. 導入した検査が実際の PR で起動すること: 対象 workflow の trigger と `if` 条件を読み、検査入力だけを変更した PR で起動するかを確認して PR 本文の「検証結果」に記録する。検査入力は、hooks のテストが読む `.claude/hooks/**`・`.claude/settings.json`・root scripts・`.mise.toml`、ハーネスの機械検査が読む `docs/**`・`.claude/**`・`.github/workflows/**`・ルート直下の `*.md`・`package.json`・`tests/harness/**` である。

## Step 5: 完了処理と open PR

1. PR 本文を確定する（標準 5 節、承認ログ、移管先の文書。導入資産一覧、スキップ一覧と理由、検証結果、残 TODO を含める。`../monorepo-bootstrap/references/bootstrap-artifacts.md`）。
2. 対象 repo の既定 branch を基点に導入 branch を切り、Conventional Commits で commit する（既存規約があればそれに従う）。
3. open PR を作成する（既定の完了形）。作成手順は `docs/harness/skills/shared/pr-creation.md` に従い、通常 PR（draft にしない）で作る。
4. 完了報告に人間への引き継ぎを明記する: routine 登録（対象 repo の `docs/harness/scheduled-operations.md` のカタログ参照）、TODO のままの magic value、秘密値が必要な設定（webhook 等）、専用 workflow を併設した場合の required check への登録。

## 制約

- 対象 repo の既存ファイルを削除・移動・一括改稿しない（置き換えは提案に留める）。
- 対象 repo の既存規約とテンプレートが矛盾する場合は既存規約を優先する。
- テンプレート資産をスクラッチで再作成しない。必ず `../monorepo-bootstrap/assets/` から copy する。
- secrets、tokens、個人情報を成果物・棚卸し結果に書かない。

## Self-check

- [ ] Step 4 の 1〜6 を実施し、結果を PR 本文の「検証結果」に記録した（既存ファイルの削除・移動・リネームが無いこと、既存 adapter の記述が保持され Claude の入口が 1 か所のみであること、導入した検査が起動することを含む）。専用 workflow を併設した場合、required check への登録が人間への引き継ぎに載っている
- [ ] PR 本文に棚卸し表、衝突一覧、マージ判断、opt-in 採否、token 値がある
- [ ] 既存のルート設定（`package.json` / `turbo.json` / `.gitignore` 等）を上書きしておらず、追記マージのみである。既存 adapter は pointer 節の追記のみである（新規作成の場合は両 adapter が対称）
- [ ] `docs/harness/OPERATING_MODEL.md` の skill コマンド一覧と「領域別 rule の読み場面」表が、導入した skill と rule に一致している（未導入の行が残っていない）。`.claude/skills/*/SKILL.md` と `docs/harness/skills/*.md` の 1:1 対応が導入分について成立している
- [ ] 導入資産に導入先と異なるブランチモデル・既定ブランチ名が残っていない（MANIFEST の索引の検索コマンドで確認）
- [ ] 不採用 opt-in グループ・不採用 core 資産（deploy-verify / infra-development 等の判断分）が copy されていない
- [ ] PR 本文にスキップ資産と理由、残 TODO（routine 登録・TODO 値・秘密値が必要な設定）がある
- [ ] PR が対象 repo 側に作成されており、本文に標準節、承認ログ、移管先の文書がある

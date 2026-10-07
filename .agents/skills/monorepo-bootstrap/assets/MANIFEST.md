# assets MANIFEST

この文書は `assets/` 配下のテンプレート資産の正本台帳である。bootstrap 実行時は本表に従って copy → placeholder 置換 → 不要資産の削除を行う。資産の追加・削除時は本表を同一 PR で更新する（1:1 整合が受入条件）。設計判断の根拠は `../references/` 側に置き、本書には書かない。本書自身と、assets の外にあるテンプレート専用の検査（`../scripts/`）は、bootstrap 先へ配布しない。

## 使い方（bootstrap での適用手順）

1. `core` 区分の資産を bootstrap 先へ同一相対パスでコピーする（本書はコピーしない）。
2. opt-in グループ（一覧・採否基準・除去時の残存参照は「opt-in グループ」節）は、Intake / 計画時の採否判断に従い、採用グループのみコピーする。採否とその理由の記録先は、bootstrap では ADR 1 本（→ `../references/bootstrap-artifacts.md` §2.3）、adopt では PR 本文（→ `../../harness-adopt/SKILL.md` の成果物表）とする。不採用グループの資産はコピーしない。`docs/README.md` のディレクトリマップは、「opt-in」と付記した行のうち不採用グループの行を削除し、表の直前の HTML コメントも削除する。
3. 明示 token を一括置換する: `{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}`。`{{PROJECT_LANGUAGE}}` は Intake で確認した project language（例: `日本語` / `English`）で、`docs/harness/OPERATING_MODEL.md` の言語ポリシー節が唯一の記入箇所である（他の資産は同節を参照するだけで言語名を持たない）。assets の運用文書は収録言語（日本語）のまま導入し、翻訳は Intake で明示された場合だけ行う。翻訳しても、識別子・パス・コマンド・TODO 記法・表構造・見出し・token は保持する。
4. `TODO(...)` は次節「TODO 記法」に従って埋める。
5. Self-check（下記）を実行する。

## TODO 記法

TODO は次の 2 種類だけを使う。他の文書は本節を参照し、記法を再定義しない。

| 記法                               | 対象                                                     | 埋め方                                                                       |
| ---------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `TODO(取得方法: <コマンドや手順>)` | 環境から取得する値（ID・URL・版数・実コマンドなど）      | 実環境で検証した値だけを埋める。推測値や他の repository からの転記を書かない |
| `TODO(記入方法: <判断基準>)`       | チームが決める内容（スタック・規約・運用の取り決めなど） | 決めた内容で置き換える。判断基準を満たす材料が無ければ TODO のまま残す       |

- 値を埋めた行は、`TODO(...)` ごと実値に置き換える。HTML コメントの中の TODO も同じ記法で書く。
- 裸の `TODO` や、時期を示す種別（bootstrap 時・bootstrap 後など）は使わない。上の 2 種類のどちらかに当てはめる。
- 完了前に `TODO(` を含む箇所を列挙し（`grep -rn 'TODO(' .`）、残したものを完了報告の残 TODO に転記する。`docs/harness/skills/deploy-verify.md` の TODO は、具体化するか、不採用として資産ごと除去する。

## 既定スタックと差し替え点

| 既定                                                | 収録箇所                                                                                                                                                                                         | 差し替え方                                                                                                                                                                                                                                                                                                                                                                               |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| pnpm + turbo                                        | package.json / turbo.json / hooks / ci.yml                                                                                                                                                       | scripts 6 本（build / test / lint / typecheck / format / format:check）の名前を保てば実装は自由。名前を変える場合は `docs/harness/skills/shared/verification-gates.md` と hooks を同時更新する。検証コマンド名（`pnpm run <name>`）を直接書いてよい箇所は、verification-gates.md・`.claude/hooks/`・`.github/workflows/ci.yml`・package.json に限り、他の文書は `gate:<name>` で参照する |
| pnpm workspace                                      | pnpm-workspace.yaml                                                                                                                                                                              | `apps/*` と `packages/*` を列挙する。hooks の package 解決（`.claude/hooks/README.md` の外部契約 3）が前提とする。レイアウトを変える場合は `.claude/bin/hook-utils.sh` の 2 つのパス prefix と `.claude/rules/product-development.md` の `paths:` を同時に変える                                                                                                                         |
| pnpm の版                                           | package.json の packageManager と .mise.toml                                                                                                                                                     | 2 か所に同じ版を pin する（dual-pin）。更新は同時に行う                                                                                                                                                                                                                                                                                                                                  |
| prettier                                            | pre-format-check hook / .prettierignore                                                                                                                                                          | md を含む手書き文書も整形対象で、収録 md は整形済みである。.prettierignore は生成物だけを除外する。除外を広げると、md だけの変更に使う `gate:docs`（format:check のみ）が検査対象を失うため、広げるときは `gate:docs` を再定義する。formatter の差し替えは hook 冒頭のコマンド変数で行う                                                                                                 |
| eslint + TypeScript                                 | post-edit-check hook の case 分岐                                                                                                                                                                | 既定で `.ts` / `.tsx` / `.js` / `.jsx` の編集後に eslint と `tsc --noEmit` を呼ぶ。両者は root の devDependencies に含めないため、導入先の既存設定を使う。採用しない場合は該当 case と `.claude/hooks/tests/test-post-edit-check.sh` のケースを同時に削除し、他言語は hook 内の「言語別チェックの追加例」に従って case を足す                                                            |
| gitleaks + mise + node 22 + jq                      | .mise.toml / .gitleaks.toml / pre-push hook                                                                                                                                                      | .mise.toml の pin を変更する。node は bootstrap 時点の最新 LTS を確認して pin する。gitleaks は pre-push hook でだけ使い、CI では実行しない。.gitleaks.toml は既定ルールを継承し、`[allowlist]` はコメントアウトした雛形である。gitleaks を外す場合は pre-push hook の秘密検知区画も外す                                                                                                 |
| hook 環境変数 prefix `PROJ_`                        | hooks / tests / .env.example / `docs/harness/skills/shared/notification-contract.md` / `.claude/skills/review-cycle/references/notification-mapping.md` / `docs/harness/skills/renovate-sync.md` | 全ファイル一括置換                                                                                                                                                                                                                                                                                                                                                                       |
| エージェント作業ブランチ `agent/<skill>-YYYY-MM-DD` | shared/sync-pr-flow.md                                                                                                                                                                           | 置換可。open PR ガードの prefix 判定と揃えること                                                                                                                                                                                                                                                                                                                                         |

## 資産一覧

この節の表は、第 1 列が資産のパスで、`../scripts/check-assets.sh` が実ファイルとの 1:1 を検査する（パスに `<name>` や `*` を含む行はパターン、末尾 `/` の行はディレクトリ配下全体として読む）。パスを第 1 列に持たない表は、この節の外に置く。

### ルート（core）

| パス                     | 用途                                                                                                                                                                                                                                      |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MANIFEST.md              | 本書（bootstrap 先へはコピーしない）                                                                                                                                                                                                      |
| README.md                | 人間向けの入口（紹介・構成表・セットアップ・開発スタイル pointer）。版数は `.mise.toml` を正本とし複製しない。他の入口（`AGENTS.md` / `CLAUDE.md` / `docs/harness/OPERATING_MODEL.md` / `docs/README.md`）の内容は複製せず pointer で示す |
| AGENTS.md                | Codex 入口の薄い adapter 雛形（最初に読む正本の pointer）                                                                                                                                                                                 |
| CLAUDE.md                | Claude 入口の薄い adapter 雛形                                                                                                                                                                                                            |
| DEVELOPMENT.md           | 人間向け開発スタイル（自律実行モデル・承認ポイント・実装フロー・ハーネス構成表）                                                                                                                                                          |
| .gitignore               | `.claude/settings.local.json` `.claude/state/` `.claude/worktrees/` `.claude/logs/` に加え、`.env.*.local` / 秘密鍵・証明書 / `coverage/` / `*.tsbuildinfo` / `.cache/` を含む                                                            |
| .mise.toml               | ツールバージョン正本（node / pnpm / jq / gitleaks の最小 pin。pnpm は package.json の packageManager と dual-pin。追加例は `<tool>` プレースホルダ）                                                                                      |
| .gitleaks.toml           | gitleaks 設定（既定ルールを継承。値ベースの allowlist はコメントアウトした雛形。pre-push hook が `--config` で読む）                                                                                                                      |
| .env.example             | 環境変数のキー名の雛形（値は書かない・読み手を明記・秘密値の投入は人間）                                                                                                                                                                  |
| .prettierignore          | prettier の除外（生成物・依存・キャッシュのみ。md は整形対象）                                                                                                                                                                            |
| pnpm-workspace.yaml      | workspace 定義（`apps/*` と `packages/*`。hooks の外部契約 3 の前提）                                                                                                                                                                     |
| package.json             | hooks / CI が依存する 6 script 名の契約。契約外の補助 script として `harness:test` を持つ                                                                                                                                                 |
| turbo.json               | build / test / lint / typecheck の最小 pipeline                                                                                                                                                                                           |
| .github/workflows/ci.yml | 基礎 CI（format:check / test / build。test job で hooks の bash テストとハーネス機械検査 `pnpm harness:test` も実行）                                                                                                                     |

### docs 正本（core）

| パス                                    | 用途                                                                                                                       |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| docs/README.md                          | docs 全体のディレクトリマップ + INDEX 更新主体の参照と経過措置。opt-in の行は使い方の手順 2 で処理する                     |
| docs/harness/OPERATING_MODEL.md         | ハーネス運用の neutral 正本（両 adapter が参照。領域別 rule の読み場面・ツール固有手段の読み替え・人間引き渡し境界を含む） |
| docs/harness/harness_authoring_guide.md | ハーネス文書の書き方規約（サイズ上限・分離原則・description の書式・プロンプト記述）                                       |
| docs/harness/scheduled-operations.md    | routine 登録カタログ + 起動プロンプトの正準形 + 登録チェックリスト + 定期 workflow を追加する際の設計ガイド                |
| docs/adr/README.md                      | ADR 運用（起票基準・命名・Status 遷移と追従・置換と廃止・INDEX 形式と更新主体・圧縮運用）                                  |
| docs/adr/INDEX.md                       | ADR 一覧（Status 別・空）                                                                                                  |
| docs/adr/template.md                    | ADR 本文テンプレート（暫定対策の撤去条件・再評価トリガの任意欄付き）                                                       |
| docs/requirements/README.md             | 要件正本の運用（ID 体系・定型構成・AI 編集対象外）                                                                         |
| docs/requirements/INDEX.md              | 要件一覧（空）                                                                                                             |
| docs/product/ARCHITECTURE.md            | 内部設計正本の骨格（役割宣言 + 抽象度規約 + 冒頭にプロダクト概要を書く構成）                                               |
| docs/product/TECH_STACK.md              | 技術スタック確定表の骨格（ADR 参照列付き。選定は 1 領域 1 ADR）                                                            |
| docs/product/TERMS.md                   | ドメイン用語集の骨格                                                                                                       |
| docs/product/TEST_STRATEGY.md           | テスト戦略の骨格（ユーザーストーリー起点のテスト規約を含む）                                                               |
| docs/runbooks/README.md                 | 手順書の必須要素・成功判定と結果不明・状態変更手順の確認観点・設定投入手順の値表の規約                                     |
| docs/runbooks/INDEX.md                  | runbook 一覧の骨格（参照再配線チェック付き）                                                                               |
| docs/notes/README.md                    | 調査層の運用（技術選定の調査ノートの置き方を含む。確定仕様は要件へ昇格）                                                   |
| docs/notes/research/INDEX.md            | 調査ノート一覧（空）                                                                                                       |
| docs/audit/README.md                    | 外部監査・診断レポートの置き場の命名規約                                                                                   |

### styles（core）

| パス                                                        | 用途                                                                                          |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| docs/styles/coding_guide/INDEX.md                           | コーディング規約の目次                                                                        |
| docs/styles/coding_guide/docs.md                            | docs 編集規約（4 層モデル + 「現状の事実のみ」3 原則 + 実装整合の原則と矛盾の 3 分類）        |
| docs/styles/coding_guide/code-comments.md                   | コードコメント規約（3 原則の適用 + 内部参照禁止）                                             |
| docs/styles/coding_guide/testing_principles.md              | テスト記述規約（ユーザーストーリー → 対応テストのみ。ストーリー軸の構成・変動値のロック禁止） |
| docs/styles/refactoring_guide.md                            | リファクタ運用モデル + 検出観点（コード量削減の 3 分類・検出方法の実効性）                    |
| docs/styles/team-feedback/INDEX.md                          | team 共有 rule の一覧 + memory 昇格運用                                                       |
| docs/styles/team-feedback/long-term-automation.md           | 長期自動化を優先する判断 rule                                                                 |
| docs/styles/team-feedback/autonomous-flow.md                | 自律実行の既定（open PR まで / 承認必須は課金・秘密値のみ / 1 案確定と無人 run 契約への参照） |
| docs/styles/team-feedback/single-solution.md                | 解決策を 1 案に確定して書く rule（3 条件。人間引き渡し境界は OPERATING_MODEL を参照）         |
| docs/styles/team-feedback/implementation-flow-switch.md     | 実装フロー切替 rule（判定は Issue 全体の性質 + メインエージェント判断の標準手順）             |
| docs/styles/team-feedback/shared-aggregate-single-writer.md | INDEX を実装 PR で編集しない rule（更新主体は割当表、routine 登録前の経過措置）               |
| docs/styles/team-feedback/format-check.md                   | commit 前 format rule（hook は Claude Code 経由、CI は全経路の 2 段書き）                     |
| docs/styles/team-feedback/review-comments.md                | レビューコメントの批判的評価 rule                                                             |
| docs/styles/team-feedback/scope-boundary.md                 | スコープ外は Issue 化する rule                                                                |
| docs/styles/team-feedback/pr-closing-keyword.md             | PR に closing keyword を必須とする rule                                                       |
| docs/styles/team-feedback/refactor-before-pr.md             | PR 前の簡素化パス rule                                                                        |

### skill 手順の正本（docs/harness/skills/）

| パス                                                     | 用途                                                                                                                                  | 区分               |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| docs/harness/skills/shared/sync-prelude.md               | sync 系共通の前段（origin/main 基準・0 件終了・編集を伴わない所見だけの run）                                                         | core               |
| docs/harness/skills/shared/sync-pr-flow.md               | sync 系共通の後段（ブランチ・open PR ガード・1 スキャン 1 PR・識別ラベル付与）                                                        | core               |
| docs/harness/skills/shared/sync-noise-filter.md          | CI ノイズ除外と違反の退避先の既存性確認の共通手順                                                                                     | core               |
| docs/harness/skills/shared/gh-query-fail-closed.md       | GitHub CLI 照会の fail-closed 規約（search 経路の排除・canary・GraphQL 不可 / gh 不在時の経路切替）                                   | core               |
| docs/harness/skills/shared/pr-creation.md                | PR 作成共通手順（base 判定・open 前の衝突検査・draft にしない・closing keyword・本文の標準節）                                        | core               |
| docs/harness/skills/shared/verification-gates.md         | 検証ゲートコマンド定義と名前付き組合せ（gate:commit / gate:push / gate:ci / gate:docs）                                               | core               |
| docs/harness/skills/shared/unattended-contract.md        | 無人 run の共通契約（対話待ち・確認ゲート別の扱い・変えないもの）                                                                     | core               |
| docs/harness/skills/shared/index-writer-policy.md        | INDEX ごとの更新主体の割当表・leaf 文書の要件・routine 登録前の経過措置                                                               | core               |
| docs/harness/skills/shared/implementation-consistency.md | 記述と実装の矛盾を 3 分類で扱う共通手順と PR 本文の記録形式                                                                           | core               |
| docs/harness/skills/shared/notification-contract.md      | チャット webhook 通知の共通契約（解決順・未設定時の 2 区分・資格情報の扱い）                                                          | core               |
| docs/harness/skills/readme-sync.md                       | README ↔ 実コードの定期突合（README を直すのは記述修正のみ）                                                                          | core               |
| docs/harness/skills/docs-sync.md                         | docs 現状層の鮮度・3 原則・実装整合・INDEX 行の定期検査                                                                               | core               |
| docs/harness/skills/code-sync.md                         | ソースコメントの 3 原則・内部参照・実装整合検査（コメントのみの編集を検証）                                                           | core               |
| docs/harness/skills/refactor-guide-sync.md               | 規約正本 ↔ リファクタガイドの整合                                                                                                     | core               |
| docs/harness/skills/refactor-sync.md                     | リファクタ観点の検出と Issue 提案（refactorer agent を起動する入口）                                                                  | core               |
| docs/harness/skills/gc-scan.md                           | ハーネス GC（重複・孤児。すべて PR で提案。サイズ・1:1・パス実在は CI の機械検査）                                                    | core               |
| docs/harness/skills/adr-compress.md                      | ADR の Status 追従・INDEX 再構築・stub 化・要約の定期実行（INDEX の単一 writer）                                                      | core               |
| docs/harness/skills/adr-compress/compression-rules.md    | adr-compress の圧縮規則（カテゴリ 0 / I / II / III / IV の検出・手順、stub 形式、INDEX の canonical 構造、Status 読み取り、抑制条件） | core               |
| docs/harness/skills/adr-compress/pr-output-format.md     | adr-compress の PR 本文構成と受入条件                                                                                                 | core               |
| docs/harness/skills/create-adr.md                        | ADR の構造的記録（起票基準・既存 ADR の置換と廃止）                                                                                   | core               |
| docs/harness/skills/create-issue.md                      | Issue 作成（依存と親子の分離・item ID 経由の読み戻し検証）                                                                            | core               |
| docs/harness/skills/handle-review.md                     | レビューコメントの批判的評価（first-match 判定表）と自律対応（スレッド返信 + resolve）                                                | core               |
| docs/harness/skills/review-cycle.md                      | LGTM までの自律対応（優先順位付き判定表・conflict 解消・CI 失敗の修正・終了通知）                                                     | core               |
| docs/harness/skills/multi-issue.md                       | Planner–Worker 並列実装（PR base は常に既定ブランチ・独立 review pass・worker 骨格）                                                  | core               |
| docs/harness/skills/promote-memory.md                    | 個人 memory → team rule 昇格                                                                                                          | core               |
| docs/harness/skills/runbook-alignment.md                 | 運用手順書の未確定事項と実装の照合（質問せず確定、差異評価表を PR 本文へ）                                                            | core               |
| docs/harness/skills/deploy-verify.md                     | デプロイ一気通貫と release 反映（merge commit 限定・同期点・前提ゲート・マージ後の step 単位確認）の骨格。手順は bootstrap 時に具体化 | core               |
| docs/harness/skills/renovate-sync.md                     | 依存 pin ↔ Renovate 設定の突合                                                                                                        | opt-in:renovate    |
| docs/harness/skills/public-arch-sync.md                  | 内部正本 → 公開射影の追従                                                                                                             | opt-in:public-site |
| docs/harness/skills/customer-doc-review.md               | 対外ドキュメントの多視点レビュー                                                                                                      | opt-in:public-site |

### .claude（adapter・rules・hooks・agents）

| パス                                                              | 用途                                                                                                         | 区分               |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------ |
| .claude/skills/&lt;name&gt;/SKILL.md                              | 上記各 skill の薄い adapter（同名で 1:1）                                                                    | 正本と同区分       |
| .claude/skills/create-issue/references/project-fields.md          | Project ID / ラベル / マイルストーンの profile（読み戻し経路表・routine ラベル一覧を含む。TODO 形式）        | core               |
| .claude/skills/docs-sync/references/freshness-policy.md           | per-file 鮮度検証対象の profile                                                                              | core               |
| .claude/skills/review-cycle/references/notification-mapping.md    | レビュー終了通知の通知手段・宛先マッピング（空テンプレ）                                                     | core               |
| .claude/skills/review-cycle/references/ci-and-conflict-profile.md | conflict 解消・CI 修正の PJ 固有値（再生成が必要な生成物・連番生成物・CI レビュー bot・回数上限。TODO 形式） | core               |
| .claude/skills/public-arch-sync/references/projection-rules.md    | 射影ルールの profile（章構成のみ）                                                                           | opt-in:public-site |
| .claude/skills/customer-doc-review/references/target-prep.md      | 対象準備の profile（区画ごとの生成手段・形式別抽出・サニタイズ文脈の採取元。記入用テンプレート）             | opt-in:public-site |
| .claude/rules/team-policy.md                                      | 常時ロード rule（pointer 層）                                                                                | core               |
| .claude/rules/harness-development.md                              | paths: .claude/**・docs/harness/** スコープ rule                                                             | core               |
| .claude/rules/product-development.md                              | paths: apps/**・packages/** スコープ rule（skeleton。コマンド表の型を含む）                                  | core               |
| .claude/rules/infra-development.md                                | paths: infra/** スコープ rule（skeleton、IaC 不採用なら削除）                                                | core               |
| .claude/settings.json                                             | hook 配線の正本（pre-push は `git push` と `git -C` の 2 つの if で起動）                                    | core               |
| .claude/hooks/README.md                                           | hook の外部契約 4 点・hook と CI の分担・検査対象の作業ツリー・opt-in 配線手順・増減規約                     | core               |
| .claude/hooks/session-start.sh                                    | セッション開始時の環境 bootstrap                                                                             | core               |
| .claude/hooks/pre-format-check.sh                                 | commit 前の staged 限定フォーマット                                                                          | core               |
| .claude/hooks/pre-push-ci-check.sh                                | push 前の秘密検知 + CI 同等検査（push 先の作業ツリーを cd / git -C から特定し、解決不能は deny）             | core               |
| .claude/hooks/post-edit-check.sh                                  | 編集ファイルの拡張子別検査（絶対・相対パスを受け、ファイルが属する作業ツリーで実行）                         | core               |
| .claude/hooks/pre-commit-submodule-guard.sh                       | submodule pointer 混入の防止                                                                                 | opt-in:submodule   |
| .claude/hooks/post-edit-projection-reminder.sh                    | 内部正本編集時の公開射影リマインド                                                                           | opt-in:public-site |
| .claude/bin/hook-utils.sh                                         | hooks 共通ユーティリティ（パス正規化を含む）                                                                 | core               |
| .claude/bin/submodule-guard.sh                                    | submodule 初期化ユーティリティ                                                                               | opt-in:submodule   |
| .claude/hooks/tests/run-all.sh                                    | hooks テストの一括実行（CI の test job から呼ぶ。hook ごとのテスト存在も検査）                               | core               |
| .claude/hooks/tests/test-pre-format-check.sh                      | 同 hook の hermetic テスト                                                                                   | core               |
| .claude/hooks/tests/test-pre-push-ci-check.sh                     | 同 hook の hermetic テスト                                                                                   | core               |
| .claude/hooks/tests/test-post-edit-check.sh                       | 同 hook の hermetic テスト                                                                                   | core               |
| .claude/hooks/tests/test-hook-utils.sh                            | ユーティリティのテスト（パス正規化・symlink を含む）                                                         | core               |
| .claude/hooks/tests/test-submodule-guard.sh                       | bin/submodule-guard.sh（初期化ユーティリティ）の hermetic テスト                                             | opt-in:submodule   |
| .claude/hooks/tests/test-pre-commit-submodule-guard.sh            | pre-commit-submodule-guard.sh の hermetic テスト                                                             | opt-in:submodule   |
| .claude/hooks/tests/test-post-edit-projection-reminder.sh         | post-edit-projection-reminder.sh の hermetic テスト                                                          | opt-in:public-site |
| .claude/agents/gc-agent.md                                        | ハーネス文書の重複・孤児の意味判定と PR 提案（サイズ等の機械判定項目は CI が担当）                           | core               |
| .claude/agents/adr-compactor.md                                   | ADR 圧縮の検出・安全ゲート・PR 化（圧縮規則は `docs/harness/skills/adr-compress/compression-rules.md`）      | core               |
| .claude/agents/architecture-sync.md                               | 変更近傍 README の構造同期                                                                                   | core               |
| .claude/agents/refactorer.md                                      | リファクタ観点検出（Issue 提案のみ。入口は `/refactor-sync`）                                                | core               |
| .claude/agents/refactor-guide-sync.md                             | 規約正本 ↔ ガイド突合                                                                                        | core               |
| .claude/agents/references/gc-agent-detection.md                   | gc-agent の検出条件・除外規定・同一性判定・証拠の記録                                                        | core               |
| .claude/agents/references/refactorer-profile.md                   | 検出コマンド・必読ガイド・対象範囲と除外・削減候補の反証と公開面の profile                                   | core               |
| .claude/agents/references/refactorer-issue-template.md            | 提案 Issue のテンプレート                                                                                    | core               |
| .claude/agents/references/refactor-guide-sync-detection.md        | 突合アルゴリズム詳細                                                                                         | core               |
| .claude/agents/references/refactor-guide-sync-output.md           | 出力先判定・open PR ガードの固有パラメータ・PR body テンプレート                                             | core               |

### tests（core）

| パス                                                  | 用途                                                                                      |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| tests/harness/README.md                               | ハーネス機械検査の一覧・実行方法・除外定数・検査の追加手順                                |
| tests/harness/run.mjs                                 | 検査ランナー（`pnpm harness:test` の実体。検査 0 件・実行 0 件を失敗にする）              |
| tests/harness/support/repo-files.mjs                  | 検査共通ヘルパ（HARNESS_ROOT・ファイル列挙・markdown 簡易解析・除外定数の検査）           |
| tests/harness/check-harness-structure.test.mjs        | サイズ上限（authoring guide の表から読む）・skill 1:1・adapter の薄さ・検証ゲート名の整合 |
| tests/harness/check-doc-placeholders.test.mjs         | docs/ の未解決プレースホルダ・未置換の明示 token・空 owner の症状                         |
| tests/harness/check-harness-refs.test.mjs             | ハーネス文書のインラインコードに書かれたパスの実在                                        |
| tests/harness/check-gh-usage.test.mjs                 | gh の `--limit`・search フィルタの排除・owner 直書き禁止                                  |
| tests/harness/check-workflows.test.mjs                | workflow が空でなく jobs を持つこと                                                       |
| tests/harness/check-agent-launch-paths.test.mjs       | agent の起動経路（subagent_type）または orphan-allow の宣言                               |
| tests/harness/check-adr-compression-lossless.mjs      | ADR 要約の無損失検証 CLI（決定節の逐語一致・参照 ID 保存・Status 不変・サイズ純減）       |
| tests/harness/check-adr-compression-lossless.test.mjs | 同 CLI の自己テスト                                                                       |
| tests/harness/harness-gates-e2e.test.mjs              | 最小ルートでの gate 結合テスト（通過と、違反注入での失敗）                                |
| tests/harness/harness-support.test.mjs                | support ヘルパとランナーの自己テスト・空ルートでの退化ガード                              |

### 公開区画（opt-in:public-site をまとめて採否判断）

| パス                                | 用途                                                 |
| ----------------------------------- | ---------------------------------------------------- |
| docs/CUSTOMER_PUBLISH_POLICY.md     | 対外公開の判定基準と機械検査の正本                   |
| docs/product/PUBLIC_ARCHITECTURE.md | 公開射影ドキュメントの骨格（直接編集禁止ヘッダ付き） |
| docs/customer/README.md             | 顧客資料の保管運用（原本 → 要約 → INDEX）            |
| docs/customer/summaries/INDEX.md    | 要約一覧（空）                                       |
| docs/customer/runbooks/INDEX.md     | 顧客向け手順書一覧（空）                             |

skill 正本・adapter・profile・hook とそのテストは、上の skill と `.claude` の表で `opt-in:public-site` の区分を持つ。

### トレーサビリティ（opt-in:traceability）

| パス                                                | 用途                                                                                             |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| docs/product/tests/README.md                        | traceability matrix の置き場・最小スキーマ・同一 PR 更新規約・不一致検査の最小契約（差し替え点） |
| docs/product/tests/traceability-matrix.example.yaml | traceability matrix の雛形（`{{GITHUB_ORG}}` `{{REPO_NAME}}` token を含む）                      |

### インシデント記録（opt-in:incident）

| パス                                | 用途                                                           |
| ----------------------------------- | -------------------------------------------------------------- |
| docs/postmortems/README.md          | インシデント記録の置き場・該当判定・命名・書き方（INDEX なし） |
| docs/templates/incident-timeline.md | インシデント対応の作業記録テンプレート                         |
| docs/templates/postmortem.md        | インシデント振り返り（blameless）のテンプレート                |

### API 契約バージョニング（opt-in:versioning）

| パス                           | 用途                                                                                            |
| ------------------------------ | ----------------------------------------------------------------------------------------------- |
| docs/product/API_VERSIONING.md | API 契約バージョニング方針の骨格（判定原則・区分表の型・採番の窓・リリース記録項目。TODO 付き） |

### Renovate（opt-in:renovate）

| パス          | 用途                                                                    |
| ------------- | ----------------------------------------------------------------------- |
| renovate.json | Renovate の最小構成（mise ツールのグルーピング・pnpm の dual-pin 束ね） |

skill 正本と adapter は、上の skill の表で `opt-in:renovate` の区分を持つ。

## opt-in グループ

グループ名を列挙する正本は本節だけである。他の文書は、グループ名の一覧を持たず、採用時だけ有効な箇所を「opt-in」「採用時のみ」と付記する（個々の資産の先頭タグ `opt-in:<group>` を除く）。グループに属する資産は、資産一覧の `opt-in:<group>` を持つ行と節、およびファイル先頭の `opt-in:<group>` タグで特定できる。

| グループ              | 採用する project                                                             | 不採用にする場合                                   |
| --------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------- |
| `opt-in:renovate`     | Renovate で依存を更新する                                                    | Renovate を使わない                                |
| `opt-in:public-site`  | 顧客・提携組織など外部へドキュメントや射影版の設計文書を公開する             | 公開先が無い                                       |
| `opt-in:submodule`    | git submodule を含む repository                                              | submodule を持たない                               |
| `opt-in:traceability` | 要件の受入条件とテストの対応を、機械可読の matrix で管理する                 | matrix を管理しない                                |
| `opt-in:incident`     | 障害・インシデントの事後記録を git に残す                                    | 事後記録を git に残さない                          |
| `opt-in:versioning`   | リポジトリ外の利用者が依存する契約（公開 API・SDK・webhook・イベント）を出す | 利用者が同一 repository の同時リリース範囲に閉じる |

### グループ除去チェックリスト

不採用のグループの資産を削除したら、core 側に残る参照を次の表で処理する。除去後は、次の 2 つで取りこぼしを確認する。

- `grep -rn 'opt-in:<group>' .`（`<group>` は不採用のグループ名）が、処理済みの箇所を除いて 0 件になる
- `pnpm harness:test` が通る（ハーネス文書のインラインコードに残った、削除済み資産へのパス参照を検出する）

| グループ              | 除去する資産                                                                                                                                    | core 側に残る参照の所在                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | 処置                                                                                                                          |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `opt-in:renovate`     | `renovate.json`・`/renovate-sync` の正本と adapter                                                                                              | `docs/harness/OPERATING_MODEL.md` の skill コマンド一覧（opt-in 表）/ `docs/harness/scheduled-operations.md` の routine カタログの行 / `.claude/skills/create-issue/references/project-fields.md` の routine ラベル表の `routine:renovate-sync` 行                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | 行を削除する                                                                                                                  |
| `opt-in:public-site`  | 公開区画の資産・skill 2 本の正本と adapter・profile 2 本・`post-edit-projection-reminder.sh` とそのテスト                                       | `docs/README.md` のマップ行（customer・CUSTOMER_PUBLISH_POLICY）・`docs/product/` 行の `PUBLIC_ARCHITECTURE.md（opt-in）`・命名規約の「顧客原本要約」行・運用ルールの customer/originals の 2 行 / `docs/notes/README.md` の顧客原本由来の要約の行 / `docs/harness/skills/docs-sync.md` の policy scan 対象表の EXCLUDE 列と実装整合の突合対象表の `docs/customer/**` / `docs/styles/coding_guide/docs.md` の除外パス表と規範層の `docs/customer/**`、`docs/styles/coding_guide/code-comments.md` の内部パス表の `docs/customer/` / `docs/harness/skills/shared/index-writer-policy.md` の割当表の `docs/customer/**/INDEX.md` / `docs/harness/skills/multi-issue.md` の公開射影区画の項 / `docs/harness/OPERATING_MODEL.md` の opt-in 表 / `docs/harness/scheduled-operations.md` の routine カタログの行 / `.claude/skills/create-issue/references/project-fields.md` の `routine:public-arch-sync` 行 / `.claude/hooks/README.md` の構成表と「公開射影採用時」の手順 | 行・項・節を削除する。除外表の `docs/customer/**` は、列挙された他のパスを残して語句だけ外す                                  |
| `opt-in:submodule`    | `pre-commit-submodule-guard.sh`・`bin/submodule-guard.sh`・それぞれのテスト（`test-pre-commit-submodule-guard.sh` / `test-submodule-guard.sh`） | `.claude/hooks/session-start.sh` の「opt-in: submodule 採用時に有効化」区画 / `.claude/hooks/README.md` の構成表と「submodule 採用時」の手順                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | hook 本体とテストは一緒に削除する（hook を残してテストだけ消すと、`run-all.sh` の逆向き検査が失敗する）。区画と手順は削除する |
| `opt-in:traceability` | `docs/product/tests/`                                                                                                                           | `docs/README.md` のマップ行と命名規約の matrix 行 / `docs/harness/OPERATING_MODEL.md` の docs 正本 pointer 集の行 / `docs/product/TEST_STRATEGY.md` の関連文書表の行 / `docs/harness/skills/multi-issue.md` の検収項目（matrix 更新）/ `docs/styles/team-feedback/implementation-flow-switch.md` の標準手順 4 / `docs/CUSTOMER_PUBLISH_POLICY.md` の区画表の `/quality` の行（public-site を採用している場合のみ）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | 行・項を削除する。手順の番号は詰める                                                                                          |
| `opt-in:incident`     | `docs/postmortems/`・`docs/templates/`                                                                                                          | `docs/README.md` のマップ行（postmortems・templates）と命名規約のインシデント記録の行 / `docs/harness/OPERATING_MODEL.md` の docs 正本 pointer 集の行 / `docs/harness/skills/docs-sync.md`（policy scan 対象表の EXCLUDE 列）と `docs/styles/coding_guide/docs.md`（除外パス表）の `docs/postmortems/**` / `docs/CUSTOMER_PUBLISH_POLICY.md` の公開前 gate のパターンの `postmortems\|templates`（public-site を採用している場合のみ）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | 行を削除する。gate のパターンは語句だけ外す                                                                                   |
| `opt-in:versioning`   | `docs/product/API_VERSIONING.md`                                                                                                                | `docs/README.md` の `docs/product/` 行の `API_VERSIONING.md（opt-in）` / `docs/harness/OPERATING_MODEL.md` の docs 正本 pointer 集の行                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | 語句と行を削除する                                                                                                            |

条件付きで落とす core 資産は、同じ手順で残存参照を処理する。

| 資産                                   | 落とす条件                                        | 残る参照の所在                                                                                                                                                                                                                                                            | 処置                                                              |
| -------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `.claude/rules/infra-development.md`   | IaC を採用しない                                  | `docs/harness/OPERATING_MODEL.md` の「領域別 rule の読み場面」表の行と `rules/` の件数 / `.claude/rules/team-policy.md` の領域別 rule の行と冒頭注記の列挙 / `DEVELOPMENT.md` の `.claude/rules/` の件数 / `docs/harness/skills/promote-memory.md` の rule 振り分け表の行 | 行を削除し、件数を直す                                            |
| `docs/harness/skills/deploy-verify.md` | deploy 手段が確立せず、release 反映も手順化しない | `docs/harness/OPERATING_MODEL.md` の skill コマンド一覧の行と承認モデルの pointer / `DEVELOPMENT.md` の slash コマンド表の行 / `docs/harness/skills/multi-issue.md` の委譲先の言及                                                                                        | 行・語句を削除する。正本と adapter は一緒に削除する（1:1 を保つ） |

## 導入先依存の関心事の索引

導入先の運用に合わせて置き換える記述の所在を、関心事ごとに引く索引である。既存の運用を持つ repository への導入（adopt）では、該当する資産を導入先の実態に合わせる。列挙は検索コマンドで再導出でき、資産を足したときは検索結果の差分を本表へ反映する。

| 関心事         | 内容                                                                 | 検索                                                                                      | 埋め込み箇所                                                                                                                                                                                                                                                                                                                                                |
| -------------- | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| branch-model   | main = dev 環境 / release = prod 環境のブランチモデル                | `grep -rlE 'main = dev\|release = prod\|長期統合ブランチ' .`                              | `.claude/rules/team-policy.md` / `DEVELOPMENT.md` / `docs/harness/OPERATING_MODEL.md` / `docs/harness/skills/deploy-verify.md` / `docs/harness/skills/shared/pr-creation.md` / `docs/styles/coding_guide/docs.md` / `docs/styles/team-feedback/INDEX.md` / `docs/styles/team-feedback/autonomous-flow.md`                                                   |
| default-branch | 既定ブランチ名（main）。`origin/main` として参照される               | `grep -rlE 'origin/main\|DEFAULT_BRANCH' .` と、`.github/workflows/ci.yml` の `branches:` | 入口 adapter・skill 正本・`docs/harness/skills/shared/`・agent 定義・hook のテスト・基礎 CI。既定ブランチが main でない導入先は、検索結果の全ファイルを置換する                                                                                                                                                                                             |
| root-config    | 導入先に同名のファイルがあるときは上書きせず、不足項目だけを追記する | （該当ファイルを列挙）                                                                    | `.gitignore` / `.mise.toml` / `.gitleaks.toml` / `.prettierignore` / `.env.example` / `renovate.json` / `pnpm-workspace.yaml` / `package.json` / `turbo.json`。`.gitleaks.toml` の `[allowlist]` は、値を入れるまでコメントアウトのままにする（値が無い `[allowlist]` は gitleaks が設定エラーにする）                                                      |
| hook-wiring    | 導入先に既存の hook 設定があるときは残したまま追記する               | （該当ファイルを確認）                                                                    | `.claude/settings.json`。pre-push hook の `if` は `Bash(git push *)` と `Bash(git -C *)` の 2 つを持つ。既存の pre-push 設定が `git push` だけを照合している場合は、`git -C` の `if` を追加する。追記する hook の `command` は `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/<hook ファイル名>` の形にする（cwd に依存しない起動。→ `.claude/hooks/README.md`） |
| entry-adapters | 導入先に既存の入口があるときは上書きせず、pointer 節だけを追記する   | （該当ファイルを確認）                                                                    | `AGENTS.md` / `CLAUDE.md` / `README.md`（README は無い場合だけ骨格を新規作成し、あれば「開発スタイル」の pointer だけを追記する）                                                                                                                                                                                                                           |

言語は `{{PROJECT_LANGUAGE}}` の記入箇所（OPERATING_MODEL の言語ポリシー節）、ツール・版・workspace は「既定スタックと差し替え点」の表が、それぞれ索引の役割を持つ。

## テンプレート自身の保守（配布しない）

assets を変更したら、テンプレート repository のルートから次を実行する。

```bash
bash .agents/skills/monorepo-bootstrap/scripts/check-assets.sh
```

検査の分担は次のとおり。

| 区分             | 場所                                         | 検査                                                                                                                                                               | 配布   |
| ---------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| 配布版           | `tests/harness/`（bootstrap 先の CI で動く） | サイズ上限・skill の 1:1・参照の実在・未置換 token・検証ゲート名の整合など。一覧は `tests/harness/README.md`                                                       | する   |
| テンプレート専用 | `../scripts/check-assets.sh`                 | MANIFEST と実ファイルの 1:1・skill 正本と adapter の 1:1・未置換 token の網羅・固有語 denylist。あわせて `HARNESS_ROOT` を assets に向けた `tests/harness/` の実行 | しない |

- 固有語 denylist は、環境変数 `TEMPLATE_DENYLIST_FILE` で repository 外のファイルのパスを渡す。形式は 1 行 1 パターンの拡張正規表現で、`#` で始まる行はコメント、大文字小文字は区別しない。denylist を repository に置くと固有語そのものが混入するため、未設定の場合はこの検査を skip する。
- MANIFEST の「資産一覧」節は、見出しを `## 資産一覧` のまま保ち、表の第 1 列をパスにする（検査が読む）。

## Self-check（bootstrap 完了前に実施）

- [ ] 明示 token（`{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}`）がルート直下の文書・package.json・設定に残っていない。docs/ 配下は `pnpm harness:test` の未解決プレースホルダ検査が見る。置換対象外の記入欄は `docs/adr/template.md` と `docs/templates/` の単一波括弧 `{…}` で、`docs/product/API_VERSIONING.md` の `{{PRODUCT_NAME}}` と `docs/product/tests/traceability-matrix.example.yaml` の `{{GITHUB_ORG}}` `{{REPO_NAME}}` は置換対象である
- [ ] `TODO(` を含む箇所を列挙し、残したものを完了報告の残 TODO に転記した。`docs/harness/skills/deploy-verify.md` の TODO が 0、または不採用として除去済みである
- [ ] 不採用の opt-in グループの資産がコピーされておらず、「グループ除去チェックリスト」の残存参照を処理した
- [ ] `.claude/skills/*/SKILL.md` と `docs/harness/skills/*.md` が 1:1 対応している
- [ ] hooks の外部契約 4 点が成立している（root scripts 6 本 / mise pin / `apps/*`・`packages/*` レイアウトと pnpm-workspace.yaml / 秘密検知ツール設定）
- [ ] `.claude/hooks/tests/run-all.sh` が green（`hooks/*.sh` ごとにテストが存在することも検査される。対象外は `session-start.sh` のみ）
- [ ] `pnpm harness:test`（Node のみで `node tests/harness/run.mjs` でも可）が green
- [ ] local と CI の検査の差が、`docs/harness/skills/shared/verification-gates.md` の名前付き組合せの表で説明できる
- [ ] 導入先依存の関心事の索引（branch-model・default-branch）に載る資産が、導入先の実態と一致している
- [ ] 翻訳した場合も、言語ポリシー節以外に言語名が混入していない
- [ ] routine 登録（`docs/harness/scheduled-operations.md` のカタログ）と、INDEX の経過措置の解除（`docs/harness/skills/shared/index-writer-policy.md` の運用状態表）を完了報告の TODO に含めた

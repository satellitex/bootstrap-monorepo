# assets MANIFEST

この文書は `assets/` 配下のテンプレート資産の正本台帳である。bootstrap 実行時は本表に従って copy → placeholder 置換 → 不要資産の削除を行う。資産の追加・削除時は本表を同一 PR で更新する（1:1 整合が受入条件）。設計判断の根拠は `../references/` 側に置き、本書には書かない。本書自身と、assets の外にあるテンプレート専用の検査（`../scripts/`）は、bootstrap 先へ配布しない。

## 使い方（bootstrap での適用手順）

1. `core` 区分の資産を bootstrap 先へ同一相対パスでコピーする（本書はコピーしない）。Skill を `gh skill install` で install した場合、assets 内の `SKILL.md` の frontmatter に installer の追跡用 `metadata`（`github-repo` などの `github-*` キー）が付いている。コピー後に `.claude/skills/*/SKILL.md` から `metadata` ブロックを除き、収録時の `name` と `description` だけに戻す（残っていると `tests/harness` の adapter 構造検査が失敗する）。
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

| 既定                                                | 収録箇所                                                                                                                                                                                                    | 差し替え方                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| pnpm + turbo                                        | package.json / turbo.json / hooks / ci.yml                                                                                                                                                                  | scripts の名前の契約と、名前を変える場合の同時更新、コマンド名を直接書いてよい箇所は `docs/harness/skills/shared/verification-gates.md`「コマンド定義」「変更時の注意」に従う。名前を保てば実装は自由                                                                                                                                                                                                                                                                                   |
| pnpm workspace                                      | pnpm-workspace.yaml                                                                                                                                                                                         | `apps/*` と `packages/*` を列挙する。hooks の package 解決（`.claude/hooks/README.md` の外部契約 3）が前提とする。レイアウトを変える場合は `.claude/bin/hook-utils.sh` の `_pkg_dir_of_rel`（package 解決の prefix を持つ 1 か所）と `.claude/rules/product-development.md` の `paths:` を同時に変える                                                                                                                                                                                  |
| pnpm の版                                           | package.json の packageManager と .mise.toml                                                                                                                                                                | 2 か所に同じ版を pin する（dual-pin）。更新は同時に行う                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| prettier                                            | pre-format-check hook / .prettierignore                                                                                                                                                                     | md を含む手書き文書も整形対象で、収録 md は整形済みである。.prettierignore は生成物だけを除外する。除外を広げると、md だけの変更に使う `gate:docs`（format:check のみ）が検査対象を失うため、広げるときは `gate:docs` を再定義する。formatter の差し替えは hook 冒頭のコマンド変数で行う                                                                                                                                                                                                |
| eslint + TypeScript                                 | post-edit-check hook の case 分岐                                                                                                                                                                           | 既定で `.ts` / `.tsx` / `.js` / `.jsx` の編集後に eslint と `tsc --noEmit` を呼ぶ。両者は root の devDependencies に含めないため、導入先の既存設定を使う。採用しない場合は該当 case と `.claude/hooks/tests/test-post-edit-check.sh` のケースを同時に削除し、他言語は hook 内の「言語別チェックの追加例」に従って case を足す                                                                                                                                                           |
| gitleaks + mise + node + jq                         | .mise.toml / .gitleaks.toml / pre-push hook。mise に依存する資産は `grep -rl mise .` で列挙する（hooks・settings.json の SessionStart 配線・ci.yml の `jdx/mise-action`・README.md のセットアップ手順など） | .mise.toml の pin を変更する。node は bootstrap 時点の最新 LTS を確認して pin する。gitleaks は pre-push hook でだけ使う（hook と CI の分担 → `docs/harness/skills/shared/verification-gates.md`「ゲートごとの実行先」）。.gitleaks.toml は既定ルールを継承し、`[allowlist]` はコメントアウトした雛形である。gitleaks を外す場合は pre-push hook の秘密検知区画も外す。mise を使わない導入先は、.mise.toml を導入せず、検索に出る資産の mise 依存箇所を既存ツールの解決方法へ差し替える |
| hook 環境変数 prefix `PROJ_`                        | hooks / tests / .env.example / `docs/harness/skills/shared/notification-contract.md` / `.claude/skills/review-cycle/references/notification-mapping.md` / `docs/harness/skills/renovate-sync.md`            | 全ファイル一括置換                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| エージェント作業ブランチ `agent/<skill>-YYYY-MM-DD` | shared/sync-pr-flow.md と、`grep -rl 'agent/' .` に出る資産（skill 正本・agent 定義・OPERATING_MODEL.md・scheduled-operations.md）                                                                          | 置換可。検索に出る全資産で同時に置換し、open PR ガードの prefix 判定と揃えること                                                                                                                                                                                                                                                                                                                                                                                                        |

## 資産一覧

この節の表は、第 1 列が資産のパスで、`../scripts/check-assets.sh` が実ファイルとの 1:1 を検査する（パスに `<name>` や `*` を含む行はパターン、末尾 `/` の行はディレクトリ配下全体として読む）。パスを第 1 列に持たない表は、この節の外に置く。

### ルート（core）

| パス                     | 用途                                  |
| ------------------------ | ------------------------------------- |
| MANIFEST.md              | 本書（bootstrap 先へはコピーしない）  |
| README.md                | 人間向けの入口（pointer 中心）        |
| AGENTS.md                | Codex 入口の薄い adapter              |
| CLAUDE.md                | Claude 入口の薄い adapter             |
| DEVELOPMENT.md           | 人間向け開発スタイル                  |
| .gitignore               | git の除外設定                        |
| .mise.toml               | ツールバージョンの正本（pin）         |
| .gitleaks.toml           | gitleaks 設定                         |
| .env.example             | 環境変数のキー名の雛形                |
| .prettierignore          | prettier の除外設定                   |
| pnpm-workspace.yaml      | workspace 定義                        |
| package.json             | 検証ゲートの script 契約と補助 script |
| turbo.json               | task runner の最小 pipeline           |
| .github/workflows/ci.yml | 基礎 CI                               |

### docs 正本（core）

| パス                                    | 用途                                            |
| --------------------------------------- | ----------------------------------------------- |
| docs/README.md                          | docs のディレクトリマップ                       |
| docs/harness/OPERATING_MODEL.md         | ハーネス運用の neutral 正本                     |
| docs/harness/harness_authoring_guide.md | ハーネス文書の書き方規約                        |
| docs/harness/scheduled-operations.md    | routine カタログと定期 workflow の設計ガイド    |
| docs/adr/README.md                      | ADR 運用規約                                    |
| docs/adr/INDEX.md                       | ADR 一覧（Status 別・空）                       |
| docs/adr/template.md                    | ADR 本文テンプレート（様式）                    |
| docs/requirements/README.md             | 要件正本の運用（ID 体系・定型構成・起草と確定） |
| docs/requirements/INDEX.md              | 要件一覧（空）                                  |
| docs/product/ARCHITECTURE.md            | 内部設計正本の骨格                              |
| docs/product/TECH_STACK.md              | 技術スタック確定表の骨格                        |
| docs/product/TERMS.md                   | ドメイン用語集の骨格                            |
| docs/product/TEST_STRATEGY.md           | テスト戦略の骨格                                |
| docs/runbooks/README.md                 | 手順書の規約                                    |
| docs/runbooks/INDEX.md                  | runbook 一覧の骨格                              |
| docs/notes/README.md                    | 調査層の運用規約                                |
| docs/notes/research/INDEX.md            | 調査ノート一覧（空）                            |
| docs/audit/README.md                    | 外部監査レポートの命名規約                      |

### styles（core）

| パス                                                        | 用途                                          |
| ----------------------------------------------------------- | --------------------------------------------- |
| docs/styles/coding_guide/INDEX.md                           | コーディング規約の目次                        |
| docs/styles/coding_guide/docs.md                            | docs 編集規約                                 |
| docs/styles/coding_guide/code-comments.md                   | コードコメント規約                            |
| docs/styles/coding_guide/testing_principles.md              | テスト記述規約                                |
| docs/styles/refactoring_guide.md                            | リファクタ運用モデルと検出観点                |
| docs/styles/team-feedback/INDEX.md                          | team 共有 rule の一覧（各 rule の概要の正本） |
| docs/styles/team-feedback/long-term-automation.md           | team 共有 rule: 長期自動化の優先              |
| docs/styles/team-feedback/autonomous-flow.md                | team 共有 rule: 自律実行の既定                |
| docs/styles/team-feedback/single-solution.md                | team 共有 rule: 解決策の 1 案確定             |
| docs/styles/team-feedback/implementation-flow-switch.md     | team 共有 rule: 実装フローの切替              |
| docs/styles/team-feedback/shared-aggregate-single-writer.md | team 共有 rule: INDEX の単一 writer           |
| docs/styles/team-feedback/format-check.md                   | team 共有 rule: commit 前の format            |
| docs/styles/team-feedback/review-comments.md                | team 共有 rule: レビューコメントの批判的評価  |
| docs/styles/team-feedback/scope-boundary.md                 | team 共有 rule: スコープ外の Issue 化         |
| docs/styles/team-feedback/pr-closing-keyword.md             | team 共有 rule: PR の closing keyword         |
| docs/styles/team-feedback/refactor-before-pr.md             | team 共有 rule: PR 前の簡素化パス             |

### skill 手順の正本（docs/harness/skills/）

| パス                                                     | 用途                                     | 区分               |
| -------------------------------------------------------- | ---------------------------------------- | ------------------ |
| docs/harness/skills/shared/sync-prelude.md               | sync 系共通の前段                        | core               |
| docs/harness/skills/shared/sync-pr-flow.md               | sync 系共通の後段                        | core               |
| docs/harness/skills/shared/sync-noise-filter.md          | CI ノイズ除外と退避先確認の共通手順      | core               |
| docs/harness/skills/shared/gh-query-fail-closed.md       | gh 照会の fail-closed 規約               | core               |
| docs/harness/skills/shared/pr-creation.md                | PR 作成の共通手順と本文の標準節          | core               |
| docs/harness/skills/shared/verification-gates.md         | 検証ゲートの定義と hook / CI の分担      | core               |
| docs/harness/skills/shared/unattended-contract.md        | 無人 run の共通契約                      | core               |
| docs/harness/skills/shared/index-writer-policy.md        | INDEX の更新主体の割当と leaf 文書の要件 | core               |
| docs/harness/skills/shared/implementation-consistency.md | 記述と実装の矛盾の共通手順               | core               |
| docs/harness/skills/shared/notification-contract.md      | チャット webhook 通知の共通契約          | core               |
| docs/harness/skills/readme-sync.md                       | README と実コードの定期突合              | core               |
| docs/harness/skills/docs-sync.md                         | docs 現状層の定期検査                    | core               |
| docs/harness/skills/code-sync.md                         | ソースコメントの定期検査                 | core               |
| docs/harness/skills/refactor-guide-sync.md               | 規約正本とリファクタガイドの整合         | core               |
| docs/harness/skills/refactor-sync.md                     | リファクタ観点の検出と Issue 提案        | core               |
| docs/harness/skills/gc-scan.md                           | ハーネス GC（重複・孤児）                | core               |
| docs/harness/skills/adr-compress.md                      | ADR の定期圧縮                           | core               |
| docs/harness/skills/adr-compress/compression-rules.md    | adr-compress の圧縮規則                  | core               |
| docs/harness/skills/adr-compress/pr-output-format.md     | adr-compress の PR 本文構成              | core               |
| docs/harness/skills/create-adr.md                        | ADR の構造的記録                         | core               |
| docs/harness/skills/create-issue.md                      | Issue 作成                               | core               |
| docs/harness/skills/handle-review.md                     | レビューコメントの評価と対応             | core               |
| docs/harness/skills/review-cycle.md                      | LGTM までの自律対応                      | core               |
| docs/harness/skills/multi-issue.md                       | Planner–Worker 並列実装                  | core               |
| docs/harness/skills/promote-memory.md                    | 個人 memory から team rule への昇格      | core               |
| docs/harness/skills/runbook-alignment.md                 | 運用手順書と実装の照合                   | core               |
| docs/harness/skills/deploy-verify.md                     | デプロイ一気通貫と release 反映の骨格    | core               |
| docs/harness/skills/renovate-sync.md                     | 依存 pin と Renovate 設定の突合          | opt-in:renovate    |
| docs/harness/skills/public-arch-sync.md                  | 内部正本から公開射影への追従             | opt-in:public-site |
| docs/harness/skills/customer-doc-review.md               | 対外ドキュメントのレビュー               | opt-in:public-site |

### .claude（adapter・rules・hooks・agents）

| パス                                                              | 用途                                                                                            | 区分               |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ------------------ |
| .claude/skills/&lt;name&gt;/SKILL.md                              | 上記各 skill の薄い adapter（同名で 1:1）                                                       | 正本と同区分       |
| .claude/skills/multi-issue/references/model-profile.md            | モデル名と subagent 起動パラメータの profile                                                    | core               |
| .claude/skills/create-issue/references/project-fields.md          | Project / ラベル / マイルストーンの profile                                                     | core               |
| .claude/skills/docs-sync/references/freshness-policy.md           | 鮮度検証対象の profile                                                                          | core               |
| .claude/skills/review-cycle/references/notification-mapping.md    | 通知手段と宛先の profile                                                                        | core               |
| .claude/skills/review-cycle/references/ci-and-conflict-profile.md | conflict 解消と CI 修正の profile                                                               | core               |
| .claude/skills/public-arch-sync/references/projection-rules.md    | 射影ルールの profile                                                                            | opt-in:public-site |
| .claude/skills/customer-doc-review/references/target-prep.md      | 対象準備の profile                                                                              | opt-in:public-site |
| .claude/rules/team-policy.md                                      | 常時ロード rule（pointer 層）                                                                   | core               |
| .claude/rules/harness-development.md                              | ハーネス編集時の rule                                                                           | core               |
| .claude/rules/product-development.md                              | プロダクトコード編集時の rule（skeleton）                                                       | core               |
| .claude/rules/infra-development.md                                | インフラ編集時の rule（skeleton）                                                               | core               |
| .claude/settings.json                                             | hook 配線の正本                                                                                 | core               |
| .claude/hooks/README.md                                           | hook の運用ガイド                                                                               | core               |
| .claude/hooks/session-start.sh                                    | セッション開始時の環境 bootstrap                                                                | core               |
| .claude/hooks/pre-format-check.sh                                 | commit 前のフォーマット                                                                         | core               |
| .claude/hooks/pre-push-ci-check.sh                                | push 前の秘密検知と CI 同等検査                                                                 | core               |
| .claude/hooks/post-edit-check.sh                                  | 編集後の拡張子別検査                                                                            | core               |
| .claude/hooks/pre-commit-submodule-guard.sh                       | submodule pointer 混入の防止                                                                    | opt-in:submodule   |
| .claude/hooks/post-edit-projection-reminder.sh                    | 内部正本編集時の公開射影リマインド                                                              | opt-in:public-site |
| .claude/bin/hook-utils.sh                                         | hooks 共通ユーティリティ                                                                        | core               |
| .claude/bin/submodule-guard.sh                                    | submodule 初期化ユーティリティ                                                                  | opt-in:submodule   |
| .claude/hooks/tests/run-all.sh                                    | hooks テストの並列一括実行（CI の test job から呼ぶ。hook ごとのテスト存在も検査）              | core               |
| .claude/hooks/tests/lib.sh                                        | 各 test-*.sh が source する共通ヘルパ（隔離 repo・stub・hook 出力の取り出し）。実行対象ではない | core               |
| .claude/hooks/tests/test-pre-format-check.sh                      | 同 hook の hermetic テスト                                                                      | core               |
| .claude/hooks/tests/test-pre-push-ci-check.sh                     | 同 hook の hermetic テスト                                                                      | core               |
| .claude/hooks/tests/test-post-edit-check.sh                       | 同 hook の hermetic テスト                                                                      | core               |
| .claude/hooks/tests/test-hook-utils.sh                            | ユーティリティのテスト（パス正規化・symlink・git 操作の対象作業ツリーの解決を含む）             | core               |
| .claude/hooks/tests/test-submodule-guard.sh                       | submodule-guard.sh のテスト                                                                     | opt-in:submodule   |
| .claude/hooks/tests/test-pre-commit-submodule-guard.sh            | pre-commit-submodule-guard.sh の hermetic テスト                                                | opt-in:submodule   |
| .claude/hooks/tests/test-post-edit-projection-reminder.sh         | post-edit-projection-reminder.sh の hermetic テスト                                             | opt-in:public-site |
| .claude/agents/gc-agent.md                                        | ハーネス文書の重複・孤児の検出と PR 提案                                                        | core               |
| .claude/agents/adr-compactor.md                                   | ADR 圧縮のオーケストレーション                                                                  | core               |
| .claude/agents/architecture-sync.md                               | 変更近傍 README の構造同期                                                                      | core               |
| .claude/agents/refactorer.md                                      | リファクタ観点の検出                                                                            | core               |
| .claude/agents/refactor-guide-sync.md                             | 規約正本 ↔ ガイド突合                                                                           | core               |
| .claude/agents/references/gc-agent-detection.md                   | gc-agent の検出条件                                                                             | core               |
| .claude/agents/references/refactorer-profile.md                   | refactorer の profile                                                                           | core               |
| .claude/agents/references/refactorer-issue-template.md            | 提案 Issue のテンプレート                                                                       | core               |
| .claude/agents/references/refactor-guide-sync-detection.md        | 突合アルゴリズム詳細                                                                            | core               |
| .claude/agents/references/refactor-guide-sync-output.md           | 出力先判定と PR body テンプレート                                                               | core               |

### tests（core）

| パス                                                  | 用途                                                                                                                          |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| tests/harness/README.md                               | 機械検査の運用ガイド                                                                                                          |
| tests/harness/run.mjs                                 | 検査ランナー                                                                                                                  |
| tests/harness/support/repo-files.mjs                  | 検査共通ヘルパ（HARNESS_ROOT・テンプレートモード・ファイル列挙・読み取りの memo・パス仕様・除外定数の検査）                   |
| tests/harness/support/markdown.mjs                    | ROOT に依存しない markdown の簡易解析・frontmatter・計測（repo-files.mjs が re-export し、ADR 検証 CLI が単体で import する） |
| tests/harness/support/gates.mjs                       | 走査系 gate の列挙と、環境を切り離した子プロセス実行（結合テストと足場の自己テストが使う）                                    |
| tests/harness/check-harness-structure.test.mjs        | 構造検査（サイズ・skill 1:1・adapter の薄さ・ゲート名・文書間の名前の整合）                                                   |
| tests/harness/check-doc-placeholders.test.mjs         | プレースホルダ検査                                                                                                            |
| tests/harness/check-harness-refs.test.mjs             | パス参照の実在検査                                                                                                            |
| tests/harness/check-gh-usage.test.mjs                 | gh コマンドの使い方検査                                                                                                       |
| tests/harness/check-workflows.test.mjs                | workflow 構造検査                                                                                                             |
| tests/harness/check-agent-launch-paths.test.mjs       | agent の起動経路検査                                                                                                          |
| tests/harness/check-adr-compression-lossless.mjs      | ADR 要約の無損失検証 CLI                                                                                                      |
| tests/harness/check-adr-compression-lossless.test.mjs | 同 CLI の自己テスト                                                                                                           |
| tests/harness/harness-gates-e2e.test.mjs              | gate の結合テスト                                                                                                             |
| tests/harness/harness-support.test.mjs                | support とランナーの自己テスト                                                                                                |

### 公開区画（opt-in:public-site をまとめて採否判断）

| パス                                | 用途                       |
| ----------------------------------- | -------------------------- |
| docs/CUSTOMER_PUBLISH_POLICY.md     | 対外公開の判定基準         |
| docs/product/PUBLIC_ARCHITECTURE.md | 公開射影ドキュメントの骨格 |
| docs/customer/README.md             | 顧客資料の保管運用         |
| docs/customer/summaries/INDEX.md    | 要約一覧（空）             |
| docs/customer/runbooks/INDEX.md     | 顧客向け手順書一覧（空）   |

skill 正本・adapter・profile・hook とそのテストは、上の skill と `.claude` の表で `opt-in:public-site` の区分を持つ。

### トレーサビリティ（opt-in:traceability）

| パス                                                | 用途                             |
| --------------------------------------------------- | -------------------------------- |
| docs/product/tests/README.md                        | traceability matrix の運用ガイド |
| docs/product/tests/traceability-matrix.example.yaml | traceability matrix の雛形       |

### インシデント記録（opt-in:incident）

| パス                                | 用途                         |
| ----------------------------------- | ---------------------------- |
| docs/postmortems/README.md          | インシデント記録の運用規約   |
| docs/templates/incident-timeline.md | 作業記録テンプレート（様式） |
| docs/templates/postmortem.md        | 振り返りテンプレート（様式） |

### API 契約バージョニング（opt-in:versioning）

| パス                           | 用途                             |
| ------------------------------ | -------------------------------- |
| docs/product/API_VERSIONING.md | API 契約バージョニング方針の骨格 |

### Renovate（opt-in:renovate）

| パス          | 用途                |
| ------------- | ------------------- |
| renovate.json | Renovate の最小構成 |

skill 正本と adapter は、上の skill の表で `opt-in:renovate` の区分を持つ。

## opt-in グループ

グループ名を列挙する正本は本節だけである。他の文書は、グループ名の一覧を持たず、採用時だけ有効な箇所を「opt-in」「採用時のみ」と付記する（個々の資産の先頭タグ `opt-in:<group>` を除く）。グループに属する資産は、資産一覧の `opt-in:<group>` を持つ行と節、およびファイル冒頭の `opt-in:<group>` タグで特定できる。

| グループ              | 採用する project                                                             | 不採用にする場合                                   |
| --------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------- |
| `opt-in:renovate`     | Renovate で依存を更新する                                                    | Renovate を使わない                                |
| `opt-in:public-site`  | 顧客・提携組織など外部へドキュメントや射影版の設計文書を公開する             | 公開先が無い                                       |
| `opt-in:submodule`    | git submodule を含む repository                                              | submodule を持たない                               |
| `opt-in:traceability` | 要件の受入条件とテストの対応を、機械可読の matrix で管理する                 | matrix を管理しない                                |
| `opt-in:incident`     | 障害・インシデントの事後記録を git に残す                                    | 事後記録を git に残さない                          |
| `opt-in:versioning`   | リポジトリ外の利用者が依存する契約（公開 API・SDK・webhook・イベント）を出す | 利用者が同一 repository の同時リリース範囲に閉じる |

### グループ除去チェックリスト

不採用のグループの資産を削除したら、core 側に残る参照を処理する。残存参照の所在は列挙せず、次の検索で見つけて、表の「処置の種類」に従って直す。

- 除去した資産のパスと名前（skill は `/<name>` と `routine:<name>` ラベルを含む）を `grep -rn` で検索し、見つかった参照を処理する
- `grep -rn 'opt-in:<group>' .`（`<group>` は不採用のグループ名）が、処理済みの箇所を除いて 0 件になる
- `pnpm harness:test` が通る（ハーネス文書のインラインコードに残った、削除済み資産へのパス参照を検出する）

| グループ              | 除去する資産                                                                                                                                    | 処置の種類                                                                                                                           |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `opt-in:renovate`     | `renovate.json`・`/renovate-sync` の正本と adapter                                                                                              | 行の削除                                                                                                                             |
| `opt-in:public-site`  | 公開区画の資産・skill 2 本の正本と adapter・profile 2 本・`post-edit-projection-reminder.sh` とそのテスト                                       | 行・項・節の削除。除外表の `docs/customer/**` は、列挙された他のパスを残して語句だけ削除。`docs/product/PUBLIC_*.md` は行ごと削除    |
| `opt-in:submodule`    | `pre-commit-submodule-guard.sh`・`bin/submodule-guard.sh`・それぞれのテスト（`test-pre-commit-submodule-guard.sh` / `test-submodule-guard.sh`） | hook 本体とテストの一括削除（hook を残してテストだけ消すと、`run-all.sh` の逆向き検査が失敗する）。hook を有効化する区画と手順の削除 |
| `opt-in:traceability` | `docs/product/tests/`                                                                                                                           | 行・項の削除。手順の番号を詰める                                                                                                     |
| `opt-in:incident`     | `docs/postmortems/`・`docs/templates/`                                                                                                          | 行の削除。公開前 gate のパターン（public-site を採用している場合のみ）は語句だけ削除                                                 |
| `opt-in:versioning`   | `docs/product/API_VERSIONING.md`                                                                                                                | 語句と行の削除                                                                                                                       |

条件付きで落とす core 資産も、同じ検索で残存参照を処理する。

| 資産                                   | 落とす条件                                        | 処置の種類                                                    |
| -------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------- |
| `.claude/rules/infra-development.md`   | IaC を採用しない                                  | 行の削除と、件数の訂正                                        |
| `docs/harness/skills/deploy-verify.md` | deploy 手段が確立せず、release 反映も手順化しない | 行・語句の削除。正本と adapter は一緒に削除する（1:1 を保つ） |

## 導入先依存の関心事の索引

導入先の運用に合わせて置き換える記述の所在を、関心事ごとに引く索引である。既存の運用を持つ repository への導入（adopt）では、該当する資産を導入先の実態に合わせる。列挙は検索コマンドで再導出でき、資産を足したときは検索結果の差分を本表へ反映する。

| 関心事         | 内容                                                                 | 検索                                                                                         | 埋め込み箇所                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| branch-model   | main = dev 環境 / release = prod 環境のブランチモデル                | `grep -rlE 'main = dev\|release = prod\|長期統合ブランチ\|release 反映\|release ブランチ' .` | `.claude/skills/deploy-verify/SKILL.md` / `DEVELOPMENT.md` / `docs/harness/OPERATING_MODEL.md` / `docs/harness/skills/deploy-verify.md` / `docs/harness/skills/shared/pr-creation.md` / `docs/styles/coding_guide/docs.md`                                                                                                                                                                                                                                                     |
| default-branch | 既定ブランチ名（main）。`origin/main` として参照される               | `grep -rlE 'origin/main\|DEFAULT_BRANCH' .` と、`.github/workflows/ci.yml` の `branches:`    | 入口 adapter・skill 正本・`docs/harness/skills/shared/`・agent 定義・hook のテスト・基礎 CI。既定ブランチが main でない導入先は、検索結果の全ファイルを置換する                                                                                                                                                                                                                                                                                                                |
| root-config    | 導入先に同名のファイルがあるときは上書きせず、不足項目だけを追記する | （該当ファイルを列挙）                                                                       | `.gitignore` / `.mise.toml` / `.gitleaks.toml` / `.prettierignore` / `.env.example` / `renovate.json` / `pnpm-workspace.yaml` / `package.json` / `turbo.json`。`.gitleaks.toml` の `[allowlist]` は、値を入れるまでコメントアウトのままにする（値が無い `[allowlist]` は gitleaks が設定エラーにする）                                                                                                                                                                         |
| hook-wiring    | 導入先に既存の hook 設定があるときは残したまま追記する               | （該当ファイルを確認）                                                                       | `.claude/settings.json`。pre-push hook と commit 系の hook（pre-format-check・採用していれば pre-commit-submodule-guard）は、`Bash(git push *)` または `Bash(git commit *)` に加えて `Bash(git -C *)` の `if` を持つ。既存の設定が `git push` / `git commit` だけを照合している場合は、`git -C` の `if` を追加する。追記する hook の `command` は `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/<hook ファイル名>` の形にする（cwd に依存しない起動。→ `.claude/hooks/README.md`） |
| entry-adapters | 導入先に既存の入口があるときは上書きせず、pointer 節だけを追記する   | （該当ファイルを確認）                                                                       | `AGENTS.md` / `CLAUDE.md` / `README.md`（README は無い場合だけ骨格を新規作成し、あれば「開発スタイル」の pointer だけを追記する）                                                                                                                                                                                                                                                                                                                                              |

言語は `{{PROJECT_LANGUAGE}}` の記入箇所（OPERATING_MODEL の言語ポリシー節）、ツール・版・workspace は「既定スタックと差し替え点」の表が、それぞれ索引の役割を持つ。

## テンプレート自身の保守（配布しない）

assets を変更したら、テンプレート repository の checkout のルートから次を実行する。skill installer で install した Skill や、bootstrap / adopt の実行中には実行しない（Self-check の対象でもない）。検査項目と、固有語 denylist の形式は、`../scripts/check-assets.sh` の冒頭コメントが正本である。

```bash
bash .agents/skills/monorepo-bootstrap/scripts/check-assets.sh
```

- 固有語 denylist は、環境変数 `TEMPLATE_DENYLIST_FILE` に repository 外のファイルのパスを渡して指す。denylist を repository に置くと固有語そのものが混入するため、未設定の場合はこの検査を skip する。
- 終了コードは、すべて通過（skip を含む）なら 0、1 つ以上失敗なら 1。
- 配布版の機械検査（`tests/harness/`）は bootstrap 先の CI で動く。テンプレート専用の検査（`../scripts/`）は配布しない。
- MANIFEST の「資産一覧」節は、見出しを `## 資産一覧` のまま保ち、表の第 1 列をパスにする（検査が読む）。

## Self-check（bootstrap 完了前に実施）

- [ ] 明示 token（`{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}`）がルート直下の文書・package.json・設定に残っていない。docs/ 配下は `pnpm harness:test` の未解決プレースホルダ検査が見る。置換対象外の記入欄は、冒頭で `<!-- harness:form -->` を自己宣言する様式ファイル（規約 → `tests/harness/README.md`「除外定数と許容リスト」。収録は `docs/adr/template.md` と `docs/templates/` 配下）の単一波括弧 `{…}` で、`docs/product/API_VERSIONING.md` の `{{PRODUCT_NAME}}` と `docs/product/tests/traceability-matrix.example.yaml` の `{{GITHUB_ORG}}` `{{REPO_NAME}}` は置換対象である
- [ ] `TODO(` を含む箇所を列挙し、残したものを完了報告の残 TODO に転記した。`docs/harness/skills/deploy-verify.md` の TODO が 0、または不採用として除去済みである
- [ ] 不採用の opt-in グループの資産がコピーされておらず、「グループ除去チェックリスト」の残存参照を処理した
- [ ] `.claude/skills/*/SKILL.md` と `docs/harness/skills/*.md` が 1:1 対応している
- [ ] hooks の外部契約が成立している（→ `.claude/hooks/README.md`「外部契約」）
- [ ] `.claude/hooks/tests/run-all.sh` が green（`hooks/*.sh` ごとにテストが存在することも検査される。対象外は `session-start.sh` のみ）
- [ ] `pnpm harness:test`（Node のみで `node tests/harness/run.mjs` でも可）が green
- [ ] local と CI の検査の差が、`docs/harness/skills/shared/verification-gates.md` の名前付き組合せの表で説明できる
- [ ] 導入先依存の関心事の索引（branch-model・default-branch）に載る資産が、導入先の実態と一致している
- [ ] 翻訳した場合も、言語ポリシー節以外に言語名が混入していない
- [ ] routine 登録（`docs/harness/scheduled-operations.md` のカタログ）と、INDEX の経過措置の解除（`docs/harness/skills/shared/index-writer-policy.md` の運用状態表）を完了報告の TODO に含めた

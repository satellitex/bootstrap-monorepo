# assets MANIFEST

この文書は `assets/` 配下のテンプレート資産の正本台帳である。bootstrap 実行時は本表に従って copy → placeholder 置換 → 不要資産の削除を行う。資産の追加・削除時は本表を同一 PR で更新する（1:1 整合が受入条件）。設計判断の根拠は `../references/` 側に置き、本書には書かない。

## 使い方（bootstrap での適用手順）

1. `core` 区分の資産を bootstrap 先へ同一相対パスでコピーする。
2. opt-in グループ（下表の `opt-in:*`）は Intake / 計画時の採否判断に従い、採用グループのみコピーする。不採用グループの資産はコピーしない。
3. 明示 token を一括置換する: `{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}`。`{{PROJECT_LANGUAGE}}` は Intake で確認した project language（例: `日本語` / `English`）で、`docs/harness/OPERATING_MODEL.md` の言語ポリシー節が唯一の記入箇所である（他の資産は同節を参照するだけで言語名を持たない）。
4. `TODO(取得方法: ...)` 形式の値は、実環境で検証した値のみ埋める（未検証のまま実値を書かない）。
5. Self-check（下記）を実行する。

## 既定スタックと差し替え点

| 既定 | 収録箇所 | 差し替え方 |
|---|---|---|
| pnpm + turbo | package.json / turbo.json / hooks / ci.yml | scripts 6 本（build / test / lint / typecheck / format / format:check）の名前を保てば実装は自由。名前を変える場合は `docs/harness/skills/shared/verification-gates.md` と hooks を同時更新 |
| prettier | pre-format-check hook | hook 冒頭の formatter コマンド変数を差し替え |
| gitleaks + mise + node 22 + jq | .mise.toml / pre-push hook | .mise.toml の pin を変更。gitleaks を外す場合は pre-push hook の秘密検知区画も外す |
| hook 環境変数 prefix `PROJ_` | hooks / tests | 全ファイル一括置換 |
| エージェント作業ブランチ `agent/<skill>-YYYY-MM-DD` | shared/sync-pr-flow.md | 置換可。open PR ガードの prefix 判定と揃えること |

## 資産一覧

### ルート（core）

| パス | 用途 |
|---|---|
| MANIFEST.md | 本書（bootstrap 先へはコピーしない） |
| AGENTS.md | Codex 入口の薄い adapter 雛形 |
| CLAUDE.md | Claude 入口の薄い adapter 雛形 |
| DEVELOPMENT.md | 人間向け開発スタイル（自律実行モデル・承認ポイント・フロー） |
| .gitignore | `.claude/settings.local.json` `.claude/state/` `.claude/worktrees/` `.claude/logs/` を含む |
| .mise.toml | ツールバージョン正本（node / pnpm / jq / gitleaks の最小 pin） |
| package.json | hooks / CI が依存する 6 script 名の契約 |
| turbo.json | build / test / lint / typecheck の最小 pipeline |
| .github/workflows/ci.yml | 基礎 CI（format:check / test / build。test job で hooks の bash テストも実行） |

### docs 正本（core）

| パス | 用途 |
|---|---|
| docs/README.md | docs 全体のディレクトリマップ + INDEX 同時更新ルール |
| docs/harness/OPERATING_MODEL.md | ハーネス運用の neutral 正本（両 adapter が参照） |
| docs/harness/harness_authoring_guide.md | ハーネス文書の書き方規約（サイズ上限・分離原則） |
| docs/harness/scheduled-operations.md | routine 登録カタログ + 定期 workflow を追加する際の設計ガイド |
| docs/adr/README.md | ADR 運用（命名・Status 遷移・INDEX 形式・圧縮運用） |
| docs/adr/INDEX.md | ADR 一覧（Status 別・空） |
| docs/adr/template.md | ADR 本文テンプレート |
| docs/issues/README.md | Issue 単位成果物の運用 + in-place スタブ化アーカイブポリシー |
| docs/issues/templates/task-note.md | Issue 着手時の計画・記録テンプレート |
| docs/requirements/README.md | 要件正本の運用（ID 体系・定型構成・AI 編集対象外） |
| docs/requirements/INDEX.md | 要件一覧（空） |
| docs/product/ARCHITECTURE.md | 内部設計正本の骨格（役割宣言 + 抽象度規約） |
| docs/product/TECH_STACK.md | 技術スタック確定表の骨格 |
| docs/product/TERMS.md | ドメイン用語集の骨格 |
| docs/product/TEST_STRATEGY.md | テスト戦略の骨格（ユーザーストーリー起点のテスト規約を含む） |
| docs/runbooks/INDEX.md | runbook 一覧の骨格（参照再配線チェック付き） |
| docs/notes/README.md | 調査層の運用（確定仕様は要件へ昇格） |
| docs/notes/research/INDEX.md | 調査ノート一覧（空） |
| docs/audit/README.md | 監査レポート置き場の命名規約 |

### styles（core）

| パス | 用途 |
|---|---|
| docs/styles/coding_guide/INDEX.md | コーディング規約の目次 |
| docs/styles/coding_guide/docs.md | docs 編集規約（4 層モデル + 「現状の事実のみ」3 原則） |
| docs/styles/coding_guide/code-comments.md | コードコメント規約（3 原則の適用 + 内部参照禁止） |
| docs/styles/coding_guide/testing_principles.md | テスト記述規約（ユーザーストーリー → 対応テストのみ） |
| docs/styles/refactoring_guide.md | リファクタ運用モデル + 検出観点 |
| docs/styles/team-feedback/INDEX.md | team 共有 rule の一覧 + memory 昇格運用 |
| docs/styles/team-feedback/long-term-automation.md | 長期自動化を優先する判断 rule |
| docs/styles/team-feedback/autonomous-flow.md | 自律実行の既定（open PR まで / 承認必須は課金・秘密値のみ） |
| docs/styles/team-feedback/review-comments.md | レビューコメントの批判的評価 rule |
| docs/styles/team-feedback/scope-boundary.md | スコープ外は Issue 化する rule |
| docs/styles/team-feedback/pr-closing-keyword.md | PR に closing keyword を必須とする rule |
| docs/styles/team-feedback/refactor-before-pr.md | PR 前の簡素化パス rule |

### skill 手順の正本（docs/harness/skills/）

| パス | 用途 | 区分 |
|---|---|---|
| docs/harness/skills/shared/sync-prelude.md | sync 系共通の前段（origin/main 基準・0 件終了） | core |
| docs/harness/skills/shared/sync-pr-flow.md | sync 系共通の後段（ブランチ・open PR ガード・1 スキャン 1 PR） | core |
| docs/harness/skills/shared/gh-query-fail-closed.md | GitHub CLI 照会の fail-closed 規約 | core |
| docs/harness/skills/shared/pr-creation.md | PR 作成共通手順（base 判定・closing keyword） | core |
| docs/harness/skills/shared/verification-gates.md | 検証ゲートコマンド定義の一元管理 | core |
| docs/harness/skills/readme-sync.md | README ↔ 実コードの定期突合 | core |
| docs/harness/skills/docs-sync.md | docs 現状層の鮮度・3 原則の定期検査 | core |
| docs/harness/skills/code-sync.md | ソースコメントの 3 原則・内部参照検査 | core |
| docs/harness/skills/refactor-guide-sync.md | 規約正本 ↔ リファクタガイドの整合 | core |
| docs/harness/skills/gc-scan.md | ハーネス GC（サイズ・重複・孤児。すべて PR で提案） | core |
| docs/harness/skills/adr-compress.md | ADR コーパスの定期圧縮 | core |
| docs/harness/skills/create-adr.md | ADR の構造的記録 | core |
| docs/harness/skills/create-issue.md | Issue 作成（読み戻し検証付き） | core |
| docs/harness/skills/handle-review.md | レビューコメントの批判的評価と自律対応 | core |
| docs/harness/skills/review-cycle.md | LGTM までの自律ポーリング | core |
| docs/harness/skills/multi-issue.md | Planner–Worker 並列実装 | core |
| docs/harness/skills/promote-memory.md | 個人 memory → team rule 昇格 | core |
| docs/harness/skills/security-audit.md | 多次元セキュリティ監査 | core |
| docs/harness/skills/static-check.md | 検証ゲート一括実行・表形式報告 | core |
| docs/harness/skills/deploy-verify.md | デプロイ一気通貫の骨格（手順は bootstrap 時に具体化） | core |
| docs/harness/skills/renovate-sync.md | 依存 pin ↔ Renovate 設定の突合 | opt-in:renovate |
| docs/harness/skills/public-arch-sync.md | 内部正本 → 公開射影の追従 | opt-in:public-site |
| docs/harness/skills/customer-doc-review.md | 対外ドキュメントの多視点レビュー | opt-in:public-site |

### .claude（adapter・rules・hooks・agents）

| パス | 用途 | 区分 |
|---|---|---|
| .claude/skills/&lt;name&gt;/SKILL.md | 上記各 skill の薄い adapter（同名で 1:1） | 正本と同区分 |
| .claude/skills/create-issue/references/project-fields.md | Project ID / ラベル / マイルストーンの profile（TODO 形式） | core |
| .claude/skills/security-audit/references/project-profile.md | 監査対象マップ・脅威モデルの profile（空テンプレ） | core |
| .claude/skills/docs-sync/references/freshness-policy.md | per-file 鮮度検証対象の profile | core |
| .claude/skills/review-cycle/references/notification-mapping.md | レビュアー通知先マッピング（空テンプレ） | core |
| .claude/skills/public-arch-sync/references/projection-rules.md | 射影ルールの profile（章構成のみ） | opt-in:public-site |
| .claude/rules/team-policy.md | 常時ロード rule（pointer 層） | core |
| .claude/rules/harness-development.md | paths: .claude/**・docs/harness/** スコープ rule | core |
| .claude/rules/product-development.md | paths: apps/**・packages/** スコープ rule（skeleton） | core |
| .claude/rules/infra-development.md | paths: infra/** スコープ rule（skeleton、IaC 不採用なら削除） | core |
| .claude/settings.json | hook 配線の正本 | core |
| .claude/hooks/README.md | hook の外部契約 4 点と opt-in 配線手順 | core |
| .claude/hooks/session-start.sh | セッション開始時の環境 bootstrap | core |
| .claude/hooks/pre-format-check.sh | commit 前の staged 限定フォーマット | core |
| .claude/hooks/pre-push-ci-check.sh | push 前の秘密検知 + CI 同等検査 | core |
| .claude/hooks/post-edit-check.sh | 編集ファイルの拡張子別検査 | core |
| .claude/hooks/pre-commit-submodule-guard.sh | submodule pointer 混入の防止 | opt-in:submodule |
| .claude/hooks/post-edit-projection-reminder.sh | 内部正本編集時の公開射影リマインド | opt-in:public-site |
| .claude/bin/hook-utils.sh | hooks 共通ユーティリティ | core |
| .claude/bin/submodule-guard.sh | submodule 初期化ユーティリティ | opt-in:submodule |
| .claude/hooks/tests/run-all.sh | hooks テストの一括実行（CI の test job から呼ぶ） | core |
| .claude/hooks/tests/test-pre-format-check.sh | 同 hook の hermetic テスト | core |
| .claude/hooks/tests/test-pre-push-ci-check.sh | 同 hook の hermetic テスト | core |
| .claude/hooks/tests/test-post-edit-check.sh | 同 hook の hermetic テスト | core |
| .claude/hooks/tests/test-hook-utils.sh | ユーティリティのテスト | core |
| .claude/hooks/tests/test-submodule-guard.sh | 同 opt-in のテスト | opt-in:submodule |
| .claude/agents/gc-agent.md | ハーネス GC（孤児も PR で提案） | core |
| .claude/agents/adr-compactor.md | ADR 圧縮 | core |
| .claude/agents/architecture-sync.md | 変更近傍 README の構造同期 | core |
| .claude/agents/refactorer.md | 夜間リファクタ観点検出（Issue 提案のみ） | core |
| .claude/agents/refactor-guide-sync.md | 規約正本 ↔ ガイド突合 | core |
| .claude/agents/references/refactorer-profile.md | 検出コマンド・必読ガイドの profile | core |
| .claude/agents/references/refactorer-issue-template.md | 提案 Issue のテンプレート | core |
| .claude/agents/references/refactor-guide-sync-detection.md | 突合アルゴリズム詳細 | core |
| .claude/agents/references/refactor-guide-sync-output.md | 出力先判定・PR 形式 | core |

### 公開区画（opt-in:public-site をまとめて採否判断）

| パス | 用途 |
|---|---|
| docs/CUSTOMER_PUBLISH_POLICY.md | 対外公開の判定基準と機械検査の正本 |
| docs/product/PUBLIC_ARCHITECTURE.md | 公開射影ドキュメントの骨格（直接編集禁止ヘッダ付き） |
| docs/customer/README.md | 顧客資料の保管運用（原本 → 要約 → INDEX） |
| docs/customer/summaries/INDEX.md | 要約一覧（空） |
| docs/customer/runbooks/INDEX.md | 顧客向け手順書一覧（空） |

### トレーサビリティ（opt-in:traceability）

| パス | 用途 |
|---|---|
| docs/issues/templates/traceability.md | 要件 ↔ テストのカバレッジレポートテンプレート |

## Self-check（bootstrap 完了前に必ず実施）

- [ ] 明示 token（`{{PRODUCT_NAME}}` `{{GITHUB_ORG}}` `{{REPO_NAME}}` `{{PROJECT_LANGUAGE}}`）が置換されず残っていない。`docs/issues/templates/` と `docs/adr/template.md` の記入欄 `{{...}}` は置換対象外
- [ ] 不採用の opt-in グループの資産がコピーされていない
- [ ] `.claude/skills/*/SKILL.md` と `docs/harness/skills/*.md` が 1:1 対応している
- [ ] hooks の外部契約 4 点が成立している（root scripts 6 本 / mise pin / `apps/*`・`packages/*` レイアウト / 秘密検知ツール設定）
- [ ] `.claude/hooks/tests/run-all.sh` が green
- [ ] routine 登録（`docs/harness/scheduled-operations.md` のカタログ）を完了報告の TODO に含めた

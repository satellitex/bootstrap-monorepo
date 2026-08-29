# CI/CD, Runner, And Deploy Reference

この文書は、`monorepo-bootstrap` が CI 拡張・deploy strategy・runner 運用・repository settings を設計するときの参照（設計根拠と候補リスト）である。
収録済み CI 資産の一覧は書かない（正本台帳は `../assets/MANIFEST.md`）。provider 固有のコマンドも書かず、target repo の `docs/runbooks/` に閉じ込める。

## 1. CI/CD Design Scope

CI/CD は後回しにせず、runtime/provider selection と同じタイミングで比較する。
決定は `decision-matrix.md` と `bootstrap-plan.md` に残し、PR で提示する（承認 gate ではない）。

| Area | Required decision |
|------|-------------------|
| CI provider | GitHub Actions, GitLab CI, Buildkite, provider-native CI, or other |
| Required checks | 基礎 CI に何を足すか（§2 の拡張候補から選ぶ） |
| Deployment trigger | branch deploy, PR preview, manual promotion, release tag |
| Environments | local, preview, dev (main), prod (release), ephemeral review apps |
| Secrets | where secrets live, who can modify them, how `.env.example` stays current |
| Artifacts | build outputs, test reports, coverage, deploy URLs, smoke logs |
| Rollback | previous release, branch revert, provider rollback, migration rollback/forward |
| Runner model | hosted runner, self-hosted runner, larger runner, provider-native build worker |

## 2. CI Quality Gates

### 2.1 既定

CI は基礎 CI 1 本のみを既定とする。

| Job | 内容 |
|-----|------|
| format | `format:check` |
| test | `test` + hooks の bash テスト |
| build | `build` |

設計意図:

- CI job を増やすほど、原因切り分けと待ち時間が伸びる。agent が merge 可能性を判断できる最小集合から始める。
- 秘密検知は CI ではなく pre-push hook が担う。push 前に止めるほうが、漏洩後の revert より安い。
- lint / typecheck は package scripts と post-edit hook 側で走る。CI 追加は重複の価値が説明できる場合に限る。
- 検証ゲートのコマンド定義は 1 箇所（`docs/harness/skills/shared/verification-gates.md`）に置き、CI・hooks・skill が同じ定義を参照する。

### 2.2 拡張候補

以下は既定に含めない。product に必要なものだけ選び、採否と理由を `bootstrap-plan.md` に残す。

1. YAML parse / workflow lint
2. install/cache 最適化
3. base branch diff check（§3）
4. lint（CI 側でも二重に走らせる場合）
5. typecheck（同上）
6. integration / contract / migration / schema test
7. docs gate（層ルール、internal reference、link check）
8. secret scan（hook を持たない contributor 経路がある場合）
9. dependency / license scan
10. e2e test
11. preview または staging deploy
12. smoke test
13. 公開 docs の build と公開射影チェック（opt-in:public-site）

注意点:

- workflow lint が未導入なら、未実行であることと理由を報告する。
- 差分実行を使う場合でも、main branch または定期 CI では全量検証を残す。
- CI は agent が local で使う検査と同じものを走らせる。ずれると local green / CI red が常態化する。
- 既知の許容失敗には issue、担当、失効条件を必ず付ける。

### 2.3 定期実行 workflow

定期実行 workflow は既定では収録しない。追加する場合は bootstrap 先の `docs/harness/scheduled-operations.md` にある設計ガイド（marker Issue の upsert、preflight tripwire、手動 dispatch の branch 限定、状態を表す exit code の設計、送信先を variable で補間しない）に従う。

## 3. Base Branch Diff

差分ベースの check は、比較に必要な remote ref を消さずに base branch を fetch する。

- workflow が必要とする base ref を正確に fetch する
- diff 計算前に remote ref を消しうる prune 操作を避ける
- base SHA と head SHA をログに出す
- base ref が見つからないときは明確に fail する
- CI provider の pull request metadata が使えるならそれを使う

## 4. Repository Settings Checklist

`bootstrap-plan.md` と repo settings runbook に残す。
repo settings の変更は自律実行してよい（人間承認が必要なのは課金が発生する操作と秘密値の挿入・変更のみ）。変更内容と理由は成果物に残す。

| Setting | Decision |
|---------|----------|
| default merge strategy | merge commit, squash, rebase, or restricted combination |
| squash merge policy | title/body source, commit message convention |
| auto-delete merged branches | enabled/disabled and exceptions |
| branch protection | protected branches, bypass rules, required reviews |
| required checks | exact check names and environments |
| environments | dev (main) / prod (release) の保護設定と reviewer |
| status checks for docs/security | 拡張として採用した check のみ |

## 5. Self-Hosted Runner Operations

self-hosted runner は制約が正当化する場合にのみ使う。使う場合、runner 運用は bootstrap 設計の一部になる。

必須の runbook 項目:

| Topic | Requirement |
|-------|-------------|
| Process management | foreground の常駐スクリプト常用ではなく service manager 経由の常駐を既定にする |
| Runner user | service user と、必要な CLI login / keychain / credentials / cache / workspace 権限を持つ user を一致させる |
| CLI versions | workflow option を使う前に、runner 実機の CLI version と `--help` を確認する |
| Credentials | secret 値を commit せずに login / credential 設定手順を残す |
| Workspace cleanup | cache / workspace の掃除と disk 逼迫時の方針を決める |
| Base branch fetch | diff check に必要な ref を prune しない fetch 戦略にする |
| Logs | log path または service log コマンドを残す |
| Status | status 確認コマンドと healthy 状態の定義を残す |
| Restart | restart と復旧手順を残す |
| Upgrades | runner binary と CLI の upgrade 手順を残す |
| Security | token scope、network access、filesystem access、secret 露出範囲を残す |

service-runner に interactive shell の状態があると仮定しない。workflow は runner の実際の non-interactive environment で検証する。

## 6. Deployment Strategy

### 6.1 既定のブランチモデル

既定は main = dev 環境 / release = prod 環境とする。

| Branch | Environment | 運用 |
|--------|-------------|------|
| `main` | dev | 壊れても復旧可能な開発環境。CI と build が通れば自律 deploy してよい。開発過程ではセキュリティより柔軟性を優先する |
| `release` | prod | prod リリース手順を踏んでから反映する |

prod リリース手順:

1. main の安全性確認（CI green、smoke、既知の未解決リスクの確認）
2. release への反映手順の確認（反映範囲、migration、rollback 経路、切り戻し条件）

課金が発生する操作と秘密値の挿入・変更のみ、人間の明示承認を得てから行う。これ以外の deploy 操作は自律実行してよい。

### 6.2 戦略の選択

採用した戦略を `decision-matrix.md`、`bootstrap-plan.md`、deploy runbook に残す。

| Strategy | What to document |
|----------|------------------|
| Branch-based deploy（既定） | main/release と環境の対応、保護設定、昇格ルール |
| PR preview | trigger, URL discovery, data isolation, auth, teardown |
| Environment promotion | artifact promotion, smoke tests, rollback |
| Release tag deploy | versioning, changelog, rollback, hotfix |
| Manual deploy | 実行者、コマンド、監査ログ |

## 7. Deploy Runbook Checklist

`docs/runbooks/` に deploy 手順を作り、`docs/runbooks/INDEX.md` に登録する。

必須セクション:

- 環境と branch/tag の対応（既定は main = dev / release = prod）
- provider bindings と必要な権限
- environment variables と secret 名（値は書かない）
- build / deploy コマンド
- smoke test コマンドと期待出力
- rollback 手順
- migration 手順と安全性の注意
- observability リンクと alert の経路
- 既知の limits と cost
- prod リリース手順（main の安全性確認 → release への反映手順の確認）
- 課金操作・秘密値投入が必要な箇所と、その承認の取り方

## 8. Smoke Tests

smoke test は local build の成功ではなく、deploy 済み artifact を検証する。

| Surface | Smoke check |
|---------|-------------|
| Web UI | page loads, key route renders, critical asset と API call が成功する |
| API | health endpoint, auth boundary, 安全なら read/write を 1 本 |
| Worker/job | 安全な job を enqueue/run し、retry/log を確認する |
| Workflow | 短い workflow を開始し、status と完了を確認する |
| DB migration | migration status と read-only な schema check |
| 公開 docs（opt-in:public-site） | docs が build でき、公開ページに内部参照が無い |

deploy URL、commit SHA、environment、timestamp、結果を `implementation-report.md` に記録する。

## 9. Provider-Specific References

provider 固有の知識が要る場合は、target repo の runbook に narrow なファイルとして足す。

```text
docs/runbooks/providers/<provider>.md
```

provider reference には CLI コマンドや binding 構文を書いてよいが、その provider を template の既定として前提化しない。
`docs/runbooks/INDEX.md` に登録し、参照が切れていないかを README/docs の鮮度維持 skill の対象に含める。

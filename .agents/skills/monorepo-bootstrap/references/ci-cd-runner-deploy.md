# CI/CD, Runner, And Deploy Reference

この文書は、`monorepo-bootstrap` が CI 拡張・deploy strategy・runner 運用・repository settings を設計するときの参照（設計根拠と候補リスト）である。
収録済み CI 資産の一覧は書かない（正本台帳は `../assets/MANIFEST.md`）。provider 固有のコマンドも書かず、target repo の `docs/runbooks/` に閉じ込める。

## 1. CI/CD Design Scope

CI/CD は後回しにせず、runtime/provider selection と同じタイミングで比較する。
決定は ADR（1 領域 1 ADR。代替案と棄却理由を含む）と PR 本文の標準節（方針と却下案など）に残し、PR で提示する（承認 gate ではない）。

| Area | Required decision |
|------|-------------------|
| CI provider | 基礎 CI は GitHub Actions（`../assets/.github/workflows/ci.yml`）を既定とする。deploy を担う CI/CD は GitHub Actions, GitLab CI, Buildkite, provider-native CI などから比較する（→ `../SKILL.md`「Provider / Runtime Neutrality」） |
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
| test | `test` + hooks の bash テスト + ハーネス機械検査（`pnpm harness:test`） |
| build | `build` |

設計意図:

- CI job を増やすほど、原因切り分けと待ち時間が伸びる。agent が merge 可能性を判断できる最小集合から始める。
- hook と CI の分担は `../assets/docs/harness/skills/shared/verification-gates.md`「ゲートごとの実行先」が正本であり、他の文書へ複製しない。CI への追加は、重複の価値が説明できる場合に限る。
- 検証ゲートのコマンド定義は 1 箇所（`docs/harness/skills/shared/verification-gates.md`）に置き、CI・hooks・skill が同じ定義を参照する。

### 2.2 拡張候補

以下は既定に含めない。product に必要なものだけ選び、採否と理由を PR 本文の「方針と却下案」に残す。

1. YAML parse / workflow lint
2. install/cache 最適化
3. base branch diff check（§3）
4. lint（採用すると hook と二重になる。採用しない場合、CI では担保されない）
5. typecheck（同上）
6. integration / contract / migration / schema test
7. docs gate（層ルール、internal reference、link check）
8. secret scan（hook を持たない contributor 経路がある場合。採用しない場合、hook を経由しない push では担保されない）
9. dependency / license scan
10. e2e test
11. preview または staging deploy
12. smoke test
13. 公開 docs の build と公開射影チェック（opt-in:public-site）
14. モジュール依存の循環検査（§2.7。baseline ratchet を併用する）

注意点:

- workflow lint が未導入なら、未実行であることと理由を報告する。
- 差分実行を使う場合でも、main branch または定期 CI では全量検証を残す。
- local と CI の検査の差は、検証ゲートの名前付き組合せに明記する。差が説明できないまま増えると、local green / CI red が常態化する。
- 既知の許容失敗には issue、担当、失効条件を必ず付ける。既存違反を記録して純増だけを止める仕組みは §2.4 に従う。

### 2.3 定期実行 workflow

定期実行 workflow は既定では収録しない。追加する場合は bootstrap 先の `docs/harness/scheduled-operations.md` にある設計ガイド（追加を検討してよい条件、routine との使い分け、marker Issue の upsert と判定不能の扱い、preflight tripwire、secret の到達境界、状態を表す exit code の設計、cron の時刻）に従う。

追加を検討する場面の例:

- 時間経過でのみ顕在化する回帰に備えて、基礎 CI（`test` / `build`）を既定ブランチに対して定期に再実行する。固定日付で組んだテストが実時刻との比較で窓から外れる場合など、変更を契機にする CI では検出できない失敗を拾える。
- PR ゲート（変更範囲のみ）と定期バックストップ（全量・全履歴）を対にする。§2.2 の「差分実行でも main か定期 CI では全量検証を残す」の具体形である。秘密検知（PR ゲートは PR が導入した commit のみ、定期は全履歴）と依存の既知脆弱性の検査が典型で、後者は依存を変えない期間に新しく公開される情報も拾える。
- 監査系 CLI の終了コードが「検出あり」と「実行不能」を同じ値で返す場合は、両者を区別するラッパー script（0 / 1 / 2）を経由する。実行不能を「検出ゼロ」と読むと検知が無効のまま緑になる。CLI の終了コードの仕様は版により変わるため、導入時に一次情報で確認する。

### 2.4 既存違反の baseline ratchet

既存違反が多い状態で新しい検査を導入する場合と、構造変更で一時的に違反が出る場合に、検査を無効にせず、既存の違反件数を baseline に記録して純増だけを fail させる。新規の流入を止めながら、削減を段階化できる。§2.2 の「既知の許容失敗には issue、担当、失効条件を付ける」を機構にしたものである。

適用しない検査: 秘密検知と既知脆弱性。個別に解消するか、値ベースで許容するかを判断する検査であり、件数で許容しない（秘密検知は `.gitleaks.toml` の値ベース allowlist に従う）。

| 項目 | 規約 | 理由 |
|------|------|------|
| baseline の置き場 | gate ごとのデータファイル（例 `scripts/baselines/<gate-id>.json`。置き場は差し替え可）。検査 script の定数にしない | PR と base ブランチの baseline を機械的に比較できるようにするため |
| baseline の項目 | 件数型は `total`、識別型は `entries[]`。共通で `recordedAt` と `tracking`（削減を追う Issue 等の参照）。経緯の追記欄は持たず、履歴は git log に任せる | 項目を最小にし、経緯の記述は履歴と重複させない。Issue 番号は散文に置くと陳腐化するため、構造化した項目にだけ置く |
| 判定 | 現状の違反が baseline を超えたら fail（純増のみ fail）。減った分を同一 PR で baseline へ反映させるか、定期の引き下げ PR に任せるかは gate ごとに選び、gate の docs に書く | 同一 PR での反映を強制すると、並行する PR が baseline ファイルで衝突する |
| baseline の引き上げ | PR では行わない。CI が base の baseline と PR の baseline を比較し、増えていれば fail にする。構造変更で意図して引き上げる場合の免除の手段は gate ごとに定め、理由と追跡先を PR 本文に残す | 引き上げを許すと、ratchet が機能しなくなる |
| 件数型と識別型の選択 | 件数型は総数が変わらない入れ替えを許す。識別型はリネームで偽の新規が出る。どちらを選んだかと理由を gate の docs に残す | 誤検知と見逃しの出方が異なる |
| stale の扱い（識別型） | baseline にあって実在しなくなった entry を stale として検出し、除去を要求するかを gate ごとに選んで、gate の docs に書く | 解消済みの entry が残ると、同じ違反の再発が許容されているように見える |
| 失効 | baseline が 0 に到達したら、baseline ファイルと ratchet の分岐を削除して通常の gate にする | 不要になった ratchet の分岐が残ると、読み手が許容の仕組みが生きていると誤解する |

### 2.5 required check の集約

基礎 CI は無条件の 3 job で、skip されないため、required は job 名で直接指定できる。拡張 job が次のいずれかを持つ場合に、required を静的名の単一の集約 job に一本化する。

- matrix の動的な job 名を使う。skip されると、個別名の check が報告されないまま待ち続け、merge を恒久的にブロックする
- workflow 全体が paths / branches の条件で起動しない。同じく required の check が報告されない

job レベルの条件で skip された静的名の job は skipped として扱われ、merge を妨げない。この場合に残る穴は、変更検出 job の失敗で下流の job が誤って skip され、緑に見えることである。

規約は CI provider に依存しない。GitHub Actions では `if: ${{ always() }}` と `needs` で書ける。

1. 集約 job は静的な名前で、条件に関わらず必ず結果を報告する
2. 集約 job の `needs` が、blocking な job の集合を宣言する唯一の場所になる。blocking にしない観測用の job は `needs` に入れず、workflow のコメントに理由を書く
3. 変更検出 job を持つ構成では、変更検出 job が success でなければ集約 job も fail にする。本来走るべき job の誤 skip を緑にしないため
4. 各 job は success と skipped だけを許容し、failure と cancelled は fail にする
5. job を追加するときに分類（blocking / 観測 / 条件付き）を決めさせるため、workflow の job 一覧が既知の集合と一致することを確かめるテストを置いてよい（任意）

基礎 CI の既定（無条件の 3 job）は変えない。

### 2.6 ゲートの実効性

ゲートがあることと、ゲートが効いていることは別である。常時 green のゲートは、違反を見逃していても誰も気付かない。導入時と変更時に次を確認する。

- **前提不足は fail-loud にする**: 比較元の ref が無い、shallow clone で履歴が足りない、資格情報が無い、といった前提不足のとき、警告だけ出して return するスクリプト・テストを作らない。明確な失敗メッセージで fail させる（§3 の base ref 不在と同じ扱い）。警告で終わると、前提が崩れた時点からゲートが常時 green になる。
- **導入時に違反を注入して確認する**: ゲートを入れる PR で、違反を 1 件入れた状態でゲートが fail することを一度確かめ、違反を戻す。確認結果を PR 本文に残す。fail することを確かめていないゲートは、何も検査していない可能性を排除できない。
- **path filter の盲点を塞ぐ**: 必須 check の job が path filter で skip される構成では、変更が無い間の回帰を検出できない。この構成を採る場合は、既定ブランチへの全量検証を定期実行（routine、または `docs/harness/scheduled-operations.md` の設計ガイドに従う定期 workflow）で担保する。既定の CI は path filter を持たないため、差分実行を導入するときの注意点である。

### 2.7 レシピ: モジュール依存の循環検査

循環依存は初期化順やビルド順の不具合源になる。依存グラフの解析は言語と stack に依存するため既定にせず、採用時に bootstrap 先で stack に合う script を生成する。既存の循環が多い repo でも導入できるよう、§2.4 の識別型 ratchet を併用する。

| 項目 | 内容 |
|------|------|
| 入力 | 検査対象のソースルートの一覧（設定値。script に直書きしない） |
| 出力 | 検出した循環の正規化キーの集合（例 `a.ts > b.ts > a.ts`）。循環を構成するファイルを辞書順に並べ、回転や向きに依存しないキーにする。解析ツールの出力は循環の起点が環境で揺れうるため |
| 判定 | baseline に無い循環があれば fail。baseline にあって解消された entry は stale として扱う（§2.4） |
| 接続 | 検査 script を root `package.json` の `lint`（または独立した script）に連結する。`lint` は hook では実行されるが CI では実行されないため、CI で担保するなら §2.2 の 4 として足す |
| 差し替え点 | 依存グラフの解析ツール（`<analyzer>`。TS/JS 以外は各言語の解析器）。既定にしない |

キー化と差分判定は純関数に分け、単体テストを持つ。単体テストの無い検査は、解析ツールの出力が変わった時点で見逃しや偽の新規を出しても気付けない。

## 3. Base Branch Diff

差分ベースの check は、比較に必要な remote ref を消さずに base branch を fetch する。

- workflow が必要とする base ref を正確に fetch する
- diff 計算前に remote ref を消しうる prune 操作を避ける
- base SHA と head SHA をログに出す
- base ref が見つからないときは明確に fail する
- CI provider の pull request metadata が使えるならそれを使う

## 4. Repository Settings Checklist

下表の決定は、PR 本文の計画節と repo settings runbook に残す。
repo settings の変更は自律実行してよい（承認の定義 → `../assets/docs/harness/OPERATING_MODEL.md`「承認モデル」）。変更内容と理由は成果物に残す。

| Setting | Decision |
|---------|----------|
| default merge strategy | merge commit, squash, rebase, or restricted combination。release 反映 PR は merge commit でマージする（→ §6.1） |
| squash merge policy | title/body source, commit message convention |
| auto-delete merged branches | enabled/disabled and exceptions |
| branch protection | protected branches, bypass rules, required reviews |
| required checks | exact check names and environments |
| environments | dev (main) / prod (release) の保護設定。prod の deploy job に required reviewers を置かない（prod 反映の承認は release 反映 PR のマージ 1 か所 → `../assets/docs/harness/skills/deploy-verify.md`「承認モデルの適用」） |
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

ブランチモデルの定義は `../assets/docs/harness/OPERATING_MODEL.md`「承認モデル」が正本である。deploy の設計では、次の対応を環境に落とす。

| Branch | Environment | 運用 |
|--------|-------------|------|
| `main` | dev | CI と build が通れば自律 deploy してよい |
| `release` | prod | prod リリース手順を踏んでから反映する |

prod リリース手順は、main の安全性確認 → release への反映手順の確認の 2 段で踏む。具体（R1〜R6。merge commit 限定、承認は release 宛て PR のマージ 1 か所）は `../assets/docs/harness/skills/deploy-verify.md`「release 反映（prod）」が正本であり、ここには複製しない。smoke・既知の未解決リスクの確認を要件にする PJ は、R2 の PJ 固有ゲートに記入する。

### 6.2 戦略の選択

採用した戦略を ADR（代替案と棄却理由を含む）と deploy runbook に残す。

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

- 環境と branch/tag の対応（既定 → §6.1）
- provider bindings と必要な権限
- environment variables と secret 名（値は書かない）
- build / deploy コマンド
- smoke test コマンドと期待出力
- rollback 手順
- migration 手順と安全性の注意
- observability リンクと alert の経路
- 既知の limits と cost
- prod リリース手順（§6.1）
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

deploy URL、commit SHA、environment、timestamp、結果を PR 本文の検証結果に記録する。

## 9. Provider-Specific References

provider 固有の知識が要る場合は、target repo の runbook に narrow なファイルとして足す。

```text
docs/runbooks/providers/<provider>.md
```

provider reference には CLI コマンドや binding 構文を書いてよいが、その provider を template の既定として前提化しない。
`docs/runbooks/INDEX.md` に登録し、参照が切れていないかを README/docs の鮮度維持 skill の対象に含める。

# 定期運用（routine カタログと定期 workflow 設計ガイド）

この文書は定期運用の正本である。前半に routine 登録カタログと事前作成が必要な外部リソースを、後半に定期 GitHub Actions workflow を将来追加する場合の設計ガイドを定める。各 skill の手順本文は `docs/harness/skills/` に置き、ここには書かない。

**既定構成では GitHub Actions は基礎 CI（`.github/workflows/ci.yml`: format:check / test / build）1 本のみで、schedule トリガーの定期 workflow を持たない。** 定期実行はエージェント routine（repo 外の scheduler から slash コマンド / agent を起動する方式）で行う。

## routine 登録カタログ

| 頻度 | エントリポイント | 目的 |
| --- | --- | --- |
| 週次 | `/readme-sync` | README と実コードの乖離を検出し修正 PR |
| 週次 | `/docs-sync` | docs「現状層」の鮮度ドリフト・原則違反を検出し修正 PR |
| 週次 | `/code-sync` | ソースコメントの 3 原則違反・内部参照を検出し修正 PR |
| 週次（opt-in:renovate 採用時のみ） | `/renovate-sync` | 依存 pin と Renovate 設定の検知漏れを検出し改善 PR |
| 隔週 | `/gc-scan` | ハーネスのサイズ超過・重複・孤児を検出し修正 PR |
| 隔週 | `/adr-compress` | ADR コーパスの肥大化を圧縮する PR |
| 隔週 | `/refactor-guide-sync` | 規約正本とリファクタガイドの検出基準を突合する PR |
| 夜間 | refactorer agent（`.claude/agents/refactorer.md`） | リファクタ観点を検出し提案 Issue を起票（コードは変更しない） |

運用上の前提:

- **cron 登録は repo 外で人間が行う**（エージェント実行環境の scheduler 機能、または任意の外部 cron）。repo 内にはエントリポイントと手順正本だけを置く。bootstrap の完了報告には「routine 登録が未実施」を TODO として必ず含める。
- 同一 skill の tick 重複は各 skill 側の open PR ガード（`docs/harness/skills/shared/sync-pr-flow.md`）が防ぐ。scheduler 側での排他は不要。
- routine が作る PR / Issue はすべて `agent/<skill-name>-YYYY-MM-DD` ブランチと既定ラベルの規約に従う（→ `docs/harness/OPERATING_MODEL.md`）。

## 事前作成が必要な外部リソース

routine と skill 群が前提とする外部リソース。bootstrap 時に作成し、未作成分は完了報告に TODO として残す。

- [ ] ラベル `harness:harness` — TODO(取得方法: `gh label create "harness:harness"` を実行。ハーネス系 PR / Issue の分類に使用)
- [ ] ラベル `refactor:proposal` — TODO(取得方法: `gh label create "refactor:proposal"` を実行。refactorer agent の提案 Issue に使用)
- [ ] ラベル `refactor:approved` — TODO(取得方法: `gh label create "refactor:approved"` を実行。リファクタ提案 Issue への着手指示に使用)
- [ ] ラベル `LGTM` — TODO(取得方法: `gh label create "LGTM"` を実行。`/review-cycle` の完了判定に使用)
- [ ] GitHub Project — TODO(取得方法: org / repo の Project を作成し、Project ID とフィールド ID を `gh project list` / `gh project field-list` で取得して `.claude/skills/create-issue/references/project-fields.md` に記入)
- [ ] 通知 webhook — TODO(取得方法: チャットツール側で webhook を発行し、`/review-cycle` の通知先を `.claude/skills/review-cycle/references/notification-mapping.md` に記入。webhook URL は秘密値のため人間が投入する)

## 定期 GitHub Actions workflow を追加する場合の設計ガイド

既定では定期 workflow を持たない。追加を検討するのは「エージェント routine では担えない、インフラ・外部サービスに対する常時検査」が必要になった場合のみとする。追加する場合は以下 (a)〜(f) を満たすこと。

前提の理解: `on.schedule`（cron）トリガーの workflow は CI gate と違って**失敗しても PR をブロックしない**。通知経路が無いと「動いているように見えて実際は落ち続けている」状態を誰も検知できない。以下はその穴を塞ぐための必須設計である。

### (a) 失敗を人に届ける経路を同一 PR で必須化する

schedule workflow を追加する PR には、失敗検知経路（marker Issue の upsert / auto-close）を必ず同梱する。標準実装（`actions/github-script` inline パターン）:

1. 失敗を検出する job（または該当 step）に `permissions: issues: write` を付与する
2. 一意な marker コメント（例 `<!-- <workflow>-marker -->`）を body に埋め込んだ open Issue を `github.paginate(github.rest.issues.listForRepo, ...)` + `body.includes(marker)` で検索する
3. 検出・失敗があれば既存 Issue を `update`（無ければ `create`）、解消していれば既存 Issue を `state: 'closed', state_reason: 'completed'` で close する

失敗判定の実装は 3 方式から、workflow の失敗シグナルの形に合わせて選ぶ:

- **JSON report 件数駆動** — 構造化 report（検知件数）を生成できる検査向け
- **job.status 駆動の単一 `if: always()` step** — 構造化 report を持たず job / step の成否そのものがシグナルの場合
- **step outcome 駆動 + job.status fallback のハイブリッド** — 本体 step の outcome（success / failure）が取れるときはその詳細で Issue 化し、本体 step より前の setup step（checkout / 依存インストール等）が失敗して本体 step が `skipped` になったときは `job.status === 'failure'` で拾って汎用 body の Issue にする

教訓（実際に踏んだ穴）: step outcome だけを見て success / failure 以外を「想定外」として無視すると、setup 失敗が `skipped` 経由で無言になり、job は赤なのに誰にも届かない。**本体 step の outcome に加えて必ず `job.status` も判定材料に含める。**

### (b) preflight tripwire（schedule は fail-loud / dispatch は graceful skip）

必須 repo variable / secret が揃っているかを最初の step で判定し、未設定時の挙動を trigger で分ける:

- **schedule: fail する（fail-loud）**。schedule 専用 workflow は PR をブロックしないため green を保つ動機が無い。何もせず success を返すと「検査が動いている」ように見えて検知漏れを隠す。repo variable は org 移管等で引き継がれないことがあるため、この fail は設定消失の tripwire も兼ねる。
- **workflow_dispatch: graceful skip（success）**。setup 途中の operator が疎通確認で赤を踏まないようにする。skip した事実と投入手順は `$GITHUB_STEP_SUMMARY` に明記する。

前提リソースが段階整備中で「未設定が正常」の期間に限り schedule 側も graceful skip を許すが、その場合も skip 理由を summary に出力し、整備完了後に fail-loud へ戻す。

### (c) workflow_dispatch は main ref に限定する

secret を step env に展開する workflow は、任意 branch からの dispatch を許すと、branch 上で script を改変するだけで secret を持ち出せる。次の guard を付ける:

```yaml
if: github.event_name == 'schedule' || (github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main')
```

schedule は常に default branch の定義で走るため制限不要。この guard は dispatch 側にのみ効く。

### (d) 検知不能と検知ゼロを区別する exit code 3 状態設計

判定ロジックは workflow YAML のレシピ行に埋め込まず、リポジトリ内の script ファイルとして置く（YAML 埋め込みは読めず手実行もできない）。script の終了コードは 3 状態にする:

- `0` = 検知ゼロ（検査は完了し、問題なし）
- `1` = 検知あり（実害。通知と job 失敗の両方を行う）
- `2` = 検査未完了（API エラー等で「問題が無いか不明」）

`1` と `2` を混同しない: `2` では「検知あり」の通知を送らない（問題でないものを問題として通知しない）。`0` と `2` を混同しない: `2` を success にすると「検知が無効なのに green」になる。`1` でも `2` でも job は失敗させ、メッセージだけを分ける（前者は実害、後者は検知の無効化で、どちらも放置してはならない）。

### (e) secret と同居する送信先を repo variable で補間しない

通知 step が同一リクエストのヘッダー等に API key を載せる場合、送信先 host / URL を repo variable から補間してはならない。write 権限を持つコラボレータが variable を攻撃者管理ドメインへ書き換えるだけで、定期実行が API key をそこへ送り続ける exfiltration 経路になる。送信先は workflow ファイル内の定数として固定し、変更は必ずレビューを通る PR で行う。あわせて secret は job-level env に置かず、必要な step のみの step-level env に限定する。

### (f) 追加時チェックリスト

- [ ] 失敗を人に届ける経路（marker Issue upsert / auto-close）を同一 PR に同梱した
- [ ] 失敗判定方式（JSON report 件数 / job.status / ハイブリッド）を選定し、setup 失敗が無言にならないことを確認した
- [ ] preflight tripwire を実装した（schedule は fail-loud / workflow_dispatch は graceful skip）
- [ ] secret を扱う場合、workflow_dispatch を main ref に限定した
- [ ] 検査 script は exit code 3 状態設計（0 / 1 / 2）に従い、検知不能を検知ゼロとして扱っていない
- [ ] secret と同居する送信先を repo variable で補間していない（定数固定 + step-level env）
- [ ] `permissions` は job ごとの最小権限にした
- [ ] 下表「schedule workflow 一覧」に追記した（削除時も同様に更新する）

### schedule workflow 一覧

schedule トリガーを持つ workflow と失敗検知方式を登録する。初期状態では存在しない。

| workflow | 失敗検知方式 |
| --- | --- |
| （なし） | — |

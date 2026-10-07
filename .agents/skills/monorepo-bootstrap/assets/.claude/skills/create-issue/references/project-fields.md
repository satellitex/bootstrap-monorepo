# GitHub Project フィールド定数（プロジェクト profile）

この文書は `/create-issue` が使う magic value（Project ID・フィールド ID・ラベル体系・マイルストーン）を集約するプロジェクト固有 profile である。Issue 作成の手順・判断基準は書かない（正本は `docs/harness/skills/create-issue.md`）。

> 未記入の値は `TODO(取得方法: ...)`（環境から取得する値）と
> `TODO(記入方法: ...)`（チームが決める内容）の 2 形式で置き、取得する値は bootstrap 時に**実環境で照会して得た値のみ**を埋める。推測値・他リポジトリからの転記値を書かない。
> 値を埋めた行からは `TODO(...)` を外す。

## リポジトリ

owner は git remote から解決する。`<owner>/<repo>` を直書きしない（理由と解決方法 →
`docs/harness/skills/shared/gh-query-fail-closed.md` 規約 4）。

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

## プロジェクト（Projects V2）

| Project      | ID                                               | 対象                                         |
| ------------ | ------------------------------------------------ | -------------------------------------------- |
| プロダクト用 | TODO(取得方法: 下記 GraphQL 照会の `nodes[].id`) | プロダクト本体の実装タスク                   |
| ハーネス用   | TODO(取得方法: 同上)                             | エージェント・CI・skill 等ハーネス自体の実装 |

> Project を 1 つで運用する PJ は行を 1 つに減らし、下の振り分けルールも「単一 Project」に書き換える。

```bash
# Project ID / number / title の一覧（<project-owner-org> は Project を所有する org。リポジトリの owner とは限らない）
gh api graphql -f login='<project-owner-org>' -f query='
  query($login: String!) {
    organization(login: $login) { projectsV2(first: 20) { nodes { id number title } } }
  }'
# 個人所有の Project は organization を user に置き換える
```

> **Project ID / フィールド ID は Project を所有する org / user に紐付く**（node ID に owner ID が埋まる）。
> Projects V2 は org / user の所有物でリポジトリには属さないため、リポジトリの owner が変わっても
> これらの ID は変わらず、書き換えてはいけない。ID 文字列に owner 名が現れないため、owner 名の grep では
> 追随の要否を判定できない（→ `docs/harness/skills/shared/gh-query-fail-closed.md` 規約 4 の例外）。

### Issue と Project の読み戻し経路

Project の所有者がリポジトリの owner と異なる構成では、Issue 側から引く `projectItems` が空配列になり得る
（Project に追加済みでも「未追加」と区別できない）。Project 側の属性は、追加時に控えた item の node ID から引く。
空配列を「未追加」と判定しない。

| 読みたい属性                          | 経路                                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------------------------------- |
| milestone / labels / assignees / body | `gh issue view <番号> --json number,milestone,labels,assignees,body`                              |
| Project・Status・Expired date         | 追加時に控えた item node ID を `node(id:)` で引く（`docs/harness/skills/create-issue.md` Step 7） |
| ブロック元 Issue の Expired date      | ブロック元の所属 Project の `items` をページ送りし `content.number` で突合する（同 Step 1）       |

### 振り分けルール

- `harness:harness` ラベルを持つ Issue → **ハーネス用 Project**
- それ以外 → **プロダクト用 Project**

## フィールド ID

Project ごとに取得する。`Status`（単一選択）は必須、`Expired date`（日付）は期限運用を採用する場合のみ。

| Project      | フィールド   | ID                                                                                      |
| ------------ | ------------ | --------------------------------------------------------------------------------------- |
| プロダクト用 | Status       | TODO(取得方法: 下記 GraphQL 照会の `fields.nodes[] \| select(.name=="Status") \| .id`)  |
| プロダクト用 | Expired date | TODO(取得方法: 同上。`.name=="Expired date"`。期限フィールドを作らない PJ は本行を削除) |
| ハーネス用   | Status       | TODO(取得方法: 同上。`<PROJECT_ID>` をハーネス用に差し替えて実行)                       |
| ハーネス用   | Expired date | TODO(取得方法: 同上)                                                                    |

```bash
# フィールド ID と単一選択オプション ID の一覧
gh api graphql -f project='<PROJECT_ID>' -f query='
  query($project: ID!) {
    node(id: $project) {
      ... on ProjectV2 {
        fields(first: 50) {
          nodes {
            ... on ProjectV2FieldCommon { id name dataType }
            ... on ProjectV2SingleSelectField { id name options { id name } }
          }
        }
      }
    }
  }'
```

### Status オプション ID

| Status      | Option ID                                                                                         |
| ----------- | ------------------------------------------------------------------------------------------------- |
| Todo        | TODO(取得方法: 上記照会の `ProjectV2SingleSelectField.options[] \| select(.name=="Todo") \| .id`) |
| In Progress | TODO(取得方法: 同上)                                                                              |
| Done        | TODO(取得方法: 同上)                                                                              |

> Project ごとにフィールド ID は異なるが、**オプション ID も Project ごとに異なる**。複数 Project を
> 運用する場合は Project ごとに表を分ける。

## ラベル体系

実在するラベルのみを指定する（存在しないラベル名を `gh issue create --label` に渡すと非ゼロ終了する）。

```bash
gh label list --limit 200 --json name,description --jq '.[] | "\(.name)\t\(.description)"'
```

### ハーネス種別ラベル（1 Issue に 1 つ）

| ラベル                 | 用途                                                                  |
| ---------------------- | --------------------------------------------------------------------- |
| `harness:feature-flow` | プロダクト機能の新規実装・仕様変更（`/multi-issue` で実装する）       |
| `harness:infra`        | provider 設定・環境・deploy・migration・storage・queue・observability |
| `harness:harness`      | ハーネス自体の設計・構築（CI・agent 定義・skill 定義など）            |
| `harness:docs-only`    | ドキュメント・ADR・runbook のみの変更                                 |
| `harness:research`     | 調査・技術検証のみ                                                    |

TODO(取得方法: `gh label list` で上記 5 ラベルの実在を確認し、未作成なら
`gh label create <name> --description "<用途>"` で作成する。名称を変える場合は本表を同時に更新する)

### 種別ラベル

`enhancement` / `bug` / `documentation`（GitHub 既定ラベル。実在確認のみ）

### コンポーネントラベル

TODO(記入方法: monorepo の実レイアウト（`apps/*` / `packages/*` / `infra/*`）が確定してから、
1 ワークスペース = 1 ラベルを原則に `component:<workspace>` を定義する。横断は `component:shared`、
インフラ・CI/CD は `component:infra`。定義後は下表に「ラベル | 対象パス」で列挙する)

| ラベル             | 対象                 |
| ------------------ | -------------------- |
| `component:shared` | 全コンポーネント横断 |
| `component:infra`  | インフラ・CI/CD      |

### 優先度ラベル

| ラベル              | 条件                                    |
| ------------------- | --------------------------------------- |
| `priority:critical` | クリティカルパス上かつ基盤フェーズ      |
| `priority:high`     | **デフォルト**                          |
| `priority:medium`   | 被依存数が少なく緊急度が低いタスク      |
| `priority:low`      | 被依存数 0 のリーフタスク、nice-to-have |

TODO(取得方法: `gh label list` で上記 4 ラベルの実在を確認し、未作成なら
`gh label create <name> --description "<用途>"` で作成する)

### その他の既定ラベル

| ラベル              | 用途                                                                    |
| ------------------- | ----------------------------------------------------------------------- |
| `refactor:proposal` | 自動検出されたリファクタ観点の提案 Issue（`/refactor-sync` が起票する） |
| `refactor:approved` | リファクタ提案 Issue への着手指示（実装フローのトリガー）               |
| `LGTM`              | レビュー完了を示す PR ラベル（Issue には付けない）                      |

TODO(取得方法: `gh label list` で上記 3 ラベルの実在を確認し、未作成なら
`gh label create <name> --description "<用途>"` で作成する)

### routine ラベル

routine（定期実行）を起点にする skill が作った PR / Issue に付け、人間が一覧で見分ける目印にする。
体系は `routine:<skill-name>`。sync 系は起動経路（routine か人間の直接起動か）を問わず付ける。
人間が手で起票した Issue には付けない。付与の手順は `docs/harness/skills/shared/sync-pr-flow.md` に従う。
本表が routine ラベルの唯一の一覧であり、skill を採用・除外したら同一 PR で行を足す・消す。

| ラベル                        | 対象                                                            |
| ----------------------------- | --------------------------------------------------------------- |
| `routine:readme-sync`         | `/readme-sync` が作った PR                                      |
| `routine:docs-sync`           | `/docs-sync` が作った PR                                        |
| `routine:code-sync`           | `/code-sync` が作った PR                                        |
| `routine:gc-scan`             | `/gc-scan` が作った PR                                          |
| `routine:adr-compress`        | `/adr-compress` が作った PR                                     |
| `routine:refactor-guide-sync` | `/refactor-guide-sync` が作った PR                              |
| `routine:refactor-sync`       | `/refactor-sync` が起票した Issue（`refactor:proposal` と併用） |
| `routine:renovate-sync`       | `/renovate-sync` が作った PR（採用時のみ）                      |
| `routine:public-arch-sync`    | `/public-arch-sync` が作った PR（採用時のみ）                   |

TODO(取得方法: `gh label list` で採用した skill の `routine:*` の実在を確認し、未作成なら
`gh label create <name> --description "<用途>"` でまとめて作成する。`gh pr create --label` /
`gh issue create --label` は存在しないラベルで非ゼロ終了するため、ラベルの作成は routine 登録より前に行う)

## マイルストーン

> マイルストーン一覧は陳腐化しやすい。**新規 Issue へ割り当てる前に必ず実在を確認する**。
> 実在しないタイトルを `--milestone` に渡すと非ゼロ終了する（無言にはならない）。

```bash
# open のみ
gh api 'repos/{owner}/{repo}/milestones?per_page=100' --paginate --jq '.[].title'
# closed を含む全件
gh api 'repos/{owner}/{repo}/milestones?state=all&per_page=100' --paginate --jq '.[].title'
```

`{owner}` / `{repo}` は gh が git remote から解決するプレースホルダで、リテラルを書かない。

### 割り当て可能な open マイルストーン

| マイルストーン                                                                         | 対象                                             |
| -------------------------------------------------------------------------------------- | ------------------------------------------------ |
| TODO(記入方法: 上記 open 照会の結果から、フェーズ計画に沿ってマイルストーンを列挙する) | TODO(記入方法: 各マイルストーンの対象範囲を書く) |

- `harness:harness` ラベルの Issue はマイルストーンなしでもよい。未指定時は `gh issue create` の
  `--milestone` フラグ自体を省略する。
- closed 済みフェーズは新規 Issue の割り当て対象外。title が似た別マイルストーン（フェーズ名の使い回し）
  の取り違えに注意する。

## 更新手順

1. 上記の照会コマンドで実値を取得する
2. 該当行の `TODO(...)` を実値へ置換する（照会していない値を書かない）
3. Project / フィールド / ラベルを新設・改名した場合は、本ファイルを同一 PR で更新する

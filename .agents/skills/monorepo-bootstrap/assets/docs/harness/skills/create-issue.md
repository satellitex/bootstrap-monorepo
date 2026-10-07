# create-issue — Issue 作成（読み戻し検証付き）

この文書は `/create-issue` の tool-neutral な正本手順である。PJ 固有の magic value（Project ID・フィールド ID・ラベル一覧・マイルストーン）はここに書かず、`.claude/skills/create-issue/references/project-fields.md`（profile）に集約する。

## 目的

Issue の内容を加味して Label, Project, Assignee, Relationships, Status, Expired date を適切に策定し、GitHub Issue を一発で作成する。作成後は読み戻し照会で設定結果を検証し、未反映を「設定済み」と報告しない（fail-closed）。

## 承認モデル

承認モデル（→ `docs/harness/OPERATING_MODEL.md`「承認モデル」）に従う。Issue の作成に人間の事前確認ゲートは設けず、パラメータの策定から作成・検証・報告までを自律的に行う。ユーザから訂正が入った場合は `gh issue edit` 等で反映する。

## 入力

以下の情報を受け取る。不足分は引数・会話文脈・Issue 内容からの自動推定で補完する。

| 項目                           | 必須 | 説明                                                                                                                        |
| ------------------------------ | ---- | --------------------------------------------------------------------------------------------------------------------------- |
| タイトル                       | Yes  | Issue のタイトル（動詞で終える）                                                                                            |
| 概要                           | Yes  | 何を・なぜやるか                                                                                                            |
| 意図・モチベーション           | Yes  | この Issue を立ち上げた背景・動機                                                                                           |
| 受入条件                       | Yes  | チェックリスト形式（3–10 個目安）。リポジトリ内で満たせる確定事項として書く（選択肢のまま残さず、選んだ案とその理由を書く） |
| ラベル                         | No   | 未指定時は概要から自動推定                                                                                                  |
| アサイニー                     | No   | 未指定時は起票者（`gh` の認証ユーザ）                                                                                       |
| マイルストーン                 | No   | 未指定時は概要から自動推定。`harness:harness` ならなしでもよい                                                              |
| 優先度                         | No   | critical / high / medium / low。未指定時は `high`                                                                           |
| Expired date                   | No   | `YYYY-MM-DD` 形式。未指定時は今週日曜（ブロック元 Issue がある場合はその翌週日曜）                                          |
| ブロック元 Issue（blocked-by） | No   | `#<N>` 形式。この Issue の着手をブロックする Issue。依存関係として登録する                                                  |
| 親 Issue（parent）             | No   | `#<N>` 形式。この Issue を sub-issue として束ねる親。ブロック元とは別の入力で、指定が無ければ親子関係を作らない             |
| 参考資料                       | No   | 関連ドキュメントパス等                                                                                                      |

呼び出し元の skill・agent（スキャン系など）が指定したラベル・マイルストーン・body 末尾の機械可読ブロック（候補 ID を載せた HTML コメント等）は、そのまま使い、改変・削除しない。自動推定は未指定の項目にだけ働く既定である。呼び出し元の突合キーが壊れると、後続の実行が重複起票や取りこぼしを起こすため。

## 参照データ

magic value（Project ID, フィールド ID, ラベル一覧, マイルストーン等）は `.claude/skills/create-issue/references/project-fields.md` に集約されている。API 操作の実行前にこのファイルを読み込み、正しい ID を使う。

## フロー

### Step 1: パラメータの策定

引数と文脈から以下を決定する。不足分は Issue の内容から自動推定する。呼び出し元の指定値は上記のとおり保持する。

- ラベル: 概要・受入条件の内容から、ハーネス種別（1 つ）、種別、コンポーネント、優先度（デフォルト `high`）を選択する。選択肢は profile を参照。
- マイルストーン: Issue の対象フェーズに応じて推定する。`harness:harness` ラベルの Issue はマイルストーンなしでもよい。未指定時は `gh issue create` の `--milestone` フラグ自体を省略する。割り当て前に実在を確認する（確認コマンドは profile 参照）。
- アサイニー: 未指定時は `gh` CLI の現在の認証ユーザ（起票者）を使う。
- Expired date: (1) ユーザ明示指定 → (2) ブロック元 Issue の Expired date の翌週日曜 → (3) デフォルト: 今週の日曜日、の優先順で決定する。

ブロック元 Issue の Expired date は、ブロック元の所属 Project（振り分けは Step 4 と同じ）の `ProjectV2.items`（`first: 100`）を、`pageInfo.hasNextPage` が false になるまで `endCursor` でページ送りし、`content.number` が一致する item の `fieldValueByName(name: "Expired date")`（`ProjectV2ItemFieldDateValue` の `date`）を読む。見つからない場合と値が無い場合は (3) にフォールバックし、そのことを出力で報告する。

### Step 2: Issue body の生成

以下のテンプレート構造で body を構築する。呼び出し元が body 末尾の機械可読ブロックを指定している場合は、本文の最後にそのまま付ける。

```markdown
## 概要

{概要テキスト}

## モチベーション

{この Issue を立ち上げた意図・背景・動機}

## 受入条件

- [ ] {条件1}
- [ ] {条件2}

## 依存 Issue

- #{blocked_by_issue_number}: {依存の説明}

（依存がない場合はこのセクションを省略）

## 参考資料

- `{ドキュメントパス}`
- #{関連 Issue 番号}

（参考資料がない場合はこのセクションを省略）
```

### Step 3: Issue の作成（自律実行）

策定したパラメータで `gh issue create` を実行する。事前の人間確認は行わない（承認モデル参照）。作成結果の URL から Issue 番号を取得し、以降のステップで使う。

- リポジトリ: 作業ツリーの remote から解決させる（`--repo` に owner を直書きしない → `docs/harness/skills/shared/gh-query-fail-closed.md`）
- タイトル、アサイニー、ラベルは Step 1 で策定したものを指定する
- マイルストーンが未定の場合は `--milestone` フラグ自体を省略する

### Step 4: Project への追加と Status 設定

profile を読み込み、必要な Project ID とフィールド ID を取得する。

1. `project` scope の確認: `gh auth status` で `project` scope があるか確認し、なければ認可更新（`gh auth refresh -s project`）をユーザに案内する。認可更新は端末での対話操作を要する。無人 run では認可更新を依頼せず、Project に関わる処理（Step 4・5 と Step 7 の Project 側の読み戻し）をスキップして、「未実施」と理由を報告する。扱いは実行モードによる（→ `docs/harness/skills/shared/unattended-contract.md`）。
2. プロジェクトの振り分け: `harness:harness` ラベルがあればハーネス用 Project、それ以外はプロダクト用 Project に追加する（振り分け先の実体は profile 参照）。
3. Project に追加: `addProjectV2ItemById` mutation（`projectId` と `contentId` に、Project と Issue の node ID を渡す）で Issue を追加し、返された `item.id` を控える。以降の Status・Expired date の設定と Step 7 の読み戻しはこの item ID を使う。
4. Status を Todo に設定: `updateProjectV2ItemFieldValue` mutation に控えた item ID を渡し、Status フィールドを Todo に設定する。

### Step 5: Expired date の設定

`updateProjectV2ItemFieldValue` mutation で、控えた item ID の Expired date フィールドに Step 1 で算出した日付を設定する。

### Step 6: Relationships の設定（任意）

依存関係（blocked-by）と親子関係（sub-issue）は意味が異なるため、別の mutation で設定する。ブロック元を子として登録すると親子の階層表示と進捗集計が崩れ、blocked の表示も出ない。

- ブロック元 Issue が指定されている場合: 作成した Issue と、ブロック元 Issue の GraphQL node ID を取得し、`addBlockedBy` mutation（`issueId` = 作成した Issue、`blockingIssueId` = ブロック元）で依存関係を設定する。GraphQL が使えない実行環境では、REST の `POST /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by`（body の `issue_id` はブロック元 Issue の database ID）で代替する。
- 親 Issue が指定されている場合のみ: `addSubIssue` mutation（`issueId` = 親、`subIssueId` = 作成した Issue）で sub-issue 関係を設定する。

依存関係は body の「依存 Issue」セクションにもテキストで記載済みなので、`#<N>` 参照による自動リンクも効く。

### Step 7: 設定結果の読み戻し検証

Step 3〜6 で設定した属性が実際に GitHub 側へ反映されたかを、書き込み API の成功レスポンスではなく読み戻し照会で確認する。書き込み系コマンドは値の解決に失敗すると非ゼロ終了するため無言にはならないが（`docs/harness/skills/shared/gh-query-fail-closed.md`）、「コマンド自体は成功したが値が反映されていない」部分失敗（例: 実行環境の制約でマイルストーン番号の解決手段が無く、設定自体をスキップした）が起こり得るため、本 Step で結果そのものを見て検証する。

1. Issue 側の読み戻し（1 回）: `gh issue view <番号> --json number,milestone,labels,assignees` を実行する。呼び出し元が末尾マーカーを指定した場合は `body` も取得し、マーカーが保持されていることを確かめる。
2. Project 側の読み戻し（1 回）: Step 4 で控えた item ID を `node(id:)` で引き、`ProjectV2Item` の `project`（id・title）、`content`（Issue の number）、`fieldValueByName(name: "Status")`（`ProjectV2ItemFieldSingleSelectValue` の name）、`fieldValueByName(name: "Expired date")`（`ProjectV2ItemFieldDateValue` の date）を読む。`content.number` が作成した Issue の番号と一致することで、item ID の取り違えを検知する。

   Project 側の読み戻しに `gh issue view --json projectItems` を使わない。Project の所有者がリポジトリの owner と異なる構成では、`projectItems` が空配列になり得て、Project 追加済みでも未追加と区別できないため。

3. 突合: Step 1 で策定した値（マイルストーン・ラベル・アサイニー・Status・Expired date）と読み戻した値を比較する。
4. 不一致時の補正（1 回だけ）: 不一致が見つかった場合、`gh issue edit`（マイルストーン・ラベル・アサイニー）または Step 4・5 の mutation 再実行（Project／Status／Expired date）で補正を試み、同じ照会で再照会を 1 回だけ行う。補正・再照会とも 2 回以上は繰り返さない。
5. 直らなかった場合: 補正後もなお不一致が残る場合は「設定済み」と報告せず、未設定である事実を明示して報告する（下記「出力」参照）。
6. 検証不能時: `project` scope 不足等で Project 側を読み戻せない場合は、未設定と断定せず「検証できなかった」と報告する。空の結果を「未追加」と判定しない。

## 出力

完了後、以下をユーザに報告する:

1. 作成した Issue の URL
2. Step 7 で読み戻した実値の一覧（「設定した値」ではなく読み戻した実値を報告する）:
   - Labels / Assignee / Milestone（不一致があった場合は補正の有無と最終値）
   - Project / Status / Expired date（item node から読み戻した実値。検証できなかった場合はその旨）
3. 補正の有無（あれば補正内容と再照会結果）
4. 検証できなかった項目（あれば理由とともに明示）
5. 依存関係・親子関係の設定状況（ある場合）。ブロック元の Expired date を読めず既定にフォールバックした場合はその旨

## 関連

- `.claude/skills/create-issue/references/project-fields.md` — magic value の profile（正本）
- `docs/harness/skills/shared/gh-query-fail-closed.md` — GitHub CLI 照会の fail-closed 規約
- `docs/harness/skills/shared/unattended-contract.md` — 確認ゲートの扱い（対話 run / 無人 run）

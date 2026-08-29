# PR body に closing keyword を必須化する

> この文書は team-shared rule の 1 つ。closing keyword の記載規範のみを定め、PR 作成時の注入手順は `docs/harness/skills/shared/pr-creation.md` に書く。

起票元 Issue を完了させる PR は、body に GitHub auto-close keyword（`Closes` / `Fixes` / `Resolves`）と Issue 番号の組を必ず記載する。

## Why

GitHub の Issue ↔ PR auto-close は以下の条件で発火する（公式 docs: "Linking a pull request to an issue", https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue）:

- closing keyword（`close` / `closes` / `closed` / `fix` / `fixes` / `fixed` / `resolve` / `resolves` / `resolved`）+ `#<num>` の組が **PR body** に含まれている
- PR title 内の `#<num>` 言及はリンク表示はされるが auto-close 対象外
- **PR の base がリポジトリのデフォルトブランチ（main）であること。** デフォルト以外を base にした PR では closing keyword を含めても auto-close は発火しない

PR title だけに `#<num>` を残して body に closing keyword を書き忘れると、PR merge 後も Issue が open のまま残る。これが続くと:

- Project の Status（Todo / In Progress / Done）と Issue 実体の乖離が拡大する
- タスク選定や期限集計で「未完だが実は完了済み」の Issue が紛れ込む
- 手動で確認・close する運用コストが恒常的に発生する

事後検出の CI ではなく PR 作成時の注入（proactive 方式）で担保するため、正当に Issue 紐付けの無い保守 PR に摩擦を与えない。

## How to apply

### PR 作成時

- 起票元 Issue を完了させる PR は body に必ず記載する: `Closes #<num>` / `Fixes #<num>` / `Resolves #<num>`（case insensitive。過去形・現在形・三人称単数いずれも有効）
- cross-repo は `Closes owner/repo#<num>` の形式で認識される
- 複数 Issue を close する場合は `Closes #101, Closes #102` のように closing keyword を個別に付ける（`Closes #101 #102` は 1 個目しか auto-close されない）
- **partial PR**（大きな親 Issue の一部のみを対応し、親をまだ close すべきでない）は `Closes #<親>` を使わず `関連: #<親>` で linkage のみ残す。body 冒頭で親 Issue のどの部分を対応したかを明示する
- **保守 PR**（起票元 Issue が無い release / sync / hotfix、および bot 自動 PR）は closing keyword を単に省略する。免除ラベルの類は使わない

### NG 例 / OK 例

| NG | OK |
|----|----|
| PR title に `#123` 言及のみ、body に記載なし | PR body: `Closes #123` |
| close 意図なのに body に `関連: #123` のみ | PR body: `Closes #123` |
| `Closes #`（placeholder のまま） | `Closes #123` |
| `Closes #101 #102`（2 個目が auto-close されない） | `Closes #101, Closes #102` |

### 自動検証

closing keyword の強制は **PR 作成時のハーネス注入による proactive 方式**で担保する。PR を作成するフロー（`/multi-issue` 等の skill、およびメインエージェント判断）は `docs/harness/skills/shared/pr-creation.md` の「closing keyword の注入」手順に従い、起票元 Issue 番号から `Closes #<num>` を body に決定的に埋め、PR 作成コマンドの直前に self-check する。

## 関連

- `docs/harness/skills/shared/pr-creation.md` — PR 作成共通手順（closing keyword 注入の本体）
- GitHub Docs: "Linking a pull request to an issue"

# PR 作成共通手順（base 判定 + closing keyword 注入）

この文書は PR 自動作成の共通手順（検証 → commit → push → base 判定 → closing keyword 注入 → `gh pr create`）を定める。skill 固有の差分（commit type 候補、PR body に含めるセクション）は書かない（呼び出し側の skill 文書が指定する）。

各 skill / フロー本体は最終 Step で本ファイルを Read し、その手順に従う。

## 手順

以下を順に実行し、最後に PR URL を出力する。タスク毎に既にコミット済みの場合は 2 をスキップして 3 (push) に進む。

1. `pnpm run format:check`（NG なら `pnpm run format` 後に再実行。変更種別に応じた検証ゲートの
   組合せは `docs/harness/skills/shared/verification-gates.md` を正本とする）
2. `git add`（更新したファイルのみ個別指定）+ `git commit`（Conventional Commits 形式。type は呼び出し側指定）
3. `git push -u origin <current-branch>`（`--no-verify` 禁止）
4. **base ブランチを判定する**（「## base ブランチの判定」に従う）。`$BASE_BRANCH` を得る。
5. PR body を組み立てる（構成は呼び出し側指定）。Issue との linkage は「## closing keyword の注入」に
   従って**決定的に**埋める（placeholder のまま残さない）。`$BASE_BRANCH` が `main` 以外の場合は
   同セクションの「ケース3」に従う。
6. `gh pr create --base "$BASE_BRANCH"` で PR を作成する。直前に「## closing keyword の注入」の
   self-check を必ず通す。

## base ブランチの判定

このリポジトリの長期統合ブランチは `main` のみである（`main` = dev 環境、`release` = prod 環境。
`release` へは prod リリース手順でのみ反映するため、自動 PR の base にはしない）。したがって
`$BASE_BRANCH` は `main` に固定する。

`gh pr create` は `--base` 未指定でもリポジトリのデフォルトブランチを base に使うが、fetch 失敗・
ref 不在等で誤った base へ静かにフォールバックすることを避けるため、`origin/main` との共通祖先の
存在を明示的に確認してから固定する（確認できなければ PR を作らず fail する）。

Step 4 で以下をそのまま実行し `$BASE_BRANCH` を得る:

```bash
DEFAULT_BRANCH=main

git fetch --quiet origin +refs/heads/main:refs/remotes/origin/main 2>/dev/null || true

BASE_BRANCH="$DEFAULT_BRANCH"
MAIN_MB=$(git merge-base HEAD origin/main 2>/dev/null || true)

if [ -z "$MAIN_MB" ]; then
  # origin/main との共通祖先が計算できない（fetch 失敗 / ref 不在等）→ 誤った base への
  # 静かなフォールバックを避けるため、ここで明示的に fail する
  BASE_BRANCH=""
fi

if [ -z "$BASE_BRANCH" ]; then
  if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
    echo "ERROR: base ブランチを判定できませんでした。shallow clone のため merge-base が計算できていない可能性があります。\`git fetch --unshallow\` を実行してから再試行してください。" >&2
  else
    echo "ERROR: base ブランチを判定できませんでした（main との merge-base 計算に失敗）。origin への fetch 権限・ネットワーク接続を確認してください。" >&2
  fi
  exit 1
fi

echo "BASE_BRANCH=$BASE_BRANCH"
```

本手順は各フローが共通で参照するため、この 1 ファイルの修正のみで横断的に base 追従が有効になる。
base は PR 作成時点のコミットグラフから再計算できるため、各 skill 文書側に起点ブランチ情報を
リレーする口は不要。

## closing keyword の注入

PR merge 時の Issue auto-close / Projects Status 自動更新は **PR body の closing keyword
（`Closes` / `Fixes` / `Resolves` + `#<num>`）で発火する**。PR title 内の `#<num>` 言及は
GitHub 上のリンク表示はされるが auto-close は発火しない。したがって linkage は title ではなく
body へ確実に注入する。

**前提: closing keyword はリポジトリのデフォルトブランチ（`main`）向け PR でのみ発火する**
（GitHub Docs "Linking a pull request to an issue"）。`$BASE_BRANCH` が `main` 以外になった場合、
body に `Closes #<num>` を含めても merge 時の auto-close は発火しない。この場合は起票元 Issue を
完了させる意図の PR でもケース3 に従う。

- **ケース1（`$BASE_BRANCH=main` かつ起票元 Issue を完了させる通常 PR）**: 着手時に取得した起票元
  issue 番号を使い、body に `Closes #<issue_number>` を**必ず記載**する。複数 Issue を close する
  場合は `Closes #1, Closes #2` と closing keyword を個別に付ける（`Closes #1 #2` は 1 個目しか
  発火しない）。
- **ケース2（partial PR: 大きな親 Issue の一部のみを対応し、親をまだ close すべきでない）**:
  `Closes #<parent>` は使わず `関連: #<parent>` で linkage のみ残す（auto-close を発火させない）。
  body 冒頭で親 Issue のどの部分を対応したかを明示する。
- **ケース3（`$BASE_BRANCH` が `main` 以外）**: 現在の base 判定ロジックでは `$BASE_BRANCH` は
  `main` に固定されるため、このケースは実質的に発生しない。将来、別の長期統合ブランチ運用を
  導入した場合に備えた一般手順として残す。その場合 closing keyword は発火しないため、起票元
  Issue を完了させる意図でも `関連: #<num>` を使い、body 冒頭に「auto-close 対象外。Issue close は
  `main` 統合時または手動で行う」旨を明記する。
- **起票元 Issue が無い保守 PR**（sync 系の定期実行等）: closing keyword は不要。特定 Issue 起点で
  実行した場合のみ `関連: #<番号>` を記載する。
- **self-check（`gh pr create` 直前に必ず実施）**: ケース1 なら body に `Closes #<num>`、
  ケース2 / ケース3 なら `関連: #<num>` が含まれることを確認する。placeholder（番号未記入）の
  状態で PR を作成しない。

## 呼び出し側で指定すべき差分

| 項目 | 内容 |
|------|------|
| commit type 候補 | 各 skill の性質に合った Conventional Commits の type（例: 実装は `feat` / `fix` / `refactor`、ハーネス変更は `feat(skill)` / `refactor(harness)` / `docs(harness)`、環境整備は `chore` / `ci` / `build`） |
| PR body に含めるセクション | 検出サマリ、受入条件チェックリスト、設計判断 → ADR リンクなど、skill ごとに必要なセクション |

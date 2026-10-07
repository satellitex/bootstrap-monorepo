# refactor-sync — リファクタ観点の検出と Issue 提案

この文書は `/refactor-sync` の tool-neutral な正本手順である。実体は refactorer agent への委譲エントリポイントであり、検出・反証・観点の分類・選定・Issue 作成の詳細は `.claude/agents/refactorer.md` を正本とする（本文書には複製しない）。PJ 固有の検出コマンド・必読ガイドは `.claude/agents/references/refactorer-profile.md`（profile）が正本である。

## 目的

`apps/**`・`packages/**` のコードを `docs/styles/refactoring_guide.md` の検出基準に照らし、規約違反と、コード量を減らせる観点（効いていない・非推奨・冗長なコード）を、観点ごとの Issue として提案する。routine による定期実行と、人間による明示起動の両方を想定する。コードは変更しない。実装は、提案 Issue への着手指示（`refactor:approved` ラベル）の後に別フローで行う。

## 入力

なし。引数は受け付けない（渡されても無視する）。

## 処理

1. `docs/harness/skills/shared/sync-prelude.md` に従い `git fetch origin main` し、検出の基準を `origin/main` に固定する。HEAD が feature ブランチでも、結果が変わらないようにするため。
2. refactorer agent を起動する。subagent 機構のある実行環境では `refactorer` を subagent として起動する。subagent 機構が無い環境では、agent 定義（`.claude/agents/refactorer.md`）を読み、同じ手順を独立した別 pass として実行する。
3. agent が起票した Issue に、起動経路（routine か人間の直接起動か）を問わず `routine:refactor-sync` ラベルを付ける（`gh issue edit <番号> --add-label routine:refactor-sync`）。ラベルの一覧は `.claude/skills/create-issue/references/project-fields.md`。
4. agent の結果を再解釈せず、そのまま報告する。

## 出力

- 起票した Issue の URL（観点ごと・最大 3 件）
- 見送った候補の件数と理由（重複・件数上限・根拠不足）
- profile の未記入件数と、未記入や実行不能のために行えなかった検査
- 課題が検出されなかった場合は「課題なし」
- 照会経路の疎通 canary が落ちた場合は、「課題なし」ではなく照会経路の異常として報告する（`docs/harness/skills/shared/gh-query-fail-closed.md`）。0 件を「課題なし」と取り違えると、重複起票や取りこぼしが無言で起きるため

提案 Issue には、agent が付ける `refactor:proposal` ラベルと、処理 3 で付ける `routine:refactor-sync` ラベルが併存する。

## 責務分界

| 対象 | 担当 |
|------|------|
| `apps/**`・`packages/**` の規約違反と、効いていない・非推奨・冗長なコード | `/refactor-sync`（本 skill） |
| コーディング規約とリファクタガイドの検出基準の追従 | `/refactor-guide-sync` |
| ソースコメントの 3 原則・内部参照 | `/code-sync` |
| 作業中 PR の差分の簡素化 | `/simplify`（PR 作成前） |
| ハーネス文書の重複・孤児 | `/gc-scan` |

## 制約

- コードを変更しない。Issue 作成のみが責務で、PR も作らない（このため `docs/harness/skills/shared/sync-pr-flow.md` は使わない）
- 1 回の実行で起票する Issue は最大 3 件（人間が着手指示を出せる量を超えた Issue は放置されるため）
- 検出の基準は常に `origin/main`
- 重複確認の規則（着手指示済みの提案との重複を含む）と選定順は `.claude/agents/refactorer.md` に従う

## 言語

報告・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。

## 関連

- `.claude/agents/refactorer.md` — 検出・Issue 提案の手順正本
- `docs/styles/refactoring_guide.md` — 検出基準と承認済み観点
- `docs/harness/skills/shared/sync-prelude.md` — 比較基準の固定

---
name: adr-compactor
description: docs/adr/ の ADR 本体・INDEX.md を静的分析し、INDEX の status 別再構築・アーカイブ in-place スタブ化（Superseded/Deprecated・プロセス記録）・大型本文要約で肥大化を圧縮して 1 PR にまとめる（同一 issue 統合は opt-in）
---

# ADR Compactor

> この文書は adr-compactor の検出・安全ゲート・PR 化フローの正本である。ADR の status model・INDEX 規約・stub の正確な形式は書かない（`docs/adr/README.md` が正本）。git/PR の共通手順も書かない（`docs/harness/skills/shared/` が正本）。

## 責務分界

| Agent / Skill | 責務 | トリガー |
|---------------|------|---------|
| adr-compactor | 既存 ADR 群の圧縮（下記カテゴリ）→ 安全ゲート → PR 提案 | routine 定期実行 / `/adr-compress` skill |
| `/create-adr` | 新規 ADR の起票（1 件追加） | 設計判断の発生時 |
| gc-agent | ハーネス文書のサイズ・重複・孤児の GC | `/gc-scan` |

ADR の起票は `/create-adr`、ハーネス文書の GC は gc-agent。本 agent は **既存 ADR コーパスの圧縮のみ** を担う。

## インプット

- `docs/adr/INDEX.md` — カテゴリ I の再構築対象
- `docs/adr/ADR-*.md` — カテゴリ II / III / IV の検出・圧縮対象
- `docs/adr/README.md` — ADR status model / INDEX 規約 / stub 形式・圧縮運用の正本
- `docs/harness/skills/adr-compress.md` — 起動エントリポイント（引数・opt-in の指定方法）
- `docs/harness/skills/shared/pr-creation.md` — 共通 git/PR 手順（Step 4 で参照）
- `docs/harness/skills/shared/gh-query-fail-closed.md` — GitHub CLI 照会の fail-closed 規約

## カテゴリ（検出条件の概要）

| カテゴリ | 検出条件 | 圧縮アクション | 性質 |
|---------|---------|--------------|------|
| **I** INDEX 再構築 | `INDEX.md` が canonical（status 別 + 行コンパクト）形でない | 全 ADR を Status で分類し `## 現行（Accepted/Proposed）` / `## アーカイブ（Superseded·Deprecated / プロセス記録）` に**決定的再構築**。各行 = link + 1 行要旨（≤150 字） | lossless |
| **II** アーカイブ in-place スタブ化 | (a) Status が `Superseded` / `Deprecated`、または (b) **プロセス成果物**（レビューループの記録・一括修正作業の記録など、手続きの経緯のみで durable-decision を含まない ADR） | ADR 本体を **同パスのまま** stub に置換（後継リンク or 解決記録へのポインタ）。**ファイル移動なし**。II-a は完全 supersede のみ full stub、部分 supersede は有効 Decision を全文保持する Decision 保持圧縮形 | lossless |
| **III** 同一 issue 統合 | **opt-in 時のみ**。同一 issue 番号 slug の ADR が 3 件以上かつ全件 non-Proposed | 1 つの consolidated ADR に統合（各 Decision を §化）、原本は in-place の Superseded stub | Decision 全保持 |
| **IV** 本文要約圧縮 | ADR 本体が **400 行超 または 18KB 超**、かつ non-Proposed・非 stub | Context / Decision / Consequences の要点に短縮、詳細経緯は git 履歴に委譲 | lossy |

stub の正確な形式・INDEX の canonical 構造・`{adr-slug}` の決定的変換は `docs/adr/README.md` の圧縮運用節を正本とする。本 agent は検出・安全ゲート・PR 化のオーケストレーションを担う。stub は最低限、(1) 元タイトル、(2) Status と後継/解決先へのリンク、(3) 「本文は git 履歴を参照」の明記、(4) 再 stub 化を防ぐ marker コメントを含む。

> **III は既定で無効**。`/adr-compress` が `consolidate` 引数付きで起動された場合のみ有効化する（「1 ADR = 1 決定」規約の変更を伴うため明示 opt-in）。

## 横断安全ガードレール（全カテゴリ共通・違反候補は除外）

1. **Proposed 不可侵**: Status が `Proposed` の ADR は II / III / IV の対象にしない（レビュー進行中）。I は全 status を分類するのみ（本体不可侵）。Status の読み取りは format-agnostic に行う（インライン表 / `## Status` 節 / `- Status:` 箇条書き / bold+link の 4 形を吸収する）。4 キーワード（Proposed / Accepted / Superseded / Deprecated）に分類できない場合は Proposed 相当として II / III / IV から除外し `status-unparseable` で記録する。
2. **Decision を消さない**: III / IV は元 ADR の各 Decision（D1〜DN）とその根拠を必ず保持する。**II-a も partial-supersede（一部 Decision のみ後継に置換され残りが有効）の場合は有効 Decision を full stub で消さない**（full / partial を本文の supersede 範囲から判別し、partial は Decision 保持圧縮形を適用する）。1 つでも有効 Decision が落ちる圧縮は候補から外す。
3. **durable-decision ガード（II-b プロセス成果物）**: ファイル名や体裁がプロセス成果物パターンに一致しても、本文に恒久的な設計判断（採用方針の選定・代替案棄却理由・継続的に効くスコープ/原則）を含む場合は **stub 化しない**。IV の閾値を満たせば IV、満たさなければ無変更とし `durable-decision` で記録する。
4. **in-place 維持 = 参照保全**: II / III は **ファイルを移動しない**（同パスで本文のみ stub 化）。ADR への参照は markdown link 形式に限らず、docs・コード・Issue 本文に bare-id（ファイル名の直書き）で広く存在しうるため、パス不変によって ADR 間相互リンクと外部参照を構造的に無傷で保つ（`archive/` ディレクトリは作らない）。
5. **lossless 優先 / git 履歴が究極の正本**: I / II は lossless（I は本体不変、stub は内容を後継/履歴に委譲）。IV（lossy）は「冗長な叙述・レビュー round 履歴・重複 Context の削減」に限り、削除した詳細は git 履歴で追えることを ADR 本文と PR body に明記する。
6. **status model 準拠**: 統合（III）時の原本 stub は `docs/adr/README.md` の status 遷移に従い `Superseded by ADR-<consolidated-id>` にする。
7. **カテゴリ単一所有 + 実行順**: 1 ADR が複数カテゴリに該当する場合、優先順位 **II > III > IV** で最大 1 つが本体を所有する。本体変更（II/III/IV）をすべて適用した**後に** I（INDEX 再構築）を最終状態に対して 1 回実行する。

## プロセス

### Step 0: Input 照合（file ↔ INDEX 行のペアリング）

`docs/adr/ADR-*.md` の実ファイル集合と `INDEX.md` の各行を **第 1 セルの id を実ファイル名と完全一致**でペアリングする（行の prose 全体から id を拾わない＝phantom 防止）。`file あり/行なし`（I の再構築で追加）・`行あり/file なし`（phantom。再構築で除外）を PR body の "INDEX drift" 一覧に surface する。

### Step 1: 走査・検出

カテゴリ表の検出条件に従い候補を抽出する。観測可能な事実（実際の行長・Status・ファイルサイズ・issue 重複数・ファイル名パターン）のみを対象とする。各候補に **検出根拠の実測値**を証拠として保持する（欠落のまま次へ進まない）。III は opt-in 時のみ走査する。**走査対象 0 件 → 「検出対象なし」を報告し正常終了。**

### Step 2: 抑制条件と候補 ID 割当

横断安全ガードレールに該当する候補は **記載をスキップ**（理由を記録）。プロセス成果物候補は durable-decision ガード（#3）を必ず適用する。抑制を通過した各候補に、再実行時にも同じ ID が生成される **決定的候補 ID** を割り当てる。基本形は `{prefix}-{adr-slug}`（`{prefix}` はカテゴリを表す `index-rebuild` / `stub` / `consolidate` / `summarize`、`{adr-slug}` はファイル名の決定的変換）。候補 ID は **人間レビュー用のトレーサビリティ**であり、Step 4 の open PR ガードの判定キーではない（ガードは存在判定のみで候補 ID を参照しない）。

### Step 3: 圧縮実行

Step 2 通過候補をカテゴリ別手順で変更する。実行順は **II（in-place stub）→ III（opt-in 統合）→ IV（本文要約）→ I（INDEX 再構築）**。II / III は同パス書き換えのみで**ファイル移動を伴わない**。I は本体変更後の最終状態から INDEX を決定的に再構築する（content-driven 分類）。

### Step 4: PR 作成

共通の git/PR 手順は `docs/harness/skills/shared/pr-creation.md` に従う。

**open PR ガード（ブランチ作成前・存在判定）**: 未マージ（open）の adr-compress PR が **1 件でも存在すれば** 新規 PR を作らず、既存 PR の番号 / URL / `headRefName` / 作成日時を報告して終了する（routine tick ごとの near-duplicate PR・`INDEX.md` の同時書き換えを防ぐ）。判定は絞り込み結果の **件数のみ**（0 件か否か）であり、候補 ID どうしの比較や対象 PR の変更ファイル・body は見ない。照会は `docs/harness/skills/shared/gh-query-fail-closed.md` の規約に従い、`--search` を使わず plain list + ローカル絞り込み + 疎通 canary で行う（search 経路は空を無言で返すことがあり、ガードが毎 tick すり抜けて重複 PR を作る）。

```bash
# 疎通 canary（fail-closed）: 照会経路が死んでいるまま「既存 open PR なし」と解釈して
# 重複 PR を作らないため、絞り込みと直交した最小照会で経路の生存を確認する。
[ "$(gh pr list --state all --limit 1 --json number --jq 'length')" -eq 1 ] || { echo "ERROR: PR 照会経路の疎通 canary が失敗。ガードを通過扱いにせず停止する" >&2; exit 1; }

raw="$(gh pr list --state open --limit 1000 --json number,url,headRefName,createdAt)"

# 打ち切り検知: 取得件数が --limit に達していたら絞り込み前に PR が落ちている可能性がある。
[ "$(jq 'length' <<<"$raw")" -lt 1000 ] || { echo "ERROR: 取得件数が --limit に達した。--limit を上げて再取得する" >&2; exit 1; }

jq '[.[] | select(.headRefName | startswith("agent/adr-compress"))]' <<<"$raw"
```

canary が通り、かつ絞り込み結果が 0 件のときのみ「既存 open PR なし」として次へ進む。

- **canary が落ちた場合**: ブランチも PR も作らず、**「変更なし」ではなく照会経路の異常**として報告して終了する。
- **絞り込み結果が 1 件以上の場合**: ブランチも PR も作らず、該当する全 PR の番号 / URL / `headRefName` / 作成日時を報告して終了する。**自動 bypass は設けない**（滞留期間に関わらず、人間が既存 PR を merge/close するまで新規 PR は作らない）。

```bash
git fetch origin main
git switch -c agent/adr-compress-YYYY-MM-DD origin/main   # YYYY-MM-DD は JST 実行日。同名既存なら -2 等
# 圧縮実行（Step 3）
git add <変更・新規した ADR / INDEX を個別に指定>
git commit -m "refactor(adr): adr-compress (YYYY-MM-DD)"
git push -u origin agent/adr-compress-YYYY-MM-DD          # pre-push CI hook が自動実行
```

- 候補 0 件かつ INDEX が既に canonical 形のときはブランチも PR も作らず、`[adr-compress] 変更なし。` + スキップ件数内訳を出力して終了する。
- PR は通常 PR（`--draft` 不使用、base は `main`）。ラベルは `harness:harness`。起票元 Issue が無い保守 PR のため closing keyword は付けない（commit type `refactor(adr)`）。
- **idempotency**: II の stub は短く marker を持つため次回 run で再 stub 化されない（`archive/` 移動を行わないため、移動 → 再検出の 2-run churn は発生しない）。II-a の Decision 保持圧縮形（partial-supersede）も marker `already-compressed-partial` で再 stub 化されない。I は決定的再構築のため未変更コーパスでは同一出力＝diff なし。IV 要約済み本体は閾値未満で再検出されない。
- PR 作成後に PR URL を console 報告する。

## アウトプット

| 成果物 | 説明 |
|--------|------|
| GitHub PR | 候補がある場合のみ作成。1 スキャン = 1 PR |
| 実行サマリ（stdout） | 候補なし時の「変更なし」、または PR URL + カテゴリ別件数 + スキップ候補件数・理由内訳 |

## 制約

- **検出対象は I / II / IV（+ opt-in III）のみ**。新規 ADR 起票はしない（`/create-adr` 管轄）
- **1 スキャン = 1 PR**。日付サフィックスで同日複数実行を分ける
- **Proposed の ADR は II / III / IV の対象外**。**Decision を消さない**。**II / III はファイルを移動しない（in-place stub）**。**プロセス成果物は durable-decision ガードを通す**
- **検出証拠（実測値）を伴わない候補は候補化しない**
- 命名は小文字ケバブ（`docs/harness/harness_authoring_guide.md` の命名規則）。**consolidated ADR 名は `ADR-{YYYYMMDD}_consolidated_issue-{N}.md`**
- 比較・更新の基準は常に `origin/main`（現在の HEAD ではない）
- `git add` は変更ファイルのパスを個別指定（`git add -A` 等の広域指定禁止）。`--no-verify` 禁止。`--draft` 不使用
- stub 形式・INDEX 規約・status 遷移は `docs/adr/README.md` を正本とする（本 agent では複製しない）

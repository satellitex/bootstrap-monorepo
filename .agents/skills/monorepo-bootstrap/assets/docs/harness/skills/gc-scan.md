# gc-scan（ハーネス GC: サイズ・重複・孤児）

この文書は `/gc-scan` の手順正本である。ハーネス文書全体を `gc-agent` でスキャンし、サイズ超過・Cross-File 重複・孤児/デッド参照を検出して**すべて 1 つの PR で提案**する。検出・抽出の詳細ロジックは `.claude/agents/gc-agent.md` を正本とする（本文書には複製しない）。docs の内容鮮度（`/docs-sync` 担当）・ADR の圧縮（`/adr-compress` 担当）は扱わない。

## Purpose

ハーネス文書（agent 定義・skill adapter・skill 手順正本）の物理的な劣化 —
サイズ超過による認知負荷、複数ファイルへの同一記述の重複、誰からも使われないファイルや
実在しない先を指すポインタ — を定期的に検出し、レビュー可能な変更として提案する。

## Source of truth

`docs/harness/harness_authoring_guide.md`（サイズ上限・分離原則・命名規則の判定基準）。

## Compared against

スキャン対象のハーネス文書の実態（実際の行数・重複ブロック・参照グラフ）。

## Scope

スキャン対象:

- `.claude/agents/*.md`（agent 定義）
- `.claude/skills/*/SKILL.md`（thin adapter）
- `docs/harness/skills/**/*.md`（skill 手順の正本）
- `docs/harness/OPERATING_MODEL.md` / `CLAUDE.md` / `AGENTS.md`（サイズ検査のみ。孤児判定の対象外）

除外:

- `docs/harness/skills/shared/**` は**孤児判定（カテゴリ C）から除外**する。複数 skill / agent が
  Read する共有契約置き場であり、`/command` として起動しない設計のため、起動経路の不在は異常ではない
  （サイズ・重複の検査対象には含める）。
- gc-agent 自身（`.claude/agents/gc-agent.md`）は走査対象に含めるが提案対象から除外する。

## Detection

1. Agent tool で `subagent_type: gc-agent` を起動する（引数なし。渡されても無視する）。
2. gc-agent が 3 カテゴリで候補を検出する（検出条件・同一性判定・抑制条件・検出証拠の記録は
   `.claude/agents/gc-agent.md` を正本とする）:

| カテゴリ | 検出条件 | 提案内容 |
|---------|---------|---------|
| A: Cross-File 重複 | 2 ファイル以上に存在する 3 行以上の意味的に同一・類似ブロック | 共有 references への抽出 + 各所のポインタ置換 |
| B: サイズ超過 | `docs/harness/harness_authoring_guide.md` のサイズ表の上限を超過 | progressive disclosure（references/ への分離） |
| C: 孤児・デッド参照 | inbound 参照 0 件の references / 起動経路の無い agent / SKILL.md 不在の skill ディレクトリ / 実在しない先を指すポインタ | **削除・修正の変更を同一 PR に含めて提案**（採否はレビューで判断） |

カテゴリ B の上限値は `docs/harness/harness_authoring_guide.md` のサイズ表を正本とする（本文書に数値を複製しない）。検査対象は同表に載る全種別 — agent 定義・skill 正本に加え、**thin adapter（`.claude/skills/*/SKILL.md`）と `docs/harness/OPERATING_MODEL.md` / `CLAUDE.md` / `AGENTS.md`** も含む。

カテゴリ C の除外規定（誤検出防止）:

- 新規追加直後（追加から 7 日以内）は候補化しない（参照元を後続 PR で追加する途中状態）
- ファイル冒頭に `> orphan-allow: <理由>` 行がある場合は候補化しない（外部から直接 Read される想定等。
  理由の妥当性は PR レビューが担う）
- `docs/harness/skills/shared/**`（上記 Scope の除外）

## Auto-edit policy

- カテゴリ A / B: 抽出（references ファイルの作成 + 抽出元のポインタ置換）を実行する。
  抽出元に要約を残さない（単一情報源の原則）。
- カテゴリ C: **削除・修正の変更を同一 PR に含める**。孤児ファイルは削除、デッド参照は
  参照の修正または削除として diff を作る。削除の採否は PR レビューで人間が判断する
  （マージ前に取り消せる形で提案する。Issue 起票では追跡が滞留しやすいため、判断材料
  〔検出証拠: 探索キーワードとヒット状況・最終更新日〕を PR body に添えて diff で提示する）。
- 判定が割れる候補（実運用実績が確認できない agent 等）は削除 diff にせず、PR body の
  「要判断」一覧に検出証拠付きで記載するに留めてよい。

## Branch & PR policy

全カテゴリ候補 0 件なら「抽出対象なし」を console に出力して終了する（ブランチも PR も作らない）。
候補ありの場合は `docs/harness/skills/shared/sync-pr-flow.md` の手順（既存 open PR ガード →
`origin/main` 基点ブランチ → commit → 通常 PR）に従う。本 skill の差分:

| 項目 | 値 |
|------|-----|
| 変更なしメッセージ | `[gc-scan] 抽出対象なし。ハーネス文書はサイズ・重複・参照の閾値を超えていません。` |
| ブランチ | `agent/gc-scan-{YYYY-MM-DD}` |
| git add | 新規作成した references / 修正した抽出元 / 削除・修正したカテゴリ C 対象のみ |
| commit | `refactor(harness): gc-scan (YYYY-MM-DD)` |
| PR title | `refactor(harness): gc-scan (YYYY-MM-DD)` |
| PR ラベル | `harness:harness` |
| PR body | 下記 Report shape |

1 回の実行で **1 PR**（カテゴリ A / B / C の全候補を 1 つにまとめる）。Issue は起票しない。

## Validation

ハーネス文書のみの変更のため `pnpm run format:check`
（`docs/harness/skills/shared/verification-gates.md` の「docs のみ変更」組合せ）。
加えて PR 作成前に以下を確認する:

- 各抽出先ファイルの内容が抽出元から正しく移動されている（要約を残していない）
- 各抽出元のポインタが正しい配置先を参照している
- 抽出後の各ファイルが `docs/harness/harness_authoring_guide.md` のサイズ表の上限以内
- カテゴリ C の削除対象を参照している箇所が PR 内で同時に修正されている（削除だけして
  デッド参照を新たに作らない）

## Report shape

PR body の構成:

1. **検出サマリ**: カテゴリ A / B / C の件数 + スキップ件数（抑制条件 / 除外規定の内訳）
2. **実行した抽出（A / B）**: 候補 ID / 抽出元パス + 行範囲 / 配置先パス
3. **削除・修正の提案（C）**: 候補 ID / 対象パス / サブカテゴリ / 検出証拠（探索キーワードと
   ヒット状況・最終更新日）。**削除を確定事項として書かず**、「参照が見つからなかった」事実と
   判断材料を提示する（探索できない経路からの参照があり得るため、採否はレビューに委ねる）
4. **要判断**: 削除 diff にしなかった候補（理由付き）
5. **受入条件チェックリスト**: Validation の 4 項目

## Language

報告・PR body・Issue 本文は project language に従う（正本: `docs/harness/OPERATING_MODEL.md` の言語ポリシー節）。ファイルパス・候補 ID は原文のまま保持する。

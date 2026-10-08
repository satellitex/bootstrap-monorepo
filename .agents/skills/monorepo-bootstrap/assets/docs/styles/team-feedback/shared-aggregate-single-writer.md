# 共有集約ファイル（INDEX.md）は実装 PR で編集しない

> この文書は team-shared rule の 1 つ。INDEX.md の更新主体と実装 PR の作法のみを定め、INDEX ごとの更新主体の割当表と経過措置の詳細は `docs/harness/skills/shared/index-writer-policy.md` に書く（本書には複製しない）。

実装 PR は、既存の `INDEX.md` を変更しない。INDEX の行は、割り当てられた更新主体（routine / skill / leaf 文書を変更する PR）が更新する。新規ディレクトリの INDEX の新規作成は実装 PR で行ってよい（→ `docs/harness/skills/shared/index-writer-policy.md`「leaf 文書の要件」）。

## Why

INDEX.md は、複数の Issue の成果が同じ表・同じ件数表記に集まる共有集約ファイルである。並列に実装した PR がそれぞれ 1 行ずつ追記すると、同じ表の末尾や件数表記が衝突し、rebase のたびに解消が要る。ADR 一覧や runbook 一覧のように追記頻度の高い INDEX ほど衝突しやすい。更新主体を直列に動く 1 つに絞ると、同じ表を同時に書き換える PR が存在しなくなる。代償として、INDEX への反映は更新主体の実行頻度に従って遅れる。要件一覧のように、行の内容を最もよく知るのが対応する leaf 文書を変更する PR で、追記頻度も低い INDEX は、その PR を更新主体とし、並行する PR との衝突は rebase で解消する（割当表 → `docs/harness/skills/shared/index-writer-policy.md`）。

## How to apply

- **leaf ファイルを自己記述にする** — INDEX に載せたい行を PR 内の別の場所へ持ち回らず、追加・改名するファイルが冒頭見出しとリード文を満たす形に書く（要件 → `docs/harness/skills/shared/index-writer-policy.md`「leaf 文書の要件」）。更新主体は実体ファイルを読んで行を起こす
- **更新主体を割当表で確認する** — INDEX ごとの更新主体は `index-writer-policy.md` の割当表が正本である。leaf 文書を変更する PR が更新主体の INDEX（要件一覧など）も、その leaf 文書を変更しない実装 PR からは変更しない
- **枠組みの変更は実装 PR で行える** — 枠組み（リード文・節構成・分類方針）の変更は、行の追記・削除を含めず、既存行の文言を変えない範囲で実装 PR が行ってよい。未反映の実体ファイルがある場合は、PR 本文に列挙して更新主体に委ねる
- **経過措置と強制の範囲** — routine の登録前の扱い、並列実装フローの検収、フロー外の PR への強制の範囲は `docs/harness/skills/shared/index-writer-policy.md` の「経過措置」「強制の範囲」に従う

## 関連

- `docs/harness/skills/shared/index-writer-policy.md` — INDEX ごとの更新主体の割当表と経過措置
- `docs/harness/skills/multi-issue.md` — 並列実装フロー（検収で INDEX の変更を検出する）
- [implementation-flow-switch](./implementation-flow-switch.md) — 実装フローの切替

# 共有集約ファイル（INDEX.md）は実装 PR で編集しない

> この文書は team-shared rule の 1 つ。INDEX.md の更新主体と実装 PR の作法のみを定め、INDEX ごとの更新主体の割当表と経過措置の詳細は `docs/harness/skills/shared/index-writer-policy.md` に書く（本書には複製しない）。

実装 PR は、既存の `INDEX.md` を変更しない。INDEX の行は、割り当てられた更新主体（routine / skill / 人間）が更新する。新規ディレクトリのための INDEX の新規作成は、既存の表と衝突しないため実装 PR で行ってよい。

## Why

INDEX.md は、複数の Issue の成果が同じ表・同じ件数表記に集まる共有集約ファイルである。並列に実装した PR がそれぞれ 1 行ずつ追記すると、同じ表の末尾や件数表記が衝突し、rebase のたびに解消が要る。ADR 一覧や runbook 一覧のように追記頻度の高い INDEX ほど衝突しやすい。更新主体を直列に動く 1 つに絞ると、同じ表を同時に書き換える PR が存在しなくなる。代償として、INDEX への反映は更新主体の実行頻度に従って遅れる。

## How to apply

- **leaf ファイルを自己記述にする** — INDEX に載せたい行を PR 内の別の場所へ持ち回らず、追加するファイルの冒頭 `#` 見出し（INDEX 行のタイトルになる）と、見出し直後に置く 1〜3 行のリード文で、何のドキュメントかを読み取れる形に書く。ADR は Status 表も読み取れる形にする。更新主体は実体ファイルを読んで行を起こす
- **更新主体を割当表で確認する** — INDEX ごとの更新主体は `index-writer-policy.md` の割当表が正本である。人間が更新主体の INDEX（要件一覧など）は、実装 PR からも変更しない
- **枠組みの変更は実装 PR で行える** — 枠組み（リード文・節構成・分類方針）の変更は、行の追記・削除を含めず、既存行の文言を変えない範囲で実装 PR が行ってよい。未反映の実体ファイルがある場合は、PR 本文に列挙して更新主体に委ねる
- **経過措置と強制の範囲** — routine の登録前の扱い、並列実装フローの検収、フロー外の PR への強制の範囲は `docs/harness/skills/shared/index-writer-policy.md` の「経過措置」「強制の範囲」に従う

## 関連

- `docs/harness/skills/shared/index-writer-policy.md` — INDEX ごとの更新主体の割当表と経過措置
- `docs/harness/skills/multi-issue.md` — 並列実装フロー（検収で INDEX の変更を検出する）
- [implementation-flow-switch](./implementation-flow-switch.md) — 実装フローの切替

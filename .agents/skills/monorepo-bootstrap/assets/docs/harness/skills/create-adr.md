# create-adr — ADR の構造的記録

この文書は `/create-adr` の tool-neutral な正本手順である。ADR の運用ポリシー（起票基準・命名規約の背景・Status 遷移・INDEX 形式・圧縮運用）は `docs/adr/README.md` が正本であり、ここには手順のみを書く。

## 目的

REJECT/REVISE や設計判断が発生した際に、ADR (Architecture Decision Record) を構造的に記録する。既存の ADR を置き換える判断では、元の ADR の Status も同じ PR で更新し、無効になった決定が「現在有効」のまま残らないようにする。

## 起票基準

ADR を起票するのは、次のいずれかに該当するときである（正本: `docs/adr/README.md` の「いつ書くか」）。

- アーキテクチャや技術選定で、複数の選択肢を比較して決めたとき。技術選定は 1 領域 1 ADR とし、検討した代替案と棄却理由を含める
- 既存の方針を撤回・置換するとき
- 自動レビュー・人間レビューの指摘への対応で、設計方針が変わったとき

次の判断は ADR にせず、根拠を PR 本文または PR コメントの返信に書く。判断ごとに ADR を作ると、一覧と圧縮の負荷だけが増えるため。

- スタイルの指摘、スコープ外の軽微な指摘、設計方針が変わらない単純な却下
- 変数名、フォーマット設定のような小さな判断

暫定対策を決める ADR は、Consequences の「暫定対策の撤去条件・再評価トリガ（任意）」欄（`docs/adr/template.md`）に、撤去条件と追跡先（Issue）を書く。前提が変わったら見直す決定は、同じ欄に再評価トリガを書く。条件が成立したら、ADR を削除せず Deprecated にし、撤去や見直しの根拠は後継の ADR に書く。

## 入力

| 項目 | 必須 | 説明 |
|------|------|------|
| 問題の概要 | Yes | 何が問題だったか（人間の入力、レビュー指摘、実装中の設計判断など） |
| 関連 Issue 番号 | No | GitHub Issue `#<N>` |
| 関連要件 | No | `docs/requirements/` 配下の要件 ID への参照 |
| 置換・廃止する ADR | No | 新しい判断が置き換える既存 ADR の ID またはファイル名（Step 4） |

引数例: `/create-adr "リトライ方針の変更判断" #<N>`

引数が不足している場合は、起票文脈（レビューコメント・実装中の判断内容・関連 Issue / PR）から補完する。補完できない必須項目は、対話 run ではユーザに質問する。無人 run では、必須項目（問題の概要）を既定値で埋めず、ADR を生成せずに不足項目を明示して呼び出し元へ返す。扱いは実行モードによる（→ `docs/harness/skills/shared/unattended-contract.md`）。

## フロー

### Step 1: ファイル名の決定

パターン: `ADR-{YYYYMMDD}_{branch_name}_{slug}.md`

- `{YYYYMMDD}`: 実行日
- `{branch_name}`: 現在の git ブランチ名（`/` は `-` に置換して正規化する）
- `{slug}`: 問題の概要から英語 kebab-case（簡潔に）で生成

例: `ADR-20260101_agent-example-branch_retry-policy-change.md`

### Step 2: ADR ファイルの生成

`docs/adr/template.md` を Read し、その構造で `docs/adr/<ファイル名>` を生成する（テンプレートの SSOT は template.md。本文書に複製しない）。

- Status: `Proposed` で起票する。マージ後の `Accepted` への更新は `/adr-compress`（`docs/harness/skills/adr-compress.md`）が追従させるため、手動で更新しない。決定が確定していない ADR を含む PR はマージしない（追従はマージ済みの事実だけを根拠に進むため）。Status が未確定の間は、保留の理由を PR 説明に書く。
- Author: 起票元に応じて設定（例: `Agent (Review Comment)`, `Human`, `Agent (Planner)`）
- Context: 問題の背景・制約・前提条件。関連する要件 ID（SEC-NNNN, FR-NNNN 等）があれば言及
- Decision: 選択した方針と根拠。複数案を比較した場合は、退けた案と理由も書く
- Consequences: Positive（メリット）と Negative（トレードオフ・リスク）の両面で記述
- Related Issues: 関連 Issue 番号と要件ドキュメントへのリンク

### Step 3: INDEX.md の扱い

`docs/adr/INDEX.md` の更新主体は `docs/harness/skills/shared/index-writer-policy.md` の割当表に従う。既定の更新主体は routine（`/adr-compress`）であり、実装 PR では INDEX.md を編集しない。並列に走る PR が同じ表の末尾へ追記すると衝突するため。ADR 本文は、冒頭見出しと Status・Date の表だけで一覧の行を起こせる状態にしておく。

同ポリシーが経過措置として同一 PR での更新を許している間は、`docs/adr/INDEX.md` の Proposed 表に、第 1 セルを ADR へのリンク、第 2 セルを 1 行要旨にした行を追記する:

```markdown
| [ADR-{date}_{branch}_{slug}](./ADR-{date}_{branch}_{slug}.md) | 1 行要旨 | YYYY-MM-DD |
```

### Step 4: 既存 ADR を置換・廃止する場合

新しい ADR の Decision が既存の ADR を ID またはファイル名で名指しして置換・廃止・撤回する場合は、元の ADR の Status と冒頭見出しを、新しい ADR と同じ PR で更新する。Status の追従は置換関係を検出できないため、起票時に書かないと元の ADR が「現在有効」のまま残る。

1. Status を更新する。
   - 全体を置き換える場合、または後継のある無効化: `Superseded by ADR-{新 id}`
   - 後継のない無効化: `Deprecated`
   - 一部の Decision だけを置き換える場合: `Superseded by ADR-{新 id}（Decision N のみ。他の決定は有効）` のように、Status 行に範囲を括弧書きする
2. 元の ADR の本文冒頭（Context の前）に、見出し `## Superseded（YYYY-MM-DD）` または `## Deprecated（YYYY-MM-DD）` を追加し、後継 ADR への参照と理由を 1〜3 文で書く。Decision 本文は削除しない（本文の圧縮は `/adr-compress` が行う）。
3. 新しい ADR の Related Issues（または Context）に、置換・廃止した ADR を挙げる。
4. INDEX.md の元の ADR の行（Superseded / Deprecated 表への移動を含む）は、Step 3 の更新主体の扱いに従う。

既存の ADR が実態と合わなくなった場合は、レビュー指摘への対応で吸収せず、この Step で置換の ADR を起票する。

## 出力

完了後、作成した ADR ファイルのパス、置換・廃止した元の ADR（あれば）、INDEX.md の扱い、ADR の概要（タイトル・Status・Related Issues）をユーザに報告する。

## 関連

- `docs/adr/README.md` — ADR 運用の正本（起票基準・命名・Status 遷移・圧縮）
- `docs/adr/template.md` — 本文テンプレートの SSOT
- `docs/harness/skills/shared/index-writer-policy.md` — INDEX の更新主体
- `docs/harness/skills/shared/unattended-contract.md` — 確認ゲートの扱い（対話 run / 無人 run）
- `docs/harness/skills/adr-compress.md` — Status 追従と圧縮
- `docs/harness/skills/handle-review.md` — レビュー対応時の ADR 記録の呼び出し元

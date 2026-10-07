# ADR（Architecture Decision Record）運用ガイド

> この文書は `docs/adr/` の運用規約（書く条件・命名・Status 遷移と追従・置換と廃止・INDEX 形式・圧縮運用）の正本である。個々の決定内容は各 ADR 本文に書き、ここには書かない。
> ADR の置き場はリポジトリ全体で本ディレクトリ 1 箇所のみとする。別ディレクトリに ADR を作らない。

## ADR とは

設計・技術上の重要な判断とその根拠を記録するドキュメント。
「なぜそう決めたか」を残すことで、同じ議論の繰り返しや過去の失敗の再発を防ぐ。

## いつ書くか

次のいずれかに該当するときに書く。

- アーキテクチャや技術選定で複数の選択肢を比較して決定したとき。技術選定は 1 領域 1 ADR とし、検討した代替案と棄却理由を含める
- 既存の方針を撤回・置換するとき
- 自動レビュー・人間レビューの指摘への対応で、設計方針が変わったとき

次の判断は ADR にせず、根拠を PR 本文または PR コメントの返信に書く。ADR が増えるほど圧縮と INDEX の保守が増えるため、記録の置き場を分けている。

- スタイルの指摘、スコープ外の軽微な指摘、設計方針が変わらない単純な却下
- 変数名、フォーマット設定のような小さな判断

暫定対策を決める ADR は、template の任意欄に撤去条件（上流の修正が入る、期限が来るなど観測できる条件）と追跡先（Issue）を書く。前提が変わったら見直す決定は、同じ欄に再評価トリガを書く。条件が成立したら ADR を削除せず `Deprecated` にし、撤去や見直しの根拠は後継 ADR に書く（下記「置換と廃止」）。

## 書き方

1. [`template.md`](./template.md) をコピーしてファイルを作成する
2. ファイル名は `ADR-{YYYYMMDD}_{branch-slug}_{topic-slug}.md`
   - `{branch-slug}` は作業ブランチ名の `/` を `-` に置換して正規化する
   - 例: `ADR-20260101_agent-example-branch_retry-policy-change.md`
3. Status を `Proposed` にして PR に含める
4. 決定が確定してからマージする。Status が未確定の間（採否を保留する場合など）は PR をマージせず、保留の理由を PR 説明に書く
5. マージ後の `Proposed` → `Accepted` は `/adr-compress` が追従させる（手動更新は不要。下記「Status の追従」）

## Status の遷移

```
Proposed → Accepted → Deprecated
                    → Superseded by ADR-{id}
```

- **Proposed**: PR レビュー中。まだ確定していない
- **Accepted**: マージ済み。現在有効な決定
- **Deprecated**: 状況の変化により無効化。理由を本文に追記する
- **Superseded**: 新しい ADR で置き換えられた。後継 ADR の ID を記載する

### Status の追従

`/adr-compress` のカテゴリ 0 が、origin/main 上で Status が `Proposed` の ADR を `Accepted` へ書き換える（Status 表の値のみ変更し、他のセルは変えない）。ADR が origin/main に存在することは、追加した PR がマージ済みであることの証拠になるため、判定は `git ls-tree origin/main` と `git show origin/main:<path>` だけで行える。

- 前提: `Proposed` の ADR は PR レビュー中のブランチにだけ存在し、main へ直接 push されない
- 追従が保証するのは PR のマージという事実だけである。決定内容の有効性の再検証と、後続 ADR による置換関係の検出は行わない。置換は次節のとおり起票時に記録する

### 置換と廃止

新しい ADR が既存の ADR を名指しして置き換える・廃止する・撤回するときは、元 ADR の Status と冒頭の見出しを同一 PR で更新する。Status の追従は置換関係を検出しないため、起票時に書かないと元 ADR が現行の決定として残る。

- 全体を置き換える場合: Status を `Superseded by ADR-{新 id}` にする。後継を伴わず無効化する場合は `Deprecated` にする
- 一部の Decision だけを置き換える場合: Status に範囲を括弧書きで添える（例: `Superseded by ADR-{新 id}（Decision 2 のみ。他の決定は有効）`）
- Context の前に見出し `## Superseded（YYYY-MM-DD）` または `## Deprecated（YYYY-MM-DD）` を追加し、後継 ADR への参照と理由を 1〜3 文で書く。Decision 本文は削除しない（本文の整理は `/adr-compress` が行う）

## INDEX の更新

`INDEX.md` の更新主体は `/adr-compress`（adr-compactor エージェント）である。ADR を追加・更新する PR は `INDEX.md` を変更せず、ADR 本体（ファイル名 = id、冒頭の `#` 見出し = タイトル、Status 表 = Status・Date）を正しく書くことに責任を持つ。`/adr-compress` が本体から行を決定的に再構築するため、情報は失われない。

並列 PR が同じ表末尾と件数表記を書き換えると衝突するため、更新主体を 1 つにしている（割当表と経過措置 → `docs/harness/skills/shared/index-writer-policy.md`、規約本文 → `docs/styles/team-feedback/shared-aggregate-single-writer.md`）。経過措置（routine の登録前）→ `docs/harness/skills/shared/index-writer-policy.md`。

`INDEX.md` は **Status 別**（現行: Accepted / Proposed ／ アーカイブ: Superseded・Deprecated ／ プロセス記録）に分類し、各行は **コンパクト形式**（第 1 セル = ADR link、第 2 セル = 1 行要旨）を基本とする。Decision の詳細は ADR 本体が正本であり、INDEX 行に長文要約を詰め込まない。無効化済み・未確定の ADR を「有効な決定」として現行 Accepted に混在させない。

## 肥大化の圧縮（`/adr-compress`）

ADR コーパスが肥大化したら `/adr-compress`（adr-compactor エージェント）が以下のカテゴリで圧縮し 1 PR にまとめる（routine 定期実行向け）。実行順とカテゴリの所有は `docs/harness/skills/adr-compress/compression-rules.md` に従う:

- **0**: Status 追従（上記）。圧縮ではなく Status の値の更新で、肥大化の閾値と無関係に実行する。候補が 0 件なら変更なしで終了する
- **I**: `INDEX.md` を Status 別セクションに決定的再構築（lossless、各行リンク + 1 行要旨）
- **II**: `Superseded` / `Deprecated`、および プロセス記録（durable-decision を含まない手続き記録）の ADR 本体を **同一パスのまま** stub に置換（lossless・**ファイル移動なし**＝参照保全）
- **III**（opt-in）: 同一 issue 番号に紐づく複数 ADR を 1 ファイルに統合し、原本は in-place の `Superseded by ADR-<consolidated>` stub にする（Decision 全保持）。`/adr-compress consolidate` 時のみ
- **IV**: サイズ閾値超過の大型 ADR 本文を正準節に要約圧縮（lossy。削除した検討経緯は git 履歴が究極の正本）

ガードレール: **Proposed の ADR は II/III/IV の対象外**（カテゴリ 0 の Status 追従だけが Proposed を書き換える）・**Decision を消さない**・**II/III はファイルを移動しない（in-place stub）**・**プロセス成果物は durable-decision ガードを通す**。手順の正本は `docs/harness/skills/adr-compress.md`、エージェント定義は `.claude/agents/adr-compactor.md`。

## 参照先

- テンプレート → [`template.md`](./template.md)
- 一覧 → [`INDEX.md`](./INDEX.md)
- ADR の構造的記録手順 → `docs/harness/skills/create-adr.md`
- 圧縮手順 → `docs/harness/skills/adr-compress.md`

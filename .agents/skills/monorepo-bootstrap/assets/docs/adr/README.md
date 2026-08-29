# ADR（Architecture Decision Record）運用ガイド

> この文書は `docs/adr/` の運用規約（書く条件・命名・Status 遷移・INDEX 形式・圧縮運用）の正本である。個々の決定内容は各 ADR 本文に書き、ここには書かない。
> ADR の置き場はリポジトリ全体で本ディレクトリ 1 箇所のみとする。別ディレクトリに ADR を作らない。

## ADR とは

設計・技術上の重要な判断とその根拠を記録するドキュメント。
「なぜそう決めたか」を残すことで、同じ議論の繰り返しや過去の失敗の再発を防ぐ。

## いつ書くか

- アーキテクチャや技術選定で複数の選択肢を比較・決定したとき
- 自動レビュー・人間レビューの差し戻し理由に設計上の判断が含まれるとき
- 人間レビューで設計方針の変更が発生したとき
- 既存の方針を撤回・置換するとき

迷ったら書く。小さすぎる判断（変数名、フォーマット設定など）は不要。

## 書き方

1. [`template.md`](./template.md) をコピーしてファイルを作成する
2. ファイル名は `ADR-{YYYYMMDD}_{branch-slug}_{topic-slug}.md`
   - `{branch-slug}` は作業ブランチ名の `/` を `-` に置換して正規化する
   - 例: `ADR-20260101_agent-example-branch_retry-policy-change.md`
3. Status を `Proposed` にして PR に含める
4. PR マージ時に Status を `Accepted` へ更新する

## Status の遷移

```
Proposed → Accepted → Deprecated
                    → Superseded by ADR-{id}
```

- **Proposed**: PR レビュー中。まだ確定していない
- **Accepted**: マージ済み。現在有効な決定
- **Deprecated**: 状況の変化により無効化。理由を本文に追記する
- **Superseded**: 新しい ADR で置き換えられた。後継 ADR の ID を記載する

## INDEX の更新

ADR を追加・更新したら [`INDEX.md`](./INDEX.md) のテーブルに行を追加・更新すること。

`INDEX.md` は **Status 別**（現行: Accepted / Proposed ／ アーカイブ: Superseded・Deprecated ／ プロセス記録）に分類し、各行は **コンパクト形式**（第 1 セル = ADR link、第 2 セル = 1 行要旨）を基本とする。Decision の詳細は ADR 本体が正本であり、INDEX 行に長文要約を詰め込まない。無効化済み・未確定の ADR を「有効な決定」として現行 Accepted に混在させない。

## 肥大化の圧縮（`/adr-compress`）

ADR コーパスが肥大化したら `/adr-compress`（adr-compactor エージェント）が以下のカテゴリで圧縮し 1 PR にまとめる（routine 定期実行向け）:

- **I**: `INDEX.md` を Status 別セクションに決定的再構築（lossless、各行リンク + 1 行要旨）
- **II**: `Superseded` / `Deprecated`、および プロセス記録（durable-decision を含まない手続き記録）の ADR 本体を **同一パスのまま** stub に置換（lossless・**ファイル移動なし**＝参照保全）
- **III**（opt-in）: 同一 issue 番号に紐づく複数 ADR を 1 ファイルに統合し、原本は in-place の `Superseded by ADR-<consolidated>` stub にする（Decision 全保持）。`/adr-compress consolidate` 時のみ
- **IV**: サイズ閾値超過の大型 ADR 本文を正準節に要約圧縮（lossy。削除した検討経緯は git 履歴が究極の正本）

ガードレール: **Proposed の ADR は II/III/IV の対象外**・**Decision を消さない**・**II/III はファイルを移動しない（in-place stub）**・**プロセス成果物は durable-decision ガードを通す**。手順の正本は `docs/harness/skills/adr-compress.md`、エージェント定義は `.claude/agents/adr-compactor.md`。

## 参照先

- テンプレート → [`template.md`](./template.md)
- 一覧 → [`INDEX.md`](./INDEX.md)
- ADR の構造的記録手順 → `docs/harness/skills/create-adr.md`
- 圧縮手順 → `docs/harness/skills/adr-compress.md`

<!-- harness:form -->
<!--
ADR 本文テンプレート。docs/adr/README.md の規約（命名は「書き方」）に従い、このファイルをコピーして作成する（コピー後このコメントは削除する）。
-->

# ADR-{date}_{branch-slug}_{topic-slug}: {タイトル}

| 項目   | 値                                                        |
| ------ | --------------------------------------------------------- |
| Status | Proposed / Accepted / Deprecated / Superseded by ADR-{id} |
| Date   | YYYY-MM-DD                                                |
| Author | {著者}                                                    |

## Context

決定が必要になった背景・制約・問題を記述する。

## Decision

採用する方針と、その選択理由を記述する。

## Consequences

### Positive

- 期待されるメリット

### Negative

- トレードオフ・リスク

### 暫定対策の撤去条件・再評価トリガ（任意）

暫定対策を決める場合、または前提が変わったら見直す決定の場合に書く。該当しなければ節ごと削除する。

- 撤去条件: 暫定対策を外せる、観測可能な条件（上流の修正が入る、期限が来るなど）
- 追跡先: 撤去を追跡する Issue
- 再評価トリガ: 決定を見直すきっかけ（例: 利用者が複数になる、前提とした制約が解消する）

条件が成立したら ADR を削除せず `Deprecated` にし、撤去や見直しの根拠は後継 ADR に書く（`README.md` の「置換と廃止」）。

## Related Issues

- #{Issue番号}
- `docs/requirements/XXX.md`（関連要件）

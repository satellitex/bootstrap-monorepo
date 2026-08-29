# requirements 運用ガイド

> この文書は `docs/requirements/`（要件定義の正本）の運用規約（ID 体系・要件ファイルの定型構成・編集権限・INDEX 運用）である。
> 個々の要件内容は各要件ファイルに書き、ここには書かない。

## 位置づけ

- 本ディレクトリは **顧客要件の正本（SSOT）** である。実装・テスト・トレーサビリティはここに置かれた要件から導出する。
- 要件ファイルは **人間が管理する。AI エージェントは要件ファイルを編集しない**（参照のみ）。要件の矛盾・不足・実装との乖離を検出した場合は、直接修正せず Issue で人間に提起する。
- 要件には「ビジネスの言葉」で What を書く。実装の進捗状況・実装ロジック（How）は書かない。

## ID 体系

| 種別 | 意味 |
| --- | --- |
| BR | Business Requirement（事業要件） |
| IF | Interface Requirement（インタフェース要件） |
| DATA | Data Requirement（データ要件） |
| FR | Functional Requirement（機能要件） |
| NFR | Non-Functional Requirement（非機能要件） |
| SEC | Security Requirement（セキュリティ要件） |

- ID は `種別 + 4 桁連番`（例: `FR-0001`, `SEC-0002`）。機能群ごとに番台を分けてもよい（例: 追加機能群を `1001` 番台で採番）。
- 確定済み要件を改訂した場合は **`-FIX` サフィックス**付きファイル（例: `FR-0001-FIX-<topic-slug>.md`）を当該 Requirement ID の完全版として扱い、旧ファイルは併置しない。`-FIX` 版には変更内容だけでなく、旧要件から引き継ぐ説明・背景も含めて自己完結させる。`Supersedes` には FIX 前の要件 ID を書く（自己参照にしない）。
- ファイル名: `<ID>_<topic-slug>.md`（FIX 版は `<ID>-FIX-<topic-slug>.md`）。

## 要件ファイルの定型構成

各要件ファイルは次の節で構成する（1〜4 は必須）。

1. **Intent** — この要件の意図を 1〜2 行で述べる。
2. **Business Requirement（SHALL）** — 規範文（SHALL / SHALL NOT）で要求を列挙する。
3. **正常系シーケンス（mermaid）** — 主要な関係者・コンポーネント間のやり取りを mermaid の `sequenceDiagram` で示す。
4. **WHY** — その要件が必要な業務上の理由を書く。
5. Acceptance Criteria（How to judge） — チェックリスト形式の受入基準。
6. Verification（How to verify） — CI での担保方法と証跡（Acceptance Criteria に対応するテストの結果・対応表）。
7. Dependencies / Traceability — 関連要件へのリンク。
8. Open Questions（Q-ID） — 未確定事項と回答の記録。
9. Metadata — Requirement ID / Type / Status。

## INDEX の更新

- 要件の追加・改訂・削除時は [`INDEX.md`](./INDEX.md) を同一 PR で更新する（人間が行う）。
- 削除・見送りにした要件は INDEX の「Deleted / Scope Out」節に ID・扱い・理由を残し、同じ議論の繰り返しを防ぐ。

# requirements 運用ガイド

> この文書は `docs/requirements/`（要件定義の正本）の運用規約（ID 体系・要件ファイルの定型構成・編集権限・INDEX 運用）である。
> 個々の要件内容は各要件ファイルに書き、ここには書かない。

## 位置づけ

- 本ディレクトリは **顧客要件の正本（SSOT）** である。実装・テスト・トレーサビリティはここに置かれた要件から導出する。
- 要件ファイルは、**確定するまでは AI エージェントが起草・編集する**（要件を書くことは AI の作業に含まれる）。確定は人間が Metadata の `Status` を `Confirmed` にして明示し、AI エージェントは `Status` を `Confirmed` にしない。
- **確定した要件は AI エージェントが編集しない**（参照のみ）。矛盾・不足・実装との乖離を検出した場合は、直接修正せず Issue で人間に提起する。改訂が必要なら `-FIX` 版を `Draft` で起草して提案する。
- 確定は要件の内容を決める行為であり、AI の作業を止める承認ゲートではない（承認モデル → `docs/harness/OPERATING_MODEL.md`「承認モデル」）。
- 本 README は区画の運用規約で、要件ファイルには当たらない。記述が実体と食い違う場合は `/readme-sync` が更新する（→ `docs/README.md`「運用ルール」）。
- 要件には「ビジネスの言葉」で What を書く。実装の進捗状況・実装ロジック（How）は書かない。

## ID 体系

| 種別 | 意味                                        |
| ---- | ------------------------------------------- |
| BR   | Business Requirement（事業要件）            |
| IF   | Interface Requirement（インタフェース要件） |
| DATA | Data Requirement（データ要件）              |
| FR   | Functional Requirement（機能要件）          |
| NFR  | Non-Functional Requirement（非機能要件）    |
| SEC  | Security Requirement（セキュリティ要件）    |

- ID は `種別 + 4 桁連番`（例: `FR-0001`, `SEC-0002`）。機能群ごとに番台を分けてもよい（例: 追加機能群を `1001` 番台で採番）。
- 確定済み要件を改訂した場合は **`-FIX` サフィックス**付きファイル（例: `FR-0001-FIX-<topic-slug>.md`）を当該 Requirement ID の完全版として扱い、旧ファイルは併置しない。`-FIX` 版は `Draft` で起草してよく、人間が `Confirmed` にするときに旧ファイルを削除して置き換える。`-FIX` 版には変更内容だけでなく、旧要件から引き継ぐ説明・背景も含めて自己完結させる。`Supersedes` には FIX 前の要件 ID を書く（自己参照にしない）。
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
9. Metadata — Requirement ID / Type / Status。Status は `Draft`（起草中。AI が編集してよい）か `Confirmed`（確定。人間が設定し、以後 AI は編集しない）の 2 値とする。

## INDEX の更新

- 要件の追加・改訂・削除時は [`INDEX.md`](./INDEX.md) を同一 PR で更新する。更新主体は要件ファイルを変更する PR（起草は AI、確定は人間）であり、実装 PR は本 INDEX を変更しない（更新主体の割当 → `docs/harness/skills/shared/index-writer-policy.md`）。
- 削除・見送りにした要件は INDEX の「Deleted / Scope Out」節に ID・扱い・理由を残し、同じ議論の繰り返しを防ぐ。

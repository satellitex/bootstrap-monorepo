# セキュリティ監査プロファイル（プロジェクト固有）

この文書は `/security-audit` が参照する**唯一のプロジェクト固有ファイル**である。対象リポジトリの事実（脅威モデル・監査対象マップ・除外規定・出力先・issue 化規約）だけを書き、監査フロー・監査次元カタログ・レポート様式・subagent プロンプト骨格は書かない（正本は `docs/harness/skills/security-audit.md`）。

> **本ファイルはテンプレート状態（未記入）である。** 各節の記入指示に従い、bootstrap の技術調査ステップ
> （スタック確定・アーキテクチャ確定）の後に埋める。埋まっていない節が残ったまま監査を実行すると、
> auditor に渡す「対象パス」「この領域の正本規約」が空になり、監査が沈黙で網羅を装う。
> **未記入の節がある状態で実行する場合は、その範囲をレポートの「カバレッジと制限」に必ず記録する。**

## 対象概要

<!-- 記入指示: 監査対象の全体像を 5 行以内で。owner は git remote から解決するため
     `<owner>/<repo>` を直書きしない（→ docs/harness/skills/shared/gh-query-fail-closed.md 規約 4）。 -->

- 対象リポジトリ: {{PRODUCT_NAME}}（TODO: 何を提供するシステムか。公開面（外部公開 API / 管理画面 / バッチ等）を 1 行で）
- 全体構成: TODO(取得方法: `docs/product/ARCHITECTURE.md` の構成図とワークスペース一覧から転記)
- 技術スタック正本: `docs/product/TECH_STACK.md`
- セキュリティ規約正本: TODO(`docs/styles/coding_guide/` 配下にセキュリティ規約を置く場合はそのパス。無ければ「未整備」と明記)
- 用語集: `docs/product/TERMS.md`

## 脅威モデル要約

<!-- 記入指示: 「守るべき資産 × 境界」を洗い出し、この PJ で特に重い attack surface だけを列挙する。
     一般論（OWASP の再掲）は書かない。各行は監査次元カタログ（D1〜D13）または下記「追加監査次元」に紐づける。
     行数の目安は 5〜10。 -->

| # | 資産・境界 | 主リスク | 関連次元 |
|---|-----------|----------|----------|
| T1 | TODO | TODO | TODO |
| T2 | TODO | TODO | TODO |

## 追加監査次元

<!-- 記入指示: 汎用カタログ（D1〜D13）で捕捉できないドメイン固有の次元がある場合のみ定義する。
     無ければ「なし」と明記して表を削除してよい。汎用カタログ側にドメイン固有次元を足さない。 -->

| ID | 次元 | 観点 |
|----|------|------|
| DS1 | TODO | TODO |

## 監査対象マップ（領域 × 次元 → 正本規約/要件）

<!-- 記入指示: `/security-audit` Step 1 のオーケストレーターがこの表から監査マトリクス（監査セル）を組む。
     auditor プロンプトの「対象パス」「この領域の正本規約・要件」に該当行がそのまま埋まる粒度で書く。
     - 「対象パス」は glob / ディレクトリで一意に閉じる（曖昧だと領域外まで読み、セルが肥大化する）
     - 「主次元」は 2〜4 個に絞る（全次元を全領域に掛けるとセル数が爆発する）
     - 「正本規約・要件」は逸脱を finding 候補にできる具体パス・要件 ID を書く（無ければ「なし」） -->

| 領域 | 対象パス | 主次元 | 正本規約・要件 |
|------|----------|--------|----------------|
| TODO | `apps/<app>/src/**` | TODO | TODO |
| TODO | `packages/<pkg>/src/**` | TODO | TODO |
| 依存・サプライチェーン | root `package.json` / 各 workspace / lockfile | D10 | TODO |

## 除外規定（監査しない / 別扱い）

<!-- 記入指示: 誤検知と時間浪費の主因を先に潰す。除外した範囲は必ずレポートの
     「カバレッジと制限」に出るため、ここでの除外は「見なかった」ことの明示的な宣言になる。 -->

- テストフィクスチャ・`*.example` のダミー値・サンプルコードは finding にしない。
- 暗号化済みシークレットファイルは、暗号化されている事実の確認までとし、復号して中身を監査しない。
- TODO(この PJ で主対象外にする領域と、その代わりに拾う観点。例: IaC 実体は別フロー対象だが、
  秘密混入・公開設定（D13）に限り観点として拾い詳細修正は別 issue とする)

## レポート出力先

- レポート本体: `docs/audit/<YYYY-MM-DD>_security-audit-report.md`（コミット対象。命名規約は `docs/audit/README.md`）
- 中間成果物（findings / verdicts）: `.claude/state/security-audit/<YYYY-MM-DD>/`（gitignore 済み。コミットしない）
- **機微取り扱い**: レポートに実シークレット値・悪用の逐次手順（PoC exploit コード）を転記しない。
  `file:line` と成立条件までに留める。TODO(対外公開区画〔opt-in:public-site〕を採用している PJ は、
  そこへの転記禁止を明記する)

## issue 化規約

> 起票は `/create-issue`（正本: `docs/harness/skills/create-issue.md`）とフィールド規約
> （`.claude/skills/create-issue/references/project-fields.md`）に従う。ここでは本監査固有のマッピングのみ定義する。

- **milestone**: TODO(セキュリティ対応フェーズのマイルストーン名。起票前に実在を確認:
  `gh api 'repos/{owner}/{repo}/milestones?per_page=100' --paginate --jq '.[].title'`。無ければ「なし」)
- **種別ラベル**: `bug`（既存実装の脆弱性）/ `enhancement`（ハードニング提案）
- **コンポーネントラベル**: TODO(上記「監査対象マップ」の領域 → `component:*` の対応を書く)
- **優先度ラベル（severity → priority）**: Critical → `priority:critical` / High → `priority:high` /
  Medium → `priority:medium` / Low → `priority:low`
- **Project**: TODO(プロダクト用 Project。`harness:harness` は付けない。ID は project-fields.md 参照)
- **粒度**: Critical / High は 1 finding = 1 issue、Medium / Low は severity ごとにまとめ issue
- **issue body**: finding の再現条件（precondition / path）・影響・該当 `file:line`・推奨対策・
  監査レポートへのリンク（PR / パス）を含める

## 更新手順

1. 監査対象の構成（ワークスペース追加・公開面の変更）が変わったら「監査対象マップ」を同一 PR で更新する
2. 新しい資産・境界が生まれたら「脅威モデル要約」に行を足し、対応する領域行の主次元を見直す
3. 本ファイル以外（skill 正本・監査次元カタログ・レポート様式）に PJ 固有の事実を書かない

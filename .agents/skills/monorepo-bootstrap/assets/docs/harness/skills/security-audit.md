# security-audit — 多次元セキュリティ監査

この文書は `/security-audit` の tool-neutral な正本手順であり、監査次元カタログ・レポート様式・subagent プロンプト骨格も本文の節として収録する。対象リポジトリ固有の事実（脅威モデル・監査対象マップ・除外規定・issue 化規約）はここに書かず、`.claude/skills/security-audit/references/project-profile.md`（profile）に分離する。

## 目的

上位モデルのオーケストレーターが実装モデルの subagent 群を「発見（auditor）」と「反証（verifier）」の 2 wave で並列使役し、リポジトリ全体を多次元セキュリティ監査する。検証済み findings のみをレポートに統合して PR を作成し、issue 起票まで自律実行する。

## 承認モデル（要旨）

既定は自律実行とする。監査マトリクスの確定・監査実行・レポート統合・open PR の提出・issue 起票までを人間承認なしで行い、確定した方針は報告のみ行って続行する。人間の明示承認が必須なのは課金が発生する操作と秘密値の挿入・変更のみであり、read-only 監査とレポート PR・issue 起票はどちらにも該当しない。PR のマージは人間の操作。

## 役割分担

| 役割 | 担当 | モデル |
|------|------|--------|
| スコープ確定・wave 制御・dedup・最終判定・レポート統合・issue 起票 | オーケストレーター（本セッション） | **上位モデル**（Step 0 で確認） |
| 次元×領域ごとの監査（発見） | auditor subagent（read-only 運用） | 実装モデル |
| finding 単位の再現・反証 | verifier subagent（read-only 運用） | 実装モデル |
| PR merge | 人間 | — |

## 再利用性: 汎用 / PJ 固有の分離

本 skill は「フロー + 監査観点 + テンプレート（汎用 = 本文書）」と「対象リポジトリの事実（PJ 固有 = profile）」を分離している。**他リポジトリへ移植する際は profile のみ書き換えればよい。** 本文書には対象リポジトリ固有のパス・技術名・要件 ID を書かない。PJ 固有の事実が必要になったら profile に追記し、本文書からは「project-profile を参照」とだけ書く。

## フロー

```
/security-audit [scope（領域名 or パス。省略時は全域）]
  ├── Step 0: セットアップ（モデル確認 / AUDIT_DIR / 再開判定）
  ├── Step 1: 監査マトリクス確定（報告のみ・承認待ちなし）
  ├── Step 2: 監査 wave（auditor 並列 → findings/*.md）
  ├── Step 3: 反証 wave（dedup → verifier → 最終判定）
  ├── Step 4: レポート統合（docs/audit/ へ）
  ├── Step 5: レポート PR 作成（通常 PR）
  └── Step 6: issue 起票（profile の issue 化規約に従い自律起票 → レポート追記）
```

## Step 0: セットアップ

1. **モデル確認**: 現在のセッションモデルが上位モデルクラスでない場合は警告し、モデル変更後の再実行を提案する（最終判定・統合の品質前提が上位モデルクラスであるため）。ユーザーが続行を選んだ場合のみそのまま進む。
2. `git fetch origin main` し、セッションブランチを `agent/security-audit-YYYY-MM-DD` に整える（同日重複は `-2`。detached / ランダム名なら `origin/main` 起点で作成）。
3. 作業ディレクトリ（コミットしない中間成果物置き場）を作成し `$AUDIT_DIR` として記録する: `.claude/state/security-audit/<YYYY-MM-DD>/`（`findings/` / `verdicts/` サブディレクトリ付き。`.claude/state/` は gitignore 済み）。
4. **再開判定**: `$AUDIT_DIR/findings/*.md`・`$AUDIT_DIR/verdicts/*.md` に前回成果物があれば、完了済みセルを特定し、**未完セルのみ**を Step 2 / 3 で起動する。
5. タスク管理ツールで Step 単位・wave 単位のタスクリストを作成する。

## Step 1: 監査マトリクス確定（自律）

1. profile と下記「監査次元カタログ」を Read する。
2. profile の監査対象マップ（領域 × 次元）から**監査マトリクス**を組み立てる。引数 `scope` があれば該当領域・パスに絞る。除外規定（profile）を適用する。
3. 以下をユーザーへ**報告のみ**行い、承認を待たずに Step 2 へ進む:
   - 監査マトリクス（セル一覧 = auditor subagent 数）と除外領域・根拠
   - 同時実行数の上限（既定 6〜8。超過分は wave 内で順次投入）
   - issue 起票の既定方針（Critical / High は個別 issue、Medium / Low はまとめ issue）
4. 実行中にユーザーから訂正が入った場合はマトリクス・方針へ反映して継続する。

## Step 2: 監査 wave（auditor 並列）

マトリクスの各セルについて、下記「auditor プロンプト骨格」にセル固有情報（次元チェックリスト・対象パス・PJ 固有の正本規約/要件・出力先）を埋め、実装モデルの subagent（バックグラウンド実行）で起動する。

- 出力先: `$AUDIT_DIR/findings/<dimension>-<area-slug>.md`（ファイルベースのハンドオフ）
- auditor は **read-only 運用**（`$AUDIT_DIR` 配下への Write のみ許可。対象コードの修正・Edit は禁止）をプロンプトで明示する
- 同時実行は Step 1 で確定した上限まで。完了通知を受けたら次セルを投入する
- **途中停止への対応**: 完了通知の result が途中経過文・タイムアウトのときは、findings ファイルの既出セクションを確認し、「前任の進捗 + 残観点」を明記した再開プロンプトで新 subagent を起動する

全セルの findings ファイルが揃ったら wave 完了。

## Step 3: 反証 wave（verifier → 最終判定）

1. **dedup（オーケストレーター自身）**: 全 findings を読み、同一根本原因の指摘を統合する（同一 file:line・同一設定値に対する別次元からの指摘は 1 finding に束ね、次元タグを併記）。明白な誤検知（除外規定該当・テストフィクスチャのダミー値等）はこの時点で棄却理由付きで落としてよい。
2. **verifier 起動**: 残った各 finding について、下記「verifier プロンプト骨格」で subagent を起動する。verifier の任務は**反証**（成立条件を崩す証拠探し）であり、追認ではない。出力先: `$AUDIT_DIR/verdicts/<finding-id>.md`
   - Critical / High 仮判定の finding は **2 verifier**（観点を変えて: 到達可能性 / 既存緩和策の有無）、Medium 以下は 1 verifier を割り当てる
3. **最終判定（オーケストレーター自身）**: auditor の主張と verifier の反証を突き合わせ、finding ごとに CONFIRMED / REJECTED / UNCERTAIN と最終 severity を**自ら根拠を検証して**確定する。subagent の報告は鵜呑みにせず、Critical / High は該当コードを必ず直接 Read して裏取りする。UNCERTAIN は棄却せずレポートの「要追加調査」に残す。

## Step 4: レポート統合

下記「レポート様式」で、CONFIRMED / UNCERTAIN の findings と棄却済み指摘（透明性のため）を 1 本のレポートに統合する。出力先は `docs/audit/` 配下（命名規約は `docs/audit/README.md`。profile で上書きしている場合はそちらに従う）。

- severity 定義・findings 一覧表・詳細・カバレッジ制限（監査しなかった領域とその理由）を必ず含める
- 機微な取り扱い: レポートに実シークレット値・悪用の逐次手順（PoC exploit コード）を転記しない。`file:line` と成立条件までに留める。対外公開区画へは転記しない（追加規定は profile）

## Step 5: レポート PR 作成

レポートをコミットし（`docs: <日付> セキュリティ監査レポートを追加` 等）、push して **通常 PR** を作成する（`--draft` は使わない → `docs/harness/skills/shared/sync-pr-flow.md` §4）。PR body は `docs/harness/skills/shared/pr-creation.md` に従う。セキュリティ監査レポートは起票元 issue を持たない保守 PR のため closing keyword は付けない（`docs/styles/team-feedback/pr-closing-keyword.md` の「起票元 Issue が無い保守 PR は省略」に従う）。レポート本文に機微な脆弱性詳細を含むため公開範囲に注意する。

## Step 6: issue 起票（自律）

1. **起票対象の確定**: CONFIRMED findings を severity 順に整理し、既定方針（Critical / High は 1 finding = 1 issue、Medium / Low は severity ごとにまとめ issue）で起票対象を確定してユーザーへ報告する（承認待ちなし）。UNCERTAIN・REJECTED は起票しない（レポートには残す）。
2. **起票**: `/create-issue`（`docs/harness/skills/create-issue.md`）とフィールド規約（`.claude/skills/create-issue/references/project-fields.md`）に従い、profile の「issue 化規約」（milestone・ラベル・severity → priority マッピング）を適用して起票する。各 issue body には finding の再現条件・影響・該当 `file:line`・推奨対策・レポートへのリンクを含める。
3. **レポート追記**: 起票した issue 番号を findings 一覧表に追記し、PR を更新する。

## 監査次元カタログ（汎用）

基盤: OWASP Top 10 (2021) / OWASP ASVS 4.0 / CWE。auditor は担当セルについて、各次元の「観点」が violated でないかを能動的に確認し、「証拠」（`file:line` + 成立条件）を収集する。

| ID | 次元 | 観点（典型的な失敗パターン） |
|----|------|------------------------------|
| D1 | 認証・セッション | 認証必須エンドポイントの網羅 / トークン・キー検証の位置 / 失効。失敗例: 認証を個別 handler 任せにして抜け漏れ、一定比較でないキー照合 |
| D2 | 認可・アクセス制御 | リソース所有者検証（IDOR/BOLA）/ テナント・組織スコープの強制 / 権限昇格経路。失敗例: ID 直参照で所有者チェックなし、テナント ID を入力から信頼 |
| D3 | シークレット・鍵管理 | ハードコード秘密 / 保管方式 / 最小権限 / ライフサイクル。失敗例: コード・設定への直書き、過剰な権限スコープ |
| D4 | インジェクション | SQL/NoSQL/コマンド/テンプレートへの入力混入。失敗例: 文字列連結クエリ、シェル呼び出しへの未検証入力 |
| D5 | 入力検証・逆シリアライズ | 全外部入力のスキーマ検証 / mass assignment / prototype 汚染。失敗例: リクエストボディの丸ごと展開 |
| D6 | 暗号 | 乱数源（CSPRNG か）/ タイミングセーフ比較 / アルゴリズム選定 / IV・nonce 再利用回避 |
| D7 | SSRF・アウトバウンド通信 | ユーザー指定 URL フェッチの検証 / 内部ホスト遮断 / リダイレクト追従制御 |
| D8 | エラー処理・情報漏洩 | 本番エラーでの内部情報露出回避 / 例外の握り潰し回避 / fail-safe な既定 |
| D9 | ロギング・機微情報の露出 | 秘密・個人情報の redaction / 監査ログの完全性 / 過不足のないイベント記録 |
| D10 | 依存・サプライチェーン | バージョン固定 / 既知脆弱性（CVE）/ lockfile 整合 / 出所不明パッケージ |
| D11 | レート制限・リソース枯渇 | ペイロード上限 / タイムアウト / ReDoS / ページネーション上限 |
| D12 | 業務ロジック・冪等性・競合 | 冪等キー / 二重実行防止 / TOCTOU・race / 数量・金額の境界 |
| D13 | 設定・セキュリティヘッダ・CORS・IaC | セキュリティヘッダ / CORS 許可元限定 / 危険な既定値 / IaC の秘密混入・公開設定 |

ドメイン固有次元（例: 特定プロトコル・特定実行環境）は profile の「追加監査次元」に定義し、本カタログはドメイン非依存に保つ。

## findings スキーマ（auditor / verifier 共通）

各 finding は以下の Markdown ブロックで記述する（1 ファイルに複数可）:

```markdown
### <finding-id: 次元ID-領域slug-連番。例 D2-api-01>

- **title**: <一文で脆弱性を述べる>
- **dimension**: <D1〜D13 / ドメイン次元>
- **severity(仮)**: Critical | High | Medium | Low | Info
- **location**: <file:line>（複数可）
- **precondition**: <成立条件: どの入力 / どの権限 / どの状態か>
- **path**: <入力 → 到達経路 → 影響。具体的に>
- **impact**: <何が起きるか（機密性/完全性/可用性のどれにどう）>
- **evidence**: <該当コード引用（数行）>
- **recommendation**: <推奨対策（実装方針。具体コードまでは不要）>
- **confidence**: high | medium | low（auditor の自己評価）
```

証拠（`file:line` + 引用）を伴わない指摘は**書かない**。推測のみの懸念は末尾「## 未確認の懸念」に分離する。

## auditor プロンプト骨格（Step 2）

```
あなたは本リポジトリのセキュリティ監査 auditor です。担当セルを read-only で監査し findings を出力します。

## 担当セル
- 次元: <D 番号: 次元名>（観点は次元カタログの該当行）
- 対象領域: <領域名> / 対象パス（この範囲のみ精査）: <glob / ディレクトリ>

## この領域の正本規約・要件（PJ 固有 — 逸脱は finding 候補）
<profile から該当領域の正本規約パス・脅威モデル・要件 ID を貼る>

## 運用制約（厳守）
- **read-only**: 対象コードを Edit / Write しない。**出力は <AUDIT_DIR>/findings/<dimension>-<area-slug>.md への Write のみ**
- Read / Grep / Glob / 読み取り系 Bash / Web 検索（CVE 確認）を使う
- 証拠主義: 全 finding に file:line と成立条件・到達経路・影響を付ける。付けられないものは「未確認の懸念」へ
- 誤検知抑制: テストフィクスチャ・サンプルのダミー値・既に緩和策がある箇所は finding にしない（迷えば confidence: low で記録）
- 除外規定（この範囲は監査しない）: <profile の除外規定>

## 出力
1. findings スキーマで <AUDIT_DIR>/findings/<dimension>-<area-slug>.md に書き出す
2. 最終報告に: 発見 finding 数 / severity 内訳 / 最重要 finding の 1 行要約 / 監査できなかった箇所と理由
```

## verifier プロンプト骨格（Step 3）

```
あなたは本リポジトリのセキュリティ監査 verifier です。与えられた 1 finding を **反証**（成立を疑い崩す）します。
追認ではなく、成立条件を否定する証拠を探すのが任務です。

## 対象 finding
<finding ブロックをそのまま貼る>

## 反証観点
- 到達可能性: precondition/path は実際に到達可能か。認証・認可・入力検証・型/スキーマで手前で弾かれないか
- 既存緩和策: 指摘箇所の前後・ミドルウェア・フレームワーク既定・設定で既に緩和されていないか
- 影響の正確性: impact は誇張でないか。実際の権限/データ範囲でどこまで起きるか

## 運用制約
- **read-only**: Edit / Write は <AUDIT_DIR>/verdicts/<finding-id>.md のみ。対象コードは変更しない
- 該当 file:line と周辺・呼び出し元を必ず自分で Read して裏取りする

## 出力（<AUDIT_DIR>/verdicts/<finding-id>.md）
- **verdict**: CONFIRMED | REJECTED | UNCERTAIN
- **reason**: 反証の結果（到達不能なら遮断箇所の file:line、緩和策ありならその file:line、成立するなら成立を示す経路）
- **adjusted_severity**: 反証を踏まえた severity（降格/据え置き/根拠付き昇格）
- 最終報告に verdict と 1 行根拠を返す
```

## レポート様式（Step 4）

severity 定義:

| severity | 基準（悪用可能性 × 影響） | 起票既定 |
|----------|--------------------------|----------|
| Critical | 認証なし/低権限で悪用可能かつ、鍵・全テナントデータ・完全性の即時侵害に至る | 1 finding = 1 issue（`priority:critical`） |
| High | 悪用に一定条件を要するが、特定テナント/リソースの機密・完全性を侵害する | 1 finding = 1 issue（`priority:high`） |
| Medium | 悪用条件が厳しい、または影響が限定的 | severity 単位でまとめ issue（`priority:medium`） |
| Low | 深層防御の欠如・軽微な情報露出 | severity 単位でまとめ issue（`priority:low`） |
| Info | 脆弱性ではないが記録すべき観察・ハードニング提案 | 起票任意（レポート記載のみ） |

レポート構造（この順で必須）:

1. **サマリ** — 監査範囲（領域×次元セル数）/ 使用モデル / severity 別件数（CONFIRMED のみ計上）/ 最重要所見 1〜3 行
2. **findings 一覧** — `| ID | severity | 次元 | title | location | verdict | issue |` の表（verdict = CONFIRMED / UNCERTAIN。issue は Step 6 で追記）
3. **finding 詳細（severity 降順）** — findings スキーマ + verification（verifier verdict とオーケストレーターの裏取り結果）
4. **要追加調査（UNCERTAIN）** — 次アクションを添える
5. **棄却一覧（透明性のため）** — REJECTED とした指摘と棄却理由（到達不能/緩和策あり/誤検知）
6. **カバレッジと制限** — 監査した/しなかった領域×次元とその理由。静的レビュー中心で悪用可能性は PoC 未確認である旨

記載原則: 沈黙で網羅を装わない / CONFIRMED のみをサマリ件数に計上 / 各 finding は `file:line` と再現条件を必ず伴う / 実シークレット値・悪用手順の過度な詳細を転記しない。

## 制約・原則

- **read-only 監査**: auditor / verifier は対象コードを一切 Edit しない（監査と修正を分離。修正は別途 `/multi-issue` 等のフローへ）
- **証拠主義**: 全 finding は `file:line` と具体的な成立条件を伴う。伴わない指摘はレポートに載せない
- **反証優先**: verifier と最終判定は「成立を疑う」姿勢を既定とし、到達不能・既存緩和策ありのものは REJECTED / severity 降格する
- **subagent 報告を鵜呑みにしない**: Critical / High はオーケストレーター自身が直接 Read して裏取りする
- **カバレッジの明示**: 監査しなかった領域・次元は必ずレポートに「制限」として記録する
- **汎用/PJ 固有の分離を保つ**: 対象リポジトリ固有の事実は profile にのみ書く

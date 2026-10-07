# Refactorer Profile — 検出コマンド・必読ガイド・対象範囲

> この文書は refactorer agent が検出フェーズで Read する PJ 固有 profile である。検出フロー・観点分類・Issue 化の手順は書かない（`.claude/agents/refactorer.md` が正本）。
>
> 記入指示: bootstrap 時に、対象プロジェクトの言語スタックと `docs/styles/coding_guide/` の実際の構成に合わせて `TODO(...)` を埋める。`TODO(取得方法: ...)` は環境から取得して確認する値、`TODO(記入方法: ...)` はチームが決めて書く値である。言語・ガイドを追加/削除したら本表も同一 PR で更新する。
>
> 未記入の扱い: `TODO(` で始まる項目は、refactorer が未記入として読み飛ばし、完了報告に未記入の件数を載せる。埋めるまでは「共通（言語非依存）」の検査だけが有効になる。

## 必読ガイド一覧

refactorer は検出の前に以下を全て Read する（未記入の行を除く）。

| ドキュメント | 目的 |
|-------------|------|
| `docs/styles/refactoring_guide.md` | 検出基準・承認済み観点の把握 |
| `docs/styles/coding_guide/INDEX.md` | ガイド一覧の起点（掲載ガイドを全て読む） |
| `docs/styles/coding_guide/code-comments.md` | コードコメント規約 |
| `docs/styles/coding_guide/testing_principles.md` | テスト記述規約 |
| TODO(記入方法: PJ の主要言語の規約ガイド `docs/styles/coding_guide/<language>.md` を作成し、1 言語 1 行で追加する) | 言語規約 |
| TODO(記入方法: 採用するデザインパターン規約 `docs/styles/coding_guide/<pattern>.md` ごとに行を追加する) | デザインパターン規約 |

## 対象範囲と除外

検出コマンドと目視検査の対象は次のとおり。参照元の探索（未参照の判定など）は、対象範囲外からの参照を見落とさないよう、リポジトリ全体で行う。

| 項目 | 値 |
|------|-----|
| 検査対象パス | TODO(記入方法: 検査対象のパス glob。例: `apps/**`, `packages/**`) |
| 除外パス | TODO(取得方法: 生成物・migration 履歴・submodule・依存／ビルド成果物のパスを、`.gitignore`・`.gitmodules`・ビルド設定から列挙する) |

### 削減候補の反証と公開面

`docs/styles/refactoring_guide.md` の「コード量削減の観点」で、未参照・未使用と判定した候補は、起票の前に次の参照が無いことを確かめる。確かめられない候補は起票しない。

- 動的 import・文字列によるシンボル解決・reflection 的な参照
- 設定ファイル・CI・スクリプトからの参照
- 実行時の分岐（環境変数・feature flag）でだけ到達するコード

| 項目 | 値 |
|------|-----|
| 採用スタック固有の動的参照の形 | TODO(記入方法: 例: 設定ファイルに書かれたモジュール名、プラグイン登録、DI コンテナへの名前登録) |
| 公開面（公開 API・公開パッケージ・外部契約）の範囲 | TODO(記入方法: 公開面に当たるパスまたは glob。該当候補は Issue に後方互換を壊す可能性を明記する) |

## 検出コマンド表

`origin/main` 最新のコードに対して実行する。refactorer は HEAD が `origin/main` と異なるとき、`origin/main` を detach した一時 worktree のルートでコマンドを実行する。依存のインストールを要するコマンド（lint など）が worktree 内で動かない場合、refactorer は実行せず、完了報告にその旨を明記する。

ヒット = 即 Issue ではなく、`refactoring_guide.md` の検出基準と突き合わせて観点にグルーピングする材料とする。

### 共通（言語非依存・既定で有効）

```bash
# lint の警告・エラーを一次シグナルとして収集する（コマンド定義は docs/harness/skills/shared/verification-gates.md）
pnpm run lint 2>&1 | grep -E "error|warning"

# 放置マーカーの棚卸し（bootstrap 時に --include で PJ の対象拡張子へ絞り込む）
grep -rn 'TODO\|FIXME\|HACK' apps/ packages/
```

### 言語別（bootstrap 時に記入）

| 検査対象 | コマンド | 根拠ガイド |
|---------|---------|-----------|
| TODO(記入方法: 言語規約の機械的検出項目を 1 行 1 検査で列挙する) | TODO(記入方法: 検査に使う grep / lint コマンド) | TODO(記入方法: 根拠となる `docs/styles/coding_guide/<language>.md` の該当規約) |

記入例（TypeScript を採用した場合。実際の規約ガイドに対応する行だけを残す）:

| 検査対象 | コマンド | 根拠ガイド |
|---------|---------|-----------|
| default export の使用 | `grep -rn "export default" --include="*.ts" --include="*.tsx" apps/ packages/` | 言語ガイドの named export 規約 |
| namespace import の乱用 | `grep -rn "import \*" --include="*.ts" --include="*.tsx" apps/ packages/` | 言語ガイドの import 規約 |
| `any` 型の使用 | `grep -rn ": any" --include="*.ts" --include="*.tsx" apps/ packages/` | 言語ガイドの型安全規約 |
| 素の `throw new Error` | `grep -rn "throw new Error" --include="*.ts" --include="*.tsx" apps/ packages/` | エラーハンドリング規約 |

<!-- <additional-language-check>: 言語を追加する場合は、その言語の lint 実行コマンドと
     規約違反を機械的に拾える grep をここに追記する。 -->

### 機械的検出で判断できない観点（コードを読んで判断）

デザインパターン規約を採用している場合、以下の型の違反は grep では判断できないため、対象コードを読んで判断する。bootstrap 時に、採用したガイドの原則 ID と対応付けて具体化する。

- TODO(記入方法: 例「データアクセス層へのビジネスロジック混入（<pattern>.md の該当原則）」)
- TODO(記入方法: 例「interface 未定義のまま具象へ依存（依存性注入規約の該当原則）」)
- TODO(記入方法: 例「合成ルート外での直接生成・環境変数の直接参照（依存性注入規約の該当原則）」)
- TODO(記入方法: 例「外部 SDK / プラットフォーム固有 API のサービス層直接使用（Adapter 未経由）」)
- TODO(記入方法: 例「カスタムエラー階層の未使用・エラーメッセージ文字列での分岐（エラーハンドリング規約の該当原則）」)

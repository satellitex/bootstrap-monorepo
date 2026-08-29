# Refactorer Issue Template

> この文書は refactorer agent の Issue 作成フェーズで使う `gh issue create` コマンドと Issue body テンプレートである。検出・観点分類の手順は書かない（`.claude/agents/refactorer.md` が正本）。

観点ごとに 1 件、以下のコマンドで Issue を作成する。ラベルは `refactor:proposal`。

```bash
gh issue create \
  --title "refactor: {観点タイトル}" \
  --label "refactor:proposal" \
  --body "$(cat <<'EOF'
## 観点

{この観点が何を問題とし、なぜ改善すべきか — 2〜3 文}

## 根拠ガイド

- ガイド: {docs/styles/coding_guide/xxx.md}
- 原則 ID / 見出し: {原則 ID 型ガイドなら R1, D4 等の ID。ルール散文型ガイドなら該当見出し}
- チェックリスト項目: {該当するチェックリスト項目を引用}

## 優先度

{Critical / Must / Should / Nice} — {理由}

## 検出結果

| ファイル | 行 | 内容 |
|---------|-----|------|
| `{path}` | {line} | {該当コード抜粋} |
| ... | ... | ... |

## 修正方針

{どう変えるか — 具体的な Before/After コード例}

## 受入条件

- [ ] 該当する全箇所が修正されている
- [ ] `docs/harness/skills/shared/verification-gates.md` に定義された検証ゲートが全て PASS している
- [ ] `docs/styles/refactoring_guide.md` の承認済み観点に追記されている
- [ ] 既存テストが変更なしでパスする（振る舞い変更がないことの証明）

## 影響範囲

- 対象パッケージ: {apps/xxx, packages/yyy, ...}
- 変更ファイル数（見込み）: {N} 件
- テストへの影響: {なし / テスト追加が必要 / テスト修正が必要}

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

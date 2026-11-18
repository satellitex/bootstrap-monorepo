---
name: persona-test
description: 利用者の視点でプロダクトの問題点を集めたい場合に使う。ペルソナを策定し、subagent に画面なしの独立したブラウザで公開面と検証環境を触らせ、改善してほしい点・理由・理想の形の feedback を画面の画像つきで送り先に送る
---

# /persona-test

正本は `docs/harness/skills/persona-test.md`。これを読み、記載の手順どおり実行する。
プロジェクト固有値は本ディレクトリの `references/target-profile.md` を参照する。

実行基盤の注記（Claude Code）: テスターと点検役は Agent tool の `general-purpose` で起動し、同じペルソナのパートは SendMessage で同じ subagent を続けて使う。

# multi-issue のモデル指定と subagent 起動の profile（Claude Code）

この文書は `/multi-issue` を Claude Code で実行するときの、モデル名と subagent 起動パラメータの profile である。手順・役割分担・判断基準は書かない（正本は `docs/harness/skills/multi-issue.md`）。

## モデル指定

| 区分       | 指定するモデル                                                                                     |
| ---------- | -------------------------------------------------------------------------------------------------- |
| 上位モデル | TODO(取得方法: 導入先で使えるモデルの一覧から、計画と検収に使う最上位のモデル名を確認して記入する) |
| 実装モデル | TODO(取得方法: 同上。実装とレビューに使う、費用の低いモデル名を確認して記入する)                   |

Planner と sub-planner には上位モデルを、worker と Reviewer には実装モデルを指定する。

## subagent の起動

- worker と Reviewer は subagent（バックグラウンド実行）として起動する。
- review skill は subagent の中で実行する。
- worker は `.claude/` 配下への新規ファイルの書き込みを権限拒否される場合があり、その場合は Planner が代行する。

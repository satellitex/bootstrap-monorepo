# フィードバックの受付設定

使うサービスの行だけを残す。受付を複数持つ場合は行を増やす。bot ID・チャンネル ID・承認者 ID は資格情報を含まない識別子。実行環境には受付ごとに対応する provider・チャンネル・資格情報を設定する。

| `FEEDBACK_PROVIDER` | `FEEDBACK_CHANNEL_ID`                                      | bot の user ID                      | 承認する人の user ID                                         | 親投稿のリンクを作るための値                                              |
| ------------------- | ---------------------------------------------------------- | ----------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------- |
| `slack`             | TODO(取得方法: 受付チャンネルの詳細から ID をコピー)       | TODO(取得方法: bot token で whoami) | TODO(取得方法: 承認者のプロフィールからメンバー ID をコピー) | TODO(取得方法: メッセージリンクからワークスペースの HTTPS オリジンを確認) |
| `discord`           | TODO(取得方法: 開発者モードで受付チャンネルの ID をコピー) | TODO(取得方法: bot token で whoami) | TODO(取得方法: 開発者モードで承認者のユーザー ID をコピー)   | TODO(取得方法: サーバー ID をコピー)                                      |

Slack の親投稿は `<workspace-origin>/archives/<channel-id>/p<ドットを除いた親ID>`、Discord の親投稿は `https://discord.com/channels/<guild-id>/<channel-id>/<親ID>` を使う。設定時に各チャンネルでコピーした親投稿リンクとの一致を確認する。

## Slack

- Slack アプリの bot を受付チャンネルに招待する。ボットには公開チャンネルの `channels:history` または非公開チャンネルの `groups:history`、返信用の `chat:write`、リアクションの `reactions:read`・`reactions:write`、添付の `files:read` を付与する。[conversations.history](https://docs.slack.dev/reference/methods/conversations.history/) / [chat.postMessage](https://docs.slack.dev/reference/methods/chat.postMessage/) / [reactions.get](https://docs.slack.dev/reference/methods/reactions.get/) / [reactions.add](https://docs.slack.dev/reference/methods/reactions.add/) / [files.info](https://docs.slack.dev/reference/methods/files.info/)
- bot token を `SLACK_FEEDBACK_BOT_TOKEN` に設定する。実際のチャンネルのスレッドで `replies` を確認し、読み取り専用の user token が必要な場合のみ、受付の履歴スコープを持つ token を `SLACK_FEEDBACK_READ_TOKEN` に設定する。返信と 👀・🏁 の付与には bot の資格情報を使う。[conversations.replies](https://docs.slack.dev/reference/methods/conversations.replies/)

## Discord

- サーバーの通常のテキストチャンネルを用意し、導入した bot に `VIEW_CHANNEL`、`READ_MESSAGE_HISTORY`、`SEND_MESSAGES`、`CREATE_PUBLIC_THREADS`、`SEND_MESSAGES_IN_THREADS`、`ADD_REACTIONS` を許可する。投稿者と承認者にもスレッドの表示・発言・リアクションに必要な権限を与える。bot token を `DISCORD_FEEDBACK_BOT_TOKEN` に設定する。[Channels Resource](https://docs.discord.com/developers/resources/channel) / [Threads](https://docs.discord.com/developers/topics/threads) / [Message Resource](https://docs.discord.com/developers/resources/message)
- アプリの Bot 設定で `MESSAGE_CONTENT` を有効にし、Discord が審査を要求する場合は承認済みであることを確かめる。通常投稿の本文と添付は REST で読む場合にもこの設定が必要。最初の試験には bot をメンションしない通常の投稿を使う。[Gateway](https://docs.discord.com/developers/events/gateway#message-content-intent)

## 運用値

| 項目                                        | 初期値・記入方法                                                                                                                                                                              |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 新規投稿の収集範囲                          | 直近 30 日。長期間停止した場合は前回の成功時刻まで広げる                                                                                                                                      |
| Issue のラベル                              | [Project のラベル体系](../../create-issue/references/project-fields.md#ラベル体系) の出所・自動実装・着手・起票元の各ラベルを使い、routine 登録前に実在を確かめる                             |
| Issue・コメントを書き込む GitHub アカウント | TODO(取得方法: 起票に使う認証でアカウントを確認し、印を記録するアカウントを記入)                                                                                                              |
| 実装 run の上限                             | 3 Issue。残りは後続の run が扱う                                                                                                                                                              |
| 配布完了の根拠                              | TODO(記入方法: 本番環境または配布先、PR と配備した版の照合方法、成功を確認する検証と記録 URL の取得方法を既存 runbook から記入。本番環境がなければ配布した版と配布完了を示すイベントを決める) |

## 導入時の確認

1. Node.js 22 以降を用意する。資格情報は人間が実行環境の secret または git 管理外のルート `.env` に投入し、ここには値を書かない。
2. 受付先ごとに `whoami`、`history`、既存スレッドの `replies` で、人間の投稿本文・添付・人間のリアクションの user ID を読めることを確認する。
3. `/feedback-triage --dry-run` で予定だけを確認する。テスト用の通常投稿に実行して起票案を出し、承認者以外の ✅ では Issue ができず、承認者の ✅ で一つだけできることを確かめる。同じ入力で再実行し、返信と Issue の件数を照合する。
4. 実装 routine は `/feedback-implement --dry-run` から始める。検証用の変更で、PR、マージ、配布の各記録と元スレッドへの返信を突き合わせてから [定期運用](../../../../docs/harness/scheduled-operations.md) に登録する。

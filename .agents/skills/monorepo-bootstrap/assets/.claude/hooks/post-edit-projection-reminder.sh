#!/usr/bin/env bash
set -euo pipefail

# PostToolUse Hook (opt-in:public-site): 内部正本（射影元ドキュメント）を Write / Edit
# したとき、公開版への射影が乖離する旨を additionalContext として注入し、sync skill の
# 実行（または同一ブランチでの射影反映）を促す。
#
# 内部正本だけ編集して公開版を追従させ忘れると、対外配信されるドキュメントが古いまま残る。
# 本 hook はその取りこぼしを編集直後に検知して通知するだけで、skill を機械実行はしない
# （注意喚起に徹する。射影の書き換えは人間 / skill の判断に委ねる）。
#
# 対象外ファイル・file_path 抽出不可の場合は何も出力せず exit 0
# （他の PostToolUse hook を妨げない）。

# --- 設定（採用 repo に合わせて変更する） --------------------------------------
# 各値は PROJ_PROJECTION_* の環境変数で上書きできる（テスト用の seam）。
# 射影元の内部正本（作業ツリーのルート基準。複数は ":" で区切る）。
TARGET_DOCS="${PROJ_PROJECTION_TARGET_DOCS:-docs/product/ARCHITECTURE.md}"
# 射影先の公開版ドキュメント。
PROJECTION_DOC="${PROJ_PROJECTION_DOC:-docs/product/PUBLIC_ARCHITECTURE.md}"
# 追従を促す skill 名。
SYNC_SKILL="${PROJ_PROJECTION_SYNC_SKILL:-/public-arch-sync}"
# 射影ルールの SSOT。
PROJECTION_RULES="${PROJ_PROJECTION_RULES:-.claude/skills/public-arch-sync/references/projection-rules.md}"
# -------------------------------------------------------------------------------

## --- 共通ユーティリティ読み込み ---
HOOK_UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/hook-utils.sh"
# shellcheck source=../bin/hook-utils.sh
source "$HOOK_UTILS"

input="$(cat)"
file="$(jq -r '.tool_input.file_path // .tool_input.path // empty' <<< "$input")"

# 対象は TARGET_DOCS のみ。作業ツリーのルート基準の相対パスに揃え、完全一致で判定する
# （絶対パス・相対パスのどちらでも判定できる）。
rel="$(normalize_repo_path "$file")"
[ -n "$rel" ] || exit 0
case ":${TARGET_DOCS}:" in
  *":${rel}:"*) ;;
  *) exit 0 ;;
esac

msg="$(
  cat <<MSG
[projection-sync リマインド] 内部正本 ${TARGET_DOCS//:/ } を編集しました。
これらは公開版 ${PROJECTION_DOC} の射影元です。
編集が一段落したら、公開版を必ず追従させてください:

- 公開版を別ブランチ・別 PR で更新する場合 -> ${SYNC_SKILL} を実行する（origin/main 基準で差分検出し PR を作成）。
- 公開版を本ブランチ・同一 PR で更新する場合 -> 射影ルール
  ${PROJECTION_RULES} に従い、編集内容を
  ${PROJECTION_DOC} へ反映する（具体サービス名・内部パス・内部参照 ID / 要件 ID を出さない）。

未反映のまま放置すると、対外配信されるドキュメントが古い状態のままになります。
MSG
)"

emit_hook_context PostToolUse "$msg"

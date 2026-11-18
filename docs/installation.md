# インストールと更新

`harness-adopt` は `monorepo-bootstrap` のテンプレート資産を使います。2 つのスキルを元の名前のまま、同じ skills ディレクトリに配置してください。

## npx skills

```sh
npx skills add satellitex/bootstrap-monorepo -g --skill '*' -a claude-code codex
```

`-g` はユーザー単位のインストールです。実体は `~/.agents/skills/` に置かれ、Claude Code からはリンクを通じて利用できます。プロジェクト単位の導入は `-g` を省略し、実体を各エージェントにコピーする場合は `--copy` を追加します。更新には `npx skills update`、削除には `npx skills remove` を使います。

## GitHub CLI

`gh auth login` で認証し、`gh skill install`（プレビュー）に各スキルのパスを指定します。次は Claude Code 用の例です。Codex 用には `--agent codex` を指定します。

```sh
gh skill install satellitex/bootstrap-monorepo .agents/skills/monorepo-bootstrap --agent claude-code --scope user
gh skill install satellitex/bootstrap-monorepo .agents/skills/harness-adopt --agent claude-code --scope user
```

パスを指定すると、配布用テンプレート内のスキルがインストール対象に混ざるのを防げます。更新には `gh skill update` を使います。更新用の `github-*` メタデータはインストール先に保持し、導入先へコピーしたスキルからは資産台帳の手順に従って取り除きます。[資産の適用手順](../.agents/skills/monorepo-bootstrap/assets/MANIFEST.md#使い方bootstrap-での適用手順)

## Codex の skill-installer

次のコマンドは Codex 用です。Claude Code 用にインストールする場合は、同じコマンドに `--dest ~/.claude/skills` を付けます。

```sh
INSTALLER=~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py
python3 "$INSTALLER" --repo satellitex/bootstrap-monorepo \
  --path .agents/skills/monorepo-bootstrap .agents/skills/harness-adopt
```

Codex のチャットで `$skill-installer` にリポジトリ名と上記の 2 つのパスを渡してもインストールできます。版を固定する場合は `--ref <タグまたはコミット>` を指定します。更新時は既存の 2 つのスキルをインストール先から外し、同じコマンドを再実行します。

## 手動コピー

このリポジトリを clone し、ルートから `.agents/skills/` 内の 2 つのディレクトリをコピーします。リポジトリ内の `.claude/skills/` はリンクなので、ダウンロードやコピーの元には `.agents/skills/` 側の実体を指定してください。

```sh
mkdir -p ~/.claude/skills
cp -R .agents/skills/monorepo-bootstrap .agents/skills/harness-adopt ~/.claude/skills/
```

Codex 向けにコピーする場合は、コピー先に `~/.agents/skills/` を使います。

## 起動時の確認

- Codex では次のターンでスキルを確認できます。表示されない場合は再起動してください。
- Claude Code のセッション開始後に `~/.claude/skills/` を初めて作った場合は、`/reload-skills` を実行します。
- 既存リポジトリに導入するときは、そのルートで起動します。別の場所から Claude Code を起動する場合は `claude --add-dir /path/to/target-repo` で対象を追加し、`/harness-adopt /path/to/target-repo` に絶対パスを渡します。
- テンプレートの保守中は、このリポジトリのスキルとインストール済みの同名スキルが見えることがあります。Claude Code では優先されるユーザー版を一時的に外し、Codex では編集中の版を選んで動作を確認します。

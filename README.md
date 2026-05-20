# what-why

コミット単位で **What（やること）** と **Why（なぜ）** を確定・記録する Claude Code 開発ワークフロー。

## これが解くこと

- 着手前に What を commit サイズへ分解・確定し、実装をスムーズにする
- 各 commit に What/Why を必ず添える（`commit-msg` hook が機械的に強制）
- What/Why を `WHAT-WHY.md` に living な形で集積する（PRD のように腐らせない）
- How はコード・git log に任せ、ドキュメントには持たせない

## 構成

| 構成要素 | 形式 | 役割 |
|---|---|---|
| `what-why-commit` | Skill（自動発火） | What確定フェーズ → 実装 → commit 整形 → WHAT-WHY.md 更新 |
| `what-why-init` | Skill（ユーザー起動） | リポジトリ初期化（commit-msg hook 設置・WHAT-WHY.md 作成） |
| SessionStart hook | hooks.json | 有効リポジトリでワークフローを毎セッション想起させる |
| `resources/commit-msg` | スクリプト | init が各リポジトリへ設置する git hook 本体 |

## インストール

1. このリポジトリをマーケットプレイスとして追加する:
   ```
   /plugin marketplace add <github-user>/<repo>
   ```
2. プラグインをインストールする:
   ```
   /plugin install what-why@fumiya-plugins
   ```

## リポジトリへの導入

ワークフローを使いたい git リポジトリで、Claude Code に「what-why を初期化して」と
頼む（`what-why-init` スキルが発火）。これで commit-msg hook の設置と `WHAT-WHY.md`
の作成が行われる。

`package.json` のあるリポジトリでは husky 経由で hook を設置するため、以降はチーム
メンバーが `install` するだけで hook が自動で入る。

## 巻き戻し

- プラグイン: `/plugin uninstall what-why@fumiya-plugins`
- リポジトリ側: `.husky/commit-msg`（または `.githooks/commit-msg`）を削除。husky を
  入れた場合は devDependency と `prepare` スクリプトを外す。

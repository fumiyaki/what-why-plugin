---
name: what-why-init
description: 現在の git リポジトリに What/Why ワークフローを導入する。commit-msg hook（husky 経由）の設置と WHAT-WHY.md の作成を行う。「what-why を初期化」「このリポジトリに what-why を入れて」「what-why-init」と言われた時に使う。
allowed-tools: Bash, Read, Write, Edit
---

# what-why-init

現在の git リポジトリに What/Why ワークフローを導入する。

## 手順

### 1. git リポジトリ確認

`git rev-parse --show-toplevel` でリポジトリルートを得る。git 管理外なら中止し、その旨を伝える。

### 2. commit-msg hook の設置

リポジトリルートに `package.json` があるか確認する。

**ある場合（husky 方式 — 推奨）**

- パッケージマネージャを判定する（`pnpm-lock.yaml`→pnpm / `yarn.lock`→yarn / それ以外→npm）。
- husky を devDependency に追加して初期化する。例（pnpm）:
  ```
  pnpm add -D husky && pnpm exec husky init
  ```
  これで `package.json` に `prepare` スクリプトが入り、以降は `install` 時に hook が
  全メンバーへ自動設置される（手動の `git config` 不要）。
- プラグイン同梱の検証スクリプトを `.husky/commit-msg` にコピーし、実行権限を付与する:
  ```
  cp "${CLAUDE_PLUGIN_ROOT}/resources/commit-msg" .husky/commit-msg
  chmod +x .husky/commit-msg
  ```

**ない場合（.githooks 方式）**

- `.githooks/` を作り、検証スクリプトをコピーして実行権限を付与する:
  ```
  mkdir -p .githooks
  cp "${CLAUDE_PLUGIN_ROOT}/resources/commit-msg" .githooks/commit-msg
  chmod +x .githooks/commit-msg
  git config core.hooksPath .githooks
  ```
- この方式では `core.hooksPath` がクローンごとのローカル設定になる。チームメンバーは
  各自1回 `git config core.hooksPath .githooks` を実行する必要がある旨を報告に明記する。

### 3. WHAT-WHY.md の作成

リポジトリに `WHAT-WHY.md` も `what-why/WHAT-WHY.md` も無ければ、`what-why/WHAT-WHY.md`
と `what-why/WHAT-WHY-grouping-history.md` を下記テンプレートで作成する。既にあれば作らない。

### 4. 報告

設置した hook 方式、作成したファイル、チームメンバーに必要な操作（husky 方式なら
`install` の実行、.githooks 方式なら `core.hooksPath` 設定）をまとめて伝える。

## WHAT-WHY.md テンプレート

```
# WHAT-WHY

このリポジトリの What と Why の正本。運用ルールは what-why-commit スキルに従う。

## やること（進行中）

<!-- 形式: - <達成したい状態> — なぜ: <理由> -->

（まだなし）

## やらないこと

<!-- 「放っておくと誰かがやってしまう／繰り返し提案される」ものだけ載せる -->

（まだなし）

## やったこと（完了）

<!-- グルーピング軸: 機能領域。同領域が3件以上で見出しを切る。 -->
<!-- 最終整理時の項目数: 0 -->

（まだなし）
```

## WHAT-WHY-grouping-history.md テンプレート

```
# WHAT-WHY グルーピング遍歴

「やったこと（完了）」を再整理するたび、採用した見出し集合をここに追記する。
連続2回で見出し集合が実質同じなら、グルーピングを固定してよい。

<!-- 形式:
## YYYY-MM-DD / 完了N件 / 第M回
- 見出しA
- 見出しB
変更: <前回からの差分。初回は「初回」と記す>
-->

（再整理はまだ行われていない）
```

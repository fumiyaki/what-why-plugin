# what-why

Issue を **grill（質問攻め）** で詰めてから、**What（やること）** と **Why（なぜ）** を
確定・記録する Claude Code 開発ワークフロー。

## これが解くこと

- 実装前に Issue を grill で詰め、仕様の曖昧さとドメイン用語のブレを潰す
- grill で固めた理解から What/Why を抽出し、`WHAT-WHY.md` 台帳へ具体的に記録する
- 台帳をドメイン（bounded context）単位で分割し、後から関連分だけ読めるようにする
- How はコード・commit メッセージ（git log）に任せ、台帳本体には持たせない

## 構成（3つの分離されたコンポーネント）

| 構成要素 | 形式 | 役割 |
|---|---|---|
| `/ww-flow` | Command | ワークフロー司令塔。並列実装・レビュー・結合・E2E まで統括する |
| `grill-with-docs` | Skill | grill フェーズ。仕様理解とドメイン用語集 `CONTEXT.md` の育成 |
| `what-why` | Skill | `WHAT-WHY.md` 台帳の構造・ドメイン分割・記録・commit 作法 |

## インストール

```
/plugin marketplace add fumiyaki/what-why-plugin
/plugin install what-why@fumiya-plugins
```

## 使い方

実装したい Issue を引数に `/ww-flow` を起動する。

```
/ww-flow https://github.com/owner/repo/issues/123
```

1. **Phase A — grill**: `grill-with-docs` が Issue を質問攻めで詰める。ドメイン用語は
   `CONTEXT.md` に育つ。
2. **Phase B — 抽出＋計画**: grill の理解から What/Why を抽出し `WHAT-WHY.md` へ、How は
   `what-why/tmp/` へ。Issue を PR 単位（Sub-issue or 中粒度グループ）に分割し、PR 依存
   グラフを作る。
3. **Phase C — 並列実装**: 依存グラフに従い実装メンバーを worktree 分離で並列 spawn。
   各メンバーが「1 What/Why = 1 commit」で実装し、fresh レビューメンバーが仕様だけ見て
   二段レビュー、問題は差し戻す。実装メンバーは残す。
4. **Phase D — 結合テスト**: 全 PR を結合してテスト。問題は担当メンバーへ差し戻す。
5. **Phase E — E2E ループ**: Playwright でローカル E2E を実行。失敗は原因を切り分けて
   担当メンバーへ差し戻し、green になるまで（シナリオ単位3回まで）繰り返す。
6. **Phase F — クリーンアップ**: メンバーをシャットダウン、git worktree を掃除、
   `what-why/tmp/` を破棄する。

## 台帳ファイル

- リポジトリに `CONTEXT-MAP.md` がある（複数 bounded context）場合、台帳は
  `what-why/<context-name>/WHAT-WHY.md` にドメインごと分割される。
- `CONTEXT-MAP.md` が無い場合は単一の `what-why/WHAT-WHY.md`。
- いずれも初回の What 記録時に自動作成される。

## 巻き戻し

- プラグイン: `/plugin uninstall what-why@fumiya-plugins`
- リポジトリ側: `what-why/` ディレクトリと、grill-with-docs が作った `CONTEXT.md` /
  `CONTEXT-MAP.md` を削除する。

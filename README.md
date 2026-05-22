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
| `/ww-flow` | Command | ワークフロー司令塔。人間が起動を判断する |
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
2. **Phase B — 抽出**: grill の理解から What/Why を抽出し `WHAT-WHY.md` へ、How は
   `what-why/tmp/` へ。
3. **Phase C — 実装ループ**: What を1つずつ実装し commit する。commit 書式は `COMMIT-FORMAT.md`
   に従う。
4. **Phase D — クリーンアップ**: Issue 完了で `what-why/tmp/` を破棄する。

## 台帳ファイル

- リポジトリに `CONTEXT-MAP.md` がある（複数 bounded context）場合、台帳は
  `what-why/<context-name>/WHAT-WHY.md` にドメインごと分割される。
- `CONTEXT-MAP.md` が無い場合は単一の `what-why/WHAT-WHY.md`。
- いずれも初回の What 記録時に自動作成される。

## 巻き戻し

- プラグイン: `/plugin uninstall what-why@fumiya-plugins`
- リポジトリ側: `what-why/` ディレクトリと、grill-with-docs が作った `CONTEXT.md` /
  `CONTEXT-MAP.md` を削除する。

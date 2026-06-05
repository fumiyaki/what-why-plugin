# コミットメッセージ書式

## テンプレート

```
<Why>のため<What>する

---

<how>
```

- 1行目（タイトル）: 「<Why>のため<What>する」。What は1行で言い切る動詞形。
  Why が自明 or 無い場合は「<What>する」だけでよい。
- 区切りに `---` を置き、その下に How を書く。
- How は最大5行。書くことが無ければ How ごと省略可。

## tmp の使い方

- grill フェーズで出た How と ADR は `what-why/tmp/working-notes.md` に蓄積されている。
- commit 時、この commit の What に対応する How/ADR を tmp から**読み取り**、
  How 欄へ最大5行で要約して畳み込む。tmp は読み取るだけで、ここでは削除しない。
- `what-why/tmp/` の削除は、ワークフロー全体の最終クリーンアップ（`/ww-flow` の Phase F）で
  **メインセッションだけが**行う。各 commit 時や個々のメンバーが削除してはいけない。途中で
  消すと、結合テスト・E2E の差し戻しで再 commit する際に参照すべき How/ADR が失われるため。
  永続記録は commit メッセージ（git log）に残る。

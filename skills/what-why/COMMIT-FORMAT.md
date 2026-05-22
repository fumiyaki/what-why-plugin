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
- commit 時、この commit の What に対応する How/ADR を tmp から取り出し、
  How 欄へ最大5行で要約して畳み込む。
- Issue の全 What を commit し終えたら `what-why/tmp/` ディレクトリごと削除する。
  永続記録は commit メッセージ（git log）に残るため tmp は消してよい。

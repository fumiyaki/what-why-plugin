---
description: Issue を grill-with-docs で詰め、What/Why を台帳に記録し、実装ループから tmp クリーンアップまでを束ねる開発ワークフロー。
argument-hint: "[Issue の URL / 番号 / 自由記述]"
---

# /ww-flow

引数で渡された Issue を起点に、grill フェーズ → What/Why/How 抽出 → 実装ループ →
クリーンアップ を進める開発ワークフロー。人間が「今回はこれを使う」と判断して起動する。

入力: $ARGUMENTS

## Phase A — grill

1. `$ARGUMENTS` が GitHub Issue の URL または番号なら `gh issue view` で本文を取得する。
   自由記述ならそのテキストを Issue 内容として扱う。
2. `grill-with-docs` スキルを起動し、Issue 内容を対象に grill を行う。
   - grill-with-docs は素のまま完走させる。grill 中に成果を仕分けようとしない。
     grill フェーズは grill だけを行う。
   - この Phase では実装に着手しない。
3. grill-with-docs が「共通理解に達した」と判断して終了するまで進める。grill の過程で
   ドメイン用語は `CONTEXT.md` に、3条件を満たす重い判断は `what-why/tmp/` に
   grill-with-docs 自身が書き出す。

## Phase B — 抽出

grill 完了後、grill の成果を仕分ける。

1. `what-why` スキルを読み込む。
2. grill で固まった理解から、commit サイズの What と対応する Why を抽出する。
   - What/Why は `what-why` スキルの記録ルールに従い、ドメイン知識を踏まえて
     具体的に記述する。
   - 書き込み先は `what-why` スキルの台帳ドメイン分割ルール（`CONTEXT-MAP.md` 参照）
     で決める。
   - 抽出した What/Why を該当台帳の「やること（進行中）」へ追記する。
3. grill で出た How（実装方針）を `what-why/tmp/working-notes.md` の「How」セクション
   へ書き出す。grill-with-docs が同ファイルへ書いた ADR と合わせ、tmp が実装ループの
   作業バッファになる。

## Phase C — 実装ループ

Phase B で台帳の「やること（進行中）」へ積んだ What を、上から順に処理する。
「やること」の What を1つずつ実装する。1 What 実装したら commit する。
commit の作法は `what-why` スキルおよび `COMMIT-FORMAT.md` に従う。
commit 後、その項目を台帳の「やること」から「やったこと」へ移す。

## Phase D — クリーンアップ

Issue の全 What を commit し終えたら `what-why/tmp/` ディレクトリを削除する。
永続記録は commit メッセージ（git log）に残る。

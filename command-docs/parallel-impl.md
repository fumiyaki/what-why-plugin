# Phase C — 並列実装（詳細手順）

Phase B で決めた PR 単位と依存グラフに従い、実装メンバーを spawn して各 PR を実装・
レビュー・完成させる。メインセッションが司令塔として全メンバーを spawn・統括する。

## チーム準備

1. まだチームが無ければ `TeamCreate` でチームを作る（team_name は Issue に紐づく分かり
   やすい名前にする）。
2. PR の一覧と依存グラフを TaskCreate で各 PR を1タスクとして登録し、依存は
   `addBlockedBy` で表現する。

## worktree 準備（メインが手動で行う）

`Agent` の `isolation: "worktree"` は使わない。チームメンバーには効かず、プライマリ作業
ツリーを汚染するため。メインが手動で worktree を作る。

3. 着手する PR について、メインが worktree を作成する:
   ```
   git worktree add <worktree-path> -b <pr-branch> <base-branch>
   ```
   - `<worktree-path>`: リポジトリ外の専用パス（例 `<repo>/../.ww-flow/<pr-key>`）。
   - `<pr-branch>`: PR 用ブランチ（例 `ww/<issue>/<pr-key>`）。
   - `<base-branch>`: **独立 PR は `main`（既定ブランチ）、依存 PR は依存元 PR のブランチ**。
     これにより依存 PR は依存元のコードが見える状態で実装でき、スタック PR を形成する。
   - メインは各 PR の `<worktree-path>` / `<pr-branch>` / `<base-branch>` / 担当メンバー名 /
     PR 仕様 を自分の記録として保持する（リカバリと統合に使う）。

## 実装メンバーの spawn

4. worktree を用意した PR について、実装メンバーを spawn する。
   - `Agent` を `team_name`（同じチーム）、`name`（PR が分かる名前、例 `impl-<pr-key>`）で
     起動する。`isolation` は指定しない。
   - 独立 PR は同一メッセージ内で複数 `Agent` を並列に呼んで同時 spawn する。
   - 同時 spawn 数に上限は設けない。依存グラフ上で独立な PR は全て同時に spawn する。
   - 依存 PR は依存元メンバーの PR 完成後に spawn する（依存元ブランチが確定してから）。
5. 各実装メンバーへ渡すプロンプトに含める内容:
   - **作業ディレクトリ**: 担当 worktree の絶対パス。「このパスの中だけで作業せよ」と明示する。
   - 担当 PR の仕様（担当 Sub-issue の本文、または PR グループの What/Why）。
   - 「1 What/Why = 1 commit」で実装し、commit 作法は `what-why` スキルと `COMMIT-FORMAT.md`
     に従うこと。
   - **台帳ファイル（WHAT-WHY.md / CONTEXT.md / what-why/tmp/）には触れないこと**。コードの
     commit のみ行い、実装した What/Why/How はメインへ報告すること（台帳反映はメインが行う）。
   - 実装が終わったらブランチを push し、PR を作成すること（PR の base は `<base-branch>`）。
     PR 番号と差分の git 範囲（base/head SHA）を報告すること。

## 台帳反映（メインが直列に行う）

6. 実装メンバーの報告（実装した What/Why/How）を受け、メインが該当ドメイン台帳の項目を
   「やること」→「やったこと」へ移し、How を `what-why/tmp/working-notes.md` に反映する。
   複数メンバーの報告が同時に来ても、メインが**直列に**台帳を更新する（競合を作らない）。

## レビューと差し戻しループ

7. 実装メンバーから「PR 完成」の報告を受けたら、メインが fresh のレビューメンバーを
   spawn する（`Agent` + `team_name`、name 例 `review-<pr-key>`）。
   - レビューメンバーには **PR の仕様と差分の git 範囲（base/head SHA）だけ**を渡す。
     実装メンバーの会話コンテキストは渡さない（pure なレビューにする）。
   - レビューは二段で行わせる: ①spec 準拠（仕様通りか・過不足が無いか）→ ②コード品質
     （明快さ・保守性・プロジェクト規約準拠）。①が通ってから②に進む。
8. レビューで問題が出たら、担当の実装メンバーへ `SendMessage` で具体的な修正内容を伝えて
   修正を依頼する。修正完了後、同じレビュー観点で再レビューする。通過するまで繰り返す。
9. レビュー通過したら、そのレビューメンバーを `SendMessage` の `shutdown_request` で
   シャットダウンする（レビューメンバーは使い捨て）。
10. 実装メンバーはシャットダウンしない。Phase D/E で再修正を依頼する可能性があるため残す。

## リカバリ（実装メンバーが落ちた時）

実装メンバーがコンテキスト枯渇・タイムアウト等で落ち、差し戻し先が不在の場合:

11. 対象メンバーが**完全に終了している**ことを team config の members から消えていることで
    確認する（shutdown 処理中の同名への再 spawn は挙動が曖昧になるため、完全終了を待つ）。
12. 同じ名前で実装メンバーを再 spawn する。再 spawn したメンバーは fresh コンテキストなので、
    メインが保持していた **担当 worktree パス・PR 仕様・現在の commit 状態** をプロンプトで
    再提供し、作業を継続させる。worktree はメンバーの寿命と独立してディスクに残るため
    再アタッチできる。

## 完了条件

13. 全 PR がレビュー通過・完成するまで 3〜12 を続ける。依存 PR は依存元の完成を待って
    spawn する。全 PR 完成で Phase D へ進む。

---
description: Issue を grill で詰め、PR 単位に分割してチームメンバーで並列実装・レビュー・結合・E2E まで統括する開発ワークフロー。
argument-hint: "[Issue の URL / 番号 / 自由記述]"
---

# /ww-flow

引数で渡された Issue を起点に、grill → 抽出＋計画 → 並列実装 → 結合テスト → E2E ループ →
クリーンアップ を進める開発ワークフロー。人間が「今回はこれを使う」と判断して起動する。

メインセッションは司令塔として全エージェントを spawn し、判断と統括に徹する。実作業
（実装・レビュー・E2E）はメンバーやサブエージェントへ委譲する。

入力: $ARGUMENTS

## エージェントモデル（全 Phase 共通の前提）

子エージェントを spawn できるのはメインセッションのみ。spawn されたメンバーは
さらに子を spawn できない。役割は対話継続の要否で2種類に分ける。

- チームメンバー（`Agent` + `team_name` + `name`）: `SendMessage` で対話継続でき、
  差し戻し→再対応ができる。実装・レビュー・E2E 実行に使う。
- 内部サブエージェント（`Agent`、`team_name` なし）: 結果だけ返す一発仕事に使う。
  E2E シナリオ作成・E2E 失敗の原因切り分けに使う。

寿命: 実装メンバーは永続（結合/E2E の再修正に備え残す）。レビューメンバー・E2E 実行
メンバー・各サブエージェントは使い捨て。

## Phase A — grill

1. `$ARGUMENTS` が GitHub Issue の URL または番号なら `gh issue view` で本文を取得する。
   自由記述ならそのテキストを Issue 内容として扱う。
2. `grill-with-docs` スキルを起動し、Issue 内容を対象に grill を行う。
   - grill-with-docs は素のまま完走させる。grill 中に成果を仕分けようとしない。
   - この Phase では実装に着手しない。
3. grill-with-docs が「共通理解に達した」と判断して終了するまで進める。grill の過程で
   ドメイン用語は `CONTEXT.md` に、3条件を満たす重い判断は `what-why/tmp/` に
   grill-with-docs 自身が書き出す。

## Phase B — 抽出＋計画

grill 完了後、成果を仕分けて実装計画を立てる。

1. `what-why` スキルを読み込む。
2. grill で固まった理解から、commit サイズの What と対応する Why を抽出し、該当ドメイン
   台帳（`what-why/<context-name>/WHAT-WHY.md`、単一コンテキストなら `what-why/WHAT-WHY.md`）
   の「やること（進行中）」へ追記する。ドメイン知識を踏まえ具体的に書く。
3. grill で出た How を `what-why/tmp/working-notes.md` の「How」セクションへ書き出す。
4. PR 単位を決める。`gh issue view --json` 等で親 Issue の Sub-issue を確認する。
   - Sub-issue があれば、各 Sub-issue を1 PR とする。
   - Sub-issue が無ければ、抽出した What を機能のまとまりで中粒度の PR グループにまとめ、
     各グループを1 PR とする。
   - どの PR 内でも「1 What/Why = 1 commit」を厳守する。
5. PR 依存グラフを構築する。各 PR について「先行 PR の成果に依存するか」を判定し、独立 PR
   と依存 PR を区別する。このグラフを Phase C で使う。

## Phase C — 並列実装

依存グラフに従い実装メンバーを spawn し、PR を実装・レビュー・完成させる。実装メンバーは
完成後も残す。詳細手順は [parallel-impl.md](./ww-flow/parallel-impl.md) に従う。

要約:
- 独立 PR は実装メンバーを worktree 分離で並列 spawn、依存 PR は依存元完了後に spawn。
- 各メンバーは「1 What/Why = 1 commit」で実装。
- メインが fresh レビューメンバーを spawn し、仕様と差分だけ渡して二段レビュー（spec 準拠
  → コード品質）。問題は実装メンバーへ差し戻し、通過でレビューメンバーをシャットダウン。

## Phase D — 結合テスト

全 PR 完了後、成果を結合してテストする。

1. 各 PR を依存グラフの順でマージ・結合する。
2. 対象プロジェクトのテストコマンドを推定する（`package.json` の scripts、`Makefile`、
   `README` 等から）。推定したコマンドをユーザーに提示し、実行してよいか確認してから走らせる。
3. 失敗したら、原因に対応する実装メンバーへ `SendMessage` で再修正を依頼し、再結合・
   再テストする。問題が解消するまで繰り返す。

## Phase E — E2E ループ

ローカル環境で Playwright による E2E を回す。詳細手順は [e2e-loop.md](./ww-flow/e2e-loop.md)
に従う。

要約:
- メインが内部サブエージェントを spawn し E2E シナリオ一覧を作らせる。
- メインが E2E 実行メンバーを spawn し、Playwright MCP でローカル環境に対し実行させる。
- 失敗時はメインが内部サブエージェントに原因（どの実装メンバーの漏れか）を切り分けさせ、
  該当メンバーへ差し戻して再 E2E。
- リトライはシナリオ単位で上限3回。超過したらユーザーに報告して停止する。

## Phase F — クリーンアップ

全工程完了後に後片付けする。

1. 全実装メンバー・残存メンバーを `SendMessage` の `shutdown_request` でシャットダウンする。
2. `git worktree remove` で各メンバーの worktree を除去し、マージ済みブランチを削除する。
3. `TeamDelete` でチームを削除する。
4. `what-why/tmp/` ディレクトリを削除する。永続記録は commit メッセージ（git log）に残る。

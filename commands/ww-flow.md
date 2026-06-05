---
description: Issue を grill で詰め、PR 単位に分割してチームメンバーで並列実装・レビュー・結合・E2E まで統括する開発ワークフロー。
argument-hint: "[Issue の URL / 番号 / 自由記述]"
---

# /ww-flow

引数で渡された Issue を起点に、grill → 抽出＋計画 →（任意で計画の可視化）→ 並列実装 →
結合テスト → E2E ループ → クリーンアップ を進める開発ワークフロー。人間が「今回はこれを
使う」と判断して起動する。

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

**共有資産の書き込みはメインのみ**: 台帳ファイル群（各ドメインの `WHAT-WHY.md`・
`CONTEXT.md` / `CONTEXT-MAP.md`・`what-why/tmp/`）への書き込みはメインだけが行う。実装
メンバーは担当 worktree 内の**コード commit のみ**を行い、台帳には触れない。複数メンバーの
同時書き込みによるロストアップデート・コンフリクトを防ぐため。

**worktree はメインが手動管理**: `Agent` の `isolation: "worktree"` は使わない（チーム
メンバーには効かず、プライマリ作業ツリーを汚染するため）。メインが `git worktree add` で
各 PR の作業ディレクトリ＋ブランチを作り、メンバーにパスを指示する。

**マージは人間**: ワークフローは各 PR を作成するところまで。main への取り込みは人間が
GitHub 上で行う。Phase D/E は push しないローカル統合ブランチで検証する。

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
   の「やること（進行中）」へ**メインが**追記する。ドメイン知識を踏まえ具体的に書く。
3. grill で出た How を `what-why/tmp/working-notes.md` の「How」セクションへ**メインが**書き出す。
4. PR 単位を決める。`gh issue view --json` 等で親 Issue の Sub-issue を確認する。
   - Sub-issue があれば、各 Sub-issue を1 PR とする。
   - Sub-issue が無ければ、抽出した What を機能のまとまりで中粒度の PR グループにまとめ、
     各グループを1 PR とする。
   - どの PR 内でも「1 What/Why = 1 commit」を厳守する。
5. PR 依存グラフを構築する。各 PR について「先行 PR の成果に依存するか」を判定し、独立 PR
   と依存 PR（どの PR の上に積むか）を区別して記録する。このグラフを Phase C の worktree
   ベース選択（独立=main、依存=依存元ブランチ）と Phase D の統合に使う。

## Phase B' — 計画の可視化（任意）

Phase C の実装に入る前に、メインはユーザーに「ここまでの計画（grill で固めた仕様理解・
ドメイン用語、台帳の What/Why・PR 単位・依存グラフ）を html-render スキルで HTML 化して
確認するか」を尋ねる。ユーザーが希望したら、メンバーを spawn し、Phase A・B の成果
（CONTEXT.md / 台帳 / PR 計画・依存グラフ）を渡して html-render を実行させる。不要と
言われたらそのまま Phase C へ進む。

## Phase C — 並列実装

依存グラフに従い実装メンバーを spawn し、PR を実装・レビュー・完成させる。実装メンバーは
完成後も残す。詳細手順は `${CLAUDE_PLUGIN_ROOT}/command-docs/parallel-impl.md` を読んで従う。

要約:
- メインが `git worktree add` で worktree を作る（独立 PR は main、依存 PR は依存元ブランチを
  ベースに）。独立 PR は並列 spawn、依存 PR は依存元完了後に spawn。
- 各メンバーは担当 worktree 内で「1 What/Why = 1 commit」実装し、コード commit のみ行う
  （台帳はメインが反映）。実装後ブランチを push し PR を作成する。
- メインが fresh レビューメンバーを spawn し、仕様と差分だけ渡して二段レビュー（spec 準拠
  → コード品質）。問題は実装メンバーへ差し戻し、通過でレビューメンバーをシャットダウン。
- 実装メンバーが落ちた場合は完全終了を確認してから同名再 spawn し、保持した worktree パス・
  PR 仕様・commit 状態を再提供して継続させる（リカバリ）。

## Phase D — 結合テスト

全 PR 完了後、成果を**ローカル統合**してテストする（main へはマージしない）。

1. ローカル統合する。単一の依存チェーンなら先端ブランチをそのまま使う。独立 PR が複数なら
   メインが `ww-flow/integration` ブランチを作り各 leaf ブランチをマージする（push しない）。
   マージ衝突は関係メンバーへ差し戻して解消する。
2. 対象プロジェクトのテストコマンドを推定する（`package.json` の scripts、`Makefile`、
   `README` 等から）。推定したコマンドをユーザーに提示し、実行してよいか確認してから走らせる。
3. 失敗したら、原因に対応する実装メンバーへ `SendMessage` で再修正を依頼し、再統合・
   再テストする。
4. リトライは**3回上限**。3回直しても green にならなければユーザーに報告して停止する。

## Phase E — E2E ループ

ローカル環境で Playwright による E2E を回す。詳細手順は `${CLAUDE_PLUGIN_ROOT}/command-docs/e2e-loop.md` を読んで従う。

要約:
- E2E は Phase D のローカル統合ブランチ（`ww-flow/integration` または単一チェーンの先端）を
  チェックアウトした環境に対して行う。
- メインが内部サブエージェントを spawn し E2E シナリオ一覧を作らせる。
- メインが E2E 実行メンバーを spawn し、Playwright MCP でローカル環境に対し実行させる。
- 失敗時はメインが内部サブエージェントに原因（どの実装メンバーの漏れか）を切り分けさせ、
  該当メンバーへ差し戻して再 E2E。
- リトライはシナリオ単位で上限3回。超過したらユーザーに報告して停止する。

## Phase F — クリーンアップ

全工程完了後にメインが後片付けする。

1. 全実装メンバー・残存メンバーを `SendMessage` の `shutdown_request` でシャットダウンする。
2. `git worktree remove` で各 worktree を除去し、ローカル統合ブランチ `ww-flow/integration` と
   不要なローカルブランチを削除する（PR 用ブランチは GitHub 上の PR が残るのでローカルのみ）。
3. `TeamDelete` でチームを削除する。
4. `what-why/tmp/` ディレクトリを**メインが**削除する。永続記録は commit メッセージ（git log）
   に残る。メンバーには tmp を削除させない。

なお、Phase D/E のリトライ上限超過や中断でワークフローが**異常停止**した場合は、ここで自動
クリーンアップせず、生存メンバーと各 worktree パスをユーザーに報告し、(a) 状態保持して手動
再開 / (b) 上記クリーンアップ実行 をユーザーに選ばせる。

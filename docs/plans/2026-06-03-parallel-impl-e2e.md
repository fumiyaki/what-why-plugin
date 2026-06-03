# /ww-flow 並列実装・E2E ループ拡張 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/ww-flow` コマンドを6 Phase（grill / 抽出＋計画 / 並列実装 / 結合テスト / E2E ループ / クリーンアップ）に拡張し、Issue を PR 単位に分割してチームメンバーで並列実装・レビュー・結合・E2E まで統括するワークフローにする。

**Architecture:** 司令塔のメインセッションが全エージェントを spawn する。実装/レビュー/E2E実行はチームメンバー（`Agent`+`team_name`）、E2Eシナリオ作成/原因切り分けは使い捨てサブエージェント（`Agent`、`team_name`なし）。コマンド本体 `commands/ww-flow.md` は全 Phase の流れと要約を持ち、複雑な Phase C/E の詳細手順は `commands/ww-flow/` 配下の補助 md に外出しする（progressive disclosure）。

**Tech Stack:** Claude Code プラグイン（Markdown コマンド定義）。実装メンバーは git worktree 分離（`Agent` の `isolation: "worktree"`）。E2E は Playwright MCP（`mcp__plugin_playwright__*`）。コードのビルド/テスト機構は無く、検証は構造チェック（grep/head）＋`plugin-dev:plugin-validator`＋設計書突き合わせで行う。

**設計書:** `docs/specs/2026-06-03-parallel-impl-e2e-design.md`

**対象リポジトリ:** `fumiyaki/what-why-plugin`（ブランチ `feat/parallel-impl-e2e`、設計書コミット `8590913` 済み）。

---

## ファイル構成（最終形）

```
what-why-plugin/
├── commands/
│   ├── ww-flow.md                    ← 修正（Phase B 以降を拡張、詳細は補助 md 参照に）
│   └── ww-flow/                      ← 新規ディレクトリ（Phase 詳細の外出し先）
│       ├── parallel-impl.md          ← 新規（Phase C の詳細手順）
│       └── e2e-loop.md               ← 新規（Phase E の詳細手順）
├── skills/                            ← 変更なし
│   ├── grill-with-docs/{SKILL.md, CONTEXT-FORMAT.md, ADR-FORMAT.md}
│   └── what-why/{SKILL.md, COMMIT-FORMAT.md}
├── docs/
│   ├── specs/2026-06-03-parallel-impl-e2e-design.md   ← コミット済み
│   └── plans/2026-06-03-parallel-impl-e2e.md          ← 本ファイル
└── README.md                          ← 修正（6 Phase・並列実装・E2E を反映）
```

各ファイルの責務:
- `commands/ww-flow.md`: ワークフロー全体の司令塔。6 Phase の流れと、各 Phase の要約・前提・エージェント種別を持つ。Phase C/E は要約＋補助 md への参照に留める。
- `commands/ww-flow/parallel-impl.md`: Phase C の詳細。依存グラフに従う実装メンバー spawn、worktree 分離、レビューメンバーによる二段レビューと差し戻しループ。
- `commands/ww-flow/e2e-loop.md`: Phase E の詳細。シナリオ作成サブエージェント、Playwright 実行メンバー、原因切り分けサブエージェント、シナリオ単位3回のリトライ上限。

---

## Task 1: ww-flow.md 本体を6 Phase 構成へ書き換える

コマンド本体を、既存 Phase A〜D（grill / 抽出 / 逐次実装 / 掃除）から新しい6 Phase（A grill / B 抽出＋計画 / C 並列実装 / D 結合テスト / E E2E ループ / F クリーンアップ）へ書き換える。Phase C/E は要約と補助 md 参照に留める。

**Files:**
- Modify: `commands/ww-flow.md`

- [ ] **Step 1: `commands/ww-flow.md` を次の内容で全置換する**

ファイル本文は以下の通り（先頭行は `---`）。`$ARGUMENTS` はリテラルで記述する。

````markdown
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
````

- [ ] **Step 2: frontmatter と Phase 見出しを確認**

Run: `head -4 commands/ww-flow.md`
Expected: `---` で始まり `description:` と `argument-hint:` 行を含む。

Run: `grep -n '^## Phase' commands/ww-flow.md`
Expected: Phase A〜F の6行が順に並ぶ。

- [ ] **Step 3: 補助 md への参照が正しいパスか確認**

Run: `grep -n 'ww-flow/' commands/ww-flow.md`
Expected: `./ww-flow/parallel-impl.md` と `./ww-flow/e2e-loop.md` への参照が各1つ。

- [ ] **Step 4: コミット**

```bash
git add commands/ww-flow.md
git commit -m "$(cat <<'EOF'
並列実装と E2E を統括するためww-flow を6 Phase 構成へ拡張する

---

Phase B に PR 単位分割＋依存グラフ生成を追加。Phase C(並列実装)・D(結合テスト)・
E(E2E ループ)・F(クリーンアップ) を新設。エージェントモデル(子を spawn できるのは
メインのみ)を明記。Phase C/E の詳細は補助 md へ外出しし本体は要約＋参照に留めた。
EOF
)"
```

---

## Task 2: Phase C の詳細手順 parallel-impl.md を作成する

**Files:**
- Create: `commands/ww-flow/parallel-impl.md`

- [ ] **Step 1: `commands/ww-flow/parallel-impl.md` を次の内容で新規作成する**

````markdown
# Phase C — 並列実装（詳細手順）

Phase B で決めた PR 単位と依存グラフに従い、実装メンバーを spawn して各 PR を実装・
レビュー・完成させる。メインセッションが司令塔として全メンバーを spawn・統括する。

## チーム準備

1. まだチームが無ければ `TeamCreate` でチームを作る（team_name は Issue に紐づく分かり
   やすい名前にする）。
2. PR の一覧と依存グラフを TaskCreate で各 PR を1タスクとして登録し、依存は
   `addBlockedBy` で表現する。

## 実装メンバーの spawn

3. 依存元が無い（または依存元が完了済みの）PR について、実装メンバーを spawn する。
   - `Agent` を `team_name`（同じチーム）、`name`（PR が分かる名前、例 `impl-<pr-key>`）、
     `isolation: "worktree"` で起動する。worktree 分離により並列実装でも git index が
     競合しない。
   - 独立 PR は同一メッセージ内で複数 `Agent` を並列に呼んで同時 spawn する。
   - 依存 PR は依存元メンバーの PR 完成後に spawn する。
4. 各実装メンバーへ渡すプロンプトに含める内容:
   - 担当 PR の仕様（担当 Sub-issue の本文、または PR グループの What/Why）。
   - 「1 What/Why = 1 commit」で実装し、commit 作法は `what-why` スキルと `COMMIT-FORMAT.md`
     に従うこと。
   - 実装が終わったら PR を作成し、PR 番号と差分の git 範囲（base/head SHA）を報告すること。

## レビューと差し戻しループ

5. 実装メンバーから「PR 完成」の報告を受けたら、メインが fresh のレビューメンバーを
   spawn する（`Agent` + `team_name`、name 例 `review-<pr-key>`）。
   - レビューメンバーには **PR の仕様と差分の git 範囲（base/head SHA）だけ**を渡す。
     実装メンバーの会話コンテキストは渡さない（pure なレビューにする）。
   - レビューは二段で行わせる: ①spec 準拠（仕様通りか・過不足が無いか）→ ②コード品質
     （明快さ・保守性・プロジェクト規約準拠）。①が通ってから②に進む。
6. レビューで問題が出たら、担当の実装メンバーへ `SendMessage` で具体的な修正内容を伝えて
   修正を依頼する。修正完了後、同じレビュー観点で再レビューする。通過するまで繰り返す。
7. レビュー通過したら、そのレビューメンバーを `SendMessage` の `shutdown_request` で
   シャットダウンする（レビューメンバーは使い捨て）。
8. 実装メンバーはシャットダウンしない。Phase D/E で再修正を依頼する可能性があるため残す。

## 完了条件

9. 全 PR がレビュー通過・完成するまで 3〜8 を続ける。依存 PR は依存元の完成を待って
   spawn する。全 PR 完成で Phase D へ進む。
````

- [ ] **Step 2: 見出し構成を確認**

Run: `grep -n '^## ' commands/ww-flow/parallel-impl.md`
Expected: 「チーム準備」「実装メンバーの spawn」「レビューと差し戻しループ」「完了条件」の4見出し。

- [ ] **Step 3: コミット**

```bash
git add commands/ww-flow/parallel-impl.md
git commit -m "$(cat <<'EOF'
並列実装の手順を定義するためparallel-impl.md を追加する

---

Phase C の詳細手順を外出し。worktree 分離での実装メンバー spawn、依存グラフに沿った
並列/直列の制御、fresh レビューメンバーによる二段レビューと差し戻しループ、実装
メンバーを残しレビューメンバーを使い捨てる寿命管理を記述した。
EOF
)"
```

---

## Task 3: Phase E の詳細手順 e2e-loop.md を作成する

**Files:**
- Create: `commands/ww-flow/e2e-loop.md`

- [ ] **Step 1: `commands/ww-flow/e2e-loop.md` を次の内容で新規作成する**

````markdown
# Phase E — E2E ループ（詳細手順）

ローカル環境で Playwright MCP（`mcp__plugin_playwright__*`）による E2E を回す。メインは
判断と統括に徹し、シナリオ作成・原因切り分けは使い捨てサブエージェント、E2E 実行は
チームメンバーに委譲する。

## 前提: ローカル環境の起動

1. 対象プロジェクトの dev サーバ起動コマンドを推定する（`package.json` の scripts、
   `README` 等から。例: `pnpm dev`）。推定したコマンドをユーザーに提示し、実行してよいか
   確認してから起動する。起動後の URL（例 `http://localhost:3000`）を控える。

## シナリオ作成（使い捨てサブエージェント）

2. メインが内部サブエージェント（`Agent`、`team_name` なし）を spawn し、実装内容
   （対応した Issue / PR の仕様）から E2E シナリオを考えて一覧化させる。
   - 各シナリオは「前提・操作手順・期待結果」を持つ形にする。
   - サブエージェントはシナリオ一覧を結果として返す。メインが受け取る。

## E2E 実行（チームメンバー）

3. メインが E2E 実行メンバー（`Agent` + `team_name`、name 例 `e2e-runner`）を spawn する。
   - シナリオ一覧とローカル URL を渡す。
   - Playwright MCP でローカル環境に対しシナリオを実行し、各シナリオの green/red と、red の
     場合の失敗内容（どの手順で何が起きたか）を報告させる。

## 失敗時の切り分けと差し戻し

4. red のシナリオがあれば、メインが内部サブエージェント（`Agent`、`team_name` なし）を
   spawn し、失敗内容と各実装メンバーの担当 PR 範囲を渡して「どの実装メンバーの実装漏れか」
   を特定させる。結果（担当メンバー名と推定原因）をメインが受け取る。
5. メインが特定された実装メンバーへ `SendMessage` で修正を依頼する。修正完了後、E2E を
   再実行する（red だったシナリオを再度回す）。

## リトライ上限

6. リトライはシナリオ単位で上限3回とする。同一シナリオが3回差し戻しても green にならなければ、
   メインはそのシナリオの失敗内容・試した修正・担当メンバーをまとめてユーザーに報告し、
   ワークフローを停止して判断を仰ぐ（暴走防止の安全弁）。

## 完了条件

7. 全シナリオが green になれば Phase F へ進む。いずれかのシナリオが上限超過で停止した場合は
   ユーザーの判断を待つ。
````

- [ ] **Step 2: 見出し構成とリトライ上限の記述を確認**

Run: `grep -n '^## ' commands/ww-flow/e2e-loop.md`
Expected: 「前提: ローカル環境の起動」「シナリオ作成」「E2E 実行」「失敗時の切り分けと差し戻し」「リトライ上限」「完了条件」の6見出し。

Run: `grep -n '3回' commands/ww-flow/e2e-loop.md`
Expected: シナリオ単位3回のリトライ上限の記述が含まれる。

- [ ] **Step 3: コミット**

```bash
git add commands/ww-flow/e2e-loop.md
git commit -m "$(cat <<'EOF'
E2E ループの手順を定義するため e2e-loop.md を追加する

---

Phase E の詳細手順を外出し。dev サーバ起動の推定→確認、シナリオ作成サブエージェント、
Playwright 実行メンバー、失敗の原因切り分けサブエージェントと差し戻し、シナリオ単位
3回のリトライ上限と超過時のユーザー報告を記述した。
EOF
)"
```

---

## Task 4: README を6 Phase 構成へ更新する

**Files:**
- Modify: `README.md`

- [ ] **Step 1: README の「使い方」セクションを6 Phase に書き換える**

`README.md` の「## 使い方」セクション（現状 Phase A〜D の4項目）を、次の6項目へ置き換える。
他のセクション（これが解くこと / 構成 / インストール / 台帳ファイル / 巻き戻し）は変更しない。
ただし「## 構成（3つの分離されたコンポーネント）」の `/ww-flow` の行の役割説明を
「ワークフロー司令塔。並列実装・レビュー・結合・E2E まで統括する」に更新する。

「## 使い方」を次に置換する:

````markdown
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
````

- [ ] **Step 2: 6 Phase が並ぶことを確認**

Run: `grep -n 'Phase [A-F] —' README.md`
Expected: Phase A〜F の6行。

- [ ] **Step 3: コミット**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
6 Phase 化を反映するため README の使い方を更新する

---

使い方セクションを Phase A〜F の6段（並列実装・結合テスト・E2E ループ・クリーンアップ
を含む）へ書き換え、構成表の /ww-flow の役割説明も統括役に更新した。
EOF
)"
```

---

## Task 5: プラグインを検証する

**Files:** （検証のみ。ファイル変更なし）

- [ ] **Step 1: plugin-validator で検証**

`plugin-dev:plugin-validator` エージェントを起動し、`~/dev/what-why-plugin`（ブランチ
`feat/parallel-impl-e2e`）を対象に検証させる。

Expected: `plugin.json`/`marketplace.json` の妥当性、`commands/ww-flow.md` の frontmatter、
ディレクトリ構成に重大な指摘が無いこと。`commands/ww-flow/` 配下の補助 md は frontmatter
不要（コマンド本体から参照されるドキュメント）であることを確認。指摘があれば修正し、
該当タスク形式でコミットする。

- [ ] **Step 2: 最終ファイル構成を確認**

Run: `find commands -type f | sort`
Expected:
```
commands/ww-flow.md
commands/ww-flow/e2e-loop.md
commands/ww-flow/parallel-impl.md
```

- [ ] **Step 3: コマンド本体から補助 md への参照が解決することを確認**

Run: `for f in $(grep -o 'ww-flow/[a-z-]*\.md' commands/ww-flow.md); do test -f "commands/$f" && echo "OK: $f" || echo "MISSING: $f"; done`
Expected: `OK: ww-flow/parallel-impl.md` と `OK: ww-flow/e2e-loop.md`。MISSING が出ない。

- [ ] **Step 4: ブランチを push して PR を作成**

```bash
git push -u origin feat/parallel-impl-e2e
```

`gh pr create` で `feat/parallel-impl-e2e` → `main` の PR を作成する。PR 本文に設計書への
リンクと6 Phase の概要を記載する。

---

## Self-Review チェック結果

- **Spec coverage**: 設計書 §2 エージェントモデル → Task 1（ww-flow.md のエージェント
  モデル節）。§3 PR/commit 粒度 → Task 1 Phase B。§4 worktree 分離 → Task 2。§5 Phase A〜F
  → Task 1（本体）＋ Task 2（C 詳細）＋ Task 3（E 詳細）。§7 未確定点 → ファイル構成（本体
  ＋外出し）と「推定→確認」を Task 1〜3 に反映済み。README → Task 4。検証 → Task 5。漏れなし。
- **Placeholder スキャン**: 各 md ファイルは完全な本文を記載。TBD/TODO なし。
- **Type 整合**: ファイルパス（`commands/ww-flow/parallel-impl.md`、`commands/ww-flow/e2e-loop.md`、
  `what-why/tmp/working-notes.md`、`what-why/<context-name>/WHAT-WHY.md`）、Phase 名（A〜F）、
  エージェント種別（チームメンバー / 内部サブエージェント）は全タスクで統一。リトライ上限
  「シナリオ単位3回」も設計書・Task 1・Task 3 で一致。

#!/usr/bin/env bash
# what-why plugin: SessionStart hook
# WHAT-WHY.md があるリポジトリでのみ、ワークフローのリマインドを注入する。
# 未初期化のリポジトリ・git 外では静かに終了する（誤発火しない）。

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

whatwhy=""
for c in "$repo_root/WHAT-WHY.md" "$repo_root/what-why/WHAT-WHY.md"; do
  if [ -f "$c" ]; then whatwhy="$c"; break; fi
done
[ -n "$whatwhy" ] || exit 0

cat <<'EOF'
[what-why workflow 有効リポジトリ]

このリポジトリは What/Why ワークフローが有効です。実装（コード変更を伴う作業）に
入る場合のみ以下に従ってください。調査・説明・レビューだけなら無視してよい。

着手前（What確定フェーズ）:
- ユーザーの依頼を commit サイズの What に分解し、分解案をユーザーに確認する。
- 各 What の Why を確定する。Why が無ければ候補を3案 +「議論したい」を提示し、
  ユーザーに選ばせる（合致が無ければ自分でタイプ）。
- 確定した What/Why を WHAT-WHY.md の「やること」に追記する。
- What/Why の採否・矛盾解決は必ずユーザーが行う。Claude は提案と矛盾検知に徹する。

commit 時:
- 1 commit = 1 What。commit メッセージに What: / Why: 行を入れる。
- 完了した項目は WHAT-WHY.md の「やったこと」へ移す。

詳細は what-why-commit スキルに従う。
EOF

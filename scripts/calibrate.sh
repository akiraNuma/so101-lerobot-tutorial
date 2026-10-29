#!/usr/bin/env bash
# ============================================================
# calibrate.sh — フォロワーとリーダーをキャリブレーションする
#
# 使い方:
#   bash scripts/calibrate.sh
#
# ポートと ID は .env から読む。保存先は公式コマンドと同じ
# ~/.cache/huggingface/lerobot/calibration/（ID ごとに別のファイルになる）。
# 実行中はモーターの力が抜けるので、アームを手で動かせる。
# ============================================================
set -euo pipefail
source "$(dirname "$0")/_common.sh"

echo "=== SO-101 キャリブレーション ==="
echo "保存先 : ~/.cache/huggingface/lerobot/calibration/"
echo
echo "始めるとモーターの力が抜けます。アームが倒れないよう、手で支えてください。"
echo
echo "途中で英語の指示が3回出ます。それぞれ次の意味です。"
echo
echo "  Press ENTER to use provided calibration file ... or type 'c' ..."
echo "    → 前回のキャリブレーションが残っている。使うなら Enter、取り直すなら c と Enter"
echo "  Move ... to the middle of its range of motion and press ENTER"
echo "    → 各関節を、動く範囲のちょうど真ん中あたりに手で合わせて Enter"
echo "  Move all joints except 'wrist_roll' sequentially through their entire ranges ..."
echo "    → 手首の回転以外の関節を、1つずつ端から端まで動かす。全部終えたら Enter"
echo

run_calibration() {
    local name="$1"; shift
    echo "--- ${name} ---"
    read -r -p "始めるなら Enter..."
    lerobot-calibrate "$@"
    echo
}

run_calibration "フォロワー（モーターで動く側）" \
    --robot.type=so101_follower \
    --robot.port="${FOLLOWER_PORT}" \
    --robot.id="${FOLLOWER_ID}"

run_calibration "リーダー（手で持つ側）" \
    --teleop.type=so101_leader \
    --teleop.port="${LEADER_PORT}" \
    --teleop.id="${LEADER_ID}"

echo "=== 完了 ==="
echo "次は動作確認です:"
echo "  bash scripts/teleoperate.sh camera"

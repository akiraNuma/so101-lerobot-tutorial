#!/usr/bin/env bash
# ============================================================
# teleoperate.sh — テレオペレーションの動作確認
#
# 使い方:
#   bash scripts/teleoperate.sh           → カメラなし
#   bash scripts/teleoperate.sh camera    → カメラ映像あり
# ============================================================
set -euo pipefail
source "$(dirname "$0")/_common.sh"

CAMERA_MODE="${1:-}"

echo "=== SO-101 テレオペレーション ==="
echo "Follower    : ${FOLLOWER_PORT} (${FOLLOWER_ID})"
echo "Leader      : ${LEADER_PORT} (${LEADER_ID})"
echo "Camera      : ${CAMERA_MODE:-off}"
echo
echo "Ctrl+C で終了"
echo

CAMERA_ARGS=()
if [[ "${CAMERA_MODE}" == "camera" ]]; then
    CAMERA_ARGS=(
        --robot.cameras="${CAMERAS_JSON}"
        --display_data=true
    )
fi

lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port="${FOLLOWER_PORT}" \
    --robot.id="${FOLLOWER_ID}" \
    --teleop.type=so101_leader \
    --teleop.port="${LEADER_PORT}" \
    --teleop.id="${LEADER_ID}" \
    "${CAMERA_ARGS[@]+"${CAMERA_ARGS[@]}"}"

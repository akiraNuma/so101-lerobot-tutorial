#!/usr/bin/env bash
# ============================================================
# record.sh — テレオペしながらデータを収集する
#
# 使い方:
#   bash scripts/record.sh <データセット名> <エピソード数> <指示文>
#   bash scripts/record.sh so101_tray_red 50 "Pick up the red cube and place it in the tray"
#   bash scripts/record.sh --resume so101_tray_red 10 "Pick up the red cube and place it in the tray"
#       → 既存のデータセットに10本追加
#
# データセット名は <ユーザー名>/<名前> か、名前だけ（ユーザー名は自動で補う）。
# 指示文はそのまま学習データに記録される。1文字でも違うと別の指示として扱われる。
#
# オプション:
#   --no-upload   Hub に上げず、ローカルにだけ保存する
#   上のどれでもない --xxx の引数は、そのまま lerobot-record に渡す
#   例: --dataset.private=true --dataset.episode_time_s=30
#
# 注意:
#   - Hub には公開で上がる（LeRobot の既定）。非公開にするなら --dataset.private=true を付ける
#   - → を押したら、すぐリーダーを動かし始める。音声の案内は待たなくてよい（その間も録画は進んでいる）。
#     最初に止まっている時間もモデルは真似するので、評価で待機姿勢から動き出せなくなる
# ============================================================
set -euo pipefail
source "$(dirname "$0")/_common.sh"

USAGE='使い方: bash scripts/record.sh [--resume] <データセット名> <エピソード数> <指示文> [--no-upload]'

PUSH_TO_HUB=true
RESUME=false
ARGS=()
EXTRA_ARGS=()
for arg in "$@"; do
    case "${arg}" in
        --no-upload) PUSH_TO_HUB=false ;;
        --resume)    RESUME=true ;;
        --*)         EXTRA_ARGS+=("${arg}") ;;
        *)           ARGS+=("${arg}") ;;
    esac
done

if [[ "${#ARGS[@]}" -ne 3 ]]; then
    echo "${USAGE}" >&2
    exit 1
fi
DATASET_NAME="${ARGS[0]}"
NUM_EPISODES="${ARGS[1]}"
TASK="${ARGS[2]}"

resolve_hf_user
if [[ "${DATASET_NAME}" != */* ]]; then
    DATASET_NAME="${HF_USER}/${DATASET_NAME}"
fi

# LeRobot の保存先（lerobot/utils/constants.py と同じ決め方）
DATASET_HOME="${HF_LEROBOT_HOME:-${HF_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/huggingface}/lerobot}"
DATASET_DIR="${DATASET_HOME}/${DATASET_NAME}"

RESUME_ARGS=()
MODE="新規"
if [[ "${RESUME}" == "false" && -d "${DATASET_DIR}" ]]; then
    # LeRobot は同じ名前のフォルダがあると新規作成を拒否する
    echo "エラー: 同じ名前のデータセットが既にあります: ${DATASET_DIR}" >&2
    echo "  続きを録るなら --resume を付けてください" >&2
    echo "  前回の失敗で残った空のフォルダなら、消してからやり直してください:" >&2
    echo "    rm -rf \"${DATASET_DIR}\"" >&2
    exit 1
fi
if [[ "${RESUME}" == "true" ]]; then
    if [[ ! -d "${DATASET_DIR}" ]]; then
        echo "エラー: 追加先のデータセットがありません: ${DATASET_DIR}" >&2
        echo "  データセット名を確認してください" >&2
        exit 1
    fi
    # --resume では保存先の指定が必須
    RESUME_ARGS=(--resume=true --dataset.root="${DATASET_DIR}")
    MODE="追加"
fi

echo "=== SO-101 データ収集 ==="
echo "Dataset    : ${DATASET_NAME}"
echo "Episodes   : ${NUM_EPISODES} (${MODE})"
echo "Task       : ${TASK}"
echo "Hub Upload : ${PUSH_TO_HUB}"
echo
echo "キー操作: → 次のエピソードへ / ← 今の回をやり直す / Esc 終了"
echo "→ を押したら、すぐリーダーを動かし始めてください。止まっている時間もモデルは真似します。"
echo

lerobot-record \
    --robot.type=so101_follower \
    --robot.port="${FOLLOWER_PORT}" \
    --robot.id="${FOLLOWER_ID}" \
    --robot.cameras="${CAMERAS_JSON}" \
    --teleop.type=so101_leader \
    --teleop.port="${LEADER_PORT}" \
    --teleop.id="${LEADER_ID}" \
    --display_data=true \
    --dataset.repo_id="${DATASET_NAME}" \
    --dataset.num_episodes="${NUM_EPISODES}" \
    --dataset.single_task="${TASK}" \
    --dataset.no_stamp=true \
    --dataset.push_to_hub="${PUSH_TO_HUB}" \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2 \
    "${RESUME_ARGS[@]+"${RESUME_ARGS[@]}"}" \
    "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"

echo
echo "=== 収集完了 ==="
echo "ローカル保存先: ${DATASET_DIR}"

#!/usr/bin/env bash
# ============================================================
# evaluate.sh — 学習済みポリシーを実機で動かして評価する
#
# 使い方:
#   bash scripts/evaluate.sh <policy_path または Hub の id> <試行回数> <指示文>
#   bash scripts/evaluate.sh outputs/act_red_10/checkpoints/last/pretrained_model 10 \
#       "Pick up the red cube and place it in the tray"
#
# オプション:
#   --no-upload     評価の録画を Hub に上げない
#   --name=<名前>   評価の録画の名前（省略時はモデル名）。同じモデルを別の指示文で
#                   評価するときに付ける。例: --name=smolvla_pair2_blue
#   上のどれでもない --xxx の引数は、そのまま lerobot-rollout に渡す
#   例: SmolVLA は --rename_map='{"observation.images.overhead": "observation.images.camera1", ...}'
#
# 指示文はそのままモデルに渡る。学習データと同じ文にする。
#
# 1試行ごとにリセット時間が入る。その間にリーダーでアームを戻し、キューブを置き直す。
# 成功・失敗は自動判定されないので、目視で数える。
#
# 注意:
#   - 評価の録画は Hub に公開で上がる（LeRobot の既定）。非公開にするなら --dataset.private=true を付ける
#   - リセットに入るとき、リーダーがモーターで約2秒動いてフォロワーの姿勢に合わせる。
#     その間はリーダーを強く握らない
#   - Esc で終わると、フォロワーが開始時の姿勢へ自分で戻る
# ============================================================
set -euo pipefail
source "$(dirname "$0")/_common.sh"

PUSH_TO_HUB=true
MODEL_NAME=""
ARGS=()
EXTRA_ARGS=()
for arg in "$@"; do
    case "${arg}" in
        --no-upload) PUSH_TO_HUB=false ;;
        --name=*)    MODEL_NAME="${arg#--name=}" ;;
        --*)         EXTRA_ARGS+=("${arg}") ;;
        *)           ARGS+=("${arg}") ;;
    esac
done

if [[ "${#ARGS[@]}" -ne 3 ]]; then
    echo "使い方: bash scripts/evaluate.sh <policy_path> <試行回数> <指示文> [--name=<名前>] [--no-upload]" >&2
    exit 1
fi
POLICY_PATH="${ARGS[0]}"
NUM_EPISODES="${ARGS[1]}"
TASK="${ARGS[2]}"

resolve_hf_user

# 評価の録画に付ける名前。lerobot-rollout は rollout_ で始まる名前しか受け付けない
#   outputs/act_red_10/checkpoints/last/pretrained_model → act_red_10
#   <user>/act_red_10（Hub の id）                         → act_red_10
if [[ -z "${MODEL_NAME}" && "${POLICY_PATH}" == */checkpoints/* ]]; then
    MODEL_NAME="$(basename "${POLICY_PATH%%/checkpoints/*}")"
elif [[ -z "${MODEL_NAME}" ]]; then
    MODEL_NAME="$(basename "${POLICY_PATH}")"
fi
EVAL_DATASET="${HF_USER}/rollout_${MODEL_NAME}"

# 同じ名前の録画が残っていると、lerobot-rollout は FileExistsError で止まる
DATASET_HOME="${HF_LEROBOT_HOME:-${HF_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/huggingface}/lerobot}"
EVAL_DIR="${DATASET_HOME}/${EVAL_DATASET}"
if [[ -e "${EVAL_DIR}" ]]; then
    echo "エラー: 同じ名前の評価の録画が既にあります: ${EVAL_DIR}" >&2
    echo "  前回の録画を残すなら、--name で別の名前を付けてください。例: --name=${MODEL_NAME}_2" >&2
    echo "  要らないなら、消してからやり直してください:" >&2
    echo "    rm -rf \"${EVAL_DIR}\"" >&2
    exit 1
fi

echo "=== SO-101 推論・評価 ==="
echo "Policy       : ${POLICY_PATH}"
echo "Task         : ${TASK}"
echo "Trials       : ${NUM_EPISODES}"
echo "Eval Dataset : ${EVAL_DATASET}"
echo "Hub Upload   : ${PUSH_TO_HUB}"
echo
echo "キー操作: → 次の試行へ / ← 今の試行をやり直す / Esc 終了"
echo "成功・失敗は自動判定されません。目視で数えてください。"
echo "リセットに入るときリーダーが約2秒動きます。その間は強く握らないでください。"
echo

lerobot-rollout \
    --strategy.type=episodic \
    --policy.path="${POLICY_PATH}" \
    --robot.type=so101_follower \
    --robot.port="${FOLLOWER_PORT}" \
    --robot.id="${FOLLOWER_ID}" \
    --robot.cameras="${CAMERAS_JSON}" \
    --teleop.type=so101_leader \
    --teleop.port="${LEADER_PORT}" \
    --teleop.id="${LEADER_ID}" \
    --display_data=true \
    --dataset.repo_id="${EVAL_DATASET}" \
    --dataset.num_episodes="${NUM_EPISODES}" \
    --dataset.single_task="${TASK}" \
    --dataset.no_stamp=true \
    --dataset.push_to_hub="${PUSH_TO_HUB}" \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2 \
    "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"

echo
echo "=== 評価完了 ==="

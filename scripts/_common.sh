#!/usr/bin/env bash
# ============================================================
# _common.sh — 各スクリプトが共通で読む設定
#
# 直接実行せず、他のスクリプトから source する
# ============================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---- conda 環境が有効か ----
if ! command -v lerobot-teleoperate &>/dev/null; then
    echo "エラー: LeRobot のコマンドが見つかりません。次を実行してからやり直してください:" >&2
    echo "  conda activate lerobot-tutorial" >&2
    exit 1
fi

# ---- .env の読み込み ----
if [[ ! -f "${REPO_DIR}/.env" ]]; then
    echo "エラー: .env がありません。次のコマンドで作ってください:" >&2
    echo "  cp .env.example .env" >&2
    echo "  bash scripts/find_devices.sh   # ポートとカメラ番号を調べる" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1091
source "${REPO_DIR}/.env"
set +a

# ---- 必須項目のチェック ----
for var in FOLLOWER_PORT LEADER_PORT FOLLOWER_ID LEADER_ID; do
    if [[ -z "${!var:-}" ]]; then
        echo "エラー: .env の ${var} が空です" >&2
        exit 1
    fi
done

if [[ "${FOLLOWER_PORT}" == *XXXXXXXX* || "${LEADER_PORT}" == *YYYYYYYY* ]]; then
    echo "エラー: .env のポート番号が雛形のままです" >&2
    echo "  bash scripts/find_devices.sh で調べて書き換えてください" >&2
    exit 1
fi

# ---- カメラ設定（lerobot に渡す形に組み立てる）----
OVERHEAD_CAMERA_INDEX="${OVERHEAD_CAMERA_INDEX:-1}"
WRIST_CAMERA_INDEX="${WRIST_CAMERA_INDEX:-0}"
CAMERA_WIDTH="${CAMERA_WIDTH:-640}"
CAMERA_HEIGHT="${CAMERA_HEIGHT:-480}"
CAMERA_FPS="${CAMERA_FPS:-30}"

CAMERAS_JSON="{ overhead: {type: opencv, index_or_path: ${OVERHEAD_CAMERA_INDEX}, width: ${CAMERA_WIDTH}, height: ${CAMERA_HEIGHT}, fps: ${CAMERA_FPS}}, wrist: {type: opencv, index_or_path: ${WRIST_CAMERA_INDEX}, width: ${CAMERA_WIDTH}, height: ${CAMERA_HEIGHT}, fps: ${CAMERA_FPS}}}"

# ---- Hugging Face のユーザー名 ----
# 未ログイン・オフラインのときは空を返す
hf_user() {
    hf auth whoami --format json 2>/dev/null \
        | python -c 'import json, sys; print(json.load(sys.stdin)["user"])' 2>/dev/null \
        || true
}

# HF_USER と PUSH_TO_HUB を決める。record.sh と evaluate.sh が呼ぶ
# 未ログインなら local_user の名前でローカルにだけ保存する
resolve_hf_user() {
    HF_USER="$(hf_user)"
    if [[ -z "${HF_USER}" ]]; then
        HF_USER="local_user"
        if [[ "${PUSH_TO_HUB}" == "true" ]]; then
            echo "注意: Hugging Face にログインしていないため、Hub には上げずにローカルにだけ保存します" >&2
            echo "  Hub に上げるなら、先に hf auth login を実行してください" >&2
            echo >&2
        fi
        PUSH_TO_HUB=false
    fi
}

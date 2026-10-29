#!/usr/bin/env bash
# ============================================================
# find_devices.sh — USB ポートとカメラ番号を調べる
#
# 使い方:
#   bash scripts/find_devices.sh
#
# 見つけたポートとカメラの番号は、確認してから .env に書き込む
# ============================================================
set -euo pipefail

if ! command -v lerobot-find-cameras &>/dev/null; then
    echo "エラー: LeRobot のコマンドが見つかりません。次を実行してからやり直してください:" >&2
    echo "  conda activate lerobot-tutorial" >&2
    exit 1
fi

ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/.env"

list_ports() {
    ls /dev/tty.* /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | sort || true
}

# 1本抜いてもらい、消えたポートを返す
find_port() {
    local name="$1"
    local before after diff
    before="$(list_ports)"
    echo
    read -r -p "${name}の USB ケーブルだけを PC から抜いて、Enter を押してください..."
    sleep 1
    after="$(list_ports)"
    diff="$(comm -23 <(echo "${before}") <(echo "${after}"))"

    if [[ -z "${diff}" ]]; then
        echo "エラー: 消えたポートがありません。抜くケーブルを間違えていないか確認してください" >&2
        exit 1
    fi
    if [[ "$(echo "${diff}" | wc -l)" -gt 1 ]]; then
        echo "エラー: 2つ以上のポートが消えました。1本だけ抜いてやり直してください" >&2
        exit 1
    fi
    FOUND_PORT="${diff}"
    echo "→ ${name}のポート: ${FOUND_PORT}"
    read -r -p "${name}の USB を挿し直して、Enter を押してください..."
}

# 確認してから .env の該当行を書き換える
write_env() {
    local key="$1" value="$2" answer
    if [[ ! -f "${ENV_FILE}" ]] || ! grep -q "^${key}=" "${ENV_FILE}"; then
        echo "   .env に ${key} の行がありません。手で ${key}=${value} と書いてください"
        return 0
    fi
    echo "   今の .env: $(grep "^${key}=" "${ENV_FILE}")"
    read -r -p "   ${key}=${value} に書き換えますか？ [y/N] " answer
    if [[ "${answer}" == [yY] ]]; then
        sed "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}" > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "${ENV_FILE}"
        echo "   書き換えました"
    else
        echo "   書き換えませんでした"
    fi
}

# 今の .env の値を見せて、調べ直すか聞く（Enter だけならやる）
ask_run() {
    local title="$1"; shift
    local key answer
    echo "今の .env:"
    for key in "$@"; do
        echo "  $(grep "^${key}=" "${ENV_FILE}" 2>/dev/null || echo "${key}=（未設定）")"
    done
    read -r -p "${title}を調べますか？ [Y/n] " answer
    [[ "${answer}" != [nN] ]]
}

echo "=== 1. アームのポートを調べる ==="
echo
if ask_run "アームのポート" FOLLOWER_PORT LEADER_PORT; then
    echo
    echo "アームの USB を1本ずつ抜き、消えたポートでどちらのアームかを判定します。"
    echo "始める前に、両方のアームを PC に挿しておいてください。"

    find_port "フォロワー（モーターで動く側）"
    write_env FOLLOWER_PORT "${FOUND_PORT}"

    find_port "リーダー（手で持つ側）"
    write_env LEADER_PORT "${FOUND_PORT}"
else
    echo "アームのポートは調べずに進みます"
fi

echo
echo "=== 2. カメラの番号を調べる ==="
echo
if ask_run "カメラの番号" OVERHEAD_CAMERA_INDEX WRIST_CAMERA_INDEX; then
    echo
    echo "つながっているカメラで1枚ずつ撮影し、画像を見て番号を決めます。"
    echo "始める前に、俯瞰カメラと手元カメラを2台とも PC に挿してください。"
    echo
    read -r -p "挿したら Enter..."

    IMAGE_DIR="$(cd "$(dirname "$0")/.." && pwd)/outputs/captured_images"
    rm -rf "${IMAGE_DIR}"   # 前回の画像が残っていると取り違えるため消す

    echo "撮影中です（数十秒かかります）..."
    # OpenCV は存在しない番号を全部試してエラーを大量に出すので、その行は隠す
    lerobot-find-cameras opencv --output-dir "${IMAGE_DIR}" 2>&1 \
        | grep -v -e "out device of bound" -e "failed to properly initialize" \
                  -e "Saved image" -e "Failed list devices" || true

    echo
    echo "--- 撮影できた画像 ---"
    if ! ls "${IMAGE_DIR}"/opencv_*.png >/dev/null 2>&1; then
        echo "エラー: 1枚も撮影できませんでした。カメラの接続を確認してください" >&2
        exit 1
    fi
    for img in "${IMAGE_DIR}"/opencv_*.png; do
        id="$(basename "${img}" .png)"
        id="${id#opencv_}"
        # Linux ではファイル名が opencv__dev_video0.png になる。/dev/video0 に戻す
        [[ "${id}" == _dev_* ]] && id="/dev/${id#_dev_}"
        echo "  カメラ ${id} … ${img}"
    done
    echo
    echo "「カメラ」の後ろにあるのがカメラの番号です。画像を開いて見比べてください。"
    echo "  Mac   : open ${IMAGE_DIR}"
    echo "  Linux : xdg-open ${IMAGE_DIR}"
    echo
    echo "見分け方:"
    echo "  俯瞰カメラ … 机・トレー・アームが上から全部写っている"
    echo "  手元カメラ … グリッパーの先が大きく写っている"
    echo "  それ以外   … PC の内蔵カメラなど。使わない"
    echo "画像が無い番号は撮影に失敗したカメラです。挿し直してから再実行してください。"
    echo

    read -r -p "俯瞰カメラの番号: " overhead
    if [[ -n "${overhead}" ]]; then write_env OVERHEAD_CAMERA_INDEX "${overhead}"; fi
    read -r -p "手元カメラの番号: " wrist
    if [[ -n "${wrist}" ]]; then write_env WRIST_CAMERA_INDEX "${wrist}"; fi

    echo
else
    echo "カメラの番号は調べずに進みます"
fi

echo
echo "=== 完了 ==="
echo "カメラをつなぎ替えたら、番号が変わっていないか再実行して確かめてください。"

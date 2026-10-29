#!/usr/bin/env bash
# ============================================================
# setup.sh — conda 環境の作成と LeRobot のインストール
#
# 使い方:
#   bash scripts/setup.sh
# ============================================================
set -euo pipefail

# 本書が対象とする LeRobot のバージョン（README の対応表と揃える）
LEROBOT_VERSION="0.6.1"
CONDA_ENV="lerobot-tutorial"

echo "=== SO-101 チュートリアル 環境セットアップ ==="
echo "LeRobot   : ${LEROBOT_VERSION}"
echo "conda env : ${CONDA_ENV}"
echo

if ! command -v conda &>/dev/null; then
    echo "エラー: conda が見つかりません。Miniforge か Miniconda を入れてください。" >&2
    exit 1
fi

if conda info --envs | grep -qE "^${CONDA_ENV} "; then
    echo "[SKIP] conda env '${CONDA_ENV}' は作成済みです"
else
    echo "[INFO] conda env '${CONDA_ENV}' を作成します (Python 3.12)"
    conda create -y -n "${CONDA_ENV}" python=3.12
fi

eval "$(conda shell.bash hook)"
conda activate "${CONDA_ENV}"

# ffmpeg は conda 環境の中に入れる。Homebrew などの ffmpeg は使わない
# （torchcodec が読めるのは ffmpeg 4〜8 だけ）
FFMPEG_VERSION="7.1.1"
if [[ -x "${CONDA_PREFIX}/bin/ffmpeg" ]]; then
    echo "[SKIP] ffmpeg は conda env に入っています"
else
    echo "[INFO] ffmpeg ${FFMPEG_VERSION} を conda env に入れます"
    conda install -y "ffmpeg=${FFMPEG_VERSION}" -c conda-forge
fi

# Linux では、Ubuntu 22.04 などの古い libstdc++ が先に読み込まれ、
# conda の ffmpeg が要る新しい版と食い違って torchcodec が読めなくなる。
# conda env のライブラリを先に探すよう、activate 時に設定させる
if [[ "$(uname -s)" == "Linux" ]]; then
    echo "[INFO] conda env のライブラリを優先する設定を入れます（Linux のみ）"
    conda env config vars set -n "${CONDA_ENV}" LD_LIBRARY_PATH="${CONDA_PREFIX}/lib" > /dev/null
fi

# feetech     … SO-101 のモーター
# core_scripts … 収集（データセット・キー操作・画面表示）
# training    … 学習
# smolvla     … 第8章の SmolVLA
EXTRAS="feetech,core_scripts,training,smolvla"

echo "[INFO] lerobot[${EXTRAS}]==${LEROBOT_VERSION} を入れます"
pip install "lerobot[${EXTRAS}]==${LEROBOT_VERSION}"

echo
echo "=== セットアップ完了 ==="
echo
echo "次にやること:"
echo "  1. conda activate ${CONDA_ENV}"
echo "  2. hf auth login                   # データセットを Hub に上げる場合"
echo "  3. cp .env.example .env"
echo "  4. bash scripts/find_devices.sh    # ポートとカメラの番号を調べて .env に書く"
echo "  5. bash scripts/calibrate.sh       # フォロワーとリーダーのキャリブレーション"
echo "  6. bash scripts/teleoperate.sh camera   # 動作確認"

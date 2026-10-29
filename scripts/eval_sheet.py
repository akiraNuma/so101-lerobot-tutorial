"""
eval_sheet.py — 評価の録画から、試行ごとの写真を並べた画像を作る

使い方:
    python scripts/eval_sheet.py <評価の録画の id>
    python scripts/eval_sheet.py <HF のユーザー名>/rollout_act_red_50

1行が1試行で、左から開始・途中2枚・終わりの俯瞰カメラの写真が並ぶ。
終わりの写真でキューブがトレーに入っていれば成功。
評価中に成功・失敗をメモし忘れても、これで数え直せる。

録画は手元（~/.cache/huggingface/lerobot/）から読む。手元に無ければ Hub から取る。
画像は outputs/eval_sheets/<録画の名前>.png に保存する。
"""

import sys
from pathlib import Path

import cv2
import numpy as np
from lerobot.datasets.lerobot_dataset import LeRobotDataset

CAMERA = "observation.images.overhead"
FPS = 30
TILE_SIZE = (240, 180)  # 1枚の幅・高さ


def tile(dataset, index, start):
    """1フレームを縮小し、試行番号と経過秒を書き込む"""
    image = dataset[index][CAMERA].permute(1, 2, 0).numpy()
    image = cv2.cvtColor((image * 255).astype(np.uint8), cv2.COLOR_RGB2BGR)
    image = cv2.resize(image, TILE_SIZE)
    return image, (index - start) / FPS


def main():
    if len(sys.argv) != 2:
        print("使い方: python scripts/eval_sheet.py <評価の録画の id>", file=sys.stderr)
        sys.exit(1)
    repo_id = sys.argv[1]

    dataset = LeRobotDataset(repo_id)
    rows = []
    for episode in range(dataset.meta.total_episodes):
        start = int(dataset.meta.episodes[episode]["dataset_from_index"])
        end = int(dataset.meta.episodes[episode]["dataset_to_index"])
        length = end - start
        row = []
        for index in (start, start + length // 3, start + 2 * length // 3, end - 1):
            image, seconds = tile(dataset, index, start)
            label = f"trial{episode + 1} {seconds:.1f}s"
            cv2.putText(image, label, (4, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)
            row.append(image)
        rows.append(np.hstack(row))

    out_dir = Path("outputs/eval_sheets")
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{repo_id.split('/')[-1]}.png"
    cv2.imwrite(str(out_path), np.vstack(rows))
    print(f"{dataset.meta.total_episodes} 試行分を保存しました: {out_path}")


if __name__ == "__main__":
    main()

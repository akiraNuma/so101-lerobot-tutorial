"""
trim_merge.py — 各エピソードの最初の静止を切り落とし、複数のデータセットを1つにまとめる

使い方:
    python scripts/trim_merge.py <まとめた後の id> <データセットの id> <データセットの id> ...
    python scripts/trim_merge.py <HF のユーザー名>/so101_pair_mix \
        <HF のユーザー名>/so101_pair_red <HF のユーザー名>/so101_pair_blue

各エピソードで、どれかの関節が最初のフレームから 3 度より大きく動いた最初のフレームを
「動き出し」とし、その 5 フレーム前より前を捨てる。指示文はエピソードごとに元のまま残る。

元のデータセットは手元（~/.cache/huggingface/lerobot/）から読む。手元に無ければ Hub から取る。
まとめた後のデータセットは手元に保存し、Hub に非公開で上げる。
--no-upload を付けると、Hub には上げない。
"""

import sys

import numpy as np
import torch
from lerobot.datasets.lerobot_dataset import LeRobotDataset

MOVE_THRESHOLD = 3.0  # 動き出しとみなす角度の変化（度）
KEEP_BEFORE = 5  # 動き出しの何フレーム前から残すか
DEFAULT_FEATURES = {"index", "episode_index", "frame_index", "timestamp", "task_index"}


def onset(actions):
    """どれかの関節が最初のフレームから MOVE_THRESHOLD より大きく動いた最初のフレーム"""
    moved = np.abs(actions - actions[0]).max(axis=1) > MOVE_THRESHOLD
    return int(np.argmax(moved)) if moved.any() else 0


def main():
    args = [a for a in sys.argv[1:] if a != "--no-upload"]
    upload = "--no-upload" not in sys.argv[1:]
    if len(args) < 2:
        print("使い方: python scripts/trim_merge.py <まとめた後の id> <データセットの id> ...", file=sys.stderr)
        sys.exit(1)
    dst_id, src_ids = args[0], args[1:]

    sources = [LeRobotDataset(repo_id) for repo_id in src_ids]
    features = {k: v for k, v in sources[0].meta.features.items() if k not in DEFAULT_FEATURES}
    dst = LeRobotDataset.create(
        dst_id,
        fps=sources[0].meta.fps,
        features=features,
        robot_type=sources[0].meta.robot_type,
        use_videos=True,
    )

    for src in sources:
        for episode in range(src.meta.total_episodes):
            start = int(src.meta.episodes[episode]["dataset_from_index"])
            end = int(src.meta.episodes[episode]["dataset_to_index"])
            actions = np.stack([src.hf_dataset[i]["action"].numpy() for i in range(start, end)])
            cut = max(0, onset(actions) - KEEP_BEFORE)

            for index in range(start + cut, end):
                item = src[index]
                frame = {"task": item["task"]}
                for key, feature in features.items():
                    value = item[key]
                    if feature["dtype"] == "video":
                        # 読み込んだ画像は 0〜1 の (C, H, W)。保存用に 0〜255 の (H, W, C) に戻す
                        value = (value.permute(1, 2, 0) * 255).round().clamp(0, 255).to(torch.uint8)
                    frame[key] = value.numpy()
                dst.add_frame(frame)
            dst.save_episode()
            print(f"{src.repo_id} エピソード{episode}: {cut} フレームを切り落とし、{end - start - cut} フレームを残しました", flush=True)

    dst.finalize()
    if upload:
        dst.push_to_hub(private=True)
        print(f"Hub に非公開で上げました: {dst_id}")
    print(f"{dst.meta.total_episodes} エピソードを保存しました: {dst.root}")


if __name__ == "__main__":
    main()

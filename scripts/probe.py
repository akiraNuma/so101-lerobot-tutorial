"""
probe.py — 画像を差し替えたとき、モデルの予測がどれだけ変わるかを調べる

使い方:
    python scripts/probe.py <モデルの id> <データセットの id> <エピソード番号> [オプション]

    # 1. 元の画像を outputs/probe/ に書き出し、そのままの入力で予測する
    python scripts/probe.py <HF のユーザー名>/act_red_50 <HF のユーザー名>/so101_tray_red 0

    # 2. 書き出した画像を加工する（または撮り直す）。差し替えて予測し、元の画像の予測と並べる
    python scripts/probe.py <HF のユーザー名>/act_red_50 <HF のユーザー名>/so101_tray_red 0 \
        --overhead outputs/probe/overhead_edited.png

データセットの 1 フレーム（カメラ画像と関節の角度）をモデルに入れ、この先の動きのチャンク（一度に予測した動作のまとまり）を出させる。
ロボットは動かさない。

オプション:
    --frame N        使うフレーム（エピソードの先頭から数える）。省略すると、動き出しの5フレーム後
    --overhead PNG   俯瞰カメラの画像を差し替える
    --wrist PNG      手元カメラの画像を差し替える

元の画像は outputs/probe/overhead.png と outputs/probe/wrist.png に書き出す。
差し替える画像の大きさが違うときは、データセットの大きさに合わせて縮小・拡大する。
"""

import argparse
from pathlib import Path

import cv2
import numpy as np
import torch
from lerobot.configs.policies import PreTrainedConfig
from lerobot.datasets.lerobot_dataset import LeRobotDataset
from lerobot.policies.factory import get_policy_class, make_pre_post_processors

CAMERAS = {"overhead": "observation.images.overhead", "wrist": "observation.images.wrist"}
ARM_JOINTS = 4  # 肩の旋回・肩の上下・肘・手首の曲げ（action の先頭4つ）
ONSET_DEGREES = 3  # 最初のフレームからこれ以上変わったら「動き出し」とみなす
OUT_DIR = Path("outputs/probe")


def pick_device():
    if torch.cuda.is_available():
        return "cuda"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def onset(actions):
    """どれかの関節が最初のフレームから ONSET_DEGREES 度を超えて変わった最初のフレーム。無ければ None"""
    moved = np.abs(actions - actions[0]).max(axis=1) > ONSET_DEGREES
    return int(np.argmax(moved)) if moved.any() else None


def load_image(path, like):
    """PNG を読み、データセットの画像（C, H, W の 0〜1）と同じ形にする"""
    image = cv2.imread(str(path))
    if image is None:
        raise SystemExit(f"画像を読めません: {path}")
    height, width = like.shape[1:]
    image = cv2.resize(image, (width, height))
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    return torch.from_numpy(image).permute(2, 0, 1).float() / 255


def save_image(tensor, path):
    image = (tensor.permute(1, 2, 0).numpy() * 255).astype(np.uint8)
    cv2.imwrite(str(path), cv2.cvtColor(image, cv2.COLOR_RGB2BGR))


def main():
    parser = argparse.ArgumentParser(description="画像を差し替えたときの予測の変化を調べる")
    parser.add_argument("model")
    parser.add_argument("dataset")
    parser.add_argument("episode", type=int)
    parser.add_argument("--frame", type=int)
    parser.add_argument("--overhead", type=Path)
    parser.add_argument("--wrist", type=Path)
    args = parser.parse_args()

    dataset = LeRobotDataset(args.dataset)
    if not 0 <= args.episode < dataset.meta.total_episodes:
        raise SystemExit(f"エピソード番号は 0〜{dataset.meta.total_episodes - 1} です")
    start = int(dataset.meta.episodes[args.episode]["dataset_from_index"])
    end = int(dataset.meta.episodes[args.episode]["dataset_to_index"])
    recorded = np.stack([np.array(dataset.hf_dataset[i]["action"]) for i in range(start, end)])

    frame = args.frame
    if frame is None:
        moved_at = onset(recorded)
        frame = 0 if moved_at is None else moved_at + 5
    if not 0 <= frame < end - start:
        raise SystemExit(f"フレームは 0〜{end - start - 1} です")

    item = dataset[start + frame]
    original = {"observation.state": item["observation.state"], "task": item["task"]}
    for key in CAMERAS.values():
        original[key] = item[key]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, key in CAMERAS.items():
        save_image(item[key], OUT_DIR / f"{name}.png")

    edited = dict(original)
    replaced = []
    for name, path in (("overhead", args.overhead), ("wrist", args.wrist)):
        if path is not None:
            edited[CAMERAS[name]] = load_image(path, item[CAMERAS[name]])
            replaced.append(f"{name}={path}")

    device = pick_device()
    config = PreTrainedConfig.from_pretrained(args.model)
    policy = get_policy_class(config.type).from_pretrained(args.model)
    policy.eval()
    preprocess, postprocess = make_pre_post_processors(
        policy.config,
        pretrained_path=args.model,
        preprocessor_overrides={"device_processor": {"device": device}},
    )

    @torch.no_grad()
    def predict(observation):
        batch = {k: (v.unsqueeze(0) if torch.is_tensor(v) else [v]) for k, v in observation.items()}
        return postprocess(policy.predict_action_chunk(preprocess(batch)))[0].cpu().numpy()

    plans = {"original": predict(original)}
    if replaced:
        plans["edited"] = predict(edited)

    names = dataset.meta.features["action"]["names"]
    last = len(plans["original"]) - 1
    print(f"エピソード {args.episode} のフレーム {frame}（{frame / dataset.fps:.1f} 秒）を入力")
    print("差し替えた画像: " + (", ".join(replaced) if replaced else "なし"))
    print(f"チャンクの長さ: {last + 1} フレーム（{(last + 1) / dataset.fps:.1f} 秒）")
    print("onset はチャンクの中で動き出すフレーム（- は動き出さない）")
    print()
    print("original は元の画像、edited は差し替えた画像での予測")
    print(f"{'':20s}" + "".join(f"{label:>10s}" for label in plans))
    moves = [onset(plan) for plan in plans.values()]
    print(f"{'onset (frame)':20s}" + "".join(f"{'-' if m is None else str(m):>10s}" for m in moves))
    print(f"チャンクの最後（{last} フレーム後）の目標角度:")
    for i, name in enumerate(names):
        print(f"  {name:18s}" + "".join(f"{plan[last, i]:10.1f}" for plan in plans.values()))

    if replaced:
        diff = np.abs(plans["edited"][last, :ARM_JOINTS] - plans["original"][last, :ARM_JOINTS]).mean()
        print()
        print(f"差し替えで変わった量（チャンクの最後、腕の4関節の平均）: {diff:.1f} 度")
    print(f"元の画像は {OUT_DIR}/ に書き出しました")


if __name__ == "__main__":
    main()

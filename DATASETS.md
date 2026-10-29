# 本書で使ったデータセットとモデル

Hugging Face Hub に公開しているデータセットとモデルの一覧。
すべて1つのコレクション（https://huggingface.co/collections/anuma/so-101-lerobot-6ad060db424b0b77cc0d7c73）にまとめています。
実機が無くても、筆者のデータで学習を試したり、評価の録画を見たりできます。

## データセット

| repo_id | 内容 | 章 |
|---|---|---|
| `anuma/so101_tray_red` | 赤いキューブを運ぶタスク（赤いキューブをトレーに入れる）（50エピソード） | 第3〜7章 |
| `anuma/so101_pair_red` | 色を切り替えるタスク: 赤と青を置いて赤を運ぶ、元の置き方（30エピソード） | 第8章 |
| `anuma/so101_pair_blue` | 色を切り替えるタスク: 赤と青を置いて青を運ぶ、元の置き方（30エピソード） | 第8章 |
| `anuma/so101_pair_swap_red` | 色を切り替えるタスク: 赤を運ぶ、赤と青を入れ替えた置き方（30エピソード） | 第8章 |
| `anuma/so101_pair_swap_blue` | 色を切り替えるタスク: 青を運ぶ、赤と青を入れ替えた置き方（30エピソード） | 第8章 |
| `anuma/so101_pair_mix2` | 色を切り替えるタスクの4つを、録画開始直後の静止を切り落として結合したもの（120エピソード） | 第8章 |
| `anuma/so101_pair_mix` | 元の置き方の2つだけを結合したもの（60エピソード、比較用） | 第8章 |

## モデル

| repo_id | 内容 | 章 |
|---|---|---|
| `anuma/act_red_10` | 赤いキューブを運ぶタスクの10エピソードで学習した ACT | 第6章 |
| `anuma/act_red_25` | 赤いキューブを運ぶタスクの25エピソードで学習した ACT | 第6章 |
| `anuma/act_red_50` | 赤いキューブを運ぶタスクの50エピソードで学習した ACT | 第4〜7章 |
| `anuma/smolvla_pair2` | `so101_pair_mix2` で学習した SmolVLA | 第8章 |
| `anuma/smolvla_pair2_b64` | `so101_pair_mix2` を公式の例の設定（batch 64、2万ステップ）で学習した SmolVLA | 第8章 |
| `anuma/smolvla_pair` | `so101_pair_mix` で学習した SmolVLA（比較用） | 第8章 |

## 評価の録画

| repo_id | 内容 |
|---|---|
| `anuma/rollout_act_red_10` | `act_red_10` の評価 |
| `anuma/rollout_act_red_25` | `act_red_25` の評価 |
| `anuma/rollout_act_red_50` | `act_red_50` の評価 |
| `anuma/rollout_smolvla_pair2_red` | `smolvla_pair2` に赤を指示した評価 |
| `anuma/rollout_smolvla_pair2_blue` | `smolvla_pair2` に青を指示した評価 |
| `anuma/rollout_smolvla_pair2_swap_red` | 赤と青の場所を入れ替えて、`smolvla_pair2` に赤を指示した評価 |
| `anuma/rollout_smolvla_pair2_swap_blue` | 赤と青の場所を入れ替えて、`smolvla_pair2` に青を指示した評価 |
| `anuma/rollout_smolvla_pair2_b64_red` / `_blue` / `_swap_red` / `_swap_blue` | `smolvla_pair2_b64` の評価（4通り） |
| `anuma/rollout_smolvla_pair_red` | `smolvla_pair` に赤を指示した評価 |
| `anuma/rollout_smolvla_pair_blue` | `smolvla_pair` に青を指示した評価 |
| `anuma/rollout_smolvla_pair_swap_red` | 赤と青の場所を入れ替えて、`smolvla_pair` に赤を指示した評価 |
| `anuma/rollout_smolvla_pair_swap_blue` | 赤と青の場所を入れ替えて、`smolvla_pair` に青を指示した評価 |

## 使い方

```bash
lerobot-train \
    --dataset.repo_id=<repo_id> \
    --policy.type=act \
    --policy.device=cuda \
    --policy.push_to_hub=false \
    --output_dir=outputs/act_red_50
```

筆者は NVIDIA GPU（RTX 3060 Ti）で学習しました。`smolvla_pair2_b64` だけは、GPU のメモリが 16GB の RTX 5070 Ti で学習しています。
エピソード数を絞って学習する場合は `--dataset.episodes="[0,5,10,...]"` を付けます（第6章）。

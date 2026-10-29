# スクリプトと公式コマンドの対応

本書の手順は公式コマンドで書いています。`scripts/` のスクリプトは、それを包んで短く打てるようにしたものです。
ポート・ID・カメラの設定を `.env` から読むので、同じ作業を繰り返すときに楽になります。

LeRobot の版が上がってスクリプトが動かなくなったときは、公式コマンドに戻ってください。

## 環境を作る

```bash
# スクリプト
bash scripts/setup.sh

# 公式コマンド
conda create -y -n lerobot-tutorial python=3.12
conda activate lerobot-tutorial
conda install -y "ffmpeg=7.1.1" -c conda-forge
pip install "lerobot[feetech,core_scripts,training,smolvla]==0.6.1"
```

## アームのポートを調べる

```bash
# スクリプト（カメラの番号と続けて調べる）
bash scripts/find_devices.sh

# 公式コマンド（アーム1本につき1回）
lerobot-find-port
```

スクリプトは `lerobot-find-port` を呼ばず、同じ処理を日本語の案内付きで行います。
見つけたポートは、確認してから `.env` に書き込みます。

## カメラの番号を調べる

```bash
# 公式コマンド（find_devices.sh もこれを呼ぶ）
lerobot-find-cameras opencv
```

撮影した画像は `outputs/captured_images/` に保存されます。
ファイル名の数字がカメラの番号です。

## キャリブレーション

```bash
# スクリプト（フォロワー、リーダーの順に続けて行う）
bash scripts/calibrate.sh

# 公式コマンド
lerobot-calibrate --robot.type=so101_follower --robot.port=<フォロワーのポート> --robot.id=<フォロワーの ID>
lerobot-calibrate --teleop.type=so101_leader  --teleop.port=<リーダーのポート>   --teleop.id=<リーダーの ID>
```

結果は `~/.cache/huggingface/lerobot/calibration/` に保存されます。スクリプトも同じ場所を使います。
別のアームを使うときは、ID を変えるだけです。ファイルは ID ごとに分かれて保存されます。

ID は `.env` の `FOLLOWER_ID` / `LEADER_ID` と同じ名前にします。

## テレオペレーション

```bash
# スクリプト
bash scripts/teleoperate.sh camera

# 公式コマンド
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=<フォロワーのポート> \
    --robot.id=<フォロワーの ID> \
    --robot.cameras="{ overhead: {type: opencv, index_or_path: <俯瞰カメラの番号>, width: 640, height: 480, fps: 30}, wrist: {type: opencv, index_or_path: <手元カメラの番号>, width: 640, height: 480, fps: 30}}" \
    --teleop.type=so101_leader \
    --teleop.port=<リーダーのポート> \
    --teleop.id=<リーダーの ID> \
    --display_data=true
```

`camera` を付けないと、カメラ無しで起動します（`--robot.cameras` と `--display_data` が付かない）。

## データ収集

```bash
# スクリプト
bash scripts/record.sh so101_tray_red 50 "Pick up the red cube and place it in the tray"

# 公式コマンド
lerobot-record \
    （テレオペレーションと同じ --robot.* / --teleop.* / --display_data） \
    --dataset.repo_id=<HF のユーザー名>/so101_tray_red \
    --dataset.num_episodes=50 \
    --dataset.single_task="Pick up the red cube and place it in the tray" \
    --dataset.no_stamp=true \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2
```

`--dataset.no_stamp=true` を付けないと、データセット名の後ろに日時が付きます。

収集が終わると、データセットは自動で Hub に上がります。
Hub に上げない場合は `--dataset.push_to_hub=false` を付けます（スクリプトなら `--no-upload`）。
Hugging Face にログインしていない場合、スクリプトは自動でローカル保存だけに切り替えます。

Hub には公開で上がります。非公開にする場合は `--dataset.private=true` を付けます。
スクリプトでも同じ引数をそのまま足せます。評価（`lerobot-rollout`）の録画も同じです。

録画が始まったら、すぐにリーダーを動かし始めます。→ を押した後の音声の案内は待たなくて構いません。
音声の間も録画は進んでいます。最初に止まっている時間があると、モデルはそれも真似します。
ACT は約3秒分の動きをまとめて予測するので、最初の静止が約3〜4秒あると、評価で待機姿勢から動き出せなくなります。

## データセットを結合する

公式コマンド（`lerobot-edit-dataset`）は、録画開始直後の静止を切り落とせません。本書では、切り落としと結合を
`scripts/trim_merge.py` で一度に行います（第8章）。

```bash
python scripts/trim_merge.py <HF のユーザー名>/so101_pair_mix2 \
    <HF のユーザー名>/so101_pair_red <HF のユーザー名>/so101_pair_blue \
    <HF のユーザー名>/so101_pair_swap_red <HF のユーザー名>/so101_pair_swap_blue
```

各エピソードの指示文は、結合したあともそのまま残ります。

## 学習（ACT）

スクリプトはありません。公式コマンドを使います。学習は NVIDIA GPU 搭載の学習用のマシンで行います（第4章）。

```bash
lerobot-train \
    --dataset.repo_id=<HF のユーザー名>/so101_tray_red \
    --policy.type=act \
    --policy.device=cuda \
    --policy.repo_id=<HF のユーザー名>/act_red_50 \
    --policy.private=true \
    --output_dir=outputs/act_red_50
```

学習済みモデルは `--policy.repo_id` の名前で Hub に上がります。`--policy.private=true` を付けると非公開になります。

Mac で学習する場合は `--policy.device=mps` にします。既定の10万ステップでは1日以上かかる計算なので、
ステップ数を3万に減らします（第4章）。

```bash
lerobot-train \
    --dataset.repo_id=<HF のユーザー名>/so101_tray_red \
    --policy.type=act \
    --policy.device=mps \
    --policy.push_to_hub=false \
    --steps=30000 \
    --save_freq=5000 \
    --output_dir=outputs/act_red_mac_30k
```

学習と評価を同じ Mac で行うので、Hub には上げていません。
`--policy.push_to_hub=false` を付けないと、学習済みモデルの Hub の送り先を求められて止まります。
Hub に上げる場合は、代わりに `--policy.repo_id` と `--policy.private=true` を付けます。

エピソードを絞って学習するときは、使うエピソードの番号を並べます。
キューブの置き場所ごとに順に録った場合、先頭から10本を取ると1か所分だけになります。
置き場所ごとに同じ本数ずつ選んでください。次の例は、5か所×10本から各2本を選んでいます。

```bash
--dataset.episodes="[0,5,10,15,20,25,30,35,40,45]"
```

## 学習（SmolVLA）

スクリプトはありません。公開されている `lerobot/smolvla_base` から、追加で学習させます。

```bash
lerobot-train \
    --policy.path=lerobot/smolvla_base \
    --dataset.repo_id=<HF のユーザー名>/so101_pair_mix2 \
    --rename_map='{"observation.images.overhead": "observation.images.camera1", "observation.images.wrist": "observation.images.camera2"}' \
    --policy.device=cuda \
    --policy.push_to_hub=false \
    --batch_size=16 \
    --steps=80000 \
    --policy.scheduler_warmup_steps=4000 \
    --policy.scheduler_decay_steps=120000 \
    --output_dir=outputs/smolvla_pair2
```

`--rename_map` は、カメラの名前の対応付けです。`smolvla_base` はカメラを `camera1`〜`camera3` と
呼ぶので、本書の `overhead` と `wrist` をそれに合わせます。付けないと、名前が合わずに止まります。

公式の例は `--batch_size=64 --steps=20000` です。GPU のメモリが 8GB だと batch 64 は載りません
（RTX 3060 Ti では、batch 16 で約 5.2GB、batch 32 でメモリ不足）。
batch を4分の1にした分、次の3つを4倍にしています。

- `--steps` … 学習に使うフレームの総量を公式の例に揃える
- `--policy.scheduler_warmup_steps`（既定 1000）… 学習率を上げていく期間
- `--policy.scheduler_decay_steps`（既定 30000）… 学習率を下げていく期間

フレームの総量を揃えても、学習の進み方まで公式の例と同じにはなりません（学習率などは変えていないため）。詳しくは本の第8章を参照してください。

## 評価

```bash
# スクリプト
bash scripts/evaluate.sh <HF のユーザー名>/act_red_50 10 \
    "Pick up the red cube and place it in the tray" --dataset.private=true

# 公式コマンド
lerobot-rollout \
    --strategy.type=episodic \
    --policy.path=<HF のユーザー名>/act_red_50 \
    （テレオペレーションと同じ --robot.* / --teleop.* / --display_data） \
    --dataset.repo_id=<HF のユーザー名>/rollout_act_red_50 \
    --dataset.num_episodes=10 \
    --dataset.single_task="Pick up the red cube and place it in the tray" \
    --dataset.no_stamp=true \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2 \
    --dataset.private=true
```

スクリプトは、評価の録画の名前をモデルの名前から付けます（上の例では `rollout_act_red_50`）。

評価の録画の名前は `rollout_` で始めます。そうしないと `lerobot-rollout` が受け付けません。
`--dataset.single_task` の指示文が、そのままモデルへの指示になります。

同じモデルを別の指示文で評価するときは、`--name` で名前を分けます。

SmolVLA の評価では、学習のときと同じ `--rename_map` を付けます。
スクリプトは、知らない `--xxx` の引数をそのまま `lerobot-rollout` に渡します。
`record.sh` も同じで、`--dataset.private=true` などを足せます。

```bash
bash scripts/evaluate.sh <HF のユーザー名>/smolvla_pair2 10 \
    "Pick up the red cube and place it in the tray" \
    --rename_map='{"observation.images.overhead": "observation.images.camera1", "observation.images.wrist": "observation.images.camera2"}' \
    --name=smolvla_pair2_red --dataset.private=true
```

青の指示文で評価するときは、指示文を `"Pick up the blue cube and place it in the tray"` に、
`--name` を `smolvla_pair2_blue` に変えます（第8章）。

## 評価の結果を見返す

公式コマンドはありません。評価の録画から、試行ごとの写真を並べた画像を作ります。

```bash
python scripts/eval_sheet.py <HF のユーザー名>/rollout_act_red_50
```

1行が1試行で、左から開始・途中2枚・終わりの俯瞰カメラの写真が並びます。
終わりの写真でキューブがトレーに入っていれば成功です。
評価中に成功・失敗をメモし忘れても、これで数え直せます。
画像は `outputs/eval_sheets/` に保存されます。

# so101-lerobot-tutorial

書籍『SO-101 ロボットアーム LeRobot 学習ガイド』のサンプルコードです。

SO-101 でテレオペレーションからデータ収集・学習・実機での自律動作までを一通り動かすための
スクリプトをまとめています。

## 本書の版との対応

**本を読みながら使う場合は、必ずタグを指定して clone してください。**
`main` は最新版で、書籍の記述と合わないことがあります。
`v1` は初版用のタグで、初版の手順に合わせた修正を含む最新の状態を指します。
修正のたびの状態は `v1.0.0` のような固定のタグで残します。
タグを指定すると `detached HEAD` という注意が出ることがありますが、問題ありません。

```bash
git clone -b v1 https://github.com/akiraNuma/so101-lerobot-tutorial.git
```

| タグ | 本の版 | LeRobot |
|---|---|---|
| `v1` | 初版 | 0.6.1 |

## 必要なもの

- SO-101 リーダーアーム / フォロワーアーム（組み立て済み・キャリブレーション可能な状態）
- USB カメラ2台（俯瞰用・手元用）
- 赤・青のキューブ — `hardware/so101-grasp-cube.stl` を印刷します。
  25mm 立方体、PLA、infill 15%、サポートなし。筆者はつや有りのフィラメントで印刷した
- 置き先のトレー — `hardware/so101-task-tray.stl` を印刷します。
  120mm 角、高さ 15mm。筆者はグレーで印刷しました
- **アームをつなぐマシン** — アームとカメラをつなぎ、データ収集と評価を行います。
  本書の手順は Apple Silicon 搭載の Mac で確かめています
- **NVIDIA GPU 搭載の学習用のマシン** — 学習を行います（`--policy.device=cuda`）
  - 学習用のマシンが無い場合、ACT はステップ数を減らせば Apple Silicon の Mac でも学習できます（`--policy.device=mps`、第4章）。
    SmolVLA の Mac での学習は試していません

## 進め方

本書の手順は、LeRobot の公式コマンドで書いています。まずは公式コマンドで一通り動かしてください。
`scripts/` のスクリプトは、同じコマンドを何度も打つ作業を楽にするためのものです。使わなくても本書は進められます。

## セットアップ（公式コマンド）

```bash
# 1. 環境構築
conda create -y -n lerobot-tutorial python=3.12
conda activate lerobot-tutorial
conda install -y "ffmpeg=7.1.1" -c conda-forge
pip install "lerobot[feetech,core_scripts,training,smolvla]==0.6.1"

# 2. Hugging Face にログインする（データセットを Hub に上げる場合）
hf auth login

# 3. アームのポートを調べる（フォロワーとリーダーで1回ずつ）
lerobot-find-port

# 4. カメラの番号を調べる
lerobot-find-cameras opencv

# 5. アームのキャリブレーション
lerobot-calibrate --robot.type=so101_follower --robot.port=<フォロワーのポート> --robot.id=<フォロワーの ID>
lerobot-calibrate --teleop.type=so101_leader  --teleop.port=<リーダーのポート>   --teleop.id=<リーダーの ID>
```

この後のテレオペレーション・データ収集・学習・評価のコマンドは、`docs/official-commands.md` にまとめています。

カメラをつなぎ替えたら、番号が変わっていないか手順3・4で確かめてください。

## スクリプトで楽をする

データ収集と評価では、長いコマンドを何度も打ちます。
ポート・ID・カメラの設定を `.env` に書いておくと、スクリプトから短く呼べます。

```bash
bash scripts/setup.sh              # セットアップの手順1をまとめて行う
cp .env.example .env
bash scripts/find_devices.sh       # ポートとカメラの番号を調べて .env に書く
bash scripts/calibrate.sh          # フォロワーとリーダーのキャリブレーション
bash scripts/teleoperate.sh camera
bash scripts/record.sh so101_tray_red 50 "Pick up the red cube and place it in the tray"
```

| スクリプト | 用途 |
|---|---|
| `scripts/setup.sh` | conda 環境の作成と LeRobot のインストール |
| `scripts/find_devices.sh` | アームのポートとカメラの番号を調べる |
| `scripts/calibrate.sh` | フォロワーとリーダーのキャリブレーション |
| `scripts/teleoperate.sh` | テレオペレーションの動作確認 |
| `scripts/record.sh` | データ収集 |
| `scripts/evaluate.sh` | 学習済みポリシーを実機で動かして評価 |
| `scripts/eval_sheet.py` | 評価の録画から、試行ごとの写真を並べた画像を作る |
| `scripts/trim_merge.py` | 各エピソードの最初の静止を切り落とし、複数のデータセットを1つにまとめる |
| `scripts/probe.py` | 画像を差し替えたとき、モデルが出すチャンク（一度に予測した動作）がどれだけ変わるかを調べる |

`eval_sheet.py`・`trim_merge.py`・`probe.py` 以外は、中で公式コマンドを呼んでいるだけです。対応は `docs/official-commands.md` にあります。
LeRobot の版が変わってスクリプトが動かなくなったときは、公式コマンドに戻ってください。

学習にはスクリプトがありません。`lerobot-train` を直接打ちます。

## 設定

スクリプトを使う場合は、環境ごとに違う値を `.env` に書きます。`.env` は Git 管理外です。
雛形は `.env.example` を見てください。

キャリブレーションデータはアームの個体ごとに違うため、このリポジトリには含めていません。
保存先は公式コマンドと同じ `~/.cache/huggingface/lerobot/calibration/` です。
別のアームを使うときは、ID を変えるだけです。ファイルは ID ごとに分かれて保存されます。

## データセット

本書で使ったデータセットとモデルは Hugging Face Hub で公開しています。
実機が無くても、筆者のデータで学習を試したり、評価の録画を見たりできます。一覧は `DATASETS.md` を参照してください。

## ライセンス

Apache License 2.0（`LICENSE` / `NOTICE`）。

LeRobot（Apache License 2.0）は `pip` で別途インストールします。
このリポジトリに LeRobot のコードは含まれていません。

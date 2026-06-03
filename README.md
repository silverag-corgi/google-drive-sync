# google-drive-sync

`rclone bisync` を使ってローカルフォルダとGoogleドライブを双方向同期するためのスクリプト。

## Files

- `scripts/rclone-bisync.sh`
  - `--first-run` を付けると初回同期として `--resync` を実行
  - `--first-run` の本実行時に `LOCAL_DIR` を自動作成
  - `--first-run` の本実行時に `RCLONE_TEST` を両側へ自動作成
  - `--dry-run` を付けると変更内容だけ確認して実際の同期はしない
  - `--create-empty-src-dirs` を付けると空ディレクトリも同期対象に含める
  - 引数なしでは2回目以降の通常同期を実行

## Behavior

- Google Docs / Sheets / Slides などの Google 系ドキュメントはローカル側へ `link.html` として同期する
- 競合時は自動解決せず、`rclone bisync` の競合エラーとして停止させる
- 2回目以降の通常実行では `--check-access` を使う

## Setup

1. rclone をインストールする ([公式ドキュメント](https://rclone.org/install/))
   ```shell
   curl https://rclone.org/install.sh | sudo bash
   rclone version
   ```
2. Googleドライブの初期設定を行う ([公式ドキュメント](https://rclone.org/drive/))
   ```shell
   rclone config
   ```
3. Googleドライブ側へアクセスできることを確認する
   ```shell
   rclone lsd google-drive:
   ```

## Usage

初回:

```bash
export LOCAL_DIR="/path/to/local"
export REMOTE_DIR="mydrive:folder/path"
./scripts/rclone-bisync.sh --first-run
```

2回目以降:

```bash
export LOCAL_DIR="/path/to/local"
export REMOTE_DIR="mydrive:folder/path"
./scripts/rclone-bisync.sh
```

確認だけしたい場合:

```bash
export LOCAL_DIR="/path/to/local"
export REMOTE_DIR="mydrive:folder/path"
./scripts/rclone-bisync.sh --dry-run
```

## Cron

定期実行する場合は [cron/rclone-bisync.cron](./cron/rclone-bisync.cron) を使う。
デフォルトでは15分ごとに通常同期を実行し、ログを `LOG_FILE` に追記する。

1. 環境変数を環境に合わせて修正する
   - `LOCAL_DIR`, `REMOTE_DIR`, `LOG_FILE`
2. 既存のCronタスクを確認する
   ```shell
   crontab -l
   ```
3. Cronタスクが存在しない場合、Cronを登録する
   ```shell
   crontab cron/rclone-bisync.cron
   ```

## Recovery

オプションを変更した場合や `Bisync aborted. Must run --resync to recover.` が出た場合は状態ファイルを作り直す。

```bash
./scripts/rclone-bisync.sh --first-run
```

通常実行で `--check-access` エラーが出る場合は、
`RCLONE_TEST` を削除していないか確認した上で `./scripts/rclone-bisync.sh --first-run` を再実行する。

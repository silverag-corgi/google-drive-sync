# google-drive-sync

`rclone bisync` を使ってローカルフォルダとGoogleドライブを双方向同期するためのスクリプト。

## Files

- `scripts/rclone-bisync.sh`
  - `--first-run` を付けると初回同期として `--resync` を実行
  - `--first-run` の本実行時に `LOCAL_DIR` を自動作成
  - `--first-run` の本実行時に `CHECK_ACCESS_MARKER` を両側へ自動作成
  - `--dry-run` を付けると変更内容だけ確認して実際の同期はしない
  - `--create-empty-src-dirs` を付けると空ディレクトリも同期対象に含める
  - 引数なしでは2回目以降の通常同期を実行
- `cron/rclone-bisync.cron`
  - `cron` で15分ごとに通常同期するためのサンプル設定
- `systemd/google-drive-sync.service`
  - `systemd --user` から同期スクリプトを1回実行する unit
- `systemd/google-drive-sync.timer`
  - 15分ごとに `google-drive-sync.service` を起動する timer

## Behavior

- Google Docs / Sheets / Slides などの Google 系ドキュメントはローカル側へ `link.html` として同期する
- 競合時は自動解決せず、`rclone bisync` の競合エラーとして停止させる
- 2回目以降の通常実行では `--check-access` を使う
- `CHECK_ACCESS_MARKER` で `--check-access` 用の確認ファイル名を上書きできる

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
export CHECK_ACCESS_MARKER="RCLONE_TEST"
./scripts/rclone-bisync.sh --first-run
```

2回目以降:

```bash
export LOCAL_DIR="/path/to/local"
export REMOTE_DIR="mydrive:folder/path"
export CHECK_ACCESS_MARKER="RCLONE_TEST"
./scripts/rclone-bisync.sh
```

確認だけしたい場合:

```bash
export LOCAL_DIR="/path/to/local"
export REMOTE_DIR="mydrive:folder/path"
export CHECK_ACCESS_MARKER="RCLONE_TEST"
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

## systemd

`cron` の代わりに `systemd --user` timer でも定期実行できる。
ノートPCのスリープ復帰後にも取りこぼしを補いたい場合は、`Persistent=true` を使えるこちらが便利。

前提:
- `systemd --user` が使える Linux 環境であること

1. unit ファイルを現在のリポジトリから link する
   ```shell
   systemctl --user link "$PWD/systemd/google-drive-sync.service"
   systemctl --user link "$PWD/systemd/google-drive-sync.timer"
   ```
2. 環境変数ファイルをリポジトリ内に作成する
   ```shell
   cp systemd/google-drive-sync.env.sample systemd/google-drive-sync.env
   ```
3. `systemd/google-drive-sync.env` を環境に合わせて修正する
   - `LOCAL_DIR` には絶対パスを書く
   - `REMOTE_DIR` には `mydrive:` や `mydrive:folder/path` のような rclone remote を書く
   - `CHECK_ACCESS_MARKER` は必要なら確認ファイル名を上書きする
   - `WORKING_DIRECTORY` にはこのリポジトリの絶対パスを書く
   - `EXEC_START` には `scripts/rclone-bisync.sh` の絶対パスを書く
4. `systemd --user` 設定ディレクトリへシンボリックリンクを作成する
   ```shell
   ln -sfn "$PWD/systemd/google-drive-sync.env" ~/.config/systemd/user/google-drive-sync.env
   ```
5. timer を有効化する
   ```shell
   systemctl --user daemon-reload
   systemctl --user enable --now google-drive-sync.timer
   ```
6. 状態を確認する
   ```shell
   systemctl --user list-timers --all
   systemctl --user status google-drive-sync.timer
   systemctl --user status google-drive-sync.service
   ```

### Logs

`systemd` で実行したログは `journalctl` で確認できる。

```shell
journalctl --user -u google-drive-sync.service
journalctl --user -u google-drive-sync.service --since today
journalctl --user -u google-drive-sync.service -f
```

手動で1回だけ試す場合:

```shell
systemctl --user start google-drive-sync.service
systemctl --user status google-drive-sync.service
```

注意:
- `link` 方式では、このリポジトリを移動したり削除したりすると unit の参照先が壊れる
- `google-drive-sync.env` のシンボリックリンクも、このリポジトリを移動したり削除したりすると参照先が壊れる
- 配置場所を変えた場合は、あらためて `systemctl --user link ...` を実行し直す

## Recovery

オプションを変更した場合や `Bisync aborted. Must run --resync to recover.` が出た場合は状態ファイルを作り直す。

```bash
./scripts/rclone-bisync.sh --first-run
```

通常実行で `--check-access` エラーが出る場合は、
`CHECK_ACCESS_MARKER` で指定している確認ファイルを削除していないか確認した上で `./scripts/rclone-bisync.sh --first-run` を再実行する。

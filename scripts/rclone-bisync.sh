#!/usr/bin/env bash

set -euo pipefail

LOCAL_DIR="${LOCAL_DIR:-$HOME/workspace/GoogleDrive}"
REMOTE_DIR="${REMOTE_DIR:-google-drive:}"
CHECK_ACCESS_MARKER="${CHECK_ACCESS_MARKER:-RCLONE_TEST}"

FIRST_RUN="false"
DRY_RUN="false"
CREATE_EMPTY_SRC_DIRS="false"
ARGS=()

show_usage() {
  cat <<EOF
Usage: $0 [--first-run|-f] [--dry-run|-n] [--create-empty-src-dirs|-e] [--help|-h]

Options:
  -f, --first-run              Run bisync with --resync for the initial sync.
  -n, --dry-run                Show what would change without modifying files.
  -e, --create-empty-src-dirs  Create empty directories during sync.
  -h, --help                   Show this help message.

Environment variables:
  Required:
    LOCAL_DIR                     Local sync directory. Default: $HOME/workspace/GoogleDrive
    REMOTE_DIR                    Remote sync directory. Default: google-drive:
    CHECK_ACCESS_MARKER           Filename used by --check-access. Default: RCLONE_TEST
EOF
}

parse_args() {
  local arg

  for arg in "$@"; do
    case "$arg" in
      -f|--first-run)
        FIRST_RUN="true"
        ;;
      -n|--dry-run)
        DRY_RUN="true"
        ;;
      -e|--create-empty-src-dirs)
        CREATE_EMPTY_SRC_DIRS="true"
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $arg" >&2
        show_usage
        exit 1
        ;;
    esac
  done
}

build_args() {
  ARGS=(
    bisync
    "$LOCAL_DIR"
    "$REMOTE_DIR"
    --drive-export-formats link.html
    --check-first
    --verbose
  )

  if [[ "$FIRST_RUN" == "true" ]]; then
    ARGS+=(--resync)
  else
    ARGS+=(
      --check-access
      --check-filename "$CHECK_ACCESS_MARKER"
    )
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    ARGS+=(--dry-run)
  fi

  if [[ "$CREATE_EMPTY_SRC_DIRS" == "true" ]]; then
    ARGS+=(--create-empty-src-dirs)
  fi
}

prepare_first_run() {
  if [[ "$FIRST_RUN" != "true" || "$DRY_RUN" == "true" ]]; then
    return
  fi

  mkdir -p "$LOCAL_DIR"
  rclone touch "$REMOTE_DIR$CHECK_ACCESS_MARKER"
  rm -f "$LOCAL_DIR/$CHECK_ACCESS_MARKER"
  rclone copyto "$REMOTE_DIR$CHECK_ACCESS_MARKER" "$LOCAL_DIR/$CHECK_ACCESS_MARKER"
}

main() {
  parse_args "$@"
  build_args
  prepare_first_run
  exec rclone "${ARGS[@]}"
}

main "$@"

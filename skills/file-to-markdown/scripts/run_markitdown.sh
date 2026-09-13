#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: run_markitdown.sh <input-path> [--output <output-path>]

Converts a local file to Markdown using Microsoft MarkItDown.
By default, writes Markdown to stdout. With --output, writes atomically to the
given file path and prints that path to stdout.
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

INPUT_PATH=""
OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --output" >&2
        exit 2
      fi
      OUTPUT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [[ -n "$INPUT_PATH" ]]; then
        echo "Only one input path is supported" >&2
        exit 2
      fi
      INPUT_PATH="$1"
      shift
      ;;
  esac
done

if [[ -z "$INPUT_PATH" ]]; then
  echo "An input path is required" >&2
  exit 2
fi

if [[ ! -f "$INPUT_PATH" ]]; then
  echo "Input file not found: $INPUT_PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$SKILL_DIR/.runtime/markitdown"
VENV_DIR="$RUNTIME_DIR/venv"
BIN_DIR="$VENV_DIR/bin"
MARKITDOWN_BIN="$BIN_DIR/markitdown"
PYTHON_BIN="$BIN_DIR/python"
LOCK_DIR="$RUNTIME_DIR/bootstrap.lock"
INSTALL_SPEC_FILE="$RUNTIME_DIR/install-spec.txt"
INSTALL_SPEC="markitdown[pdf,docx,pptx,xlsx,xls]>=0.1.0,<0.2"

mkdir -p "$RUNTIME_DIR"

release_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

acquire_lock() {
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    sleep 1
  done
}

select_python() {
  local candidate version major minor
  for candidate in /opt/homebrew/bin/python3.14 /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 /opt/homebrew/bin/python3.10 python3 python; do
    if ! command -v "$candidate" >/dev/null 2>&1; then
      continue
    fi
    version="$("$candidate" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
    major="${version%%.*}"
    minor="${version#*.}"
    if [[ -n "$version" && "$major" -ge 3 && "$minor" -ge 10 || "$major" -gt 3 ]]; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

needs_rebuild=0
if [[ -x "$PYTHON_BIN" ]]; then
  existing_version="$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
  existing_major="${existing_version%%.*}"
  existing_minor="${existing_version#*.}"
  if [[ -z "$existing_version" || "$existing_major" -lt 3 || ( "$existing_major" -eq 3 && "$existing_minor" -lt 10 ) ]]; then
    needs_rebuild=1
  fi
fi

if [[ "$needs_rebuild" -eq 1 ]]; then
  rm -rf "$VENV_DIR"
fi

if [[ ! -x "$PYTHON_BIN" ]]; then
  acquire_lock
  trap release_lock EXIT
  if [[ ! -x "$PYTHON_BIN" ]]; then
    if command -v uv >/dev/null 2>&1; then
      uv venv --python 3.12 "$VENV_DIR" >/dev/null
    else
      BOOTSTRAP_PYTHON="$(select_python || true)"
      if [[ -z "${BOOTSTRAP_PYTHON:-}" ]]; then
        echo "Python 3.10+ is required to create a MarkItDown environment" >&2
        exit 1
      fi
      "$BOOTSTRAP_PYTHON" -m venv "$VENV_DIR"
    fi
  fi
  release_lock
  trap - EXIT
fi

CURRENT_INSTALL_SPEC=""
if [[ -f "$INSTALL_SPEC_FILE" ]]; then
  CURRENT_INSTALL_SPEC="$(cat "$INSTALL_SPEC_FILE")"
fi

if [[ ! -x "$MARKITDOWN_BIN" || "$CURRENT_INSTALL_SPEC" != "$INSTALL_SPEC" ]]; then
  acquire_lock
  trap release_lock EXIT
  CURRENT_INSTALL_SPEC=""
  if [[ -f "$INSTALL_SPEC_FILE" ]]; then
    CURRENT_INSTALL_SPEC="$(cat "$INSTALL_SPEC_FILE")"
  fi
  if [[ ! -x "$MARKITDOWN_BIN" || "$CURRENT_INSTALL_SPEC" != "$INSTALL_SPEC" ]]; then
    "$PYTHON_BIN" -m pip install --upgrade pip >/dev/null
    "$PYTHON_BIN" -m pip install "$INSTALL_SPEC" >/dev/null
    printf '%s\n' "$INSTALL_SPEC" > "$INSTALL_SPEC_FILE"
  fi
  release_lock
  trap - EXIT
fi

TMP_OUTPUT="$(mktemp)"
cleanup() {
  rm -f "$TMP_OUTPUT"
}
trap cleanup EXIT

run_markitdown() {
  if [[ -x "$MARKITDOWN_BIN" ]]; then
    "$MARKITDOWN_BIN" "$INPUT_PATH" -o "$TMP_OUTPUT"
  else
    "$PYTHON_BIN" -m markitdown "$INPUT_PATH" -o "$TMP_OUTPUT"
  fi
}

if ! run_markitdown >/dev/null 2>"$RUNTIME_DIR/last-error.log"; then
  cat "$RUNTIME_DIR/last-error.log" >&2
  exit 1
fi

if [[ ! -s "$TMP_OUTPUT" ]]; then
  echo "MarkItDown produced no output for: $INPUT_PATH" >&2
  exit 1
fi

if [[ -n "$OUTPUT_PATH" ]]; then
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  mv "$TMP_OUTPUT" "$OUTPUT_PATH"
  trap - EXIT
  echo "$OUTPUT_PATH"
else
  cat "$TMP_OUTPUT"
fi

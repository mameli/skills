#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: run_pdf_to_markdown.sh <input-path> [--output <output-path>]

Converts a local PDF to Markdown.
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

LOWER_INPUT_PATH="$(printf '%s' "$INPUT_PATH" | tr '[:upper:]' '[:lower:]')"
if [[ "$LOWER_INPUT_PATH" != *.pdf ]]; then
  echo "Only PDF input is supported: $INPUT_PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$SKILL_DIR/.runtime/pdf"
VENV_DIR="$RUNTIME_DIR/venv"
BIN_DIR="$VENV_DIR/bin"
OPENDATALOADER_BIN="$BIN_DIR/opendataloader-pdf"
PYTHON_BIN="$BIN_DIR/python"
LOCK_DIR="$RUNTIME_DIR/bootstrap.lock"
INSTALL_SPEC_FILE="$RUNTIME_DIR/install-spec.txt"
INSTALL_SPEC="opendataloader-pdf>=2.2.1,<3"

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

if ! command -v java >/dev/null 2>&1; then
  echo "Java is required but not found in PATH." >&2
  exit 1
fi

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
        echo "Python 3.10+ is required to create the PDF conversion environment" >&2
        exit 1
      fi
      "$BOOTSTRAP_PYTHON" -m venv "$VENV_DIR"
    fi
  fi
  release_lock
  trap - EXIT
fi

if ! "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
  "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null
fi

CURRENT_INSTALL_SPEC=""
if [[ -f "$INSTALL_SPEC_FILE" ]]; then
  CURRENT_INSTALL_SPEC="$(cat "$INSTALL_SPEC_FILE")"
fi

if [[ ! -x "$OPENDATALOADER_BIN" || "$CURRENT_INSTALL_SPEC" != "$INSTALL_SPEC" ]]; then
  acquire_lock
  trap release_lock EXIT
  CURRENT_INSTALL_SPEC=""
  if [[ -f "$INSTALL_SPEC_FILE" ]]; then
    CURRENT_INSTALL_SPEC="$(cat "$INSTALL_SPEC_FILE")"
  fi
  if [[ ! -x "$OPENDATALOADER_BIN" || "$CURRENT_INSTALL_SPEC" != "$INSTALL_SPEC" ]]; then
    "$PYTHON_BIN" -m pip install --upgrade pip >/dev/null
    "$PYTHON_BIN" -m pip install "$INSTALL_SPEC" >/dev/null
    printf '%s\n' "$INSTALL_SPEC" > "$INSTALL_SPEC_FILE"
  fi
  release_lock
  trap - EXIT
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if ! "$OPENDATALOADER_BIN" -f markdown -o "$TMP_DIR" "$INPUT_PATH" >"$RUNTIME_DIR/last-output.log" 2>"$RUNTIME_DIR/last-error.log"; then
  cat "$RUNTIME_DIR/last-error.log" >&2
  exit 1
fi

INPUT_BASENAME="$(basename "$INPUT_PATH")"
INPUT_STEM="${INPUT_BASENAME%.*}"
GENERATED_MD="$TMP_DIR/$INPUT_STEM.md"

if [[ ! -s "$GENERATED_MD" ]]; then
  FIRST_MD="$(find "$TMP_DIR" -maxdepth 1 -type f -name '*.md' | head -n 1 || true)"
  if [[ -n "$FIRST_MD" && -s "$FIRST_MD" ]]; then
    GENERATED_MD="$FIRST_MD"
  else
    echo "The converter produced no Markdown output for: $INPUT_PATH" >&2
    exit 1
  fi
fi

if [[ -n "$OUTPUT_PATH" ]]; then
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  mv "$GENERATED_MD" "$OUTPUT_PATH"
  trap - EXIT
  rm -rf "$TMP_DIR"
  echo "$OUTPUT_PATH"
else
  cat "$GENERATED_MD"
fi

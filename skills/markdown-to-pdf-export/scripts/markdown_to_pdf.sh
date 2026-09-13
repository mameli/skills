#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <input.md> [output.pdf]" >&2
  exit 1
fi

input_file="$1"
if [[ ! -f "$input_file" ]]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc is not installed or not in PATH" >&2
  exit 1
fi

# Fail early with a clear message if XeLaTeX is missing.
if ! command -v xelatex >/dev/null 2>&1; then
  echo "xelatex is not installed or not in PATH" >&2
  exit 1
fi

if [[ $# -eq 2 ]]; then
  output_file="$2"
else
  output_file="${input_file%.*}.pdf"
fi

pandoc "$input_file" -o "$output_file" \
  --pdf-engine=xelatex \
  -V geometry:margin=1.2cm \
  -V fontsize=10pt \
  -V linestretch=0.95

echo "Created: $output_file"

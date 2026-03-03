#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUTPUT_DIR="${SAGEBRUSH_SCREENSHOT_OUTPUT_DIR:-${REPO_DIR}/artifacts/ios-screenshots}"

mkdir -p "${OUTPUT_DIR}"

export SAGEBRUSH_STANDALONE_DEMO=1
export SCREENSHOT_MODE=1
export SAGEBRUSH_SCREENSHOT_OUTPUT_DIR="${OUTPUT_DIR}"

cd "${REPO_DIR}"

echo "Generating iOS screenshots into: ${OUTPUT_DIR}"

# Swift Testing filter syntax differs across toolchains, so retry with a second filter token.
if ! swift test --filter ScreenshotGenerationTests/generateIOSScreenshots; then
  swift test --filter generateIOSScreenshots
fi

REVIEW_HTML="${OUTPUT_DIR}/review.html"
if [[ ! -f "${REVIEW_HTML}" ]]; then
  echo "Expected review file not found: ${REVIEW_HTML}" >&2
  exit 1
fi

echo "Opening review page: ${REVIEW_HTML}"
open "${REVIEW_HTML}"

echo "Done."

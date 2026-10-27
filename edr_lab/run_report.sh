#!/usr/bin/env bash
# Build (once) and run isolated edr report against edr_lab.elementary.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="${EDR_LAB_IMAGE:-edr-lab-cli:0.25.1}"
NETWORK="${EDR_LAB_NETWORK:-dbt-test-ektov_default}"
OUT_DIR="${ROOT}/edr_out"

mkdir -p "${OUT_DIR}"

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "Building ${IMAGE_NAME}..."
  docker build -t "${IMAGE_NAME}" "${ROOT}"
fi

echo "Running edr report on network ${NETWORK}..."
docker run --rm \
  --network "${NETWORK}" \
  -v "${ROOT}/profiles.yml:/config/profiles.yml:ro" \
  -v "${OUT_DIR}:/out" \
  "${IMAGE_NAME}" \
  report \
  --profiles-dir /config \
  --profile-target lab \
  --file-path /out/elementary_report.html \
  --project-name edr_lab_multi_project

echo ""
echo "Report written to: ${OUT_DIR}/elementary_report.html"
echo "Open with: open ${OUT_DIR}/elementary_report.html"

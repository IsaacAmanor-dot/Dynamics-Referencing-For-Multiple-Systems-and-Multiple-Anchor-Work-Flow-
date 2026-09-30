#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 SYSTEM ANCHOR_ID"
    exit 1
fi

REF_SYS="$1"
ANCHOR_ID="$2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

RUN_DIR="${WORK_ROOT}/${REF_SYS}/anc_${ANCHOR_ID}"

INPUT_FILE="${RUN_DIR}/dn_generic.in"
OUTPUT_FILE="${RUN_DIR}/dn_generic.out"

SUCCESS_FILE="${RUN_DIR}/.success"
FAILED_FILE="${RUN_DIR}/.failed"

if [[ ! -s "${INPUT_FILE}" ]]; then
    echo "ERROR: Missing input: ${INPUT_FILE}"
    exit 1
fi

if [[ -f "${SUCCESS_FILE}" ]]; then
    echo "Already complete: ${REF_SYS} anchor ${ANCHOR_ID}"
    exit 0
fi

rm -f "${FAILED_FILE}"

echo
echo "Dynamic Reference De Novo"
echo "System: ${REF_SYS}"
echo "Anchor: ${ANCHOR_ID}"
echo "Node:   $(hostname)"
echo "Start:  $(date)"
echo

cd "${RUN_DIR}"

set +e

"${DOCK_BIN}" \
    -i "${INPUT_FILE}" \
    -o "${OUTPUT_FILE}"

DOCK_EXIT=$?

set -e

if [[ ${DOCK_EXIT} -eq 0 ]] \
    && [[ -s "${OUTPUT_FILE}" ]] \
    && grep -q "Total elapsed time" "${OUTPUT_FILE}"; then

    : > "${SUCCESS_FILE}"

    echo
    echo "SUCCESS: ${REF_SYS} anchor ${ANCHOR_ID}"
    echo "Finished: $(date)"
    echo

    exit 0
fi

: > "${FAILED_FILE}"

echo
echo "FAILED: ${REF_SYS} anchor ${ANCHOR_ID}"
echo "DOCK exit code: ${DOCK_EXIT}"
echo "Finished: $(date)"
echo

exit 1

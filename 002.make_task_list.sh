#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

if [[ ! -s "${SYSTEM_LIST}" ]]; then
    echo "ERROR: Missing ${SYSTEM_LIST}"
    echo "Run 001.write_files_hms_grid.sh first."
    exit 1
fi

printf "task_id\tsystem\tanchor_id\trun_dir\n" > "${TASK_LIST}"

TASK_ID=0

while read -r REF_SYS; do

    for RUN_DIR in "${WORK_ROOT}/${REF_SYS}"/anc_*; do

        [[ -d "${RUN_DIR}" ]] || continue

        ANCHOR_ID="$(basename "${RUN_DIR}")"
        ANCHOR_ID="${ANCHOR_ID#anc_}"

        if [[ ! -s "${RUN_DIR}/dn_generic.in" ]]; then
            echo "ERROR: Missing ${RUN_DIR}/dn_generic.in"
            exit 1
        fi

        TASK_ID=$((TASK_ID + 1))

        printf "%s\t%s\t%s\t%s\n" \
            "${TASK_ID}" \
            "${REF_SYS}" \
            "${ANCHOR_ID}" \
            "${RUN_DIR}" \
            >> "${TASK_LIST}"

    done

done < "${SYSTEM_LIST}"

echo
echo "Dynamic Reference task list created."
echo
echo "Systems:      $(wc -l < "${SYSTEM_LIST}")"
echo "Calculations: ${TASK_ID}"
echo "Task list:    ${TASK_LIST}"
echo

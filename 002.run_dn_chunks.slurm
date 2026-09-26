#!/bin/bash

set -euo pipefail

if [[ -z "${DREF_WORK_ROOT:-}" ]]; then
    echo "ERROR: DREF_WORK_ROOT was not supplied by the submission script."
    exit 1
fi

SCRIPT_DIR="${DREF_WORK_ROOT}"
source "${SCRIPT_DIR}/000.config.sh"

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID is not set."
    exit 1
fi

TOTAL_TASKS=$(awk 'NR > 1 {count++} END {print count+0}' "${TASK_LIST}")

START_TASK=$(( (SLURM_ARRAY_TASK_ID - 1) * TASKS_PER_NODE + 1 ))
END_TASK=$(( START_TASK + TASKS_PER_NODE - 1 ))

if (( END_TASK > TOTAL_TASKS )); then
    END_TASK=${TOTAL_TASKS}
fi

if (( START_TASK > TOTAL_TASKS )); then
    echo "ERROR: Chunk ${SLURM_ARRAY_TASK_ID} exceeds the task list."
    exit 1
fi

echo
echo "Dynamic Reference De Novo chunk"
echo
echo "Job ID:      ${SLURM_JOB_ID}"
echo "Array ID:    ${SLURM_ARRAY_TASK_ID}"
echo "Node:        $(hostname)"
echo "Task range:  ${START_TASK}-${END_TASK}"
echo "Started:     $(date)"
echo

PIDS=()
TASK_IDS=()

for (( TASK_ID=START_TASK; TASK_ID<=END_TASK; TASK_ID++ )); do

    TASK_LINE=$(awk -F '\t' -v ID="${TASK_ID}" '
        NR > 1 && $1 == ID {
            print
            exit
        }
    ' "${TASK_LIST}")

    if [[ -z "${TASK_LINE}" ]]; then
        echo "ERROR: Task ${TASK_ID} not found."
        exit 1
    fi

    IFS=$'\t' read -r \
        TASK_NUMBER \
        REF_SYS \
        ANCHOR_ID \
        RUN_DIR \
        <<< "${TASK_LINE}"

    echo "Launching task ${TASK_ID}: ${REF_SYS} anchor ${ANCHOR_ID}"

    bash "${SCRIPT_DIR}/run_dn.sh" \
        "${REF_SYS}" \
        "${ANCHOR_ID}" &

    PIDS+=("$!")
    TASK_IDS+=("${TASK_ID}")

done

FAILURES=0

for INDEX in "${!PIDS[@]}"; do

    PID="${PIDS[$INDEX]}"
    TASK_ID="${TASK_IDS[$INDEX]}"

    if wait "${PID}"; then
        echo "Task ${TASK_ID}: complete"
    else
        echo "Task ${TASK_ID}: failed"
        FAILURES=$((FAILURES + 1))
    fi

done

echo
echo "Chunk finished: $(date)"
echo "Tasks launched: ${#TASK_IDS[@]}"
echo "Failures: ${FAILURES}"
echo

if (( FAILURES > 0 )); then
    exit 1
fi

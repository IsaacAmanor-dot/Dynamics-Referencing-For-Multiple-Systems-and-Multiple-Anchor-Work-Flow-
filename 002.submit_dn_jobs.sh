#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

if [[ ! -s "${TASK_LIST}" ]]; then
    echo "ERROR: Missing task list: ${TASK_LIST}"
    echo "Run 002.make_task_list.sh first."
    exit 1
fi

N_TASKS=$(awk 'NR > 1 {count++} END {print count+0}' "${TASK_LIST}")

if (( N_TASKS == 0 )); then
    echo "ERROR: Task list contains no calculations."
    exit 1
fi

N_CHUNKS=$(( (N_TASKS + TASKS_PER_NODE - 1) / TASKS_PER_NODE ))

if (( N_CHUNKS > MAX_NODES )); then
    ARRAY_SPEC="1-${N_CHUNKS}%${MAX_NODES}"
else
    ARRAY_SPEC="1-${N_CHUNKS}"
fi

echo
echo "Submitting Dynamic Reference De Novo experiment"
echo
echo "Calculations:     ${N_TASKS}"
echo "Tasks per node:   ${TASKS_PER_NODE}"
echo "Node chunks:      ${N_CHUNKS}"
echo "Maximum nodes:    ${MAX_NODES}"
echo "Array:            ${ARRAY_SPEC}"
echo "Partition:        ${SLURM_PARTITION}"
echo "Walltime:         ${SLURM_TIME}"
echo

JOB_ID=$(sbatch \
    --parsable \
    --job-name=DRef_DN \
    --partition="${SLURM_PARTITION}" \
    --nodes=1 \
    --ntasks=1 \
    --cpus-per-task="${TASKS_PER_NODE}" \
    --time="${SLURM_TIME}" \
    --array="${ARRAY_SPEC}" \
    --export=ALL,DREF_WORK_ROOT="${WORK_ROOT}" \
    --chdir="${WORK_ROOT}" \
    --output="${WORK_ROOT}/DRef_slurm_%A_%a.out" \
    "${SCRIPT_DIR}/002.run_dn_chunks.slurm")

echo "Submitted job: ${JOB_ID}"
echo

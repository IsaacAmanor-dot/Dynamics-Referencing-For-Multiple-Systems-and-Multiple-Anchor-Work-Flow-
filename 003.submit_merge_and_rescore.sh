#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

JOB_ID=$(sbatch \
    --parsable \
    --job-name=DRef_Rescore \
    --partition="${SLURM_PARTITION}" \
    --nodes=1 \
    --ntasks=1 \
    --cpus-per-task=1 \
    --time="${SLURM_TIME}" \
    --chdir="${WORK_ROOT}" \
    --output="${WORK_ROOT}/DRef_rescore_%j.out" \
    "${SCRIPT_DIR}/003.merge_and_rescore.sh")

echo "Submitted rescoring job: ${JOB_ID}"

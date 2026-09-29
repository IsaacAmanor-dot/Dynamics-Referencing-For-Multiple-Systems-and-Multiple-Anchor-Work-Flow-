#!/bin/bash

set -euo pipefail

# We use the same configuration as the production workflow so the progress
# calculation always refers to the current experiment directory and task list.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

if [[ ! -s "${TASK_LIST}" ]]; then
    echo "ERROR: Missing task list: ${TASK_LIST}"
    echo "Run 002.make_task_list.sh first."
    exit 1
fi

# We count the task-list entries rather than assuming a fixed number of systems
# or anchors. This keeps the statistics consistent with the submitted experiment.

TOTAL_TASKS=$(awk 'NR > 1 {count++} END {print count+0}' "${TASK_LIST}")

if (( TOTAL_TASKS == 0 )); then
    echo "ERROR: Task list contains no calculations."
    exit 1
fi

COMPLETE=0
FAILED=0
PENDING=0
MOL2_COMPLETE=0
TOTAL_MOLECULES=0

# We use temporary files to accumulate per-system statistics and unfinished
# calculations while the complete task list is inspected.

TMP_STATS=$(mktemp)
TMP_REMAINING=$(mktemp)

trap 'rm -f "${TMP_STATS}" "${TMP_REMAINING}"' EXIT

printf "system\ttotal\tcomplete\tfailed\tpending\tmol2\tmolecules\n" > "${TMP_STATS}"

# We determine the state of every system-anchor calculation from the marker
# files written by run_dn.sh. A success marker always takes precedence.

while IFS=$'\t' read -r TASK_ID REF_SYS ANCHOR_ID RUN_DIR; do

    [[ "${TASK_ID}" == "task_id" ]] && continue
    [[ -n "${TASK_ID}" ]] || continue

    SUCCESS_FILE="${RUN_DIR}/.success"
    FAILED_FILE="${RUN_DIR}/.failed"
    MOL2_FILE="${RUN_DIR}/output.denovo_build.mol2"

    STATUS="pending"
    HAS_MOL2=0
    N_MOLECULES=0

    if [[ -f "${SUCCESS_FILE}" ]]; then

        STATUS="complete"
        COMPLETE=$((COMPLETE + 1))

        if [[ -s "${MOL2_FILE}" ]]; then

            HAS_MOL2=1
            MOL2_COMPLETE=$((MOL2_COMPLETE + 1))

            N_MOLECULES=$(grep -c '^@<TRIPOS>MOLECULE' "${MOL2_FILE}" || true)
            TOTAL_MOLECULES=$((TOTAL_MOLECULES + N_MOLECULES))

        fi

    elif [[ -f "${FAILED_FILE}" ]]; then

        STATUS="failed"
        FAILED=$((FAILED + 1))

        printf "%s\t%s\t%s\tFAILED\n" \
            "${TASK_ID}" \
            "${REF_SYS}" \
            "${ANCHOR_ID}" \
            >> "${TMP_REMAINING}"

    else

        STATUS="pending"
        PENDING=$((PENDING + 1))

        printf "%s\t%s\t%s\tPENDING\n" \
            "${TASK_ID}" \
            "${REF_SYS}" \
            "${ANCHOR_ID}" \
            >> "${TMP_REMAINING}"

    fi

    # We store one record per calculation so the results can later be summarized
    # independently for each receptor system.

    printf "%s\t1\t%s\t%s\t%s\t%s\t%s\n" \
        "${REF_SYS}" \
        "$([[ "${STATUS}" == "complete" ]] && echo 1 || echo 0)" \
        "$([[ "${STATUS}" == "failed" ]] && echo 1 || echo 0)" \
        "$([[ "${STATUS}" == "pending" ]] && echo 1 || echo 0)" \
        "${HAS_MOL2}" \
        "${N_MOLECULES}" \
        >> "${TMP_STATS}"

done < "${TASK_LIST}"

# We calculate experiment-wide completion and remaining percentages from the
# number of calculations defined in the task list.

COMPLETION_PERCENT=$(awk \
    -v complete="${COMPLETE}" \
    -v total="${TOTAL_TASKS}" \
    'BEGIN {printf "%.2f", 100*complete/total}')

REMAINING=$((TOTAL_TASKS - COMPLETE))

REMAINING_PERCENT=$(awk \
    -v remaining="${REMAINING}" \
    -v total="${TOTAL_TASKS}" \
    'BEGIN {printf "%.2f", 100*remaining/total}')

if (( COMPLETE > 0 )); then

    AVG_MOLECULES=$(awk \
        -v molecules="${TOTAL_MOLECULES}" \
        -v complete="${COMPLETE}" \
        'BEGIN {printf "%.2f", molecules/complete}')

else

    AVG_MOLECULES="0.00"

fi

echo
echo "Dynamic Reference De Novo Progress"
echo

printf "%-12s %8s %10s %8s %9s %12s\n" \
    "System" \
    "Total" \
    "Complete" \
    "Failed" \
    "Pending" \
    "Completion"

printf "%-12s %8s %10s %8s %9s %12s\n" \
    "------------" \
    "--------" \
    "----------" \
    "--------" \
    "---------" \
    "------------"

# We aggregate the individual task records to show progress for each receptor
# system independently.

awk -F'\t' '
NR > 1 {

    sys=$1

    total[sys]+=$2
    complete[sys]+=$3
    failed[sys]+=$4
    pending[sys]+=$5

    if (!(sys in seen)) {

        order[++n]=sys
        seen[sys]=1

    }
}
END {

    for (i=1; i<=n; i++) {

        sys=order[i]

        if (total[sys] > 0)
            percent=100*complete[sys]/total[sys]
        else
            percent=0

        printf "%-12s %8d %10d %8d %9d %11.2f%%\n",
            sys,
            total[sys],
            complete[sys],
            failed[sys],
            pending[sys],
            percent
    }
}
' "${TMP_STATS}"

echo
echo "Overall calculation progress"
echo

printf "%-32s %10d\n" "Total calculations:" "${TOTAL_TASKS}"
printf "%-32s %10d\n" "Completed:" "${COMPLETE}"
printf "%-32s %10d\n" "Failed:" "${FAILED}"
printf "%-32s %10d\n" "Pending:" "${PENDING}"
printf "%-32s %10d\n" "Remaining:" "${REMAINING}"

echo

printf "%-32s %9s%%\n" "Completion:" "${COMPLETION_PERCENT}"
printf "%-32s %9s%%\n" "Remaining:" "${REMAINING_PERCENT}"

echo
echo "Molecular output statistics"
echo

printf "%-32s %10d\n" "Successful calculations:" "${COMPLETE}"
printf "%-32s %10d\n" "Successful runs with MOL2:" "${MOL2_COMPLETE}"
printf "%-32s %10d\n" "Total generated molecules:" "${TOTAL_MOLECULES}"
printf "%-32s %10s\n" "Molecules per successful run:" "${AVG_MOLECULES}"

MISSING_MOL2=$((COMPLETE - MOL2_COMPLETE))

printf "%-32s %10d\n" \
    "Successful runs without MOL2:" \
    "${MISSING_MOL2}"

# We list calculations that still require attention. Failed calculations are
# distinguished from calculations that have not yet produced a status marker.

if [[ -s "${TMP_REMAINING}" ]]; then

    echo
    echo "Calculations requiring attention"
    echo

    printf "%-10s %-12s %-12s %-10s\n" \
        "Task" \
        "System" \
        "Anchor" \
        "Status"

    printf "%-10s %-12s %-12s %-10s\n" \
        "----------" \
        "------------" \
        "------------" \
        "----------"

    while IFS=$'\t' read -r TASK_ID REF_SYS ANCHOR_ID STATUS; do

        printf "%-10s %-12s %-12s %-10s\n" \
            "${TASK_ID}" \
            "${REF_SYS}" \
            "${ANCHOR_ID}" \
            "${STATUS}"

    done < "${TMP_REMAINING}"

else

    echo
    echo "All calculations have completed successfully."

fi

echo

#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

if [[ ! -s "${SYSTEM_LIST}" ]]; then
    echo "ERROR: Missing ${SYSTEM_LIST}"
    exit 1
fi

while read -r REF_SYS; do

    SYSTEM_RUN="${WORK_ROOT}/${REF_SYS}"

    cd "${SYSTEM_RUN}"

    RANKED="${REF_SYS}_rescored_fullref_ranked.mol2"

    if [[ ! -s "${RANKED}" ]]; then
        echo "Skipping ${REF_SYS}: missing ${RANKED}"
        continue
    fi

    grep -A1 "USER_CHARGES" "${RANKED}" |
        grep '\.' > fragstring_list.txt || true

    : > scorestrings.txt
    : > scorestrs.txt

    while read -r STRING; do

        [[ -n "${STRING}" ]] || continue

        grep -w -A3 "${STRING}" anc_*/output.denovo* 2>/dev/null |
            head -n3 |
            tail -n1 >> scorestrings.txt || true

    done < fragstring_list.txt

    awk -F',' '
    {
        for (i=2; i<NF; i++)
            printf "%s,", $i

        if (NF >= 1)
            print $NF
    }
    ' scorestrings.txt > scorestrs.txt

    echo "${REF_SYS}: ${SYSTEM_RUN}/scorestrs.txt"

done < "${SYSTEM_LIST}"

#!/bin/bash

set -euo pipefail

# We load the shared workflow configuration and receptor-system list.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

if [[ ! -s "${SYSTEM_LIST}" ]]; then
    echo "ERROR: Missing ${SYSTEM_LIST}"
    exit 1
fi

# We extract the De Novo score trajectory associated with molecules retained
# in the final ranked rescoring output for each receptor system.

while read -r REF_SYS; do

    SYSTEM_RUN="${WORK_ROOT}/${REF_SYS}"

    cd "${SYSTEM_RUN}"

    RANKED="${REF_SYS}_rescored_fullref_ranked.mol2"

    if [[ ! -s "${RANKED}" ]]; then
        echo "Skipping ${REF_SYS}: missing ${RANKED}"
        continue
    fi

    # We collect the fragment strings associated with molecules in the ranked
    # MOL2 file so they can be traced back to their original De Novo outputs.

    grep -A1 "USER_CHARGES" "${RANKED}" |
        grep '\.' > fragstring_list.txt || true

    : > scorestrings.txt
    : > scorestrs.txt

    # For each selected fragment string, we recover its corresponding score
    # trajectory from the anchor-specific De Novo output.

    while read -r STRING; do

        [[ -n "${STRING}" ]] || continue

        grep -w -A3 "${STRING}" anc_*/output.denovo* 2>/dev/null |
            head -n3 |
            tail -n1 >> scorestrings.txt || true

    done < fragstring_list.txt

    # We remove the first comma-separated field and retain the numerical score
    # sequence used for subsequent trajectory analysis and plotting.

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

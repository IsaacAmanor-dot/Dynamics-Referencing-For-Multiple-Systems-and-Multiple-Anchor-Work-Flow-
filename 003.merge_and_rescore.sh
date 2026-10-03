#!/bin/bash

set -euo pipefail

# We load the shared experiment paths, DOCK installation, and parameter files.

WORK_DIR="$(pwd)"
source "${WORK_DIR}/000.config.sh"

# We require the validated receptor-system list generated during setup.

if [[ ! -s "${SYSTEM_LIST}" ]]; then
    echo "ERROR: Missing ${SYSTEM_LIST}"
    exit 1
fi

# We initialize experiment-wide statistics files for the four similarity and
# scoring quantities extracted during post-generation rescoring.

: > "${WORK_ROOT}/StatisticsHMS.txt"
: > "${WORK_ROOT}/StatisticsGRD.txt"
: > "${WORK_ROOT}/StatisticsTAN.txt"
: > "${WORK_ROOT}/StatisticsVOL.txt"

# We process the generated molecules from each receptor system independently.

while read -r REF_SYS; do

    echo
    echo "Processing ${REF_SYS}"
    echo

    SYSTEM_RUN="${WORK_ROOT}/${REF_SYS}"
    SYSTEM_SOURCE="${SYSTEM_ROOT}/${REF_SYS}"

    REF_LIGAND="${SYSTEM_SOURCE}/${REF_SYS}.lig.am1bcc.mol2"
    GRID_PREFIX="${SYSTEM_SOURCE}/${REF_SYS}.rec"

    cd "${SYSTEM_RUN}"

    # We remove previous merged, rescored, and extracted analysis products so
    # the current analysis is generated from the available De Novo calculations.

    rm -f \
        "${REF_SYS}_HMS.txt" \
        "${REF_SYS}_GRD.txt" \
        "${REF_SYS}_VOL.txt" \
        "${REF_SYS}_TAN.txt" \
        All_Anchors.mol2 \
        "${REF_SYS}_rescored_fullref"* \
        hungarian.in \
        hungarian.out

    : > All_Anchors.mol2

    MERGED=0

    # We combine the completed De Novo molecular outputs from all available
    # anchors into one multi-MOL2 ensemble for this receptor system.

    for MOL2 in anc_*/output.denovo_build.mol2; do

        [[ -s "${MOL2}" ]] || continue

        cat "${MOL2}" >> All_Anchors.mol2
        MERGED=$((MERGED + 1))

    done

    if (( MERGED == 0 )); then
        echo "WARNING: No completed De Novo MOL2 files found for ${REF_SYS}"
        continue
    fi

    echo "Merged anchor files: ${MERGED}"

    # We construct the rigid Descriptor Score calculation used to rescore the
    # combined molecular ensemble against the system-specific reference ligand.

    cat > hungarian.in << EOF_IN
conformer_search_type                                        rigid
use_internal_energy                                          yes
internal_energy_rep_exp                                      12
internal_energy_cutoff                                       100.0
ligand_atom_file                                             All_Anchors.mol2
limit_max_ligands                                            no
skip_molecule                                                no
read_mol_solvation                                           no
calculate_rmsd                                               no
use_database_filter                                          no
orient_ligand                                                no
bump_filter                                                  no
score_molecules                                              yes
contact_score_primary                                        no
contact_score_secondary                                      no
grid_score_primary                                           no
grid_score_secondary                                         no
multigrid_score_primary                                      no
multigrid_score_secondary                                    no
dock3.5_score_primary                                        no
dock3.5_score_secondary                                      no
continuous_score_primary                                     no
continuous_score_secondary                                   no
footprint_similarity_score_primary                           no
footprint_similarity_score_secondary                         no
pharmacophore_score_primary                                  no
pharmacophore_score_secondary                                no
descriptor_score_primary                                     yes
descriptor_use_grid_score                                    yes
descriptor_use_pharmacophore_score                           no
descriptor_use_tanimoto                                      yes
descriptor_use_hungarian                                     yes
descriptor_use_volume_overlap                                yes
descriptor_use_gist                                          no
descriptor_use_dock3.5                                       no
descriptor_grid_score_rep_rad_scale                          1
descriptor_grid_score_vdw_scale                              1
descriptor_grid_score_es_scale                               1
descriptor_grid_score_grid_prefix                            ${GRID_PREFIX}
descriptor_fingerprint_ref_filename                          ${REF_LIGAND}
descriptor_hms_score_ref_filename                            ${REF_LIGAND}
descriptor_hms_score_matching_coeff                          -5
descriptor_hms_score_rmsd_coeff                              1
descriptor_volume_score_reference_mol2_filename              ${REF_LIGAND}
descriptor_volume_score_overlap_compute_method               analytical
descriptor_weight_grid_score                                 0
descriptor_weight_fingerprint_tanimoto                       0
descriptor_weight_hms_score                                  1
descriptor_weight_volume_overlap_score                       0
minimize_ligand                                              no
atom_model                                                   all
vdw_defn_file                                                ${VDW_DEFN_FILE}
flex_defn_file                                               ${FLEX_DEFN_FILE}
flex_drive_file                                              ${FLEX_DRIVE_FILE}
chem_defn_file                                               ${CHEM_DEFN_FILE}
ligand_outfile_prefix                                        ${REF_SYS}_rescored_fullref
write_orientations                                           no
num_scored_conformers                                        1
rank_ligands                                                 yes
max_ranked_ligands                                           100
EOF_IN

    # We execute the rigid rescoring calculation for the combined molecular set.

    "${DOCK_BIN}" \
        -i hungarian.in \
        -o hungarian.out

    # We extract and numerically sort HMS, Grid, Tanimoto, and Volume scores
    # from the rescored molecular output.

    grep "Hungarian_Matching_Similarity_Score" \
        "${REF_SYS}_rescored_fullref"* 2>/dev/null |
        awk '{print $3}' |
        sort -n > "${REF_SYS}_HMS.txt" || true

    grep "Grid_Score" \
        "${REF_SYS}_rescored_fullref"* 2>/dev/null |
        awk '{print $3}' |
        sort -n > "${REF_SYS}_GRD.txt" || true

    grep "Tanimoto" \
        "${REF_SYS}_rescored_fullref"* 2>/dev/null |
        awk '{print $3}' |
        sort -n > "${REF_SYS}_TAN.txt" || true

    grep "Volume" \
        "${REF_SYS}_rescored_fullref"* 2>/dev/null |
        awk '{print $3}' |
        sort -n > "${REF_SYS}_VOL.txt" || true

    # For HMS, the lowest score in the sorted distribution is retained as the
    # best value together with the system-wide average.

    if [[ -s "${REF_SYS}_HMS.txt" ]]; then

        AVG=$(awk '{sum += $1; n++} END {if (n > 0) print sum/n}' "${REF_SYS}_HMS.txt")
        BEST=$(head -n1 "${REF_SYS}_HMS.txt")

        echo "Sys: ${REF_SYS} Best: ${BEST} Average: ${AVG}" \
            >> "${WORK_ROOT}/StatisticsHMS.txt"

    fi

    # For Grid Score, the lowest score is retained as the best value.

    if [[ -s "${REF_SYS}_GRD.txt" ]]; then

        AVG=$(awk '{sum += $1; n++} END {if (n > 0) print sum/n}' "${REF_SYS}_GRD.txt")
        BEST=$(head -n1 "${REF_SYS}_GRD.txt")

        echo "Sys: ${REF_SYS} Best: ${BEST} Average: ${AVG}" \
            >> "${WORK_ROOT}/StatisticsGRD.txt"

    fi

    # For Tanimoto similarity, the highest value is retained as the best match.

    if [[ -s "${REF_SYS}_TAN.txt" ]]; then

        AVG=$(awk '{sum += $1; n++} END {if (n > 0) print sum/n}' "${REF_SYS}_TAN.txt")
        BEST=$(tail -n1 "${REF_SYS}_TAN.txt")

        echo "Sys: ${REF_SYS} Best: ${BEST} Average: ${AVG}" \
            >> "${WORK_ROOT}/StatisticsTAN.txt"

    fi

    # For Volume overlap, the highest value is retained as the best match.

    if [[ -s "${REF_SYS}_VOL.txt" ]]; then

        AVG=$(awk '{sum += $1; n++} END {if (n > 0) print sum/n}' "${REF_SYS}_VOL.txt")
        BEST=$(tail -n1 "${REF_SYS}_VOL.txt")

        echo "Sys: ${REF_SYS} Best: ${BEST} Average: ${AVG}" \
            >> "${WORK_ROOT}/StatisticsVOL.txt"

    fi

done < "${SYSTEM_LIST}"

echo
echo "Merge and rescoring complete."
echo

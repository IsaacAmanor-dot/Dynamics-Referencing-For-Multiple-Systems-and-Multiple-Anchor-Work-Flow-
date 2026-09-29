#!/bin/bash

set -euo pipefail

# We load the shared experiment paths, DOCK installation, and parameter files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

# We require the receptor-system list used throughout the experiment.

if [[ ! -s "${SYSTEM_LIST}" ]]; then
    echo "ERROR: Missing ${SYSTEM_LIST}"
    exit 1
fi

# We analyze molecular growth independently across De Novo layers 1 through 9.

for LAYER in $(seq 1 9); do

    while read -r REF_SYS; do

        SYSTEM_RUN="${WORK_ROOT}/${REF_SYS}"
        SYSTEM_SOURCE="${SYSTEM_ROOT}/${REF_SYS}"

        REF_LIGAND="${SYSTEM_SOURCE}/${REF_SYS}.lig.am1bcc.mol2"
        GRID_PREFIX="${SYSTEM_SOURCE}/${REF_SYS}.rec"

        cd "${SYSTEM_RUN}"

        LAYER_MOL2="All_Anchors_Layer_${LAYER}.mol2"

        rm -f "${LAYER_MOL2}"
        : > "${LAYER_MOL2}"

        FOUND=0

        # We combine the molecules generated at the current growth layer across
        # all available anchors for the receptor system.

        for MOL2 in anc_*/output.anchor_1.root_layer_"${LAYER}".mol2; do

            [[ -s "${MOL2}" ]] || continue

            cat "${MOL2}" >> "${LAYER_MOL2}"
            FOUND=$((FOUND + 1))

        done

        if (( FOUND == 0 )); then
            echo "${REF_SYS} layer ${LAYER}: no molecules found"
            continue
        fi

        # We rigidly rescore the combined layer-specific molecular ensemble
        # against the full reference ligand and retain the top-ranked molecule.

        cat > hungarian_layer_${LAYER}.in << EOF_IN
conformer_search_type                                        rigid
use_internal_energy                                          yes
internal_energy_rep_exp                                      12
internal_energy_cutoff                                       100.0
ligand_atom_file                                             ${LAYER_MOL2}
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
ligand_outfile_prefix                                        ${REF_SYS}_rescored_fullref_Layer_${LAYER}
write_orientations                                           no
num_scored_conformers                                        1
rank_ligands                                                 yes
max_ranked_ligands                                           1
EOF_IN

        "${DOCK_BIN}" \
            -i "hungarian_layer_${LAYER}.in" \
            -o "hungarian_layer_${LAYER}.out"

        RANKED="${REF_SYS}_rescored_fullref_Layer_${LAYER}_ranked.mol2"

        if [[ ! -s "${RANKED}" ]]; then
            echo "WARNING: Ranked MOL2 missing for ${REF_SYS}, layer ${LAYER}"
            continue
        fi

        # We recover the fragment string associated with the best molecule from
        # the ranked layer-specific rescoring output.

        FRAGSTRING=$(grep -A1 "USER_CHARGES" "${RANKED}" | tail -n1 || true)

        if [[ -z "${FRAGSTRING}" ]]; then
            echo "WARNING: Fragment string not found for ${REF_SYS}, layer ${LAYER}"
            continue
        fi

        # We use the fragment string to trace the selected molecule back to its
        # original anchor-specific De Novo growth tree.

        FILE=$(grep -l -F "${FRAGSTRING}" anc_*/output.growth_tree*.mol2 2>/dev/null | head -n1 || true)

        if [[ -n "${FILE}" ]]; then

            cp "${FILE}" \
                "${REF_SYS}_Best_Mol_Layer_${LAYER}_GrowthTree.mol2"

            echo "${REF_SYS} layer ${LAYER}: ${FILE}"

        else
            echo "WARNING: Growth tree not found for ${REF_SYS}, layer ${LAYER}"
        fi

    done < "${SYSTEM_LIST}"

done

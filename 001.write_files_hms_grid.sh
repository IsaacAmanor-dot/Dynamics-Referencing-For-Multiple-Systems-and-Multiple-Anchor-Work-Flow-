#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/000.config.sh"

ERRORS=0

check_file()
{
    local NAME="$1"
    local FILE="$2"

    if [[ ! -f "${FILE}" ]]; then
        echo "ERROR: Missing ${NAME}: ${FILE}"
        ERRORS=$((ERRORS + 1))
    fi
}

echo
echo "Validating Dynamic Reference workflow..."
echo

if [[ ! -x "${DOCK_BIN}" ]]; then
    echo "ERROR: DOCK binary is not executable: ${DOCK_BIN}"
    ERRORS=$((ERRORS + 1))
fi

check_file "scaffold library" "${FRAGLIB_SCAFFOLD}"
check_file "linker library" "${FRAGLIB_LINKER}"
check_file "sidechain library" "${FRAGLIB_SIDECHAIN}"
check_file "torsion environment table" "${FRAGLIB_TORENV}"
check_file "VDW definition" "${VDW_DEFN_FILE}"
check_file "flex definition" "${FLEX_DEFN_FILE}"
check_file "flex drive table" "${FLEX_DRIVE_FILE}"

N_ANCHORS=140

mapfile -t ANCHORS < <(
    find "${ANCHOR_ROOT}" \
        -maxdepth 1 \
        -type f \
        -name 'anchor_*.mol2' \
        -printf '%f\n' |
    awk -F'[_\.]' '$2 >= 1 && $2 <= 140' |
    sort -V
)

if (( ${#ANCHORS[@]} == 0 )); then
    echo "ERROR: No anchor_*.mol2 files found in ${ANCHOR_ROOT}"
    ERRORS=$((ERRORS + 1))
fi

mapfile -t SYSTEMS < <(
    find "${SYSTEM_ROOT}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%f\n' |
    sort -V
)

if (( ${#SYSTEMS[@]} == 0 )); then
    echo "ERROR: No system directories found in ${SYSTEM_ROOT}"
    ERRORS=$((ERRORS + 1))
fi

if (( ERRORS > 0 )); then
    echo
    echo "Validation failed with ${ERRORS} error(s)."
    exit 1
fi

: > "${SYSTEM_LIST}"

VALID_SYSTEMS=0

echo "Checking receptor systems..."
echo

for REF_SYS in "${SYSTEMS[@]}"; do

    SYSTEM_DIR="${SYSTEM_ROOT}/${REF_SYS}"

    REF_LIGAND="${SYSTEM_DIR}/${REF_SYS}.lig.am1bcc.mol2"
    SPHERES="${SYSTEM_DIR}/${REF_SYS}.rec.clust.close.sph"
    GRID_PREFIX="${SYSTEM_DIR}/${REF_SYS}.rec"

    SYSTEM_OK=yes

    for FILE in \
        "${REF_LIGAND}" \
        "${SPHERES}" \
        "${GRID_PREFIX}.nrg" \
        "${GRID_PREFIX}.bmp"
    do
        if [[ ! -f "${FILE}" ]]; then
            echo "Skipping ${REF_SYS}: missing ${FILE}"
            SYSTEM_OK=no
        fi
    done

    if [[ "${SYSTEM_OK}" == "yes" ]]; then
        echo "${REF_SYS}" >> "${SYSTEM_LIST}"
        VALID_SYSTEMS=$((VALID_SYSTEMS + 1))
    fi

done

if (( VALID_SYSTEMS == 0 )); then
    echo "ERROR: No complete receptor systems were found."
    exit 1
fi

echo
echo "Systems: ${VALID_SYSTEMS}"
echo "Anchors: ${#ANCHORS[@]}"
echo "Expected calculations: $(( VALID_SYSTEMS * ${#ANCHORS[@]} ))"
echo
echo "Generating Dynamic Reference De Novo inputs..."
echo

while read -r REF_SYS; do

    SYSTEM_SOURCE="${SYSTEM_ROOT}/${REF_SYS}"

    REF_LIGAND="${SYSTEM_SOURCE}/${REF_SYS}.lig.am1bcc.mol2"
    SPHERES="${SYSTEM_SOURCE}/${REF_SYS}.rec.clust.close.sph"
    GRID_PREFIX="${SYSTEM_SOURCE}/${REF_SYS}.rec"

    SYSTEM_RUN="${WORK_ROOT}/${REF_SYS}"

    mkdir -p "${SYSTEM_RUN}"

    for ANCHOR_FILE in "${ANCHORS[@]}"; do

        ANCHOR_NAME="${ANCHOR_FILE%.mol2}"
        ANCHOR_ID="${ANCHOR_NAME#anchor_}"

        RUN_DIR="${SYSTEM_RUN}/anc_${ANCHOR_ID}"

        mkdir -p "${RUN_DIR}"

        cat > "${RUN_DIR}/dn_generic.in" << EOF_IN
conformer_search_type                                        denovo
dn_fraglib_scaffold_file                                     ${FRAGLIB_SCAFFOLD}
dn_fraglib_linker_file                                       ${FRAGLIB_LINKER}
dn_fraglib_sidechain_file                                    ${FRAGLIB_SIDECHAIN}
dn_user_specified_anchor                                     yes
dn_fraglib_anchor_file                                       ${ANCHOR_ROOT}/${ANCHOR_FILE}
dn_torenv_table                                              ${FRAGLIB_TORENV}
dn_use_roulette                                              no
dn_name_identifier                                           denovo
dn_sampling_method                                           rand
dn_num_random_picks                                          50
dn_pruning_conformer_score_cutoff                            100.0
dn_pruning_conformer_score_scaling_factor                    1.0
dn_pruning_clustering_cutoff                                 100.0
use_dynamic_reference                                        yes
dynamic_ref_filename                                         ${REF_LIGAND}
dn_mol_wt_cutoff_type                                        soft
dn_upper_constraint_mol_wt                                   1000.0
dn_lower_constraint_mol_wt                                   000.0
dn_mol_wt_std_dev                                            35.0
dn_constraint_rot_bon                                        20
dn_constraint_formal_charge                                  2.0
dn_heur_unmatched_num                                        1
dn_heur_matched_rmsd                                         0.2
dn_unique_anchors                                            1
dn_max_grow_layers                                           9
dn_max_root_size                                             25
dn_max_layer_size                                            25
dn_max_current_aps                                           6
dn_max_scaffolds_per_layer                                   5
dn_write_checkpoints                                         yes
dn_write_prune_dump                                          no
dn_write_orients                                             yes
dn_write_growth_trees                                        yes
dn_output_prefix                                             output
use_internal_energy                                          yes
internal_energy_rep_exp                                      12
internal_energy_cutoff                                       100.0
use_database_filter                                          no
orient_ligand                                                yes
automated_matching                                           yes
receptor_site_file                                           ${SPHERES}
max_orientations                                             1000
critical_points                                              no
chemical_matching                                            no
use_ligand_spheres                                           no
bump_filter                                                  no
score_molecules                                              yes
contact_score_primary                                        no
grid_score_primary                                           no
gist_score_primary                                           no
multigrid_score_primary                                      no
dock3.5_score_primary                                        no
continuous_score_primary                                     no
footprint_similarity_score_primary                           no
pharmacophore_score_primary                                  no
hbond_score_primary                                          no
interal_energy_score_primary                                 no
descriptor_score_primary                                     yes
descriptor_use_grid_score                                    yes
descriptor_use_multigrid_score                               no
descriptor_use_continuous_score                              no
descriptor_use_footprint_similarity                          no
descriptor_use_pharmacophore_score                           no
descriptor_use_tanimoto                                      no
descriptor_use_hungarian                                     yes
descriptor_use_volume_overlap                                no
descriptor_use_gist                                          no
descriptor_use_dock3.5                                       no
descriptor_grid_score_rep_rad_scale                          1
descriptor_grid_score_vdw_scale                              1
descriptor_grid_score_es_scale                               1
descriptor_grid_score_grid_prefix                            ${GRID_PREFIX}
descriptor_hms_score_ref_filename                            ${REF_LIGAND}
descriptor_hms_score_matching_coeff                          -5
descriptor_hms_score_rmsd_coeff                              1
descriptor_weight_grid_score                                 1
descriptor_weight_hms_score                                  25
minimize_ligand                                              yes
minimize_anchor                                              yes
minimize_flexible_growth                                     yes
use_advanced_simplex_parameters                              no
simplex_max_cycles                                           1
simplex_score_converge                                       0.1
simplex_cycle_converge                                       1.0
simplex_trans_step                                           0.25
simplex_rot_step                                             0.1
simplex_tors_step                                            15.0
simplex_anchor_max_iterations                                500
simplex_grow_max_iterations                                  250
simplex_grow_tors_premin_iterations                          0
simplex_random_seed                                          0
simplex_restraint_min                                        no
atom_model                                                   all
vdw_defn_file                                                ${VDW_DEFN_FILE}
flex_defn_file                                               ${FLEX_DEFN_FILE}
flex_drive_file                                              ${FLEX_DRIVE_FILE}
EOF_IN

    done

    echo "${REF_SYS}: generated ${#ANCHORS[@]} anchor calculations"

done < "${SYSTEM_LIST}"

echo
echo "Input generation complete."
echo "Systems:      ${VALID_SYSTEMS}"
echo "Anchors:      ${#ANCHORS[@]}"
echo "Calculations: $(( VALID_SYSTEMS * ${#ANCHORS[@]} ))"
echo

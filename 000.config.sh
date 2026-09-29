#!/bin/bash

# We define the workflow directory from the location of this configuration file.

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="${CONFIG_DIR}"

# We define the shared receptor systems and anchor library used by the experiment.

SYSTEM_ROOT="/gpfs/projects/rizzo/iamanor/Systems_and_Library_Files/001_Systems_Files/002_DRef_Systems"

ANCHOR_ROOT="/gpfs/projects/rizzo/iamanor/DOCK6_Development/Dynamics_Referencing/for_isaac/Dynamic_Reference_for_Isaac/anchors"

# We define the developmental DOCK installation used for Dynamic Reference calculations.

DOCK_ROOT="/gpfs/projects/rizzo/iamanor/DOCK6_Development/Dynamics_Referencing/for_isaac/Dynamic_Reference_for_Isaac/dock6.21_11_05_Dynamic_Reference_Developmental_V1.6.2"

DOCK_BIN="${DOCK_ROOT}/bin/dock6"
DOCK_PARAMS="${DOCK_ROOT}/parameters"

# We define the DOCK parameter files required for De Novo generation and rescoring.

VDW_DEFN_FILE="${DOCK_PARAMS}/vdw_de_novo.defn"
FLEX_DEFN_FILE="/gpfs/projects/rizzo/zzz.programs/dock6.9_mpiv2018.0.3/parameters/flex.defn"
FLEX_DRIVE_FILE="/gpfs/projects/rizzo/zzz.programs/dock6.9_mpiv2018.0.3/parameters/flex_drive.tbl"
CHEM_DEFN_FILE="${DOCK_PARAMS}/chem.defn"

# We define the generic fragment libraries used during De Novo molecular growth.

FRAGLIB_ROOT="/gpfs/projects/rizzo/iamanor/Systems_and_Library_Files/003_Libraries/DOCK_DN_Generic_Library/DOCK6.13_Library"

FRAGLIB_SCAFFOLD="${FRAGLIB_ROOT}/fraglib_scaffold.mol2"
FRAGLIB_LINKER="${FRAGLIB_ROOT}/fraglib_linker.mol2"
FRAGLIB_SIDECHAIN="${FRAGLIB_ROOT}/fraglib_sidechain.mol2"
FRAGLIB_TORENV="${FRAGLIB_ROOT}/fraglib_torenv.dat"

# We define the system and task lists shared by the setup and execution scripts.

SYSTEM_LIST="${WORK_ROOT}/LISTOFSYSTEMS.txt"
TASK_LIST="${WORK_ROOT}/DRef_tasks.tsv"

# We define the computational resources used by the SLURM array workflow.

SLURM_PARTITION="rn-long-40core"
SLURM_TIME="8-00:00:00"
TASKS_PER_NODE=40
MAX_NODES=3

# We print the active experiment configuration when this file is executed directly.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo
    echo "Dynamic Reference De Novo configuration"
    echo
    echo "Workflow directory: ${WORK_ROOT}"
    echo "Systems root:       ${SYSTEM_ROOT}"
    echo "Anchors root:       ${ANCHOR_ROOT}"
    echo "DOCK binary:        ${DOCK_BIN}"
    echo "DOCK parameters:    ${DOCK_PARAMS}"
    echo "Fragment library:   ${FRAGLIB_ROOT}"
    echo "Partition:          ${SLURM_PARTITION}"
    echo "Walltime:           ${SLURM_TIME}"
    echo "Tasks per node:     ${TASKS_PER_NODE}"
    echo "Maximum nodes:      ${MAX_NODES}"
    echo
fi

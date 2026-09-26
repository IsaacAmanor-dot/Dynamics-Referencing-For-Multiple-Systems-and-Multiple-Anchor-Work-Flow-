# Dynamic Referencing De Novo Workflow in DOCK6

This workflow performs multi-system De Novo molecular generation using the Dynamic Referencing implementation in DOCK6.

For each receptor system, De Novo calculations are performed independently using user-specified anchor fragments. The workflow generates the DOCK input files, constructs a task list, distributes independent calculations across SLURM compute nodes, and provides scripts for merging, rescoring, and analyzing the generated molecules.

The current experiment uses anchors 1 through 140 for each receptor system.

## Workflow

The scripts should be run in the following order.

### 1. Check the configuration

All paths and SLURM settings are defined in:

    000.config.sh

Inspect the configuration with:

    bash 000.config.sh

### 2. Generate De Novo input files

    bash 001.write_files_hms_grid.sh

This discovers the receptor systems and anchors and generates a `dn_generic.in` file for each system-anchor combination.

### 3. Generate the task list

    bash 002.make_task_list.sh

This creates `DRef_tasks.tsv`, containing one independent De Novo calculation per task.

### 4. Submit the De Novo calculations

    bash 002.submit_dn_jobs.sh

The workflow distributes the calculations across `rn-long-40core` nodes, with up to 40 independent serial DOCK calculations per node and a maximum of 3 nodes running concurrently.

### 5. Merge and rescore generated molecules

After the De Novo calculations are complete:

    bash 003.submit_merge_and_rescore.sh

This merges molecules generated from the anchors for each receptor system and performs full-reference rescoring.

### 6. Analyze growth trees

    bash 004.growthtree.sh

This evaluates molecules generated at the different growth layers and identifies the growth tree associated with the best-scoring molecule.

### 7. Extract score strings

    bash 005.xtrct_score_strng.sh

This extracts score progression information from the generated molecules for downstream analysis.

## Main scripts

- `000.config.sh` — central workflow configuration.
- `001.write_files_hms_grid.sh` — generates system/anchor De Novo inputs.
- `002.make_task_list.sh` — constructs the calculation task list.
- `002.run_dn_chunks.slurm` — executes node-sized groups of De Novo calculations.
- `002.submit_dn_jobs.sh` — submits the production SLURM array.
- `run_dn.sh` — executes one system-anchor DOCK calculation.
- `003.merge_and_rescore.sh` — merges generated molecules and performs full-reference rescoring.
- `003.submit_merge_and_rescore.sh` — submits the rescoring calculation.
- `004.growthtree.sh` — performs growth-layer analysis.
- `005.xtrct_score_strng.sh` — extracts score strings.
- `006.plot_score_strng.py` — plots score progression data.

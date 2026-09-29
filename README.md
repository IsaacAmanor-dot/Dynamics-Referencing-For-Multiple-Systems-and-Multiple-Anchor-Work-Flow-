# Dynamic Reference De Novo Multi-System Workflow

This workflow automates DOCK De Novo calculations using **Dynamic Referencing (DRef)** across multiple receptor systems and multiple starting anchors.

For each receptor system, independent De Novo calculations are generated from 140 anchors, distributed through SLURM, and analyzed after completion.

## Workflow

Run the scripts from the workflow directory in the following order.

### 1. Check the configuration

```bash
bash 000.config.sh
```

Defines the receptor systems, anchors, DOCK installation, fragment libraries, parameter files, and SLURM settings.

### 2. Generate De Novo input files

```bash
bash 001.write_files_hms_grid.sh
```

Validates the required files and generates one DRef De Novo calculation for every receptor-system and anchor combination.

### 3. Create the task list

```bash
bash 002.make_task_list.sh
```

Creates `DRef_tasks.tsv`, which contains all system-anchor calculations.

### 4. Submit De Novo calculations

```bash
bash 002.submit_dn_jobs.sh
```

Calculations are distributed through the SLURM workflow:

```text
002.submit_dn_jobs.sh
        |
        v
002.run_dn_chunks.slurm
        |
        v
run_dn.sh
        |
        v
DOCK De Novo
```

### 5. Check progress

```bash
bash 007.check_progress.sh
```

Reports completed, failed, and pending calculations for each receptor system and the complete experiment.

### 6. Merge and rescore

```bash
bash 003.submit_merge_and_rescore.sh
```

Merges available De Novo molecules for each system and performs rigid Descriptor Score rescoring against the full reference ligand.

### 7. Analyze growth trees

```bash
bash 004.growthtree.sh
```

Identifies the growth tree associated with the best rescored molecule at each De Novo growth layer.

### 8. Extract score trajectories

```bash
bash 005.xtrct_score_strng.sh
```

Extracts the score trajectories of selected molecules during De Novo growth.

### 9. Plot score trajectories

```bash
python 006.plot_score_strng.py
```

Plots score trajectories for comparison between static and Dynamic Referencing calculations.

## Main Execution Order

```text
000.config.sh
      |
001.write_files_hms_grid.sh
      |
002.make_task_list.sh
      |
002.submit_dn_jobs.sh
      |
007.check_progress.sh
      |
003.submit_merge_and_rescore.sh
      |
004.growthtree.sh
      |
005.xtrct_score_strng.sh
      |
006.plot_score_strng.py
```

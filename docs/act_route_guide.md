# ACT Route Guide: From Data to Trained Policy

This guide walks you through the **ACT (Action Chunking with Transformers)** path: collect demos with LeRobot, train an ACT policy, then run it in the evaluation environment.

---

## Overview

1. **Record demos** – Teleoperate the robot (with the sim running) and record (images + robot state + actions) using `lerobot-record`.
2. **Train** – Run `lerobot-train` with `--policy.type=act` on your dataset.
3. **Run your policy** – Load the trained weights in a policy class (like `RunACT`) and run with `aic_model`.

---

## Prerequisites

- **Environment:** Same as [Getting Started](./getting_started.md): Ubuntu 24.04, Docker, Distrobox, Pixi, optional NVIDIA Container Toolkit.
- **Eval container:** You need the simulation and robot controller running so the LeRobot driver can talk to `/aic_controller` (either in the eval container or a from-source build).
- **Zenoh:** When running LeRobot commands from the host against the eval container, set `ZENOH_SESSION_CONFIG_URI` so ROS 2 (via Zenoh) connects to the container’s router.

---

## Step 1: Start the evaluation environment

Start the sim and robot so the controller is available for teleop and recording.

**Option A – Eval container (recommended):**

```bash
export DBX_CONTAINER_MANAGER=docker
distrobox enter -r aic_eval -- /entrypoint.sh ground_truth:=false start_aic_engine:=true
```

This starts the Zenoh router, Gazebo, robot, and AIC engine. The engine will wait for `aic_model`; for **recording** you will not run `aic_model` yet—you only need the sim and controller. If the engine times out, you can ignore it for now, or start the container **without** the engine (e.g. by running the launch manually with `start_aic_engine:=false` if you only need the robot and a static scene).

**Option A (alternate) – Eval container with task board and cable for recording (no engine):**

To get the **task board and cable** (and **slots** to insert into) for teleop/recording, run the entrypoint **without** the engine and **with** scene spawning:

```bash
export DBX_CONTAINER_MANAGER=docker
distrobox enter -r aic_eval -- /entrypoint.sh \
  ground_truth:=false \
  start_aic_engine:=false \
  spawn_task_board:=true \
  spawn_cable:=true \
  attach_cable_to_gripper:=true
```

By default this spawns one **NIC card** (with SFP ports) and one **SC port** on the board so you have slots to insert the cable into. Then start **lerobot-teleoperate** or **lerobot-record** on the host.

If you still only see the board and cable with **no slots** (e.g. you use the pre-built `aic_eval` image from before this change), either **rebuild the eval image** from this repo (see `docker/aic_eval/Dockerfile`; then recreate the distrobox from the new image) so the updated launch defaults are used, or from inside the container run `spawn_task_board.launch.py` separately with `nic_card_mount_0_present:=true` and `sc_port_0_present:=true` (see [aic_bringup README](../aic_bringup/README.md)).

**Option B – From source:**  
See [Building the Evaluation Component from Source](./build_eval.md). Then run the bringup launch (with or without `start_aic_engine`) so that `/aic_controller` and the robot are available.

Ensure Gazebo and the robot are visible and the controller is up before continuing.

---

## Step 2: (Optional) Practice teleoperation

Get used to controlling the robot with LeRobot before recording.

From the **host** (repo root, e.g. `~/Projects/intrinsic/aic`):

```bash
cd ~/Projects/intrinsic/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"

pixi run lerobot-teleoperate \
  --robot.type=aic_controller --robot.id=aic \
  --teleop.type=aic_keyboard_ee --teleop.id=aic \
  --robot.teleop_target_mode=cartesian --robot.teleop_frame_id=base_link \
  --display_data=true
```

- **Cartesian keyboard:** `w/s` (Y), `a/d` (X), `r/f` (Z), `q/e` (yaw), etc. See [lerobot_robot_aic README](../aic_utils/lerobot_robot_aic/README.md#keyboard).
- **SpaceMouse:** Use `--teleop.type=aic_spacemouse` (and same `--robot.teleop_target_mode=cartesian`). See the same README for udev rules.
- **Joint-space:** Use `--teleop.type=aic_keyboard_joint` and `--robot.teleop_target_mode=joint`.

Press **ESC** to exit. The watchdog Zenoh warning in the log is safe to ignore.

---

## Step 3: Record training data

Create a LeRobot dataset by teleoperating and recording episodes.

1. **Hugging Face (HF) repo:** LeRobot uses HF for datasets. Create a repo (e.g. `YOUR_HF_USER/aic_cable_insertion`) on [huggingface.co](https://huggingface.co). For local-only data you can set `--dataset.push_to_hub=false` and use a local path or a repo_id that you later push.

2. **Run recording** (host, same `cd` and `ZENOH_SESSION_CONFIG_URI` as above):

```bash
cd ~/Projects/intrinsic/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"

pixi run lerobot-record \
  --robot.type=aic_controller --robot.id=aic \
  --teleop.type=aic_keyboard_ee --teleop.id=aic \
  --robot.teleop_target_mode=cartesian --robot.teleop_frame_id=base_link \
  --dataset.repo_id=YOUR_HF_USER/aic_cable_insertion \
  --dataset.single_task="insert cable into port" \
  --dataset.push_to_hub=false \
  --dataset.private=true \
  --play_sounds=false \
  --display_data=true
```

Replace `YOUR_HF_USER/aic_cable_insertion` with your HF username and repo name.

**Recording controls:**

- **Right Arrow** – Start next episode (after finishing one insertion).
- **Left Arrow** – Cancel current episode and re-record.
- **ESC** – Stop recording and exit.

Record **many successful insertions** (e.g. 50–200+ episodes) with some variation in approach. Include both SFP and SC insertions if you want one policy for all qualification trials.

**Sim time and black images:** Run the host process with sim time so it stays in sync with the container and camera timestamps:

```bash
export ROS_DOMAIN_ID=0
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
# Use sim time so /clock from the container is used (helps cameras and recording)
export ROS2_USE_SIM_TIME=1
# or: ros2 run ... --ros-args -p use_sim_time:=true
pixi run lerobot-record ...
```

If the teleop or recording window shows **black images**, see [Troubleshooting: Black images and recording](./troubleshooting.md#black-images-in-teleop-or-lerobot-record).

**Scene (task board + cable):** The task board and cable in the gripper are spawned by the AIC engine when it runs trials. If you need that exact scene for recording, use the **“Option A (alternate)”** command in Step 1 (entrypoint with `start_aic_engine:=false` and `spawn_task_board:=true spawn_cable:=true attach_cable_to_gripper:=true`) so the scene is present without running the engine.

---

## Step 4: Train the ACT policy

Train an ACT policy on your dataset.

```bash
cd ~/Projects/intrinsic/aic

pixi run lerobot-train \
  --dataset.repo_id=YOUR_HF_USER/aic_cable_insertion \
  --policy.type=act \
  --output_dir=outputs/train/act_aic_cable \
  --job_name=act_aic_cable \
  --policy.device=cuda \
  --wandb.enable=true \
  --policy.repo_id=YOUR_HF_USER/act_aic_policy
```

- **`--dataset.repo_id`** – Same as used in `lerobot-record` (or the HF repo where you pushed the data).
- **`--policy.type=act`** – Use the ACT policy.
- **`--policy.device=cuda`** – Use GPU; use `cpu` if you have no GPU (slower).
- **`--wandb.enable=true`** – Log to Weights & Biases; set `false` to disable.
- **`--policy.repo_id`** – HF repo where the trained policy will be saved (optional if you only want local `output_dir`).

Training can take from under an hour to several hours depending on dataset size and hardware. Default ACT hyperparameters are a good starting point; see [LeRobot ACT docs](https://huggingface.co/docs/lerobot/en/act) for details.

**RTX 50xx GPUs:** If you see a PyTorch/CUDA capability warning, see [Troubleshooting](./troubleshooting.md#nvidia-rtx-50xx-cards-not-supported-by-pytorch-version-locked-in-pixi) for a `pixi.toml` override.

---

## Step 5: Run the trained policy

You have two options: use the **provided RunACT** with a different checkpoint, or **copy and adapt RunACT** into your own package (e.g. `my_aic_policy`).

### Option A: Use the pre-trained ACT policy (no training)

To try the **provided** ACT policy (downloaded from Hugging Face):

**Terminal 1 – Eval:**
```bash
export DBX_CONTAINER_MANAGER=docker
distrobox enter -r aic_eval -- /entrypoint.sh ground_truth:=false start_aic_engine:=true
```

**Terminal 2 – Policy (within ~30 s):**
```bash
cd ~/Projects/intrinsic/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=aic_example_policies.ros.RunACT
```

RunACT loads `grkw/aic_act_policy` from Hugging Face by default.

### Option B: Run your own trained ACT checkpoint

1. **Export from training:** After `lerobot-train`, the policy and normalizer stats are under `outputs/train/act_aic_cable` (or your `--output_dir`). You need at least:
   - `config.json`
   - `model.safetensors`
   - `policy_preprocessor_step_3_normalizer_processor.safetensors`

2. **Point RunACT at your checkpoint:** In [`aic_example_policies/aic_example_policies/ros/RunACT.py`](../aic_example_policies/aic_example_policies/ros/RunACT.py), change `repo_id` (around line 61) from `"grkw/aic_act_policy"` to your HF repo, or replace the loading logic to use a **local path** instead of `snapshot_download(repo_id=...)`, e.g.:

   ```python
   policy_path = Path("/home/you/Projects/intrinsic/aic/outputs/train/act_aic_cable/checkpoints/latest")
   ```

   Ensure the config and normalizer paths match (e.g. `policy_path / "config.json"`, `policy_path / "model.safetensors"`, and the normalizer safetensors file in the same folder or the path LeRobot uses).

3. **Run:** Same as Option A, using `policy:=aic_example_policies.ros.RunACT` (or your own policy class if you copied RunACT into `my_aic_policy` and registered it).

### Option C: Add a custom ACT policy class to `my_aic_policy`

1. Copy the RunACT logic from `aic_example_policies/aic_example_policies/ros/RunACT.py` into `my_aic_policy/my_aic_policy/ros/MyACT.py`.
2. In `MyACT.py`, set `policy_path` (or `repo_id`) to your trained checkpoint or HF repo.
3. In `my_aic_policy`, add the same dependencies as `aic_example_policies` (e.g. `lerobot`, `torch`, `safetensors`, `huggingface_hub`) in `package.xml` and `pixi.toml` so the package builds.
4. Run:
   ```bash
   pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=my_aic_policy.ros.MyACT
   ```

---

## Summary

| Step | What you do |
|------|-------------|
| 1 | Start eval container (sim + robot + controller). |
| 2 | (Optional) Practice with `lerobot-teleoperate`. |
| 3 | Record demos with `lerobot-record` (same Zenoh config on host). |
| 4 | Train with `lerobot-train --policy.type=act`. |
| 5 | Run ACT via RunACT (or your class) with your checkpoint; ensure Zenoh config when using the eval container. |

---

## References

- [lerobot_robot_aic README](../aic_utils/lerobot_robot_aic/README.md) – Teleop types, recording, training command.
- [LeRobot ACT](https://huggingface.co/docs/lerobot/en/act) – ACT architecture and training.
- [Example policies](../aic_example_policies/README.md) – RunACT and other baselines.
- [Troubleshooting](./troubleshooting.md) – Zenoh, RTX 50xx, entrypoint, lifecycle errors.

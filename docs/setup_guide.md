# AIC Setup Guide

One-time and per-session steps to get the environment ready. All commands assume repo root: `~/Projects/intrinsic/aic`.

---

## Prerequisites (install once)

| Tool | Install |
|------|--------|
| Docker | [Docker Engine](https://docs.docker.com/engine/install/) + [Linux post-install](https://docs.docker.com/engine/install/linux-postinstall/) |
| Distrobox | `sudo apt install distrobox` |
| Pixi | `curl -fsSL https://pixi.sh/install.sh \| sh` (restart terminal) |
| NVIDIA (optional) | [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html), then `sudo nvidia-ctk runtime configure --runtime=docker` |

Then:

```bash
cd ~/Projects/intrinsic/aic
pixi install
```

---

## One-time: Eval image and distrobox

**1. Build the eval image (has task board + slots for recording):**

```bash
cd ~/Projects/intrinsic/aic
docker build -f docker/aic_eval/Dockerfile -t aic_eval:local .
```

**2. Create the distrobox from that image:**

```bash
export DBX_CONTAINER_MANAGER=docker
distrobox rm aic_eval --force 2>/dev/null || true
distrobox create -r --nvidia -i aic_eval:local aic_eval
```

*(If you have no NVIDIA GPU, drop `--nvidia`. To use the original image instead, use `-i ghcr.io/intrinsic-dev/aic/aic_eval:latest`.)*

---

## Every new terminal (host) – env for policy / teleop / record

```bash
cd ~/Projects/intrinsic/aic
export DBX_CONTAINER_MANAGER=docker
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
export ROS2_USE_SIM_TIME=1
```

*(Optional: add these to `~/.bashrc` or a small `source ~/Projects/intrinsic/aic/setup_env.sh`.)*

---

## Ready to run policy (3 trials)

**Terminal 1 – start eval:**

```bash
distrobox enter -r aic_eval -- /entrypoint.sh ground_truth:=false start_aic_engine:=true
```

**Terminal 2 – within ~30 s, run policy:**

```bash
# (env vars set as above)
pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=my_aic_policy.ros.InsertCableStarter
```

---

## Ready to record (teleop + dataset)

**Terminal 1 – start eval with scene, no engine:**

```bash
distrobox enter -r aic_eval -- /entrypoint.sh \
  ground_truth:=false start_aic_engine:=false \
  spawn_task_board:=true spawn_cable:=true attach_cable_to_gripper:=true
```

**Terminal 2 – after Gazebo is up, set env then teleop or record:**

```bash
# (env vars set as above)
pixi run lerobot-teleoperate \
  --robot.type=aic_controller --robot.id=aic \
  --teleop.type=aic_keyboard_ee --teleop.id=aic \
  --robot.teleop_target_mode=cartesian --robot.teleop_frame_id=base_link \
  --display_data=true
```

Or use `lerobot-record` with your dataset name (see [commands_reference.md](./commands_reference.md)).

---

## Quick check

- **Eval container exists:** `distrobox list` → `aic_eval`
- **Image present:** `docker images | grep aic_eval`
- **Pixi env:** `cd ~/Projects/intrinsic/aic && pixi run ros2 --help` (no “command not found”)

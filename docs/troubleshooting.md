# Troubleshooting

## Local clone path and Pixi (`PIXI_PROJECT_MANIFEST`)

The docs assume a **single** clone of this repo at **`~/Projects/aic`** (see [Setup guide](./setup_guide.md) and [Commands reference](./commands_reference.md)). If you previously used another layout (e.g. **`~/Projects/intrinsic/aic`**), use **one** directory and update shells, IDE folders, and scripts to match.

**Symptom:** Pixi prints a warning like:

`Using local manifest …/Projects/intrinsic/aic/pixi.toml rather than …/Projects/aic/pixi.toml from environment variable PIXI_PROJECT_MANIFEST`

**Cause:** `PIXI_PROJECT_MANIFEST` points at a **`pixi.toml`** that is not the manifest in your current working directory, or you have **two clones** and mixed `cd` / tooling between them.

**Fix:**

1. **Pick one clone** (recommended: **`~/Projects/aic`**) and remove or archive the other if you no longer need it.
2. **Clear or align the variable** in `~/.bashrc`, `~/.profile`, Cursor/terminal env, or CI:
   ```bash
   unset PIXI_PROJECT_MANIFEST
   cd ~/Projects/aic
   pixi install
   ```
   If you must pin the manifest explicitly, set it to the file you actually use:
   ```bash
   export PIXI_PROJECT_MANIFEST="$HOME/Projects/aic/pixi.toml"
   ```
3. **Open a new terminal** (or reload the editor) so old values are gone, then run **`pixi install`** again from the chosen repo root.

**Related:** If you see **`pixi-build-ros`** / **`ros-kilted-my-aic-policy`** errors with “The background task closed EOF; restart required”, try **`unset PIXI_PROJECT_MANIFEST`**, **`pixi clean cache`**, and **`pixi install`** once paths are consistent; upgrade Pixi with **`pixi self-update`** if it persists.

---

## Low real-time factor on Gazebo

The simulation is configured to run at **1.0 RTF (100% real-time factor)**, meaning simulation time should match wall-clock time. If you're experiencing lower RTF, the following sections may help diagnose and resolve the issue.

### Gazebo not using the dedicated GPU

If your machine has two GPUs (or a CPU with an integrated GPU), OpenGL may be using the *integrated* GPU for rendering, which causes RTF to be very low. To fix this, you may need to manually force it to use the *discrete* GPU.

To check if Open GL is using the discrete GPU, run `glxinfo -B`. The output should show the details of your discrete GPU. Additionally, you can verify GPU-specific process by running `nvidia-smi`. When the AIC sim is active, `gz sim` should appear in the process list.

If the wrong GPU is selected, run `sudo prime-select nvidia`.
**Note**: You must log out and log in again for the changes to take effect. Then, re-run `glxinfo -B` to verify that the discrete GPU is active.

You can also check out [Problems with dual Intel and Nvidia GPU systems](https://gazebosim.org/docs/latest/troubleshooting/#problems-with-dual-intel-and-nvidia-gpu-systems).

### No GPU Available

If your system doesn't have a dedicated GPU, you may experience poor real-time factor (RTF) performance. This is because Gazebo uses [GlobalIllumination (GI)](https://gazebosim.org/api/sim/9/global_illumination.html) based rendering for the AIC scene, which requires GPU acceleration for optimal performance.

**To improve simulation performance on systems without a GPU:**

You can disable GlobalIllumination by editing [`aic.sdf`](../aic_description/world/aic.sdf) and setting `<enabled>` to `false` in the global illumination configuration [here](https://github.com/intrinsic-dev/aic/blob/c8aa4571d9dc4bd55bbefc02b0a160ba0e8e1e90/aic_description/world/aic.sdf#L39) and [here](https://github.com/intrinsic-dev/aic/blob/c8aa4571d9dc4bd55bbefc02b0a160ba0e8e1e90/aic_description/world/aic.sdf#L109). This will reduce rendering quality but may significantly improve RTF on CPU-only systems.

> [!WARNING]
> Disabling GI will change the visual appearance of the scene, which may affect vision-based policies.

## Zenoh Shared Memory Watchdog Warnings

When running the system, you may see warnings like:

```
WARN Watchdog Validator ThreadId(17) zenoh_shm::watchdog::periodic_task:
error setting scheduling priority for thread: OS(1), will run with priority 48.
This is not an hard error and it can be safely ignored under normal operating conditions.
```

**This warning is harmless and can be safely ignored.** It indicates that Zenoh's shared memory watchdog thread couldn't set a higher scheduling priority (which requires elevated privileges). The system will continue to work correctly.

**Why it happens:**
- The watchdog thread monitors shared memory health
- Setting higher priority requires `CAP_SYS_NICE` capability or root privileges
- Without it, the thread runs at default priority (48)

**When it might matter:**
- Under extremely high CPU load, the watchdog may occasionally miss its deadlines
- This could cause rare timeouts in shared memory operations
- In practice, this is almost never an issue for typical workloads

**To verify shared memory is working:**
```bash
# Check for Zenoh shared memory files
ls -lh /dev/shm | grep zenoh

# Monitor network traffic (should be minimal)
sudo tcpdump -i lo port 7447 -v
```

If you see Zenoh files in `/dev/shm` and minimal traffic on port 7447, shared memory is functioning correctly despite the warning.

## NVIDIA RTX 50xx cards not supported by PyTorch version locked in Pixi

```
UserWarning:
NVIDIA GeForce RTX 5090 with CUDA capability sm_120 is not compatible with the current PyTorch installation.

The current PyTorch install supports CUDA capabilities sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90.
If you want to use the NVIDIA GeForce RTX 5090 GPU with PyTorch, please check the instructions at https://pytorch.org/get-started/locally/
```

The `lerobot` version in `pixi.toml` depends on an older version of `pytorch` (built for an older version of cuda). 
`pixi install` will pull in that older version which does not support the newer sm_120 architecture for NVIDIA RTX 50xx cards.

We were able to run this policy on an Nvidia RTX 5090 by adding the following to `pixi.toml`:
```
[pypi-options.dependency-overrides]
torch = ">=2.7.1"
torchvision = ">=0.22.1"
```

See this [LeRobot issue](https://github.com/huggingface/lerobot/issues/2217) for details.

## Error: no such container aic_eval

when running `distrobox enter -r aic_eval`, you might encounter the following error:
```bash
Error: no such container aic_eval
```

By default, distrobox uses podman but we are using docker in our setup. Make sure to have set the default container manager by exporting the `DBX_CONTAINER_MANAGER` environment variable:
```bash
export DBX_CONTAINER_MANAGER=docker
```

## /entrypoint.sh: No such file or directory (inside aic_eval container)

If you ran `distrobox enter -r aic_eval` and then `/entrypoint.sh` reports "No such file or directory", the script may not be visible in the container’s interactive shell. Use either of these:

**Option A – Run the entrypoint when entering (recommended)**  
Don’t start an interactive shell; run the entrypoint as the container command:
```bash
distrobox enter -r aic_eval -- /entrypoint.sh ground_truth:=false start_aic_engine:=true
```
This starts the Zenoh router and the AIC engine in one go. When the run finishes, you exit the container.

**Option B – Start the eval manually from inside the container**  
If you’re already inside the container (`distrobox enter -r aic_eval`), run:
```bash
. /ws_aic/install/setup.bash
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ZENOH_ROUTER_CONFIG_URI=/aic_zenoh_config.json5
ZENOH_CONFIG_OVERRIDE='mode="router"'; ZENOH_CONFIG_OVERRIDE+=';listen/endpoints=["tcp/[::]:7447"]'; ZENOH_CONFIG_OVERRIDE+=';connect/endpoints=[]'; ZENOH_CONFIG_OVERRIDE+=';routing/router/peers_failover_brokering=true'; ZENOH_CONFIG_OVERRIDE+=';transport/shared_memory/enabled=false'
export ZENOH_CONFIG_OVERRIDE
ros2 run rmw_zenoh_cpp rmw_zenohd &
sleep 3
export ZENOH_CONFIG_OVERRIDE=';transport/shared_memory/enabled=false'
ros2 launch aic_bringup aic_gz_bringup.launch.py ground_truth:=false start_aic_engine:=true
```
Then start your policy from the host (Step 3) as usual.

## aic_model lifecycle errors: "No transition matching 2/3/4" from unconfigured

If when running the example policy (Step 3) you see:

```text
No transition matching 3 found for current state unconfigured
Unable to start transition 3 from current state (1, 'unconfigured')
```

the **aic_model** node on the host is often not on the same Zenoh network as the **aic_engine** in the eval container. The engine drives the model’s lifecycle (configure → activate); if the model isn’t connected to the container’s Zenoh router, discovery and lifecycle can be wrong.

**Fix:** Run the model with the same Zenoh config so it connects to the router in the container (`tcp/localhost:7447`):

```bash
cd /path/to/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=aic_example_policies.ros.WaveArm
```

Ensure the eval container is running and `/entrypoint.sh` has been started so the Zenoh router is up before you start the model.

## pixi install fails: "build backend (pixi-build-ros)" / "closed EOF"

If `pixi install` fails with:

```
failed to communicate with the build backend (pixi-build-ros)
The background task closed EOF; restart required
```

the **pixi-build-ros** backend requires **GLIBC 2.32 or newer**. On older systems (e.g. Ubuntu 20.04, which ships GLIBC 2.31) the backend process exits when loading its native library, which produces this error.

**Fix:** Use a system that meets the [minimum requirements](./getting_started.md#requirements): **Ubuntu 24.04** (or another distro with glibc ≥ 2.32). Alternatively, run the full toolkit (including `pixi install`) inside a container or VM with Ubuntu 24.04.

## Upgrading from Ubuntu 20.04 to 24.04

The AIC toolkit recommends Ubuntu 24.04. If you are on 20.04, you must upgrade in two steps: **20.04 → 22.04**, then **22.04 → 24.04**.

**Before you start:** Back up important data, close other apps, and allow 30–60 minutes per step (with a reboot after each).

**Step 1: 20.04 → 22.04**

```bash
sudo apt update && sudo apt install -y update-manager-core
sudo sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades
sudo do-release-upgrade
```

When finished, run `sudo reboot`.

**Step 2: 22.04 → 24.04** (after logging back in)

```bash
sudo apt update && sudo apt full-upgrade -y
sudo do-release-upgrade
```

Reboot when done, then verify with `lsb_release -a` (should show 24.04) and `ldd --version` (GLIBC 2.39+). Continue with [Getting Started](./getting_started.md).

**Alternative:** Use an Ubuntu 24.04 container or VM and run the toolkit inside it instead of upgrading the host.

## Black images in teleop or lerobot-record

If **lerobot-teleoperate** or **lerobot-record** shows black (or empty) camera windows while the timer runs:

1. **Use sim time on the host**  
   The eval container runs with `use_sim_time:=true` and publishes `/clock` from Gazebo. The host should use sim time too so timestamps and subscriptions stay in sync:
   ```bash
   export ROS2_USE_SIM_TIME=1
   # or when running a ROS 2 command:
   ros2 run ... --ros-args -p use_sim_time:=true
   ```
   Then start **lerobot-teleoperate** or **lerobot-record** in the same shell (or ensure your environment has `ROS2_USE_SIM_TIME=1`).

2. **Wait for the sim to be ready**  
   After starting the eval container, wait until Gazebo has fully loaded (robot and world visible) and the controller is up. Then start teleop/record on the host. Give it 10–20 seconds after Gazebo appears before pressing keys or starting episodes.

3. **Check that image topics are publishing**  
   On the host (with `ZENOH_SESSION_CONFIG_URI` set so you see container topics):
   ```bash
   ros2 topic list | grep camera
   ros2 topic echo /center_camera/image --once
   ```
   If you see no data or “no new messages,” the bridge or Gazebo may not be publishing. Ensure the container is running with the full bringup (robot + bridge).

4. **Scene for recording: task board and cable**  
   With the default entrypoint (`start_aic_engine:=true`), the **task board and cable are only spawned when the engine starts a trial** (after `aic_model` connects). For teleop/recording, start the container **without** the engine and **with** scene spawning:
   ```bash
   distrobox enter -r aic_eval -- /entrypoint.sh \
     ground_truth:=false start_aic_engine:=false \
     spawn_task_board:=true spawn_cable:=true attach_cable_to_gripper:=true
   ```
   The main bringup now spawns **one NIC card (SFP ports) and one SC port** on the task board by default, so you should see the **slots** to insert into in Gazebo and in the camera feeds. Then run **lerobot-teleoperate** or **lerobot-record** on the host.

5. **Saving recorded episodes**  
   In **lerobot-record**, time runs as soon as you start, but **each episode is only saved when you press Right Arrow** (next episode). Until you press Right Arrow, the current episode is not written. Press **Right Arrow** after each successful insertion (or when you want to end the current episode). Use **ESC** when you are done recording entirely.


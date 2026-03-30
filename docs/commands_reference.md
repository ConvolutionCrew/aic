# AIC Commands Reference

One-line descriptions. Run from repo root (`~/Projects/intrinsic/aic`) unless noted.

---

## Environment (once per shell when needed)

```bash
export DBX_CONTAINER_MANAGER=docker
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
export ROS2_USE_SIM_TIME=1
```
**What:** Use Docker for distrobox; point ROS 2 at container Zenoh; use sim time (for teleop/record).

---

## Eval container – run policy (with engine, 3 trials)

```bash
distrobox enter -r aic_eval -- /entrypoint.sh ground_truth:=false start_aic_engine:=true
```
**What:** Start Zenoh, Gazebo, robot, task board/cable per trial, scoring. Start your policy within ~30 s.


```bash
cd /home/rkrishnan/Projects/intrinsic/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=aic_example_policies.ros.WaveArm
```
---

## Eval container – recording (scene, no engine)

```bash
distrobox enter -r aic_eval -- /entrypoint.sh \
  ground_truth:=false start_aic_engine:=false \
  spawn_task_board:=true spawn_cable:=true attach_cable_to_gripper:=true
```
**What:** Start Zenoh, Gazebo, robot, task board + cable + slots; no trials. Use for teleop/lerobot-record.

---

## Rebuild eval image (from repo)

```bash
cd ~/Projects/intrinsic/aic
docker build -f docker/aic_eval/Dockerfile -t aic_eval:local .
```
**What:** Build updated eval image as `aic_eval:local` (e.g. for task board slots).

---

## Use new / old eval image

```bash
distrobox rm aic_eval --force
export DBX_CONTAINER_MANAGER=docker
distrobox create -r --nvidia -i aic_eval:local aic_eval
```
**What:** Recreate distrobox from **new** image (`aic_eval:local`).

```bash
distrobox rm aic_eval --force
export DBX_CONTAINER_MANAGER=docker
distrobox create -r --nvidia -i ghcr.io/intrinsic-dev/aic/aic_eval:latest aic_eval
```
**What:** Recreate distrobox from **original** image.

---

## Run policy (host; set env vars first)

```bash
pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=my_aic_policy.ros.InsertCableStarter
```
**What:** Run starter policy (gentle descent).

```bash
pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=aic_example_policies.ros.RunACT
```
**What:** Run pre-trained ACT policy.

---

## Teleop (host; set env vars first)

```bash
pixi run lerobot-teleoperate \
  --robot.type=aic_controller --robot.id=aic \
  --teleop.type=aic_keyboard_ee --teleop.id=aic \
  --robot.teleop_target_mode=cartesian --robot.teleop_frame_id=base_link \
  --display_data=true
```
**What:** Keyboard Cartesian teleop. Right/Left Arrow: next/cancel episode. ESC: exit.

```bash
cd /home/rkrishnan/Projects/intrinsic/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
export ROS2_USE_SIM_TIME=1
```
```bash
pixi run lerobot-teleoperate \
  --robot.type=aic_controller --robot.id=aic \
  --teleop.type=aic_spacemouse --teleop.id=aic \
  --robot.teleop_target_mode=cartesian --robot.teleop_frame_id=base_link \
  --display_data=true
```
---

## Teleop: monitor insertion & contact (host)

In **each** terminal where you run `ros2` against the sim:

```bash
cd ~/Projects/intrinsic/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
export ROS2_USE_SIM_TIME=1
```

Keep the **eval container** running.

**Option A — three terminals (simplest)**

**Terminal 1 — insertion (success event)**

```bash
pixi run ros2 topic echo /scoring/insertion_event
```

**Terminal 2 — force/torque**

```bash
pixi run ros2 topic echo /fts_broadcaster/wrench
```

**Terminal 3 — off-limit contacts**

```bash
pixi run ros2 topic echo /aic/gazebo/contacts/off_limit
```

Start **teleop** in another terminal (or your IDE). Watch **T1** for a `String` message when insertion succeeds; **T2** for wrench spikes during contact; **T3** for `Contacts` when off-limit geometry hits.

**What:** Live view of insertion events, tool wrench, and disallowed contacts while teleoping. If `echo` warns the topic is not published yet, wait until the sim is fully up; for `/scoring/insertion_event` you can also run `pixi run ros2 topic echo /scoring/insertion_event std_msgs/msg/String`.

---

## Record dataset (host; set env vars first)

```bash
pixi run lerobot-record \
  --robot.type=aic_controller --robot.id=aic \
  --teleop.type=aic_keyboard_ee --teleop.id=aic \
  --robot.teleop_target_mode=cartesian --robot.teleop_frame_id=base_link \
  --dataset.repo_id=YOUR_HF_USER/aic_cable_insertion \
  --dataset.single_task="insert cable into port" \
  --dataset.push_to_hub=false --dataset.private=true \
  --play_sounds=false --display_data=true
```
**What:** Record episodes. Right Arrow: save episode and start next. ESC: stop.

---

## Train ACT (host)

```bash
pixi run lerobot-train \
  --dataset.repo_id=YOUR_HF_USER/aic_cable_insertion \
  --policy.type=act \
  --output_dir=outputs/train/act_aic_cable \
  --job_name=act_aic_cable \
  --policy.device=cuda
```
**What:** Train ACT on the dataset.

---

## Checks (host; set ZENOH_SESSION_CONFIG_URI first)

```bash
pixi run ros2 topic list | grep camera
pixi run ros2 topic echo /center_camera/image --once
```
**What:** List camera topics; print one image message.

```bash
cd /home/rkrishnan/Projects/intrinsic/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
pixi run ros2 topic echo /aic_controller/controller_state --once
```
**What:** Point ROS 2 at the eval stack’s Zenoh router, then print **one** `ControllerState` message (TCP pose, velocity, errors, etc.). Use to snapshot where the tool is after a move; requires sim/container up.

```bash
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
pixi run ros2 run tf2_ros tf2_echo base_link gripper/tcp
```
**What:** Stream the **TF transform** from `base_link` (robot base) to `gripper/tcp` (tool center point): translation + rotation of the TCP in the base frame. Press Ctrl+C to stop. Same Zenoh/env as other host `ros2` checks.

---

## Reinstall policy after code change

```bash
pixi reinstall ros-kilted-my-aic-policy
```
**What:** Reinstall `my_aic_policy` so changes are used.

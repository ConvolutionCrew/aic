# my_aic_policy

Starter policy package for the **AI for Industry Challenge**. Use it as a template to implement your own cable-insertion policy.

## Policy: InsertCableStarter

- **Class:** `my_aic_policy.ros.InsertCableStarter`
- **Inputs:** Uses only data from `get_observation()` (no ground truth): `controller_state.tcp_pose`, optional `wrist_wrench`.
- **Behavior:** Respects `task.time_limit`, performs a gentle descent from the current TCP pose (step-wise Z decrease) and stops if force exceeds 20 N for more than 1 s to avoid the force penalty.
- **Intent:** Demonstrates the full policy API and a minimal insertion attempt. Replace or extend with vision-based port estimation or a learned policy to improve scoring.

## Run

From the repo root (e.g. `~/Projects/intrinsic/aic`):

**Terminal 1 – Eval container**
```bash
export DBX_CONTAINER_MANAGER=docker
distrobox enter -r aic_eval -- /entrypoint.sh ground_truth:=false start_aic_engine:=true
```

**Terminal 2 – Policy (start within ~30 s of the engine)**
```bash
cd ~/Projects/intrinsic/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=my_aic_policy.ros.InsertCableStarter
```

## Next steps

- **Docs:** [Build your policy](../docs/build_your_policy.md) – requirements, scoring, roadmap.
- **Improve:** Use `observation.center_image` (and camera_info) for port pose, or train an ACT policy with [lerobot_robot_aic](../aic_utils/lerobot_robot_aic/README.md).
- **ACT route:** Full walkthrough: [ACT Route Guide](./act_route_guide.md) (record → train → run).
- **Reinstall after edits:** `pixi reinstall ros-kilted-my-aic-policy`

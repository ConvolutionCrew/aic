# Building Your Competition Policy

This document summarizes **what the competition requires**, **how you are scored**, and a **concrete roadmap** to go from the example policy to a competitive submission.

## What You’re Building

- **Task:** Insert a cable plug (SFP or SC) into the correct port on a task board. The robot starts with the plug already in the gripper and **within a few centimeters** of the target port.
- **Your code:** A **policy** — a Python class that implements `insert_cable(task, get_observation, move_robot, send_feedback)` and runs inside the provided `aic_model` node.
- **Inputs:** You get a **Task** (which port, which plug, time limit) and **Observations** at up to 20 Hz: three wrist cameras, joint state, wrist force/torque, and controller state (TCP pose/velocity).
- **Output:** You call **move_robot()** with `MotionUpdate` (Cartesian pose/velocity) or `JointMotionUpdate` (joint targets) to control the arm. You must finish within the task’s **time_limit** and follow the [Challenge Rules](./challenge_rules.md).

## How You’re Scored

| What | Details |
|------|--------|
| **Tier 1 – Model validity** | Policy loads, responds to `InsertCable`, sends valid commands. **Required** to get any other points. |
| **Tier 2 – Performance** | Smoothness (low jerk), short task duration, efficient path; penalties for force > 20 N for > 1 s and for off-limit contacts. |
| **Tier 3 – Task success** | Up to 75 pts for correct full insertion; partial/proximity points if the plug is close but not fully inserted. |

Details: [Scoring](./scoring.md).  
Trials: [Qualification Phase](./qualification_phase.md) (e.g. SFP trials 1–2, SC trial 3; same policy for all).

## Policy API (Quick Reference)

- **`task`** – `Task` message: `cable_name`, `plug_name`, `port_name`, `target_module_name`, `time_limit`, etc.
- **`get_observation()`** – Returns latest `Observation`: `left_image`, `center_image`, `right_image`, `*_camera_info`, `joint_states`, `wrist_wrench`, `controller_state` (includes `tcp_pose`, `tcp_velocity`, `reference_tcp_pose`).
- **`move_robot(motion_update=..., joint_motion_update=...)`** – Send one of Cartesian `MotionUpdate` or `JointMotionUpdate`. Use the helper `self.set_pose_target(move_robot, pose)` for simple Cartesian targets.
- **`send_feedback("string")`** – Optional progress/debug messages.

Base class and types: `aic_model.policy.Policy`, `GetObservationCallback`, `MoveRobotCallback`, `SendFeedbackCallback`.

## Roadmap

1. **Run the examples**  
   - [Getting Started](./getting_started.md): eval container + `WaveArm` (minimal API), then `CheatCode` with `ground_truth:=true` to see a full insertion behavior.  
   - [Example policies](../aic_example_policies/README.md): try `RunACT` if you want to try a learned policy.

2. **Starter policy in this repo**  
   - Package: `my_aic_policy`, policy class: `my_aic_policy.ros.InsertCableStarter`.  
   - It uses **only** observation data (no ground truth): reads `controller_state.tcp_pose`, optionally `wrist_wrench`, and does a time-limited gentle descent. Use it as a template to add vision or learning.

3. **Improve with perception**  
   - Use `observation.center_image` (and camera_info) to estimate port pose or alignment (e.g. classical vision or a small network).  
   - Or collect data with [teleoperation](../aic_utils/aic_teleoperation/README.md) and train an ACT (or other) policy as in [lerobot_robot_aic](../aic_utils/lerobot_robot_aic/README.md). **Full walkthrough:** [ACT Route Guide](./act_route_guide.md).

4. **Respect scoring**  
   - Keep motion smooth (avoid high jerk).  
   - Finish quickly (≤5 s is best for duration points).  
   - Avoid force > 20 N for > 1 s and any off-limit contact.  
   - Aim for full insertion into the **correct** port (Tier 3).

5. **Test and submit**  
   - Run with the [sample config](../aic_engine/config/sample_config.yaml) and check [Scoring Test & Evaluation Guide](./scoring_tests.md).  
   - Package and submit per [Submission Guidelines](./submission.md).

## Run the Starter Policy

From the repo root (e.g. `~/Projects/aic`):

**Terminal 1 – Eval container:**
```bash
export DBX_CONTAINER_MANAGER=docker
distrobox enter -r aic_eval -- /entrypoint.sh ground_truth:=false start_aic_engine:=true
```

**Terminal 2 – Your policy (start within ~30 s of the engine starting):**
```bash
cd ~/Projects/aic
export ZENOH_SESSION_CONFIG_URI="$(pwd)/docker/aic_eval/aic_zenoh_config.json5"
pixi run ros2 run aic_model aic_model --ros-args -p use_sim_time:=true -p policy:=my_aic_policy.ros.InsertCableStarter
```

The starter policy does **not** use vision or ground truth; it demonstrates the API and a minimal insertion attempt (e.g. gentle descent). Replace or extend it with your own logic and perception.

## Key Docs

- [Policy integration](./policy.md) – Full API and tutorial for a new policy package.  
- [AIC interfaces](./aic_interfaces.md) – Topics, messages, actions.  
- [AIC controller](./aic_controller.md) – MotionUpdate, JointMotionUpdate, stiffness/damping.  
- [Task board](./task_board_description.md) – Ports, rails, randomization.  
- [Challenge rules](./challenge_rules.md) – Lifecycle and allowed interfaces.

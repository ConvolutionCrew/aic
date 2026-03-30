# Physical Teleop Hardware for AIC

Options to use **hardware** (instead of keyboard only) for teleoperation and recording. The sim robot is a 6-DOF UR5e; teleop must send Cartesian pose/velocity or joint targets to `/aic_controller/pose_commands` or `joint_commands`.

---

## Supported out of the box (no code changes)

### 1. 3Dconnexion SpaceMouse (6-DOF)

**What it is:** Hand-held 6-DOF controller (translate + rotate). Works with AIC via `--teleop.type=aic_spacemouse`.

**Rough cost:** ~\$100–\$330 USD depending on model (e.g. SpaceMouse Wireless, SpaceMouse Pro).

**Where to buy:**
- [3Dconnexion (US)](https://3dconnexion.com/us/product/spacemouse-wireless-bt/) – SpaceMouse Wireless (Bluetooth).
- [3Dconnexion store](https://3dconnexion.com/us/) – other models (Pro, etc.).
- Often sold on Amazon, B&H, etc. – search “3Dconnexion SpaceMouse”.

**Setup:** USB or Bluetooth. Linux udev rules and pyspacemouse are documented in [lerobot_robot_aic README](../aic_utils/lerobot_robot_aic/README.md#spacemouse) (vendor ID `046d` for 3Dconnexion). Then:

```bash
pixi run lerobot-teleoperate ... --teleop.type=aic_spacemouse --robot.teleop_target_mode=cartesian ...
```

**Pros:** Supported in AIC, 6-DOF, no bridge code. **Cons:** Not “arm-like”; takes practice for insertion tasks.

---

## Physical robot arms (custom bridge required)

AIC does **not** include a “robot arm as leader” teleop. To use a physical arm you need:

1. Hardware that exposes **joint positions** or **end-effector pose** on ROS 2 (e.g. `sensor_msgs/JointState` or `geometry_msgs/Pose` / TF).
2. A **bridge node** that subscribes to that state and publishes to `/aic_controller/pose_commands` or `joint_commands` so the **sim** robot follows the physical arm. LeRobot record then runs as today (it records the sim + those commands).

Compatibility is determined by: (a) ROS 2 driver for your arm, (b) your bridge mapping its state to the UR5e (same frame, similar DOF).

### Option A: Low-cost / DIY leader arms (ROS 2 + bridge)

| Name | Rough cost | Notes |
|------|------------|--------|
| **U-ARM** | ~\$50–57 | 3D-printed 6/7-DOF leader arm; open-source; you run a ROS 2 node and a bridge to AIC. [Paper/source](https://arxiv.org/html/2509.02437v2). |
| **Lododo / SO-101** | ~\$110/arm | ROS 2 Humble; LeRobot SO-101 / LeKiwi; [Lododo Arm (GitHub)](https://github.com/harryzy/lododo-arm). You’d add a bridge from its joint_states to AIC’s controller. |
| **SO101 ROS 2** | – | [SO101 ROS 2 docs](https://so101-ros2.readthedocs.io/) – teleop + dataset capture; bridge to AIC would be custom. |

### Option B: Commercial small arms (ROS 2 + bridge)

| Name | Rough cost | Notes |
|------|------------|--------|
| **Interbotix WidowX** | ~\$1,500 (kit) | 5–6 DOF; ROS 2 support; [Interbotix](https://www.interbotix.com/widowxrobotarm), [Trossen Robotics](https://www.trossenrobotics.com). Publish joint_states; you write a bridge to AIC. |
| **OpenArm** | ~\$6,500 (bimanual) | 7-DOF humanoid arm; ROS 2; bilateral teleop; [Reazon OpenArm](https://github.com/reazon-research/openarm). |

### Option C: Same as sim (UR)

Using another **Universal Robots** arm (e.g. UR3, UR5) as leader gives the closest match to the sim. Official UR ROS 2 drivers exist. You’d run the UR driver, then a bridge from its state to `/aic_controller/pose_commands` or `joint_commands`. Cost is high (industrial arm + controller).

---

## Summary

- **No extra hardware:** use keyboard (built-in).
- **Supported hardware, no bridge:** 3Dconnexion SpaceMouse – buy from 3Dconnexion, Amazon, or similar; set udev and use `--teleop.type=aic_spacemouse`.
- **Physical arm:** buy any arm with a **ROS 2** driver that publishes joint_states or pose; then implement a **bridge** from that topic to AIC’s controller (and optionally a new LeRobot teleop type). Low-cost options (U-ARM, SO-101/Lododo) need bridge code; Interbotix/WidowX and UR need the same bridge idea.

If you tell us which arm you prefer (e.g. SpaceMouse vs U-ARM vs WidowX), we can outline the exact topics and a minimal bridge (e.g. Python node subscribing to `/leader/joint_states` and publishing `MotionUpdate` or `JointMotionUpdate`).

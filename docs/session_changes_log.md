# Session changes log

Running list of fixes, setup steps, and code changes from troubleshooting and development sessions. Add new entries under the latest date when you make further changes.

---

## 2026-03-21 — SpaceMouse teleop + eval stack

### Code changes

| Location | Change |
| -------- | ------ |
| `aic_utils/lerobot_robot_aic/lerobot_robot_aic/aic_teleop.py` | **Bugfix:** In `AICSpaceMouseTeleop.connect()`, assign `pyspacemouse.open(...)` to `self._device` (was incorrectly stored as `self._device_open_success`). `get_action()` requires `self._device` for `read()`; without this, teleop raised `DeviceNotConnectedError` after the robot had already switched control mode. |
| Same | **Drift at rest:** Added configurable `deadband` on `AICSpaceMouseTeleopConfig` (default `0.05`, was effectively `0.02`). Small non-zero HID readings were passing the old deadband; velocity mode integrates that as continuous motion. Tune with e.g. `--teleop.deadband=0.08` if the arm still creeps when the puck is untouched. |

### Environment / system (host)

| Step | Notes |
| ---- | ----- |
| HID library | Install `libhidapi-hidraw0` and `libhidapi-libusb0` (e.g. `apt`) so `pyspacemouse` / `easyhid` can load `hid_enumerate`. Without this: `RuntimeError: HID API is probably not installed` / missing `hid_enumerate` symbol. |
| udev (3Dconnexion) | Add `/etc/udev/rules.d/99-spacemouse.rules` with rules for vendor `046d` on `hidraw` and `usb` (see `aic_utils/lerobot_robot_aic/README.md`). **Do not paste rule lines into the shell** — write them with `sudo tee ... <<'EOF'` or an editor, then `udevadm control --reload-rules` and `udevadm trigger`, replug device. Without this: `SpaceMousePro found` but `Failed to open device`. |
| Pixi package sync | After editing `lerobot_robot_aic` sources, run `pixi reinstall ros-kilted-lerobot-robot-aic` so the conda env’s `site-packages` copy matches the repo. |

### Workflow notes (no repo change)

- Eval container command `distrobox enter ... /entrypoint.sh` with `start_aic_engine:=false` and spawn flags only starts the sim; **teleop runs on the host** via `pixi run lerobot-teleoperate` with `--teleop.type=aic_spacemouse` (and `ZENOH_SESSION_CONFIG_URI`, `ROS2_USE_SIM_TIME=1` as in `commands_reference.md`).
- Default examples in `commands_reference.md` use `aic_keyboard_ee`; SpaceMouse requires `aic_spacemouse`.

---

*(Add new dated sections below as you go.)*

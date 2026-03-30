#
#  Copyright (C) 2026 Intrinsic Innovation LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

"""
Starter policy for the AI for Industry Challenge.

Uses only observation data (no ground truth): reads current TCP pose from
controller_state and performs a time-limited gentle descent toward the board.
Replace or extend with vision-based port estimation or a learned policy
to improve scoring.
"""

from aic_model.policy import (
    GetObservationCallback,
    MoveRobotCallback,
    Policy,
    SendFeedbackCallback,
)
from aic_model_interfaces.msg import Observation
from aic_task_interfaces.msg import Task
from geometry_msgs.msg import Point, Pose, Quaternion
from rclpy.duration import Duration


# Force threshold from scoring: penalty if exceeded for > 1 s
FORCE_THRESHOLD_N = 20.0


class InsertCableStarter(Policy):
    def __init__(self, parent_node):
        super().__init__(parent_node)
        self.get_logger().info("InsertCableStarter.__init__()")

    def insert_cable(
        self,
        task: Task,
        get_observation: GetObservationCallback,
        move_robot: MoveRobotCallback,
        send_feedback: SendFeedbackCallback,
    ) -> bool:
        self.get_logger().info(
            f"InsertCableStarter: plug={task.plug_name} port={task.port_name} "
            f"module={task.target_module_name} time_limit={task.time_limit}s"
        )
        send_feedback("starting insertion attempt")

        # Time limit in seconds (task.time_limit is uint64 seconds)
        time_limit_sec = float(task.time_limit)
        start_time = self.time_now()
        timeout = Duration(seconds=time_limit_sec)

        # Get initial pose from controller state (no ground truth)
        observation = get_observation()
        if observation is None:
            self.get_logger().error("No observation available")
            return False

        cs = observation.controller_state
        if cs is None or cs.tcp_pose is None:
            self.get_logger().error("No controller_state / tcp_pose in observation")
            return False

        current = cs.tcp_pose
        initial_z = current.position.z
        target_pose = Pose(
            position=Point(
                x=current.position.x,
                y=current.position.y,
                z=initial_z,
            ),
            orientation=Quaternion(
                x=current.orientation.x,
                y=current.orientation.y,
                z=current.orientation.z,
                w=current.orientation.w,
            ),
        )

        # Gentle descent: step Z down from initial height until time runs out
        # or we've moved enough. In a real policy you would use vision to
        # align to the port first.
        descent_step_m = 0.001
        max_descent_m = 0.08
        total_descent = 0.0
        control_period_s = 0.05
        high_force_steps = 0
        high_force_duration_steps = int(1.0 / control_period_s)  # 1 second

        while (self.time_now() - start_time) < timeout:
            observation = get_observation()
            if observation is None:
                self.sleep_for(control_period_s)
                continue

            cs = observation.controller_state
            if cs is not None and cs.tcp_pose is not None:
                current = cs.tcp_pose
                # Keep x,y and orientation from current (track any drift); z from descent
                target_pose.position.x = current.position.x
                target_pose.position.y = current.position.y
                target_pose.position.z = initial_z - total_descent
                target_pose.orientation = current.orientation
            if observation.wrist_wrench is not None:
                fx = observation.wrist_wrench.wrench.force.x
                fy = observation.wrist_wrench.wrench.force.y
                fz = observation.wrist_wrench.wrench.force.z
                force_mag = (fx * fx + fy * fy + fz * fz) ** 0.5
                if force_mag > FORCE_THRESHOLD_N:
                    high_force_steps += 1
                    if high_force_steps >= high_force_duration_steps:
                        self.get_logger().warn(
                            f"Force {force_mag:.1f} N > {FORCE_THRESHOLD_N} N; stopping descent to avoid penalty"
                        )
                        send_feedback("high force - stopping descent")
                        break
                else:
                    high_force_steps = 0

            if total_descent < max_descent_m:
                total_descent += descent_step_m

            self.set_pose_target(move_robot=move_robot, pose=target_pose)
            self.sleep_for(control_period_s)

        send_feedback("insertion attempt finished")
        self.get_logger().info(
            f"InsertCableStarter: done (descent ~{total_descent*1000:.1f} mm)"
        )
        return True

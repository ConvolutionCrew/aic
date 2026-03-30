#!/usr/bin/env bash
# Source this or run: source setup_env.sh
# From repo root: ~/Projects/intrinsic/aic
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
export DBX_CONTAINER_MANAGER=docker
export ZENOH_SESSION_CONFIG_URI="${SCRIPT_DIR}/docker/aic_eval/aic_zenoh_config.json5"
export ROS2_USE_SIM_TIME=1
echo "AIC env set: DBX_CONTAINER_MANAGER, ZENOH_SESSION_CONFIG_URI, ROS2_USE_SIM_TIME"

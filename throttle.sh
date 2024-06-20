#!/bin/bash

# Ensure that the script exits if any command fails
set -e

export PYTHONPATH=/home/anoop/ros2_ws/install/motion_capture_tracking_interfaces/local/lib/python3.10/dist-packages:/home/anoop/ros2_ws/build/crazyswarm_demos:/home/anoop/ros2_ws/install/crazyswarm_demos/lib/python3.10/site-packages:/home/anoop/ros2_ws/install/crazyflie_sim/local/lib/python3.10/dist-packages:/home/anoop/ros2_ws/install/crazyflie_examples/local/lib/python3.10/dist-packages:/home/anoop/ros2_ws/build/crazyflie_py:/home/anoop/ros2_ws/install/crazyflie_py/lib/python3.10/site-packages:/home/anoop/ros2_ws/install/crazyflie_interfaces/local/lib/python3.10/dist-packages:/opt/ros/humble/lib/python3.10/site-packages:/opt/ros/humble/local/lib/python3.10/dist-packages
export LD_LIBRARY_PATH=/home/anoop/ros2_ws/install/motion_capture_tracking_interfaces/lib:/home/anoop/ros2_ws/install/crazyflie_interfaces/lib:/opt/ros/humble/opt/rviz_ogre_vendor/lib:/opt/ros/humble/lib/x86_64-linux-gnu:/opt/ros/humble/lib
export PATH=/home/anoop/.local/bin:/opt/ros/humble/bin:/home/anoop/mambaforge/bin:/home/anoop/mambaforge/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

cd ros2_ws/src/Brown-crazyswarm2/crazyflie_examples/crazyflie_examples
python3 throttle.py $1

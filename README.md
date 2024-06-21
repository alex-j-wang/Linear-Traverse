### Drone Control
On the Linux computer transmitting signals to the drone, run the following
* `cd ~/ros2_ws/src/Brown-crazyswarm2/crazyflie/config`
* `open crazyflies.yaml`
* Drone number is listed at the tip of the Crazyflie power wire. Ensure that the drone is uncommented with `enabled` set to `true`. Ensure the remaining drones are commented out.

Now launch ROS
* `ros2 launch crazyflie launch.py`

Ensure the system is working
* `cd ~/ros2_ws/src/Brown-crazyswarm2/crazyflie_examples/crazyflie_examples`
* `python3 motor_set.py`

MATLAB system commands from properly configured computers should now transmit to the drone via SSH.

### Manual Execution
Use Driveware to control linear traverse movement.
* Ensure a calibration file is present in the directory (e.g. FT21128.cal)
* Run [parse_cal.m](parse_cal.m)
* Run [execution_manual.m](execution_manual.m)
* Follow the instructions.

### Automatic Execution
* Ensure a calibration file is present in the directory (e.g. FT21128.cal)
* Run [parse_cal.m](parse_cal.m)
* Run [execution.m](execution_manual.m)
* Follow the instructions.
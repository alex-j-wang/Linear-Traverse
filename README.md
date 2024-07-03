### Drone Control
Connect the drone to a power supply limited to 3.9 V.\
On the Linux computer transmitting signals to the drone, run the following:
* `cd ~/ros2_ws/src/Brown-crazyswarm2/crazyflie/config`
* `open crazyflies.yaml`
* Drone number is listed at the tip of the Crazyflie power wire. Ensure that the drone is uncommented with `enabled` set to `true`. Ensure the remaining drones are commented out.

Now launch ROS:
* `ros2 launch crazyflie launch.py`

Ensure the system is working:
* `cd ~/ros2_ws/src/Brown-crazyswarm2/crazyflie_examples/crazyflie_examples`
* `python3 motor_set.py`

MATLAB system commands from properly configured computers should now transmit to the drone via SSH.

### Automatic Execution
* Ensure a calibration file is present in the directory (e.g. FT21128.cal)
* Run [parse_cal.m](parse_cal.m)
* Turn the NI DAQ on and ensure it's plugged into the computer.
* Plug in the power supply running the AMC and ensure the AMC is plugged into the computer.
* Launch Driveware and open the provided .adf file. Press the Connect button. If prompted, press Download.
* Move the traverse to the approximate center. Press Enable on Driveware. The traverse should begin its phase detect.
* When phase detect is complete, press Disable on Driveware. Move the traverse to the desired zero position. On Driveware, Open Tuning > Gain Set 0 on the left sidebar. Click the Set button with Preset Position 0.
* Now Enable the traverse.
* Run [execution.m](execution.m)
* Run [dynamic_processing.m](dynamic_processing.m)
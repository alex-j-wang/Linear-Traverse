import sys
import numpy as np
from crazyflie_py import *

throttle = int(sys.argv[1])

def main():
    swarm = Crazyswarm()
    allcfs = swarm.allcfs

    thrust = np.clip(throttle / 100 * 65535, 0, 65535)
    print(thrust)

    for cf in allcfs.crazyflies:
        cf.setParam("motorPowerSet.m1", int(thrust))
        cf.setParam("motorPowerSet.m2", int(thrust))
        cf.setParam("motorPowerSet.m3", int(thrust))
        cf.setParam("motorPowerSet.m4", int(thrust))

if __name__ == "__main__":
    main()
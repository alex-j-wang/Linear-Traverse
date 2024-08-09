import sys
import time
import json

from crazyflie_py import *

thrust = int(sys.argv[1])

def to_pwm(thrust):
    A = 0.409E-3
    B = 140.5E-3
    C = -0.099 - (thrust / 1.59309598 - 0.099)
    return round(256 * (-B + (B ** 2 - 4 * A * C) ** 0.5) / (2 * A))

def main():
    swarm = Crazyswarm()
    allcfs = swarm.allcfs

    pwm = to_pwm(thrust)

    for cf in allcfs.crazyflies:
        cf.setParam("motorPowerSet.m1", pwm)
        cf.setParam("motorPowerSet.m2", pwm)
        cf.setParam("motorPowerSet.m3", pwm)
        cf.setParam("motorPowerSet.m4", pwm)

    with open("motor_stats.json", "r+") as f:
        data = json.load(f)
        if pwm and data["lastStop"] > data["lastStart"]:
            data["lastStart"] = time.time()
        elif not pwm and data["lastStart"] > data["lastStop"]:
            data["lastStop"] = time.time()
            data["flyTime"] += data["lastStop"] - data["lastStart"]
        f.seek(0)
        json.dump(data, f, indent=4)
        f.truncate()

if __name__ == "__main__":
    main()
# Usage: python3 throttle.py <thrust> [<disabled_cf> ...]
# Example: python3 throttle.py 50 CF65

import sys
import time
import json
import logging

from crazyflie_py import *

logging.basicConfig(filename="flight.log", level=logging.INFO, format='[%(asctime)s] %(message)s')
thrust = float(sys.argv[1])
disabled = sys.argv[2:]

def to_pwm(thrust):
    A = 0.409E-3
    B = 140.5E-3
    C = -0.099 - (thrust / 1.59309598 - 0.099)
    return round(256 * (-B + (B ** 2 - 4 * A * C) ** 0.5) / (2 * A))

def main():
    swarm = Crazyswarm()
    allcfs = swarm.allcfs
    cfnames = []

    pwm = to_pwm(thrust)

    for cf in allcfs.crazyflies:
        if 'CF' + cf.prefix[3:] in disabled:
            continue
        cf.setParam("motorPowerSet.m1", pwm)
        cf.setParam("motorPowerSet.m2", pwm)
        cf.setParam("motorPowerSet.m3", pwm)
        cf.setParam("motorPowerSet.m4", pwm)
        cfnames.append('CF' + cf.prefix[3:])

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

    logging.info(f'{" ".join(cfnames)} | T{sys.argv[1]} → PWM{pwm}')

if __name__ == "__main__":
    main()

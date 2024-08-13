# Program to analyze flight.log

import re

from datetime import datetime, timedelta
from collections import defaultdict

regex = re.compile("^\[(.{23})\] ((?:CF\d+ )*)\| T([\d\.]+) → PWM(\d+)$")
last_start = defaultdict(lambda: datetime.min)
last_stop = defaultdict(lambda: datetime.min)
fly_time = defaultdict(timedelta)

def format_td(td):
    hours, remainder = divmod(td.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f'{hours:02}:{minutes:02}:{seconds:02}'

with open('flight.log', 'r') as f:
    for line in f.readlines():
        timestamp, drones, throttle, _ = regex.match(line).groups()
        timestamp = datetime.strptime(timestamp, "%Y-%m-%d %H:%M:%S,%f")
        
        for drone in drones.strip().split():
            if throttle != '0' and last_stop[drone] >= last_start[drone]:
                last_start[drone] = timestamp
            elif throttle == '0' and last_start[drone] > last_stop[drone]:
                last_stop[drone] = timestamp
                fly_time[drone] += last_stop[drone] - last_start[drone]

for drone, duration in fly_time.items():
    print(f'{drone} - {format_td(duration)}')
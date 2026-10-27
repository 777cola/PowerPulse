#!/bin/bash
# 加负载前后对比 PSTR / PDTR / 遥测，判断 PSTR 到底是整机还是 SoC
cd ~/Developer/PowerPulse
P=/Applications/PowerPulse.app/Contents/MacOS/PowerPulse

sample() {
  echo "--- $1 ---"
  $P --smc-probe 2>&1 | grep -E "^PSTR|^PDTR" | head -2 | tr '\n' ' '
  echo
  python3 - <<'PY'
import subprocess, re
d = subprocess.run(["ioreg","-rn","AppleSmartBattery"],capture_output=True,text=True).stdout
tel = re.search(r'"PowerTelemetryData" = \{(.*?)\}', d, re.S).group(1)
def g(k, src):
    m = re.search(r'"%s"=(-?\d+)' % k, src)
    return int(m.group(1))/1000 if m else 0
a = int(re.search(r'"Amperage" = (-?\d+)', d).group(1))
v = int(re.search(r'"Voltage" = (-?\d+)', d).group(1))
print("pack=%.2fW  tel_in=%.1f  tel_load=%.1f  tel_bat=%.1f" % (
    a*v/1e6, g("SystemPowerIn",tel), g("SystemLoad",tel), g("BatteryPower",tel)))
PY
}

sample "空载"
for i in 1 2 3 4 5 6; do yes > /dev/null & done
sleep 12
sample "满负载(6 核)"
sample "满负载 再采一次"
pkill -f "^yes$"
sleep 6
sample "恢复"

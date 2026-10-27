#!/bin/bash
# 三段稳态对比：空载 → 满负载 → 空载，每段 40 秒、每 5 秒采一次
# 目的：判断 PSTR 是整机功耗还是只有 SoC；顺便看遥测块多久更新一次
cd ~/Developer/PowerPulse
P=/Applications/PowerPulse.app/Contents/MacOS/PowerPulse

sample() {
  PSTR=$($P --smc-probe 2>&1 | awk -F'value=' '/^PSTR/{print $2; exit}')
  PDTR=$($P --smc-probe 2>&1 | awk -F'value=' '/^PDTR/{print $2; exit}')
  python3 - "$1" "$PSTR" "$PDTR" <<'PY'
import subprocess, re, sys
phase, pstr, pdtr = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
d = subprocess.run(["ioreg","-rn","AppleSmartBattery"],capture_output=True,text=True).stdout
tel = re.search(r'"PowerTelemetryData" = \{(.*?)\}', d, re.S).group(1)
def g(k, src):
    m = re.search(r'"%s"=(-?\d+)' % k, src)
    return int(m.group(1))/1000 if m else 0
a = int(re.search(r'"Amperage" = (-?\d+)', d).group(1))
v = int(re.search(r'"Voltage" = (-?\d+)', d).group(1))
print("%-8s PSTR=%5.1f PDTR=%5.1f | tel_in=%5.1f tel_load=%5.1f tel_bat=%5.1f | pack=%5.2f" % (
    phase, pstr, pdtr, g("SystemPowerIn",tel), g("SystemLoad",tel), g("BatteryPower",tel), a*v/1e6))
PY
}

for i in $(seq 1 8); do sample "空载"; sleep 5; done
for i in 1 2 3 4 5 6; do yes > /dev/null & done
for i in $(seq 1 8); do sample "满负载"; sleep 5; done
pkill -f "^yes$" 2>/dev/null
for i in $(seq 1 8); do sample "空载2"; sleep 5; done

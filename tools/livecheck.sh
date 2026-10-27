#!/bin/bash
# 连采 6 次（每次间隔 5 秒），看三个数是否恒等、是否稳定、充电方向对不对
cd ~/Developer/PowerPulse
for i in $(seq 1 6); do
  ./build/PowerPulse --selftest /tmp/livecheck 2>&1 | grep -E "^battery:|^power:" | tr '\n' ' '
  ./build/PowerPulse --smc-probe 2>&1 | awk -F'value=' '/^PSTR/{printf " PSTR=%.1f", $2} /^PDTR/{printf " PDTR=%.1f", $2}'
  echo
  sleep 5
done

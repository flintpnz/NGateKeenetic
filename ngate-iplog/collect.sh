#!/bin/sh
# Снимок состояния сети и журналов NGate.
#   sudo sh collect.sh connected      — пока туннель поднят
#   sudo sh collect.sh disconnected   — после отключения, собирает архив
STAGE=${1:-snapshot}
# наши собственные вызовы ip не пишем в журнал обёртки
export NGATE_IPLOG=/dev/null
OUT=/tmp/ngate-diag
mkdir -p "$OUT"
f="$OUT/state-$STAGE.txt"

{
  echo "##### $(date '+%F %T') stage=$STAGE"
  echo "##### uname";            uname -a
  echo "##### os";               cat /etc/os-release 2>/dev/null | head -3
  echo "##### ngate packages";   dpkg -l 2>/dev/null | grep -E 'cprongate|cprocsp-(base|rdr|capilite)' ; /opt/cprongate/ngatetun -V 2>/dev/null
  echo "##### processes";        ps -eo pid,ppid,comm,args 2>/dev/null | grep -E 'ngate|PID' | grep -v grep
  echo "##### ip -d link";       ip -d link show
  echo "##### ip addr";          ip addr show
  echo "##### ip rule";          ip rule show
  echo "##### ip route (all tables)"; ip route show table all
  echo "##### /proc/net/route";  cat /proc/net/route
  echo "##### /dev/net/tun";     ls -l /dev/net/tun
  echo "##### tun devices";      for d in /sys/class/net/*; do [ -e "$d/tun_flags" ] && echo "$(basename "$d") flags=$(cat "$d/tun_flags") owner=$(cat "$d/owner" 2>/dev/null)"; done
  echo "##### resolv.conf";      cat /etc/resolv.conf
} > "$f" 2>&1
echo "saved $f"

if [ "$STAGE" = disconnected ]; then
  cp /var/log/ngate-iplog.log "$OUT/" 2>/dev/null
  cp /opt/cprongate/ngate_tun_service.log "$OUT/" 2>/dev/null
  cp /var/log/ngate-client.log "$OUT/" 2>/dev/null
  find /root /home -path '*NGateConsoleClient*' -name '*.log' -exec cp {} "$OUT/" \; 2>/dev/null
  tar czf /tmp/ngate-diag.tgz -C /tmp ngate-diag
  echo "archive: /tmp/ngate-diag.tgz"
  echo "check it for logins/addresses you don't want to share before sending"
fi

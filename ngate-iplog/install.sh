#!/bin/sh
# Шаг 1 диагностики: записать, какие команды ip/resolvconf/nmcli вызывает ngatetun.
#   sudo sh install.sh          — поставить обёртки и включить подробный журнал ngatetun
#   sudo sh install.sh remove   — убрать всё и вернуть service.ini
set -e
D=$(cd "$(dirname "$0")" && pwd)
BIN=/usr/local/sbin
INI=/opt/cprongate/service.ini
TOOLS="ip resolvconf nmcli"

restart_tun() {
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files ngatetun.service >/dev/null 2>&1 \
     && [ -d /run/systemd/system ]; then
    systemctl restart ngatetun.service
  else
    /etc/init.d/ngatetun stop >/dev/null 2>&1 || true
    sleep 1
    PATH=$BIN:/usr/local/bin:$PATH /etc/init.d/ngatetun start
  fi
}

if [ "${1:-}" = remove ]; then
  for t in $TOOLS; do
    grep -q 'ngate-iplog' "$BIN/$t" 2>/dev/null && rm -f "$BIN/$t"
  done
  if [ -f "$INI.ngate-iplog.bak" ]; then
    mv -f "$INI.ngate-iplog.bak" "$INI"
  else
    rm -f "$INI"
  fi
  restart_tun
  echo "removed; log kept: /var/log/ngate-iplog.log"
  exit 0
fi

[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
[ -x /opt/cprongate/ngatetun ] || { echo "/opt/cprongate/ngatetun not found"; exit 1; }

mkdir -p "$BIN"
for t in $TOOLS; do
  # подставной nmcli заставил бы ngatetun думать, что NetworkManager есть;
  # resolvconf подставляем всегда — так узнаем DNS, которые выдаёт шлюз
  if [ "$t" = nmcli ] && ! ls /usr/sbin/nmcli /usr/bin/nmcli /sbin/nmcli /bin/nmcli >/dev/null 2>&1; then
    continue
  fi
  if [ -e "$BIN/$t" ] && ! grep -q 'ngate-iplog' "$BIN/$t"; then
    echo "$BIN/$t already exists and is not ours, skipping"
    continue
  fi
  cp "$D/wrapper.sh" "$BIN/$t"
  chmod 755 "$BIN/$t"
done

[ -f "$INI" ] && [ ! -f "$INI.ngate-iplog.bak" ] && cp "$INI" "$INI.ngate-iplog.bak"
cat > "$INI" <<'EOF'
; временно, для диагностики (ngate-iplog)
journalVerbose=5
; принудительно iproute2 вместо NetworkManager, как будет на роутере
ignoreNetworkManager=1
EOF

: > /var/log/ngate-iplog.log
restart_tun
sleep 2

if [ -r /proc/$(pgrep -xo ngatetun 2>/dev/null)/environ ] 2>/dev/null; then
  if tr '\0' '\n' < /proc/$(pgrep -xo ngatetun)/environ | grep -q "^PATH=.*$BIN"; then
    echo "ok: ngatetun running, $BIN is in its PATH"
  else
    echo "WARNING: $BIN is not in PATH of ngatetun — wrappers may be bypassed"
  fi
else
  echo "WARNING: ngatetun is not running"
fi

echo "now connect NGate, wait ~1 min, run: sudo sh $D/collect.sh connected"
echo "then disconnect and run:          sudo sh $D/collect.sh disconnected"

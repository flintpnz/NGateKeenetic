#!/bin/bash
# Тест схемы OpkgTun0 в Docker на тестовом шлюзе КриптоПро.
# Запуск (на Mac): см. README; внутри контейнера ngate-dev.
set -u
K=/k
export NGATE_TUN_LOG=/var/log/tunshim.log NGATE_TUN_TRACE=${TRACE:-}
export NDM_CMD=/usr/local/bin/ndm-stub

gcc -shared -fPIC -O2 -o /usr/local/lib/libngatetun-shim.so $K/src/tunshim.c -ldl || exit 1
install -m 755 $K/chroot/usr/local/sbin/ip /usr/local/sbin/ip
install -m 755 $K/test/ndm-stub /usr/local/bin/ndm-stub
mkdir -p /root/.local/share
echo "url=https://ng-test.cryptopro.ru" > /tmp/c.ini

# "прошивка": постоянное устройство с заглушкой, как делает interface OpkgTun0
/usr/sbin/ip tuntap add dev opkgtun0 mode tun
/usr/sbin/ip link set opkgtun0 up
/usr/sbin/ip addr add 192.0.2.1/32 dev opkgtun0

LD_PRELOAD=/usr/local/lib/libngatetun-shim.so NGATE_TUN_DEV=opkgtun0 \
  /opt/cprongate/ngatetun -D
sleep 2

state() {
  echo "--- $1"
  /usr/sbin/ip -br link | grep -E 'tun'
  /usr/sbin/ip -br addr | grep -E 'tun'
  echo "routes via opkgtun0: $(/usr/sbin/ip route | grep -c 'dev opkgtun0')"
}

for round in 1 2; do
  echo "################ round $round"
  /opt/cprongate/ngateconsoleclient -c /tmp/c.ini -N -u test -p test -l /tmp/client.log >/dev/null 2>&1 &
  cl=$!
  for _ in $(seq 1 40); do
    /usr/sbin/ip route | grep -q 'dev opkgtun0' && break
    sleep 1
  done
  sleep 3
  state "connected"
  ping -c 3 -W 2 192.168.101.2 | tail -2
  kill -INT $cl
  wait $cl
  sleep 2
  state "disconnected"
done

echo "################ tunshim.log";  cat /var/log/tunshim.log
echo "################ ndm-stub.log"; cat /var/log/ndm-stub.log
echo "################ ngate-ip.log (без route)"; grep -v 'route' /var/log/ngate-ip.log
echo "################ tun service errors"
grep -E 'Critical|Warning|failed' /opt/cprongate/ngate_tun_service.log | head -20

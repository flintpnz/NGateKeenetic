#!/bin/bash
# Сквозной тест пакета в имитации роутера (контейнер --privileged).
# /pkg — папка ngate (как /opt/etc/ngate на роутере). Шлюз — тестовый ng-test.cryptopro.ru.
set -u
S=/pkg/test/router-sim

# --- "прошивка" и Entware
mkdir -p /opt/bin && install -m 755 $S/ndmc /opt/bin/ndmc && ln -sf /opt/bin/ndmc /usr/local/bin/ndmc
printf '#!/bin/sh\n[ "$1" = list-installed ] && printf "curl - x\\ntar - x\\ncoreutils-chroot - x\\n"\nexit 0\n' \
  > /opt/bin/opkg && chmod 755 /opt/bin/opkg
python3 $S/rci.py & sleep 1

mkdir -p /opt/etc
cp -a /pkg /opt/etc/ngate
rm -rf /opt/etc/ngate/test

echo "################ install.sh"
sh /opt/etc/ngate/install.sh || exit 1

# --- конфиги для тестового шлюза
R=/opt/debian
cat > $R/opt/cprongate/console_client.ini <<'EOF'
url=https://ng-test.cryptopro.ru
username=test
password=test
EOF
sed -i 's/^NG_CHECK_HOST=.*/NG_CHECK_HOST=192.168.101.2/; s/^NG_CHECK_PORT=.*/NG_CHECK_PORT=/; s/^CONNECT_GRACE=.*/CONNECT_GRACE=20/; s/^CHECK_INTERVAL=.*/CHECK_INTERVAL=5/' \
  $R/etc/ngate-keeper.conf

up() {
  for _ in $(seq 1 60); do
    ip route | grep -q 'dev opkgtun0' && return 0
    sleep 1
  done
  return 1
}

echo "################ hook: enable in web UI"
echo running > /var/lib/ndm-sim.conf-layer
id=OpkgTun0 layer=conf level=running sh /opt/etc/ndm/iflayerchanged.d/50-ngate.sh hook
up && echo "tunnel UP" || echo "tunnel did NOT come up"
sleep 3
/opt/etc/ngate/ngate.sh status
ping -c 2 -W 2 192.168.101.2 | tail -1

echo "################ tunnel dies: kill client, keeper must reconnect"
chroot $R pkill -KILL -f '^/opt/cprongate/ngateconsoleclient'
sleep 2
for _ in $(seq 1 90); do
  chroot $R pgrep -f '^/opt/cprongate/ngateconsoleclient' >/dev/null && ip route | grep -q 'dev opkgtun0' && break
  sleep 1
done
sleep 3
/opt/etc/ngate/ngate.sh status
ping -c 2 -W 2 192.168.101.2 | tail -1

echo "################ hook: disable in web UI"
echo disabled > /var/lib/ndm-sim.conf-layer
id=OpkgTun0 layer=conf level=disabled sh /opt/etc/ndm/iflayerchanged.d/50-ngate.sh hook
sleep 25
/opt/etc/ngate/ngate.sh status

echo "################ ndm-sim.log"
cat /var/log/ndm-sim.log
echo "################ keeper log"
grep keeper: $R/var/log/ngate-keeper.log

#!/bin/sh
# /opt/etc/ngate/ngate.sh start|stop|restart|status|log|enter
# NGate в Debian-chroot на интерфейсе прошивки OpkgTun0.
set -u
export PATH=/opt/bin:/opt/sbin:/opt/usr/bin:/opt/usr/sbin:/bin:/sbin:/usr/bin:/usr/sbin
. /opt/etc/ngate/ngate.env

KEEPER_PID=/run/ngate-keeper.pid   # путь внутри chroot

mounted() { grep -q " $1 " /proc/mounts; }

mount_root() {
  mounted "$ROOT/proc"    || mount -t proc  proc  "$ROOT/proc"
  mounted "$ROOT/sys"     || mount -t sysfs sysfs "$ROOT/sys"
  mounted "$ROOT/dev"     || mount -o bind  /dev  "$ROOT/dev"
  mounted "$ROOT/dev/pts" || mount -o bind  /dev/pts "$ROOT/dev/pts"
  # всё, что пишется во время работы, — в RAM
  for d in run tmp var/log; do
    mounted "$ROOT/$d" || mount -t tmpfs tmpfs "$ROOT/$d"
  done
  mkdir -p "$ROOT/root/.local/share"
  cp /etc/resolv.conf "$ROOT/etc/resolv.conf" 2>/dev/null
}

in_chroot() {
  chroot "$ROOT" /usr/bin/env -i \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HOME=/root LANG=C.UTF-8 "$@"
}

alive() {
  mounted "$ROOT/proc" && in_chroot start-stop-daemon --status --pidfile $KEEPER_PID
}

configured() {
  if grep -q '^username=ivanov$' "$ROOT/opt/cprongate/console_client.ini" 2>/dev/null \
     || grep -q 'JBSWY3DPEHPK3PXP' "$ROOT/etc/ngate-keeper.conf" 2>/dev/null; then
    echo "not configured: fill console_client.ini and ngate-keeper.conf in $ROOT"
    return 1
  fi
}

start() {
  configured || return 1
  mount_root
  if alive; then echo "already running"; return 0; fi
  in_chroot start-stop-daemon --start --background --make-pidfile \
    --pidfile $KEEPER_PID --exec /usr/local/bin/ngate-keeper
  echo "started"
}

stop() {
  if mounted "$ROOT/proc"; then
    # keeper по TERM гасит клиент; ngatetun при этом снимает маршруты и адрес
    in_chroot start-stop-daemon --stop --retry TERM/20/KILL/5 \
      --pidfile $KEEPER_PID --remove-pidfile >/dev/null 2>&1
    in_chroot pkill -x ngatetun
  fi
  ndmc -c "interface $NDM_IF ip address $IDLE_IP" >/dev/null 2>&1   # на случай kill -9
  echo "stopped"
}

status() {
  if alive; then echo "keeper running"; else echo "keeper not running"; fi
  mounted "$ROOT/proc" && in_chroot pgrep -a -x ngatetun
  ip -4 addr show dev opkgtun0 2>/dev/null | grep inet
  echo "routes via opkgtun0: $(ip route | grep -c 'dev opkgtun0')"
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  log) tail -n 50 -f "$ROOT/var/log/ngate-keeper.log" ;;
  enter) mount_root; chroot "$ROOT" /bin/bash -l ;;
  *) echo "usage: ngate.sh start|stop|restart|status|log|enter" >&2; exit 1 ;;
esac

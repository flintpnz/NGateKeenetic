#!/bin/sh
# Автостарт: симлинк /opt/etc/init.d/S99ngate. Событие conf может прийти раньше,
# чем смонтирован /opt, поэтому запускаемся и здесь — если NGATE включён в веб-интерфейсе.
. /opt/etc/ngate/ngate.env
case "$1" in
  start)
    curl -s --max-time 5 "http://127.0.0.1:79/rci/show/interface/$NDM_IF/summary/layer" \
      | grep -q '"conf": *"running"' && /opt/etc/ngate/ngate.sh start
    ;;
  stop)
    /opt/etc/ngate/ngate.sh stop
    ;;
esac

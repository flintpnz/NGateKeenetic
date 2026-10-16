#!/bin/sh
# Переключатель в веб-интерфейсе -> start/stop. Симлинк /opt/etc/ndm/iflayerchanged.d/50-ngate.sh.
# Хук должен быстро вернуть управление (таймаут 24 с), поэтому работа уходит в фон.
[ "$1" = "hook" ] || exit 0
. /opt/etc/ngate/ngate.env
[ "$id" = "$NDM_IF" ] || exit 0
[ "$layer" = "conf" ] || exit 0
case "$level" in
  running)  /opt/etc/ngate/ngate.sh start </dev/null >/dev/null 2>&1 & ;;
  disabled) /opt/etc/ngate/ngate.sh stop  </dev/null >/dev/null 2>&1 & ;;
esac
exit 0

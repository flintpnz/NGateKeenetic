#!/bin/sh
# Установка / обновление / восстановление из /opt/etc/ngate:
#   пакеты Entware -> rootfs Debian (если ещё нет) -> файлы в chroot -> OpkgTun0 -> симлинки.
# Повторный запуск безопасен. Снять: sh /opt/etc/ngate/install.sh remove
set -u
export PATH=/opt/bin:/opt/sbin:/opt/usr/bin:/opt/usr/sbin:/bin:/sbin:/usr/bin:/usr/sbin
D=/opt/etc/ngate
. $D/ngate.env

if [ "${1:-}" = remove ]; then
  $D/ngate.sh stop
  rm -f /opt/etc/ndm/iflayerchanged.d/50-ngate.sh /opt/etc/init.d/S99ngate
  echo "unlinked; $ROOT and $NDM_IF kept"
  echo "remove interface: ndmc -c 'no interface $NDM_IF' && ndmc -c 'system configuration save'"
  exit 0
fi

# 1. пакеты Entware
for p in curl tar coreutils-chroot; do
  opkg list-installed | grep -q "^$p " || { opkg update >/dev/null; opkg install "$p"; }
done

# 2. rootfs (собирается на Mac: build-rootfs.sh)
if [ ! -x "$ROOT/opt/cprongate/ngatetun" ]; then
  [ -f $D/ngate-rootfs.tar.gz ] || { echo "no $ROOT and no $D/ngate-rootfs.tar.gz"; exit 1; }
  echo "unpacking rootfs to $ROOT ..."
  mkdir -p "$ROOT"
  tar -xzpf $D/ngate-rootfs.tar.gz --numeric-owner -C "$ROOT" || exit 1
  rm -f $D/ngate-rootfs.tar.gz
fi

# 3. наши файлы в chroot; настоящие конфиги не трогаем
cp -a $D/chroot/. "$ROOT/"
for f in etc/ngate-keeper.conf opt/cprongate/console_client.ini; do
  [ -f "$ROOT/$f" ] || cp "$ROOT/$f.example" "$ROOT/$f"
  chmod 600 "$ROOT/$f"
done
if [ -n "$CSP_LICENSE" ]; then
  chroot "$ROOT" /opt/cprocsp/sbin/aarch64/cpconfig -license -set "$CSP_LICENSE" >/dev/null \
    && echo "CSP license set"
fi

# 4. интерфейс прошивки — только если его нет (существующий не трогаем).
#    "ip global auto" нужен, чтобы NGATE появился в вебе (график, переключатель);
#    auto ставит его в конец приоритетов — default остаётся через провайдера.
if ! ndmc -c 'show running-config' | grep -q "^interface $NDM_IF\$"; then
  ndmc -c "interface $NDM_IF"
  ndmc -c "interface $NDM_IF description $NDM_DESC"
  ndmc -c "interface $NDM_IF security-level public"
  ndmc -c "interface $NDM_IF ip address $IDLE_IP"
  ndmc -c "interface $NDM_IF ip global auto"
  ndmc -c "interface $NDM_IF ip tcp adjust-mss pmtu"
  ndmc -c "interface $NDM_IF up"
  ndmc -c "system configuration save"
fi

# 5. права и симлинки; старый вариант без OpkgTun отключаем
chmod 700 $D
chmod +x $D/*.sh
[ -f /opt/etc/init.d/S99debian ] && chmod -x /opt/etc/init.d/S99debian
mkdir -p /opt/etc/ndm/iflayerchanged.d /opt/etc/init.d
ln -sf $D/hook.sh /opt/etc/ndm/iflayerchanged.d/50-ngate.sh
ln -sf $D/init.sh /opt/etc/init.d/S99ngate

echo "done."
echo "fill: $ROOT/opt/cprongate/console_client.ini (login/password)"
echo "      $ROOT/etc/ngate-keeper.conf (TOTP secret)"
echo "then enable $NDM_DESC in web UI; check: $D/ngate.sh status | log"

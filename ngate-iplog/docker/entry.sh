#!/bin/bash
# Точка входа контейнера: обёртки ip -> ngatetun -> консольный клиент (интерактивно).
# Снимок "connected" делается сам, когда у tun появится адрес; после выхода клиента —
# снимок "disconnected" и архив в /out.
set -u
K=/opt/ngate-iplog
URL=${NGATE_URL:-https://vpn.example.com}

[ -n "${CSP_LICENSE:-}" ] && cpconfig -license -set "$CSP_LICENSE" >/dev/null

sh $K/install.sh | grep -E 'ok:|WARNING'

printf 'url=%s\n' "$URL" > /tmp/console_client.ini

# автоснимок: ждём адрес на любом интерфейсе, кроме lo и eth*
(
  export NGATE_IPLOG=/dev/null
  for _ in $(seq 1 900); do
    if ip -o -4 addr show | grep -vE ': (lo|eth[0-9]+)[ @]' | grep -q inet; then
      sleep 20
      sh $K/collect.sh connected >/dev/null 2>&1
      # сразу сохраняем в /out: вдруг контейнер завершится не штатно
      cp /var/log/ngate-iplog.log /opt/cprongate/ngate_tun_service.log /tmp/ngate-diag/ 2>/dev/null
      tar czf /out/ngate-diag-connected.tgz -C /tmp ngate-diag \
        && echo && echo "[diag] Снимок сохранён: out/ngate-diag-connected.tgz" \
        || echo "[diag] ОШИБКА: не удалось записать в /out"
      echo "[diag] Туннель поднят. Можно отключаться: Ctrl+C"
      exit 0
    fi
    sleep 1
  done
) &

echo
echo "[diag] Шлюз: $URL"
echo "[diag] Введите логин, пароль и код из Мультифактора, когда клиент спросит."
echo "[diag] После сообщения «снимок сделан» нажмите Ctrl+C."
echo

# Ctrl+C должен завершить клиент, а не этот скрипт
trap 'true' INT
/opt/cprongate/ngateconsoleclient -c /tmp/console_client.ini -l /var/log/ngate-client.log "$@"
echo "[diag] клиент завершился (код $?), собираю журналы..."
sleep 3
trap - INT
sh $K/collect.sh disconnected >/dev/null 2>&1
cp /tmp/ngate-diag.tgz /out/ && echo "[diag] Готово: out/ngate-diag.tgz"

#!/bin/sh
# Журналирующая обёртка для ip / resolvconf / nmcli.
# Ставится в /usr/local/sbin под именем утилиты. Записывает аргументы, stdin,
# вывод и код возврата в журнал и вызывает настоящую утилиту без изменений.

LOG=${NGATE_IPLOG:-/var/log/ngate-iplog.log}
name=$(basename "$0")
self=$(readlink -f "$0")

real=
for d in /usr/sbin /usr/bin /sbin /bin; do
  c="$d/$name"
  if [ -x "$c" ] && [ "$(readlink -f "$c")" != "$self" ]; then
    real=$c
    break
  fi
done

tmp=$(mktemp -d /tmp/ngate-iplog.XXXXXX) || exit 1
trap 'rm -rf "$tmp"' EXIT

# stdin нужен только "resolvconf -a" (получает конфиг DNS). Остальные вызовы
# ngatetun делает с открытым, но пустым stdin — читать его нельзя, иначе зависнем.
if [ "$name" = resolvconf ] && [ "${1:-}" = "-a" ] && [ ! -t 0 ]; then
  cat > "$tmp/in"
else
  : > "$tmp/in"
fi

if [ -n "$real" ]; then
  "$real" "$@" < "$tmp/in" > "$tmp/out" 2> "$tmp/err"
  rc=$?
else
  # утилиты нет в системе: только записываем вызов и сообщаем об успехе
  : > "$tmp/out"
  echo "ngate-iplog: $name not found, call only logged" > "$tmp/err"
  rc=0
fi

{
  echo "=== $(date '+%F %T.%N' | cut -c1-23) pid=$$ parent=$(cat /proc/$PPID/comm 2>/dev/null) real=${real:-none}"
  printf '+ %s' "$name"
  for a in "$@"; do printf " '%s'" "$a"; done
  echo
  [ -s "$tmp/in" ]  && { echo "--- stdin:";  cat "$tmp/in"; }
  [ -s "$tmp/out" ] && { echo "--- stdout:"; head -c 4000 "$tmp/out"; echo; }
  [ -s "$tmp/err" ] && { echo "--- stderr:"; head -c 4000 "$tmp/err"; echo; }
  echo "--- rc=$rc"
} >> "$LOG" 2>/dev/null

cat "$tmp/out"
cat "$tmp/err" >&2
exit $rc

#!/bin/bash
# Диагностика ngatetun в Docker на Mac (Apple Silicon, linux/arm64).
#   ./docker-diag.sh                      — собрать образ и подключиться к vpn.example.com
#   NGATE_URL=https://... ./docker-diag.sh — другой шлюз
#   CSP_LICENSE=XXXXX-... ./docker-diag.sh — ввести лицензию CSP (без неё — демо 90 дней)
# Результат: out/ngate-diag.tgz рядом со скриптом.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CSP_TGZ=${CSP_TGZ:-"$HERE/../ngate/vendor/cprocsp-5.0.13003-linux-arm64_deb.tgz"}
CERTS=${CERTS:-"$HERE/../ngate/certs"}
OUT="$HERE/out"

ctx=$(mktemp -d)
trap 'rm -rf "$ctx"' EXIT

tar xzf "$CSP_TGZ" -C "$ctx"
mv "$ctx"/linux-*_deb "$ctx/linux-arm64_deb" 2>/dev/null || true
mkdir -p "$ctx/certs/root" "$ctx/certs/ca"
cp "$CERTS/root/"*.cer "$ctx/certs/root/"
cp "$CERTS/ca/"*.cer "$ctx/certs/ca/"
mkdir "$ctx/ngate-iplog"
tar -C "$HERE" --exclude ./out -cf - . | tar -C "$ctx/ngate-iplog" -xf -
cp "$HERE/docker/Dockerfile" "$ctx/"

docker build --platform linux/arm64 -t ngate-diag "$ctx"

mkdir -p "$OUT"
# без --rm: после выхода контейнер остаётся, журналы можно достать через docker cp
docker rm -f ngate-diag >/dev/null 2>&1 || true
docker run -it --platform linux/arm64 --name ngate-diag \
  --cap-add NET_ADMIN --device /dev/net/tun \
  -e NGATE_URL="${NGATE_URL:-https://vpn.example.com}" -e CSP_LICENSE="${CSP_LICENSE:-}" \
  -v "$OUT":/out \
  ngate-diag "$@"

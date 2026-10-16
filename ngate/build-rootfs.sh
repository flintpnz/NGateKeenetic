#!/bin/bash
# Собирает на Mac (Docker, linux/arm64):
#   ngate-rootfs.tar.gz                   — Debian + КриптоПро CSP + NGate + сертификаты
#   chroot/usr/local/lib/libngatetun-shim.so — перехватчик для ngatetun
# Пути к исходникам можно переопределить: CSP_TGZ=... CERTS=... ./build-rootfs.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CSP_TGZ=${CSP_TGZ:-"$HERE/vendor/cprocsp-5.0.13003-linux-arm64_deb.tgz"}
CERTS=${CERTS:-"$HOME/Downloads/nGate_Linux/_Root_cert"}

ctx=$(mktemp -d)
trap 'rm -rf "$ctx"; docker rm -f ngate-rootfs-tmp ngate-shim-tmp >/dev/null 2>&1 || true' EXIT

tar xzf "$CSP_TGZ" -C "$ctx"
mv "$ctx"/linux-*_deb "$ctx/linux-arm64_deb" 2>/dev/null || true
mkdir -p "$ctx/certs/root" "$ctx/certs/ca" "$ctx/src"
cp "$CERTS/1.trusted root certification authorities/"*.cer "$ctx/certs/root/"
cp "$CERTS/2.Intermediate Certification Authorities/"*.cer "$ctx/certs/ca/"
cp "$HERE/src/tunshim.c" "$ctx/src/"
cp "$HERE/build/Dockerfile" "$ctx/"

docker build --platform linux/arm64 --target shim   -t ngate-shim   "$ctx"
docker build --platform linux/arm64 --target rootfs -t ngate-rootfs "$ctx"

# перехватчик ставит install.sh вместе с остальными файлами chroot
docker create --platform linux/arm64 --name ngate-shim-tmp ngate-shim /bin/true >/dev/null
mkdir -p "$HERE/chroot/usr/local/lib"
docker cp ngate-shim-tmp:/libngatetun-shim.so "$HERE/chroot/usr/local/lib/libngatetun-shim.so"

docker create --platform linux/arm64 --name ngate-rootfs-tmp ngate-rootfs /bin/true >/dev/null
docker export ngate-rootfs-tmp | gzip -9 > "$HERE/ngate-rootfs.tar.gz"

ls -lh "$HERE/ngate-rootfs.tar.gz" "$HERE/chroot/usr/local/lib/libngatetun-shim.so"

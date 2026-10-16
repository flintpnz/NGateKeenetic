# Сборка перехватчика
FROM debian:bookworm AS shim
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends gcc libc6-dev >/dev/null
COPY src/tunshim.c /src/tunshim.c
RUN gcc -shared -fPIC -O2 -Wall -o /libngatetun-shim.so /src/tunshim.c -ldl

# Rootfs для chroot на роутере
FROM debian:bookworm AS rootfs
ENV LANG=C.UTF-8
# документация и man не нужны — экономим место на роутере
RUN printf 'path-exclude /usr/share/doc/*\npath-exclude /usr/share/man/*\npath-exclude /usr/share/info/*\npath-exclude /usr/share/locale/*\npath-include /usr/share/locale/ru/*\n' \
      > /etc/dpkg/dpkg.cfg.d/01-slim \
 && apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends ca-certificates lsb-base libglib2.0-0 \
      procps iproute2 iputils-ping curl expect oathtool >/dev/null

COPY linux-arm64_deb /tmp/csp
RUN cd /tmp/csp && ./install.sh >/dev/null 2>&1 && rm -rf /tmp/csp \
 && test -x /opt/cprocsp/bin/aarch64/certmgr

COPY certs /tmp/certs
RUN for f in /tmp/certs/root/*.cer; do /opt/cprocsp/bin/aarch64/certmgr -inst -store mRoot -file "$f" >/dev/null; done \
 && for f in /tmp/certs/ca/*.cer;   do /opt/cprocsp/bin/aarch64/certmgr -inst -store mCA   -file "$f" >/dev/null; done \
 && rm -rf /tmp/certs

RUN echo 'deb [trusted=yes] https://ng-client.cryptopro.ru/repository/debian/arm64 ./' \
      > /etc/apt/sources.list.d/ngate.list \
 && apt-get update -qq \
 && apt-get install -y -qq cprongate-tun cprongate-console >/dev/null \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /var/log/*.log \
 && rm -f /etc/init.d/ngatetun.dpkg-* \
 && mkdir -p /root/.local/share

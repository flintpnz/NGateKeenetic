FROM debian:bookworm
ENV LANG=C.UTF-8 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/cprocsp/bin/aarch64:/opt/cprocsp/sbin/aarch64

RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends ca-certificates lsb-base libglib2.0-0 \
      procps iproute2 iputils-ping curl \
 && rm -rf /var/lib/apt/lists/*

COPY linux-arm64_deb /tmp/csp
RUN cd /tmp/csp && ./install.sh >/tmp/csp-install.log 2>&1 && rm -rf /tmp/csp

COPY certs /tmp/certs
RUN for f in /tmp/certs/root/*.cer; do certmgr -inst -store mRoot -file "$f" >/dev/null; done \
 && for f in /tmp/certs/ca/*.cer;   do certmgr -inst -store mCA   -file "$f" >/dev/null; done \
 && rm -rf /tmp/certs

RUN echo 'deb [trusted=yes] https://ng-client.cryptopro.ru/repository/debian/arm64 ./' \
      > /etc/apt/sources.list.d/ngate.list \
 && apt-get update -qq \
 && apt-get install -y -qq cprongate-tun cprongate-console \
 && rm -rf /var/lib/apt/lists/*

COPY ngate-iplog /opt/ngate-iplog
ENTRYPOINT ["/bin/bash", "/opt/ngate-iplog/docker/entry.sh"]

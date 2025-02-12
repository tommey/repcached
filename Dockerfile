FROM ubuntu:22.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    git \
    libevent-dev \
    libtool \
    pkg-config \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app

RUN dpkg -l \
 && ./autogen.sh \
 && ./configure --enable-replication \
 && make clean \
 && make -j8 \
 && ls -la memcached \
 && file memcached \
 && ldd memcached || true


FROM ubuntu:22.04 AS test

RUN apt-get update \
 && apt-get install -y \
    libevent-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ENV REPCACHED_PAIR="unknown"

COPY --from=build /app/memcached /usr/bin/memcached

EXPOSE 11211 11212

CMD ["/bin/bash", "-c", "set -x; until getent hosts $REPCACHED_PAIR; do sleep 0.1; done; memcached -u root -m 64 -l 0.0.0.0 -x $(getent hosts $REPCACHED_PAIR | cut -d ' ' -f1)"]

ARG DEBIAN_VERSION="${DEBIAN_VERSION:-stable-slim}"
FROM debian:${DEBIAN_VERSION} as dependencies1

WORKDIR /data

#su-exec
ARG SUEXEC_VERSION=v0.2
ARG SUEXEC_HASH=f85e5bde1afef399021fbc2a99c837cf851ceafa

RUN apt-get update -qq && apt-get -yqq --no-install-recommends install \
        ca-certificates \
        build-essential \
        cmake \
        # clang \
        pkg-config \
        libboost-all-dev \
        miniupnpc \
        libhidapi-dev \
        libhidapi-libusb0 \
        libssl-dev \
        libzmq3-dev \
        libpgm-dev \
        libunbound-dev \
        libsodium-dev \
        libunwind8-dev \
        liblzma-dev \
        libreadline6-dev \
        libldns-dev \
        libexpat1-dev \
        libcurl4-openssl-dev \
        doxygen \
        graphviz \
        libpcsclite-dev \
        libgtest-dev \
        git > /dev/null \
    && cd /usr/src/gtest || exit 1 \
    && cmake . > /dev/null \
    && make > /dev/null \
    && mv libg* /usr/lib/ \
    && cd /data || exit 1 \
    && echo "\e[32mbuilding: su-exec\e[39m" \
    && git clone --branch ${SUEXEC_VERSION} --single-branch --depth 1 https://github.com/ncopa/su-exec.git su-exec.git > /dev/null \
    && cd su-exec.git || exit 1 \
    && test `git rev-parse HEAD` = ${SUEXEC_HASH} || exit 1 \
    && make > /dev/null \
    && cp su-exec /data \
    && cd /data || exit 1 \
    && rm -rf /data/su-exec.git

FROM index.docker.io/xmrto/monero-explorer:dependencies1 as builder_monero
WORKDIR /data
# BUILD_PATH:
# Using 'USE_SINGLE_BUILDDIR=1 make' creates a unified build dir (/monero.git/build/release/bin)

ARG PROJECT_URL=https://github.com/monero-project/monero.git
ARG BRANCH=master
ARG BUILD_PATH=/monero.git/build/release/bin
ARG BUILD_BRANCH=$BRANCH

RUN echo "\e[32mcloning: $PROJECT_URL on branch: $BRANCH\e[39m" \
    && cd /data || exit 1 \
    && git clone -n --branch ${BRANCH} --single-branch --depth 1 --recursive ${PROJECT_URL} monero.git > /dev/null \
    && cd monero.git || exit 1 \
    && git checkout "$BUILD_BRANCH" \
    && git submodule update --init --force \
    && echo "\e[32mbuilding monero\e[39m" \
    && USE_SINGLE_BUILDDIR=1 make > /dev/null

FROM index.docker.io/xmrto/monero-explorer:builder_monero as builder
WORKDIR /data

ARG PROJECT_URL=https://github.com/moneroexamples/onion-monero-blockchain-explorer.git
# 'master' or 'devel'
ARG BRANCH=master

# ENV CC /usr/bin/clang
# ENV CXX /usr/bin/clang++
# checkout to develop branch for upcoming hard forks

# COPY patch.diff /data

RUN echo "\e[32mcloning: $PROJECT_URL on branch: devel\e[39m" \
    && git clone --branch master --single-branch --depth 1 ${PROJECT_URL} monero-explorer.git > /dev/null \
    && cd monero-explorer.git || exit 1  \
    # && git checkout devel > /dev/null \
    # && echo "\e[32mapplying  patch\e[39m" \
    # && git apply --stat ../patch.diff \
    # && git apply --check ../patch.diff \
    # && git apply  ../patch.diff \
    && mkdir build && cd build || exit 1 \
    && cmake -DMONERO_DIR=/data/monero.git .. > /dev/null \
    && make > /dev/null \
    && mv /data/monero-explorer.git/build/xmrblocks /data/

RUN apt-get purge -yqq \
        build-essential \
        cmake \
        libboost-all-dev \
        libssl-dev \
        libzmq3-dev \
        libpgm-dev \
        libunbound-dev \
        libsodium-dev \
        libunwind8-dev \
        liblzma-dev \
        libreadline6-dev \
        libldns-dev \
        libexpat1-dev \
        doxygen \
        graphviz \
        libpcsclite-dev \
        libgtest-dev \
        libcurl4-openssl-dev \
        git > /dev/null \
    && apt-get autoremove --purge -yqq > /dev/null \
    && apt-get clean > /dev/null \
    && rm -rf /var/tmp/* /tmp/* /var/lib/apt/* > /dev/null \
    && rm -rf /data/monero.git \
    && rm -rf /data/su-exec-clone \
    && rm -rf /data/monero-explorer.git

FROM debian:${DEBIAN_VERSION}
WORKDIR /data
COPY --from=builder /data/xmrblocks /usr/local/bin
COPY --from=builder /data/su-exec /usr/local/bin/

RUN apt-get update -qq && apt-get install -yqq --no-install-recommends \
       libboost-all-dev \
       libunbound-dev \
       libunwind8-dev \
       libpcsclite-dev \
       libcurl4-openssl-dev \
       libsodium-dev \
       libhidapi-libusb0 > /dev/null \
    && apt-get autoremove --purge -yqq > /dev/null \
    && apt-get clean > /dev/null \
    && rm -rf /var/tmp/* /tmp/* /var/lib/apt/* > /dev/null

COPY onion-monero-blockchain-explorer/src/templates /data/templates_template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /data
VOLUME ["/monero", "/data"]

EXPOSE 8081
EXPOSE 8082
EXPOSE 8083

ENV USER_ID 1000
ENV PORT 8081
ENV LMDB_PATH /monero
ENV ENABLE_AUTOREFRESH 0
ENV URL_PREFIX ""

ENTRYPOINT ["/entrypoint.sh"]

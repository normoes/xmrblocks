ARG DEBIAN_VERSION="${DEBIAN_VERSION:-stable-slim}"
FROM debian:${DEBIAN_VERSION} as dependencies1

WORKDIR /data

RUN apt-get update -qq && apt-get -yqq --no-install-recommends install \
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
        doxygen \
        graphviz \
        libpcsclite-dev \
        libgtest-dev \
        git > /dev/null \
    && cd /usr/src/gtest || exit 1 \
    && cmake . \
    && make \
    && mv libg* /usr/lib/

RUN cd /data || exit 1 \
    && git clone https://github.com/ncopa/su-exec.git su-exec-clone > /dev/null \
    && cd su-exec-clone || exit 1 \
    && make > /dev/null \
    && mv su-exec /data

# BUILD_PATH:
# Using 'USE_SINGLE_BUILDDIR=1 make' creates a unified build dir (/monero/build/release/bin)

ARG MONERO_URL=https://github.com/monero-project/monero.git
# ARG BRANCH=release-v0.13
ARG BRANCH=master
ARG BUILD_PATH=/monero/build/release/bin

RUN cd /data || exit 1 \
    && git clone -b "$BRANCH" --single-branch --depth 1 --recursive $MONERO_URL > /dev/null
RUN cd monero || exit 1 \
    && USE_SINGLE_BUILDDIR=1 make > /dev/null

# ENV CC /usr/bin/clang
# ENV CXX /usr/bin/clang++
RUN cd /data || exit 1 \
    && apt-get update -qq && apt-get install -yqq --no-install-recommends \
        libcurl4-openssl-dev > /dev/null
# checkout to develop branch for upcoming hard forks
RUN git clone https://github.com/moneroexamples/onion-monero-blockchain-explorer.git > /dev/null \
    && cd onion-monero-blockchain-explorer || exit 1  \
    && git checkout devel > /dev/null \
    && mkdir build && cd build || exit 1 \
    && cmake -DMONERO_DIR=/data/monero .. > /dev/null \
    && make > /dev/null \
    && mv /data/onion-monero-blockchain-explorer/build/xmrblocks /data/

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
        git \
        libcurl4-openssl-dev > /dev/null \
    && apt-get autoremove --purge -yqq > /dev/null \
    && apt-get clean > /dev/null \
    && rm -rf /var/tmp/* /tmp/* /var/lib/apt/* > /dev/null \
    && rm -rf /data/monero \
    && rm -rf /data/su-exec-clone \
    && rm -rf /data/onion-monero-blockchain-explorer

FROM debian:${DEBIAN_VERSION}
WORKDIR /data
COPY --from=builder /data/xmrblocks /usr/local/bin
COPY --from=builder /data/su-exec /usr/local/bin/

RUN apt-get update -qq && apt-get install -y \
       libboost-all-dev \
       libunbound-dev \
       libunwind8-dev \
       libpcsclite-dev \
       libcurl4-openssl-dev \
       libsodium-dev \
       libhidapi-libusb0 \
   && apt-get autoremove --purge -y \
   && rm -rf /var/tmp/* /tmp/* /var/lib/apt

COPY onion-monero-blockchain-explorer/src/templates /data/templates_template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /data
VOLUME ["/monero", "/data"]

ENV USER_ID 1000
ENV PORT 8081
ENV LMDB_PATH /monero
ENV ENABLE_AUTOREFRESH 0
ENV URL_PREFIX ""

ENTRYPOINT ["/entrypoint.sh"]

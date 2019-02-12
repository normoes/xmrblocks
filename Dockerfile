FROM debian:stable-slim as builder

WORKDIR /data

RUN apt-get update -qq && apt-get -y install -f \
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
        git \
    && cd /usr/src/gtest \
    && cmake . \
    && make \
    && mv libg* /usr/lib/

RUN cd /data \
    && git clone https://github.com/ncopa/su-exec.git su-exec-clone \
    && cd su-exec-clone \
    && make \
    && mv su-exec /data

# BUILD_PATH:
# Using 'USE_SINGLE_BUILDDIR=1 make' creates a unified build dir (/monero/build/release/bin)

ARG MONERO_URL=https://github.com/monero-project/monero.git
ARG BRANCH=v0.13.0.4
ARG BUILD_PATH=/monero/build/release/bin

RUN cd /data \
    && git clone -b "$BRANCH" --single-branch --depth 1 --recursive $MONERO_URL
RUN cd monero \
    && USE_SINGLE_BUILDDIR=1 make

# ENV CC /usr/bin/clang
# ENV CXX /usr/bin/clang++
RUN cd /data \
    && apt-get update -qq && apt-get install -y \
        libcurl4-openssl-dev
RUN git clone https://github.com/moneroexamples/onion-monero-blockchain-explorer.git \
    && cd onion-monero-blockchain-explorer  \
    # && git checkout devel \  # upcoming hard forks
    && mkdir build && cd build \
    && cmake -DMONERO_DIR=/data/monero .. \
    && make \
    && mv /data/onion-monero-blockchain-explorer/build/xmrblocks /data/

RUN apt-get purge -y \
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
        libcurl4-openssl-dev \
    && apt-get autoremove --purge -y \
    && apt-get clean \
    && rm -rf /var/tmp/* /tmp/* /var/lib/apt \
    && rm -rf /data/monero \
    && rm -rf /data/su-exec-clone \
    && rm -rf /data/onion-monero-blockchain-explorer

FROM debian:stable-slim
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

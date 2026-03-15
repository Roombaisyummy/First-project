# SatellaJailed Modernized - Docker Build Image
# Based on xtool and Theos requirements

FROM swift:6.2-jammy AS build-base

# Install dependencies
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    checkinstall \
    git \
    autoconf \
    automake \
    libtool-bin \
    libssl-dev \
    pkg-config \
    libxml2 \
    curl libcurl4-openssl-dev \
    zip unzip \
    liblzma-dev zlib1g-dev \
    wget \
    dpkg-dev \
    fakeroot \
    ldid \
    && rm -rf /var/lib/apt/lists/*

# Install Theos
ENV THEOS=/opt/theos
RUN git clone --recursive https://github.com/theos/theos.git $THEOS

# Install iOS SDK
RUN cd $THEOS/sdks \
    && git clone https://github.com/theos/sdks.git \
    && mv sdks/iPhoneOS16.5.sdk . \
    && ln -sf iPhoneOS16.5.sdk iPhoneOS16.0.sdk \
    && rm -rf sdks

# Install Linux toolchain (from Procursus mirrors)
RUN cd /tmp \
    && wget -q https://github.com/ProcursusTeam/Procursus/releases/download/v16.1/libprocursus-dev_16.1_amd64.deb \
    && dpkg -i libprocursus-dev_16.1_amd64.deb \
    || echo "Toolchain install attempted"

# Set up environment
ENV PATH=$PATH:$THEOS/bin

WORKDIR /src

CMD ["/bin/bash"]

# Build stage
FROM build-base AS builder

COPY . /src

RUN export THEOS=/opt/theos \
    && export PATH=$PATH:$THEOS/bin \
    && make package FINALPACKAGE=1 \
    && cp -r packages /output

# Final stage - just the packages
FROM scratch

COPY --from=builder /output /packages

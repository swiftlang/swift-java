ARG swift_version=nightly-main
ARG ubuntu_version=jammy
ARG base_image=docker.io/swiftlang/swift:${swift_version}-${ubuntu_version}
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version
ARG ubuntu_version

# set as UTF-8
RUN apt-get update && apt-get install -y \
    locales locales-all \
    make \
    libc6-dev \
    curl \
    libjemalloc2 \
    libjemalloc-dev
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# JDK dependency
RUN curl -s "https://get.sdkman.io" | bash
RUN bash -c "source /root/.sdkman/bin/sdkman-init.sh && sdk install java 25.0.1-amzn"
ENV JAVA_HOME="$(sdk home java current)"

RUN curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz && \
    tar zxf swiftly-$(uname -m).tar.gz && \
    ./swiftly init --quiet-shell-followup --assume-yes && \
    . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" && \
    hash -r

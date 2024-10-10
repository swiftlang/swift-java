ARG swift_version=nightly-main
ARG ubuntu_version=jammy
ARG base_image=docker.io/swiftlang/swift:$swift_version-$ubuntu_version
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version
ARG ubuntu_version

# set as UTF-8
RUN apt-get update && apt-get install -y \
    locales locales-all \
    make \
    libc6-dev
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# JDK dependency
COPY install_jdk.sh .
RUN bash -xc 'JDK_VENDOR=Corretto ./install_jdk.sh'
ENV JAVA_HOME="/usr/lib/jvm/default-jdk"
ENV PATH="$PATH:/usr/lib/jvm/default-jdk/bin"

# Install "untested" nightly 'main' Swift
# TODO: Only do this if the released Swift is older than what we require
RUN bash -xc './install_nightly_untested_swift.sh'

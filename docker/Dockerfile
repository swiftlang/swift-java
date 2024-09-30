ARG swift_version=nightly-main
ARG ubuntu_version=jammy
ARG base_image=docker.io/swiftlang/swift:$swift_version-$ubuntu_version
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version
ARG ubuntu_version

# set as UTF-8
RUN apt-get update && apt-get install -y locales locales-all
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Build dependencies
RUN apt-get update && apt-get install -y make curl libc6-dev

# JDK dependency (we require JDK22+ which isn't distributed as package in Jammy)
# We download the latest supported non-LTS version from OpenJDK: https://jdk.java.net
RUN echo "Download JDK for: $(uname -m)"
RUN if [ "$(uname -m)" = 'aarch64' ]; then \
      echo "Download JDK for: ARM64" && \
      curl https://download.java.net/java/GA/jdk23/3c5b90190c68498b986a97f276efd28a/37/GPL/openjdk-23_linux-aarch64_bin.tar.gz --output jdk.tar.gz && \
      EXPECT_JDK_SHA=076dcf7078cdf941951587bf92733abacf489a6570f1df97ee35945ffebec5b7; \
    else \
      echo "Download JDK for: x86" && \
      curl https://download.java.net/java/GA/jdk23/3c5b90190c68498b986a97f276efd28a/37/GPL/openjdk-23_linux-x64_bin.tar.gz --output jdk.tar.gz && \
      EXPECT_JDK_SHA=08fea92724127c6fa0f2e5ea0b07ff4951ccb1e2f22db3c21eebbd7347152a67; \
    fi
# Verify the downlaoded JDK checksums
RUN JDK_SHA=$(sha256sum jdk.tar.gz | cut -d ' ' -f 1)
RUN if [ "$JDK_SHA" != "$EXPECT_JDK_SHA" ]; then  \
          echo "Downloaded JDK SHA does not match expected!" && \
          exit 1; \
        else \
          echo "JDK SHA is correct."; \
        fi
# Extract and verify the JDK installation
RUN tar xzvf jdk.tar.gz && rm jdk.tar.gz && mv jdk-23 jdk
RUN /jdk/bin/java -version
ENV JAVA_HOME="/jdk"
ENV PATH="$PATH:/jdk/bin"

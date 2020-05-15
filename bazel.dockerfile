###############################################################################
## Dockerfile to build bazel in alpine linux
###############################################################################
FROM alpine:3.11
LABEL maintainer="justin@duomai.com"

# TF <= v2.0 requires bazel v0.26.1
# TF >= v2.2 requires bazel v2.0.0

# To build different version, simply pass it on the command line using the flag:
# --build-arg BAZEL_VERSION=<value>
ARG BAZEL_VERSION
ARG BUILD_FROM_SCRATCH

ENV JAVA_HOME=/usr/lib/jvm/default-jvm/ \
    BAZEL_VERSION=${BAZEL_VERSION:-2.0.0} \
    BUILD_FROM_SCRATCH=${BUILD_FROM_SCRATCH:-true} \
    BAZEL_JAVAC_OPTS="-J-Xmx2g -J-Xms128m" \
    EXTRA_BAZEL_ARGS=--host_javabase=@local_jdk//:jdk \
    PYTHON_BIN_PATH=/usr/bin/python3 \
    BAZEL_DEPENDENCIES="bash libarchive openjdk8 zip unzip libgcc libstdc++" \
    BAZEL_BUILD_DEPENDENCIES="g++ git curl python3 linux-headers protoc"

# Build & Install Bazel
RUN set -ex \
    && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk update && apk upgrade \
    && apk add --no-cache ${BAZEL_DEPENDENCIES} ${BAZEL_BUILD_DEPENDENCIES} \
    #&& wget -q https://releases.bazel.build/${BAZEL_VERSION}/release/bazel-${BAZEL_VERSION}-dist.zip -O /tmp/bazel-${BAZEL_VERSION}-dist.zip \
    #&& wget -q https://releases.bazel.build/${BAZEL_VERSION}/release/bazel-${BAZEL_VERSION}-dist.zip.sha256 -O /tmp/bazel.sha256 \
    # Use curl for better progress bar
    && curl -SL# https://releases.bazel.build/${BAZEL_VERSION}/release/bazel-${BAZEL_VERSION}-dist.zip -o /tmp/bazel-${BAZEL_VERSION}-dist.zip \
    && curl -SL# https://releases.bazel.build/${BAZEL_VERSION}/release/bazel-${BAZEL_VERSION}-dist.zip.sha256 -o /tmp/bazel.sha256 \
    && cd /tmp && cat bazel.sha256 | sha256sum -c - \
    && mkdir bazel-src \
    && unzip -qd bazel-src bazel-${BAZEL_VERSION}-dist.zip \
    # Build Bazel
    && ln -s /usr/bin/python3 /usr/bin/python \
    && cd bazel-src && \
    if [ "${BUILD_FROM_SCRATCH}" = true ]; then \
        # Build Bazel from scratch (bootstrapping)
        bash compile.sh \
        && cp -p output/bazel /usr/bin/; \
    else \
        # Build Bazel using Bazel
        apk add --no-cache bazel --repository http://mirrors.aliyun.com/alpine/edge/testing/ \
        && bazel build //src:bazel --compilation_mode=opt \
        && apk del --purge bazel \
        && cp -p bazel-bin/src/bazel /usr/bin; \
    fi \
    # Done
    && bazel version \
    && apk del -q --purge ${BAZEL_BUILD_DEPENDENCIES} \
    && rm -rf /var/cache/apk/* /tmp/* /root/.cache/bazel

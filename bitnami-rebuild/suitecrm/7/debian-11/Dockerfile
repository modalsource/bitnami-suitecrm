# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

FROM docker.io/bitnami/minideb:bullseye

ARG TARGETARCH

LABEL com.vmware.cp.artifact.flavor="sha256:1e1b4657a77f0d47e9220f0c37b9bf7802581b93214fff7d1bd2364c8bf22e8e" \
      org.opencontainers.image.base.name="docker.io/bitnami/minideb:bullseye" \
      org.opencontainers.image.created="2024-02-02T18:25:41Z" \
      org.opencontainers.image.description="Application packaged by VMware, Inc" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.ref.name="7.14.2-debian-11-r10" \
      org.opencontainers.image.title="suitecrm" \
      org.opencontainers.image.vendor="VMware, Inc." \
      org.opencontainers.image.version="7.14.2"

ENV OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-11" \
    OS_NAME="linux"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
# REBUILD NOTE (not in the original Dockerfile): bullseye (Debian 11) hit end-of-LTS in 2026
# and its security pool has been retired, so live mirrors now 404. Pin apt to the Debian
# snapshot at the original build date (OCI label: 2024-02-02T18:25:41Z) to fetch the exact
# same package versions Bitnami used.
RUN echo 'Acquire::Check-Valid-Until "false"; Acquire::Retries "20"; Acquire::http::Timeout "120"; Acquire::https::Timeout "120";' > /etc/apt/apt.conf.d/99-snapshot ; \
    { \
      echo "deb http://snapshot.debian.org/archive/debian/20240202T180000Z bullseye main" ; \
      echo "deb http://snapshot.debian.org/archive/debian-security/20240202T180000Z bullseye-security main" ; \
    } > /etc/apt/sources.list ; \
    rm -f /etc/apt/sources.list.d/* ; true
# Install required system packages and dependencies
RUN install_packages acl ca-certificates cron curl libaudit1 libbrotli1 libbsd0 libbz2-1.0 libcap-ng0 libcom-err2 libcrypt1 libcurl4 libexpat1 libffi7 libfftw3-double3 libfontconfig1 libfreetype6 libgcc-s1 libgcrypt20 libglib2.0-0 libgmp10 libgnutls30 libgomp1 libgpg-error0 libgssapi-krb5-2 libhogweed6 libicu67 libidn2-0 libjpeg62-turbo libk5crypto3 libkeyutils1 libkrb5-3 libkrb5support0 liblcms2-2 libldap-2.4-2 liblqr-1-0 libltdl7 liblzma5 libmagickcore-6.q16-6 libmagickwand-6.q16-6 libmd0 libmemcached11 libncurses6 libnettle8 libnghttp2-14 libonig5 libp11-kit0 libpam0g libpcre2-8-0 libpcre3 libpng16-16 libpq5 libpsl5 libreadline8 librtmp1 libsasl2-2 libsodium23 libsqlite3-0 libssh2-1 libssl1.1 libstdc++6 libsybdb5 libtasn1-6 libtidy5deb1 libtinfo6 libunistring2 libuuid1 libwebp6 libx11-6 libxau6 libxcb1 libxdmcp6 libxext6 libxml2 libxslt1.1 libzip4 openssl procps zlib1g
# REBUILD NOTE (not in original): optional local Stacksmith cache. `pkg-cache/` may contain the
# `<component>-linux-<arch>-debian-11.tar.gz` + `.sha256` files; with them present the next RUN
# skips network downloads entirely (original Bitnami `if [ ! -f ... ]` logic). Populate it with
# ../fetch-pkg-cache.sh from the repo root. Required if `downloads.bitnami.com` returns 404 for
# the build containers (seen intermittently with BuildKit while plain containers get 200 OK).
COPY pkg-cache/ /tmp/bitnami/pkg/cache/
RUN mkdir -p /tmp/bitnami/pkg/cache/ ; cd /tmp/bitnami/pkg/cache/ ; \
    COMPONENTS=( \
      "render-template-1.0.6-7-linux-${OS_ARCH}-debian-11" \
      "php-8.1.27-3-linux-${OS_ARCH}-debian-11" \
      "apache-2.4.58-6-linux-${OS_ARCH}-debian-11" \
      "mysql-client-11.2.2-1-linux-${OS_ARCH}-debian-11" \
      "libphp-8.1.27-2-linux-${OS_ARCH}-debian-11" \
      "suitecrm-7.14.2-5-linux-${OS_ARCH}-debian-11" \
    ) ; \
    for COMPONENT in "${COMPONENTS[@]}"; do \
      if [ ! -f "${COMPONENT}.tar.gz" ]; then \
        curl -SsLf "https://downloads.bitnami.com/files/stacksmith/${COMPONENT}.tar.gz" -O ; \
        curl -SsLf "https://downloads.bitnami.com/files/stacksmith/${COMPONENT}.tar.gz.sha256" -O ; \
      fi ; \
      sha256sum -c "${COMPONENT}.tar.gz.sha256" ; \
      tar -zxf "${COMPONENT}.tar.gz" -C /opt/bitnami --strip-components=2 --no-same-owner --wildcards '*/files' ; \
      rm -rf "${COMPONENT}".tar.gz{,.sha256} ; \
    done
RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true
RUN sed -i -e '/pam_loginuid.so/ s/^#*/#/' /etc/pam.d/cron

COPY rootfs /
RUN /opt/bitnami/scripts/mysql-client/postunpack.sh
RUN /opt/bitnami/scripts/apache/postunpack.sh
RUN /opt/bitnami/scripts/php/postunpack.sh
RUN /opt/bitnami/scripts/apache-modphp/postunpack.sh
RUN /opt/bitnami/scripts/suitecrm/postunpack.sh
ENV APACHE_HTTPS_PORT_NUMBER="" \
    APACHE_HTTP_PORT_NUMBER="" \
    APP_VERSION="7.14.2" \
    BITNAMI_APP_NAME="suitecrm" \
    PATH="/opt/bitnami/common/bin:/opt/bitnami/php/bin:/opt/bitnami/php/sbin:/opt/bitnami/apache/bin:/opt/bitnami/mysql/bin:$PATH"

EXPOSE 8080 8443

ENTRYPOINT [ "/opt/bitnami/scripts/suitecrm/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/suitecrm/run.sh" ]

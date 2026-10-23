# Variante di bitnamilegacy/suitecrm:7.14.2-debian-11-r10 con PHP 8.2.35
#
# Strategia:
#   - Stage 1 ("builder"): compila PHP 8.2.35 da sorgente su Debian 11.
#     (niente binari precompilati: il repo Sury per bullseye ha 8.2.34 su arm64;
#      compilare garantisce la 8.2.35 esatta su amd64 e arm64)
#   - Stage 2: immagine originale Bitnami; il PHP 8.1 di Bitnami resta al suo
#     posto ma non viene più eseguito, mentre:
#       * /usr/local/php82/{bin/php,sbin/php-fpm} vengono collegati nei punti
#         PATH-aspettati da Bitnami (/opt/bitnami/php/bin) così TUTTI gli script
#         Bitnami (setup, cron, ecc.) continuano a usare il PHP 8.2;
#       * Apache smette di usare mod_php (libphp.so 8.1) e passa a
#         proxy_fcgi -> PHP-FPM 8.2 (modulo già caricato in httpd.conf,
#         vedi rootfs/opt/bitnami/apache/conf/bitnami/php.conf);
#       * PHP 8.2 è compilato con --with-config-file-path=/opt/bitnami/php/etc:
#         legge LO STESSO php.ini gestito a runtime dagli script Bitnami, quindi
#         le env PHP_MEMORY_LIMIT, PHP_DATE_TIMEZONE, PHP_ENABLE_OPCACHE, ecc.
#         continuano a funzionare.
#
# Build:   docker build -f php82/Dockerfile -t suitecrm:7.14.2-debian-11-r10-php8.2.35 php82
# Offline: ./fetch-php-src.sh prima della build (mette il tarball in ./src-cache/)
ARG PHP_VERSION=8.2.35
ARG BASE_IMAGE=bitnamilegacy/suitecrm:7.14.2-debian-11-r10

FROM debian:bullseye-slim AS builder

ARG PHP_VERSION

# bullseye è EOL: viene usato snapshot.debian.org pinnato al 02/02/2024
# (stesso timestamp del build Bitnami originale, vedi REBUILD.md): indice
# auto-consistente. La base slim di oggi ha runtime più nuovi (stato post-EOL
# di bullseye); nello stage temporaneo si accettano i downgrade verso lo stato
# dello snapshot per rispettare i Depends "=" dei pacchetti dev: gli artefatti
# finali non subiscono modifiche e ABI-coerenti con la runtime dell'immagine
# finale (stesso upstream).
RUN set -eux; \
    echo 'deb http://snapshot.debian.org/archive/debian/20240202T180000Z bullseye main' > /etc/apt/sources.list; \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99-archive; \
    apt-get -o Acquire::Retries=10 -o Acquire::http::Timeout=60 update; \
    # Le runtime della base slim sono allo stato post-EOL (u14/u8/u5); i dev
    # della snapshot esigono "=" al loro stato (u6/u1/u2): si pinnano
    # esplicitamente, apt effettua il downgrade a catena di tutto il resto.
    # (È uno stage temporaneo: gli artefatti finali restano ABI-coerenti con
    # le runtime più recenti dell'immagine Bitnami, stesso upstream.)
    apt-get -o Acquire::Retries=10 -o Acquire::http::Timeout=60 install -y \
        --no-install-recommends --allow-downgrades \
        libc6=2.31-13+deb11u6 \
        libssl1.1=1.1.1w-0+deb11u1 \
        perl-base=5.32.1-4+deb11u2 \
        build-essential pkg-config ca-certificates curl xz-utils \
        libssl-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev \
        libpng-dev libjpeg62-turbo-dev libfreetype6-dev libzip-dev \
        libxml2-dev libxslt1-dev libsqlite3-dev libreadline-dev \
        libgmp-dev libsodium-dev libldap2-dev libonig-dev libicu-dev \
        libtidy-dev; \
    rm -rf /var/lib/apt/lists/*

# Tarball: dalla cache locale (offline) oppure da php.net
COPY src-cache/ /src-cache/
RUN set -eux; \
    if [ -s "/src-cache/php-${PHP_VERSION}.tar.xz" ]; then \
        echo "Uso il tarball dalla cache locale"; \
    else \
        echo "Scarico il tarball da php.net..."; \
        curl -fSL --retry 5 --connect-timeout 20 \
            "https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz" \
            -o "/src-cache/php-${PHP_VERSION}.tar.xz"; \
    fi; \
    if [ ! -f "/src-cache/php-${PHP_VERSION}.tar.xz.sha256" ]; then \
        sha256sum "/src-cache/php-${PHP_VERSION}.tar.xz" \
            > "/src-cache/php-${PHP_VERSION}.tar.xz.sha256"; \
    fi; \
    cat "/src-cache/php-${PHP_VERSION}.tar.xz.sha256"; \
    cd /src-cache && sha256sum -c "php-${PHP_VERSION}.tar.xz.sha256"; \
    mkdir -p /tmp/php-src; \
    tar -xJf "/src-cache/php-${PHP_VERSION}.tar.xz" -C /tmp/php-src

WORKDIR "/tmp/php-src/php-${PHP_VERSION}"
RUN set -eux; \
    ./configure --prefix=/usr/local/php82 \
        --with-config-file-path=/opt/bitnami/php/etc \
        --with-config-file-scan-dir=/opt/bitnami/php/etc/conf.d \
        --with-openssl --with-zlib --enable-bcmath --with-bz2 --enable-calendar \
        --with-curl --enable-exif --enable-ftp --with-gettext --with-gmp \
        --enable-gd --with-jpeg --with-freetype \
        --with-ldap --enable-mbstring --enable-mysqlnd \
        --enable-intl --with-mysqli --with-pdo-mysql \
        --with-sqlite3 --with-pdo-sqlite \
        --enable-opcache --enable-pcntl --with-readline \
        --enable-soap --enable-sockets --with-sodium \
        --with-xsl --with-zip --with-tidy \
        --enable-fpm --with-fpm-user=daemon --with-fpm-group=daemon \
        --without-pear; \
    make -j"$(nproc)"; \
    make install

# ------------------------------------------------------------------------------
# Immagine Bitnami + integrazione PHP 8.2
# ------------------------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG PHP_VERSION=8.2.35
ENV PHP_VERSION="${PHP_VERSION}"

# 0) CVE-hardening (aggiunto 2026-10): bullseye è EOL dal 31/08/2026; i pacchetti
#    OS della base Bitnami (fermi a feb 2024) vengono portati all'ultimo stato
#    pubblicato della LTS (snapshot 31/08/2026), che include tutte le fix di
#    sicurezza fino a fine LTS. Elimina la gran parte dei CVE fixabili del layer
#    Debian (baseline Trivy: 1802 CVE, vedi bitnami-rebuild/logs/trivy-*).
#    Il PHP 8.2 del builder è linkato allo stesso upstream => ABI compatibile
#    (glibc è backward-compatible); le versioni runtime non scendono mai sotto
#    quelle viste dal builder.
RUN set -eux; \
    { \
      echo 'deb http://snapshot.debian.org/archive/debian/20260831T120000Z bullseye main'; \
      echo 'deb http://snapshot.debian.org/archive/debian-security/20260831T120000Z bullseye-security main'; \
    } > /etc/apt/sources.list; \
    echo 'Acquire::Check-Valid-Until "false"; Acquire::Retries "10"; Acquire::http::Timeout "120";' \
        > /etc/apt/apt.conf.d/99-archive; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Librerie runtime collegate dal PHP compilato. Sono già tutte presenti
# nell'immagine Bitnami (verificato: "0 newly installed"): qui si forza solo la
# garanzia di presenza/installazione con --no-upgrade, evitando di pescare i
# pacchetti da bullseye-security (404 post-EOL, vedi REBUILD.md). Le versioni in
# immagine e in builder (bullseye main) hanno lo stesso upstream => ABI coerente.
RUN set -eux; \
    echo 'deb http://deb.debian.org/debian bullseye main' > /etc/apt/sources.list; \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99-archive; \
    apt-get update; \
    apt-get install -y --no-install-recommends --no-upgrade \
        libbz2-1.0 libcurl4 libfreetype6 libgmp10 libjpeg62-turbo \
        libldap-2.4-2 libonig5 libpng16-16 libreadline8 libsodium23 \
        libsqlite3-0 libxslt1.1 libzip4 libicu67 libxml2 libssl1.1 \
        zlib1g libtidy5deb1; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# 0) copia dell'artefatto compilato dallo stage builder
COPY --from=builder /usr/local/php82 /usr/local/php82

# 1) I binari nei percorsi aspettati da Bitnami puntano ora a PHP 8.2
RUN set -eux; \
    rm -f /opt/bitnami/php/bin/php /opt/bitnami/php/bin/php-config /opt/bitnami/php/bin/phpize; \
    rm -f /opt/bitnami/php/sbin/php-fpm; \
    ln -s /usr/local/php82/bin/php        /opt/bitnami/php/bin/php; \
    ln -s /usr/local/php82/bin/php-config /opt/bitnami/php/bin/php-config; \
    ln -s /usr/local/php82/bin/phpize     /opt/bitnami/php/bin/phpize; \
    ln -s /usr/local/php82/sbin/php-fpm   /opt/bitnami/php/sbin/php-fpm

# 1-bis) Rimozione residui PHP 8.1 Bitnami, non più referenziati: extension_dir,
# phpize e Apache ora usano la 8.2 (mod_php commentato, conf.d vuoto, unica
# zend_extension = opcache risolta nella build 8.2). Restano: etc/ (php.ini
# condiviso), composer/pear/pecl/phar (tooling sul PHP attivo), var/logs/tmp
# (runtime FPM). Se servissero imagick/apcu/mongodb/xdebug con la 8.2 vanno
# ricompilati (pecl o --with-* nella configure).
RUN set -eux; \
    rm -f /opt/bitnami/apache/modules/libphp.so; \
    rm -f /opt/bitnami/php/bin/php-cgi /opt/bitnami/php/bin/phpdbg; \
    rm -rf /opt/bitnami/php/lib/php/extensions /opt/bitnami/php/lib/php/build /opt/bitnami/php/include; \
    /opt/bitnami/php/bin/php -v | head -1

# 2) Apache: niente mod_php (libphp.so 8.1) -> proxy_fcgi verso PHP-FPM 8.2
RUN sed -i 's|^LoadModule php_module .*|# mod_php PHP 8.1 disattivato: si usa PHP-FPM 8.2 via proxy_fcgi|' \
        /opt/bitnami/apache/conf/httpd.conf

# 3) Overlay: php.conf Apache, php82-fpm.conf, script di avvio
#    (struttura raft a specchio dell'albero bitnami: rootfs/opt/bitnami/...)
COPY rootfs/ /

# 4) Patch dell'entrypoint: accetta anche il run.sh della variante PHP 8.2
#    (così i setup Bitnami girano identici all'originale)
RUN set -eux; \
    sed -i 's#"$1" = "/opt/bitnami/scripts/nginx-php-fpm/run.sh"#& || "$1" = "/opt/bitnami/scripts/php82/run.sh"#' \
        /opt/bitnami/scripts/suitecrm/entrypoint.sh; \
    grep -q 'php82/run.sh' /opt/bitnami/scripts/suitecrm/entrypoint.sh; \
    # PHP-FPM 8.2 deve essere attivo PRIMA del setup Bitnami: il wizard di
    # installazione fa richieste HTTP ad Apache, che ora inoltra ad FPM.
    sed -i '/print_welcome_page/a . /opt/bitnami/scripts/php82/start-fpm.sh' \
        /opt/bitnami/scripts/suitecrm/entrypoint.sh; \
    grep -q 'start-fpm.sh' /opt/bitnami/scripts/suitecrm/entrypoint.sh; \
    chmod +x /opt/bitnami/scripts/php82/*.sh; \
    mkdir -p /opt/bitnami/php/etc/conf.d /opt/bitnami/php/var/run \
             /opt/bitnami/php/logs /opt/bitnami/php/tmp

# 3.5) Redirige extension_dir nel php.ini Bitnami verso le estensioni della
#      build 8.2 (la 8.1 puntiava a /opt/bitnami/php/lib/php/extensions e al
#      suo opcache.so con API 20210902 -> conflitto API con la 8.2).
RUN set -eux; \
    sed -i \
        -e 's|/opt/bitnami/php/lib/php/extensions|/usr/local/php82/lib/php/extensions/no-debug-non-zts-20220829|g' \
        /opt/bitnami/php/etc/php.ini /opt/bitnami/php/lib/php.ini; \
    grep -n 'extension_dir' /opt/bitnami/php/etc/php.ini

# 3.6) Certificato self-signed per localhost (httpd -t a build-time; a runtime
#      Bitnami mantenere i propri in /bitnami se montati)
COPY gen-cert.php /tmp/gen-cert.php
RUN set -eux; \
    mkdir -p /opt/bitnami/apache/conf/bitnami/certs; \
    php /tmp/gen-cert.php; \
    rm -f /tmp/gen-cert.php

# Sanity check: librerie risolte, moduli chiave, ini Bitnami, sintassi Apache
RUN set -eux; \
    for b in /opt/bitnami/php/bin/php /opt/bitnami/php/sbin/php-fpm; do \
        if ldd "$b" 2>&1 | grep -q 'not found'; then \
            echo "ERRORE: librerie mancanti per $b:" >&2; \
            ldd "$b" 2>&1 | grep 'not found' >&2; \
            exit 1; \
        fi; \
    done; \
    /opt/bitnami/php/bin/php -v | head -1; \
    php -i 2>/dev/null | grep 'Loaded Configuration File' | grep -q '/opt/bitnami/php/etc/php.ini'; \
    php -m | grep -qi opcache; \
    for mod in mysqli pdo_mysql curl gd mbstring zip intl sodium bcmath tidy; do \
        php -m | grep -q "^${mod}$"; \
    done; \
    /opt/bitnami/apache/bin/httpd -t

# 5) CMD: avvia FPM 8.2 e poi delega al run.sh Bitnami originale (cron+Apache)
#    L'ENTRYPOINT resta quello originale (patchato per riconoscere questo path).
CMD ["/opt/bitnami/scripts/php82/run.sh"]

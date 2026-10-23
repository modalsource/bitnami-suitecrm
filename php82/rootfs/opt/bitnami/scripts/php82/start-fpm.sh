#!/bin/bash
# Avvia PHP-FPM 8.2 e attende il socket. Sorgentato da php82/run.sh
# (richiede che liblog.sh sia già caricata: si usa la funzione info()).
FPM_BIN="/opt/bitnami/php/sbin/php-fpm"
FPM_CONF="/opt/bitnami/php/etc/php82-fpm.conf"
SOCK="/opt/bitnami/php/var/run/php82.sock"

# idempotente: se il socket esiste già non riavvia (sorgentato più volte)
if [ -S "$SOCK" ]; then
    info "** PHP-FPM ${PHP_VERSION} already running (skip) **"
    return 0 2>/dev/null || true
fi

if [ "$(id -u)" = "0" ]; then
    mkdir -p /opt/bitnami/php/var/run /opt/bitnami/php/logs /opt/bitnami/php/tmp
    chown -R daemon:daemon /opt/bitnami/php/var/run /opt/bitnami/php/logs /opt/bitnami/php/tmp 2>/dev/null || true
fi

info "** Starting PHP ${PHP_VERSION} (FPM) **"
"$FPM_BIN" --fpm-config "$FPM_CONF"

# Attende il socket (max 10s)
_ok=""
for _ in $(seq 1 100); do
    if [ -S "$SOCK" ]; then _ok=1; break; fi
    sleep 0.1
done
if [ -z "$_ok" ]; then
    echo "ERRORE: socket PHP-FPM 8.2 non creato: $SOCK" >&2
    exit 1
fi

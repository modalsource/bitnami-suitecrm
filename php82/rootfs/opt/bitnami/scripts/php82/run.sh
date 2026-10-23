#!/bin/bash
# run.sh della variante PHP 8.2: avvia FPM e poi delega al run.sh originale
# (cron + Apache in foreground). L'entrypoint originale riconosce questo path
# grazie alla patch nel Dockerfile, quindi esegue tutti i setup Bitnami come al solito.
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/php82/start-fpm.sh
exec /opt/bitnami/scripts/suitecrm/run.sh

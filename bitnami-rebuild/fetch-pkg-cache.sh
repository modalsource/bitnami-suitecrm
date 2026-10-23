#!/usr/bin/env bash
# Scarica in pkg-cache/ i pacchetti Stacksmith della release 7.14.2-debian-11-r10
# in modo che `docker build` NON dipenda da downloads.bitnami.com a build-time.
# Uso: ./fetch-pkg-cache.sh amd64|arm64   (default: arch nativa del Mac)
set -euo pipefail
pkg=$(dirname "$0")
cache="$pkg/suitecrm/7/debian-11/pkg-cache"
mkdir -p "$cache"
comps=(
  render-template-1.0.6-7
  php-8.1.27-3
  apache-2.4.58-6
  mysql-client-11.2.2-1
  libphp-8.1.27-2
  suitecrm-7.14.2-5
)
if [ $# -ge 1 ]; then
  arch="$1"
else
  a=$(uname -m)
  case "$a" in
    x86_64) arch=amd64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) echo "arch non gestita: $a (passa amd64|arm64)"; exit 1 ;;
  esac
fi
echo "Architettura target: $arch"
failed=0
for c in "${comps[@]}"; do
  f="${c}-linux-${arch}-debian-11"
  for ext in .tar.gz .tar.gz.sha256; do
    if [ -s "$cache/${f}${ext}" ]; then
      echo "skip (già presente) ${f}${ext}"
      continue
    fi
    if curl -fSL --retry 5 --connect-timeout 20 \
        "https://downloads.bitnami.com/files/stacksmith/${f}${ext}" \
        -o "$cache/${f}${ext}"; then
      echo "ok  ${f}${ext}"
    else
      echo "FAIL ${f}${ext}"
      failed=$((failed+1))
    fi
  done
done
if [ $failed -gt 0 ]; then
  echo "ATTENZIONE: $failed file non scaricati (riprove loop di risoluzione)."
  exit 1
fi
echo "Cache completa in $cache:"
du -sh "$cache"

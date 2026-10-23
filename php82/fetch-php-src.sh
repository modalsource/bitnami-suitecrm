#!/usr/bin/env bash
# Scarica in src-cache/ il tarball sorgente di PHP (necessario per il build
# offline della variante php82/Dockerfile).
# Uso: ./fetch-php-src.sh [versione-php]   (default: 8.2.35)
set -euo pipefail
dir="$(dirname "$0")"
cache="$dir/src-cache"
php_version="${1:-8.2.35}"
url="https://www.php.net/distributions/php-${php_version}.tar.xz"
tgz="${cache}/php-${php_version}.tar.xz"
sha="${cache}/php-${php_version}.tar.xz.sha256"

mkdir -p "$cache"

if [ -s "$tgz" ]; then
  echo "skip (già presente) $(basename "$tgz")"
else
  echo "Download ${url}"
  curl -fSL --retry 5 --connect-timeout 20 "$url" -o "$tgz"
fi

# Hash locale (TOFU: calcolato al primo fetch; il Dockerfile lo riverifica)
if [ ! -f "$sha" ]; then
  shasum -a 256 "$tgz" | awk '{print $1"  "$2}' > "$sha"
fi
echo "SHA256  $(cat "$sha")"
du -sh "$cache"

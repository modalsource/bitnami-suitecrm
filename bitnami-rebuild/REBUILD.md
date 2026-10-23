# Ricostruzione di `bitnami/suitecrm:7.14.2-debian-11-r10`

## Provenienza (dati verificati a oggi)

- Il componente è stato rimosso dal monorepo `bitnami/containers` con il commit
  `002ff798` — *"Deprecate suitecrm (#89081)"* del **17/12/2025**, ma la **git history è intatta**.
- Lo stato esatto dell'immagine `7.14.2-debian-11-r10` corrisponde al commit di release:
  **`4133792d3d4246b6b80a451e7bf1c74b9832a5f4`** — *"[bitnami/suitecrm] Release 7.14.2-debian-11-r10 (#56296)"* del **02/02/2024**.
- Da quel commit sono stati ricostruiti **76 file**: `Dockerfile`, `prebuildfs/` (16), `rootfs/` (55),
  `docker-compose.yml`, `tags-info.yaml`, più `README.md` e il compose a livello di componente.

Tutto il materiale della ricostruzione è nella cartella dedicata `bitnami-rebuild/`:

```
bitnami-rebuild/
├── REBUILD.md                          (questa guida)
├── fetch-pkg-cache.sh                  (scarica la cache Stacksmith per amd64/arm64)
├── dpkg-legacy.txt                     (inventario pacchetti dell'immagine originale)
├── logs/                               (log di build e download)
├── images/                             (archivi docker save dell'originale bitnamilegacy)
│   └── suitecrm-7.14.2-debian-11-r10.arm64.tar
└── suitecrm/                           (ricostruzione dal commit 4133792d, context = 7/debian-11/)
    ├── README.md
    ├── docker-compose.yml              (compose a livello componente, tag "7")
    └── 7/debian-11/
        ├── Dockerfile
        ├── docker-compose.yml          (compose dedicato alla 7.x)
        ├── tags-info.yaml              (rolling tag: 7, 7-debian-11, 7.14.2)
        ├── prebuildfs/                 (librerie bitnami + install_packages)
        ├── rootfs/                     (script e config Apache/PHP/SuiteCRM in /opt/bitnami)
        └── pkg-cache/                  (cache locale tarball Stacksmith)
```

Nota su `bitnamilegacy`: **non** contiene i Dockerfile (è un **namespace Docker Hub** dove Broadcom
ha spostato le immagini deprecate) — i Dockerfile si recuperano dalla git history come fatto qui.

## Come funziona la build

Il Dockerfile di Bitnami **non compila da sorgente**: monta `bitnami/minideb:bullseye`, installa le
librerie Debian via `install_packages` e scarica dall'**incubatore Stacksmith** di Bitnami
(`downloads.bitnami.com`) questi pacchetti precompilati:

| Componente     | Versione nel tag r10 |
|----------------|----------------------|
| render-template| 1.0.6-7             |
| php            | 8.1.27-3            |
| apache         | 2.4.58-6            |
| mysql-client   | 11.2.2-1            |
| libphp         | 8.1.27-2            |
| suitecrm       | 7.14.2-5            |

Ogni pacchetto è verificato con il relativo `.sha256` prima dell'estrazione in `/opt/bitnami`.

## Build

### Stato della build "dal vivo" oggi: si ferma ai tarball Stacksmith

⚠️ **Verificato 23/10/2026**: i tarball `.tar.gz` dei pacchetti Stacksmith NON sono più
scaricabili da `downloads.bitnami.com` — **GET 404 su tutte le versioni e entrambe le
architetture** (amd64/arm64); i piccoli `.sha256` e le richieste HEAD continuano a dare 200 per
cache CDN (risultato fallace). Il passo apt è risolvibile col pin snapshot (vedi sotto), ma
nell'ottica della buildричин Bitnami l'anello irrecuperabile è il `.tar.gz`: la build da solo
Dockerfile **non può completare** finché i tarball non ritornano online o vengono recuperati da
una fonte propria.

Strade operative:

1. **Riproduzione by-reference (consigliata; già eseguita in questo workspace)**: l'immagine
   originale è ancora su `bitnamilegacy` (manifest multi-arch, verificato):
   ```bash
   docker pull bitnamilegacy/suitecrm:7.14.2-debian-11-r10            # arch nativa del Mac
   docker pull bitnamilegacy/suitecrm:7.14.2-debian-11-r10 --platform linux/amd64
   docker save -o images/suitecrm-7.14.2-debian-11-r10.arm64.tar bitnamilegacy/suitecrm:7.14.2-debian-11-r10
   docker tag  bitnamilegacy/suitecrm:7.14.2-debian-11-r10 TUO-REGISTRY/suitecrm:7.14.2-debian-11-r10
   docker push TUO-REGISTRY/suitecrm:7.14.2-debian-11-r10
   ```
2. **Ricostruzione completa bit-for-bit**: persa (tarball rimossi da Broadcom). Una ricostruzione
   "ispirata" al Bitnami (compilando PHP/Apache/MariaDB upstream) non riprodurrebbe l'artefatto r10.

```bash
# build diretta (funziona di nuovo solo se i tarball tornano raggiungibili):
cd suitecrm/7/debian-11
docker build -t suitecrm:7.14.2-debian-11-r10 .
```

### Fix necessario rispetto al Dockerfile originale: mirror apt

Il Dockerfile originale montava e installava i pacchetti **live** da `deb.debian.org` +
`security.debian.org`. Oggi quell'impostazione **.erk non funziona più**: Debian 11 (bullseye) ha
chiudo il ciclo di LTS nel 2026 e i `.deb` di `bullseye-security` sono stati rimossi dal pool live
(nome file 404 su `security.debian.org`, ma presenti su `archive.debian.org`). E minideb non ha alcun
CA store, quindi il TLS verso snapshot non può partire per primo ("chicken and egg").

Nel Dockerfile ricostruito è stato quindi aggiunto un passo (highlight "REBUILD NOTE", assente
nell'originale) prima di `install_packages`:

- `Acquire::Check-Valid-Until "false"` (i Release snapshot sono storici) + retry/timeout generosi
- `/etc/apt/sources.list` riscritto verso **`http://snapshot.debian.org/archive/{debian,debian-security}/20240202T180000Z`**
  (HTTP: minideb non ha `ca-certificates` finché non lo installa lui stesso — via HTTP parte e gli
  snapshot URL restano in HTTP, verificato)
- timestamp pin = **02/02/2024 18:00 UTC**, immediatamente prima del build timestamp dell'originale
  (OCI label `org.opencontainers.image.created=2024-02-02T18:25:41Z`) → download degli stessi identici
  `.deb` che avevano le immagini buildate da Bitnami in quella data

Piano B alternativo (più recenti, meno "esatto"): puntare su `http://archive.debian.org/` (stato
finale post-EOL: include patch di sicurezza fino al 2026, ma le versioni differiscono leggermente
dall'originale r10).

### Cache locale Stacksmith (già impostata nel Dockerfile ricostruito)

`./fetch-pkg-cache.sh arm64|amd64` (in `bitnami-rebuild/`) scarica i tarball in `suitecrm/7/debian-11/pkg-cache/`;
il `.dockerignore` whitelist il context e il Dockerfile ricostruito contiene la `COPY pkg-cache/
/tmp/bitnami/pkg/cache/`, così il loop originale Bitnami (`if [ ! -f ... ]`) salta il download di
rete e verifica/estrae localmente — utile per build offline/CI. Oggi il CDN restituisce 404 sui
tarball, quindi la cache si può riempire solo se tornano online o provengono da una fonte propria.

## Run (docker compose)

Il compose originale punta a `bitnami/mariadb:11.2` e `bitnami/suitecrm:7`, che **non esistono più
sull'org `bitnami`**. Versioni corrette contro `bitnamilegacy` (le immagini ci sono ancora):

```yaml
version: '2'
services:
  mariadb:
    image: docker.io/bitnamilegacy/mariadb:11.2-debian-11
    environment:
      - ALLOW_EMPTY_PASSWORD=yes          # solo per sviluppo! in prod: MARIADB_ROOT_PASSWORD + user/password
      - MARIADB_USER=bn_suitecrm
      - MARIADB_DATABASE=bitnami_suitecrm
      - MARIADB_PASSWORD=bitnami123
    volumes:
      - 'mariadb_data:/bitnami/mariadb'
  suitecrm:
    image: suitecrm:7.14.2-debian-11-r10   # la tua immagine ricostruita
    ports:
      - '80:8080'
      - '443:8443'
    environment:
      - SUITECRM_DATABASE_HOST=mariadb
      - SUITECRM_DATABASE_PORT_NUMBER=3306
      - SUITECRM_DATABASE_USER=bn_suitecrm
      - SUITECRM_DATABASE_NAME=bitnami_suitecrm
      - SUITECRM_DATABASE_PASSWORD=bitnami123
      - ALLOW_EMPTY_PASSWORD=yes
    volumes:
      - 'suitecrm_data:/bitnami/suitecrm'
    depends_on:
      - mariadb
volumes:
  mariadb_data:
  suitecrm_data:
```

## Alternativa senza build: immagine originale ancora scaricabile

Il tag originale è ancora pubblicato su `bitnamilegacy` (verificato: 1 manifest disponibile):

```bash
docker pull bitnamilegacy/suitecrm:7.14.2-debian-11-r10
docker tag  bitnamilegacy/suitecrm:7.14.2-debian-11-r10 tuo-registry/suitecrm:7.14.2-debian-11-r10
docker push tuo-registry/suitecrm:7.14.2-debian-11-r10
# oppure archivialo localmente:
docker save -o images/suitecrm-7.14.2-debian-11-r10.arm64.tar bitnamilegacy/suitecrm:7.14.2-debian-11-r10
```

⚠️ `bitnamilegacy` non riceve aggiornamenti: archivialo con `docker save`/push nel tuo registry
prima che Broadcom lo faccia sparire.

## Note

- Licenze: Dockerfile e script Bitnami = Apache-2.0; SuiteCRM = AGPL-3 (a monte, `salesagility/SuiteCRM`).
- La r10 (02/02/2024) serve SuiteCRM 7.14.2 con stack PHP 8.1.27 / Apache 2.4.58 / MariaDB-client 11.2.2.
  Eventuali CVE di quell'epoca restano presenti nella ricostruzione; se vuoi la linea corretta,
  considera i tag successivi `7.14.3-debian-11-r0..r15` (commit release `b36cdfea`→`381a4bee`, febbraio 2024)
  ricostruibili con lo stesso metodo cambiando solo il commit di riferimento.
- SuiteCRM 7.14.x è la linea legacy; SuiteCRM 8.x è la versione corrente a monte.

---

## Variante con PHP 8.2.35 (aggiunta 23/10/2026)

Directory **`php82/`**: Dockerfile che dipende da `bitnamilegacy/suitecrm:7.14.2-debian-11-r10`
e sostituisce PHP 8.1.27 con **PHP 8.2.35**.

### Architettura della variante

| Punto | Decisione | Motivo |
|---|---|---|
| Sorgente PHP | compilazione da `php-8.2.35.tar.xz` | il repo Sury per bullseye si ferma a 8.2.34 su arm64; compilare garantisce la 8.2.35 esatta su amd64 **e** arm64 |
| Installazione | `/usr/local/php82` + symlink in `/opt/bitnami/php/{bin,sbin}` | tutti gli script Bitnami (setup, wizard, cron) continuano a usare `php` dal PATH, ora → 8.2 |
| php.ini | resta quello Bitnami (`/opt/bitnami/php/etc/php.ini`, `extension_dir` riscritto via sed) | gli override runtime (`PHP_MEMORY_LIMIT`, `PHP_DATE_TIMEZONE`, `PHP_ENABLE_OPCACHE`, ...) continuano a funzionare via `php_initialize` |
| Apache | mod_php 8.1 disattivato; `SetHandler proxy:unix:...php82.sock` via `mod_proxy_fcgi` (già caricato in httpd.conf) | il `libphp.so` 8.1 non è compatibile; FPM 8.2 è la strada pulita |
| Pool FPM | user `daemon` (come l'httpd Bitnami), socket Unix, `pm ondemand` | stessa semantica del pool Bitnami; ownership app già `daemon` |
| Entry flow | FPM avviato **prima** dei setup (hook dopo `print_welcome_page` nell'entrypoint) | il wizard d'installazione fa richieste HTTP ad Apache → servono FPM vivo; avvio idempotente (`php82/run.sh` poi esegue il `run.sh` originale: cron + Apache foreground) |
| apt del builder | snapshot.debian.org pinnato a `20240202T180000Z` + `--allow-downgrades` e pin espliciti di `libc6`/`libssl1.1`/`perl-base` | bullseye-security → 404 post-EOL; indice live incoerente con la base slim |
| apt runtime | solo `--no-upgrade` | le librerie runtime sono già presenti nell'immagine (0 nuove) |
| Certificati | self-signed localhost generato in build via PHP | serve ad `httpd -t` (Bitnami genera i propri a runtime) |

### Moduli PHP: parità con la build Bitnami 8.1

Confronto `php -m`: **identica lista** + `random` (modulo sempre presente in PHP 8.2, non selezionabile). L'unico requisito mancante era `imap` — mancante anche nell'originale Bitnami.

### Build e run

```bash
# tarball sorgente in cache locale (consigliato, build ripetibile/offline):
./php82/fetch-php-src.sh                       # → php82/src-cache/php-8.2.35.tar.xz
# build (cache del builder: ~1-2 min alle build successive):
docker build -f php82/Dockerfile -t suitecrm:7.14.2-debian-11-r10-php8.2.35 php82
# stack completo (mariadb 11.2 legacy + suitecrm php8.2), porto 8080/8443:
docker compose -f php82/docker-compose.yml -p suitecrm82 up -d
```

### Test E2E eseguiti (23/10/2026, arm64) — tutti passati

- build con sanity check: `PHP 8.2.35 (cli)`, `httpd -t → Syntax OK`, ldd pulito
- bootstrap: wizard installato con successo ("** SuiteCRM setup finished! **"), FPM attivo, cron + Apache foreground
- HTTP: `/` → 301 → login `Bitnami SuiteCRM`; **pagina di test via FPM: `PHP 8.2.35`**
- DB: 222 tabelle create in `bitnami_suitecrm`
- login `user`/`bitnami` (default Bitnami) → dashboard `Home » Bitnami SuiteCRM` con sessione valida

### Limiti / note

- SuiteCRM **7.14.2 non è certificato ufficialmente per PHP 8.2**: l'installer mostra warning deprecazione (`Undefined array key ...`) nei log, non bloccanti (identici comportamenti noti della serie 7.x su 8.2). Un'eventuale migrazione di versione PHP 8.2 ufficiale arriva con i tag successivi della serie 7.14.
- OpCache resta disattivato di default come nell'originale (abilitabile con `PHP_ENABLE_OPCACHE=1`).
- Il PHP 8.1 Bitnami resta su disco (non più invocato); gli artefatti compilati linkano runtime di upstream compatibili (verificato con `ldd`).
- Il builder scarica lo snapshot pinnato e il tarball php.net alla prima build: per la build offline, usare `fetch-php-src.sh`.

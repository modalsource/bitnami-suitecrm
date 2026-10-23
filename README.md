# bitnami-suitecrm

Workspace per la sopravvivenza dell'immagine **`bitnami/suitecrm:7.14.2-debian-11-r10`**
(rimossa dall'org `bitnami` su Docker Hub il 17/12/2025 con la deprecazione Broadcom).

## Contenuto

| Cartella | Cos'è |
|----------|-------|
| [`bitnami-rebuild/`](bitnami-rebuild/) | Ricostruzione dell'immagine: sorgenti originali recuperati dalla git history di `bitnami/containers` (commit di release `4133792d`), guida completa in [`bitnami-rebuild/REBUILD.md`](bitnami-rebuild/REBUILD.md), archivio `docker save` dell'originale in `images/` |
| [`php82/`](php82/) | Variante locale: PHP 8.2.35 compilato da sorgente sopra l'immagine originale Bitnami |

## Situazione in breve (23/10/2026)

- **L'immagine originale esiste ancora**: `bitnamilegacy/suitecrm:7.14.2-debian-11-r10`
  (multi-arch amd64/arm64) — ma `bitnamilegacy` non riceve aggiornamenti: salvarla
  (`docker save`) e/o pusharla nel proprio registry è urgente.
- **I Dockerfile Bitnami si recuperano dalla git history** del monorepo `bitnami/containers`
  (path originale: `bitnami/suitecrm/7/debian-11/`) — non da `bitnamilegacy`, che è solo un
  namespace Docker Hub.
- **La build bit-for-bit non è più reiterabile**: Broadcom ha eliminato i tarball Stacksmith
  da `downloads.bitnami.com` (GET 404 per ogni versione/arch). Il Dockerfile ricostruito resta
  valido e documentato; il passo apt (bullseye post-LTS) è già fixato con pin su
  `snapshot.debian.org`.

## Comandi rapidi

```bash
# usare l'immagine originale (già archiviata in bitnami-rebuild/images/):
docker load -i bitnami-rebuild/images/suitecrm-7.14.2-debian-11-r10.arm64.tar

# stack completo (SuiteCRM + MariaDB legacy):
docker compose -f bitnami-rebuild/suitecrm/7/debian-11/docker-compose.yml up -d
# (sostituire i tag `bitnami/...` con `bitnamilegacy/...` come da REBUILD.md)

# variante PHP 8.2:
docker compose -f php82/docker-compose.yml up -d --build
```

Per dettagli, diagnosi e workaround: **[`bitnami-rebuild/REBUILD.md`](bitnami-rebuild/REBUILD.md)**.

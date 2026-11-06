# Nautilus — gestionnaire de fichiers

> Mise à jour : 2026-11-04 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-04 — paquets relus contre `manifests/packages-nautilus.txt` et `manifests/packages-nautilus-optional.txt`, réglages contre `config/gnome.conf` et `config/performance.conf` — matériel : non vérifié

> Fait partie du bureau GNOME du projet : vue d'ensemble dans [`GNOME.md`](GNOME.md).

## Objectif

Nautilus reste le gestionnaire de fichiers GNOME natif. Le projet complète volontairement l'installation Fedora sans remplacer Files, sans ajouter un fork et sans dépendre d'extensions Python non nécessaires.

Le contrat vise quatre propriétés :

1. navigation locale rapide ;
2. accès distant et périphériques complet ;
3. previews et archives intégrés ;
4. comportement mesurable et certifiable.

## Paquets installés

Le manifeste [`../manifests/packages-nautilus.txt`](../manifests/packages-nautilus.txt) installe :

- `nautilus` ;
- `gvfs` ;
- `gvfs-gphoto2` pour les appareils photo ;
- `gvfs-fuse` pour l'exposition FUSE des montages GIO ;
- `localsearch` pour l'indexation et la recherche de fichiers ;
- `gvfs-afc` pour les appareils Apple/AFC ;
- `gvfs-goa` pour l'intégration des services de fichiers GNOME Online Accounts lorsqu'un compte est configuré ;
- `gvfs-nfs` pour les partages NFS ;
- `sushi` pour l'aperçu rapide ;
- `file-roller` et `file-roller-nautilus` pour ouvrir et extraire les archives depuis Files.

Les backends `gvfs-smb` et `gvfs-mtp` sont validés par [`../manifests/packages-nautilus-optional.txt`](../manifests/packages-nautilus-optional.txt) puis installés selon les flags versionnés :

```text
NAUTILUS_ENABLE_SMB=true
NAUTILUS_ENABLE_MTP=true
```

Les deux sont activés par défaut (`config/gnome.conf`).

## Miniatures

La politique reste :

```text
NAUTILUS_ENABLE_PREVIEWS=true
NAUTILUS_PREVIEW_POLICY=local-only
```

`local-only` conserve les miniatures utiles sur les NVMe locaux tout en évitant qu'un partage réseau ou un périphérique lent pénalise le premier affichage.

Si `NAUTILUS_ENABLE_PREVIEWS=false`, le module converge explicitement `show-image-thumbnails` vers `never`.

`ffmpegthumbnailer` est géré par le socle multimédia et complète les miniatures vidéo.

## Archives et aperçu rapide

`file-roller-nautilus` fournit l'extension native de File Roller pour ouvrir et extraire les archives prises en charge.

`Sushi` est l'outil d'aperçu de référence de GNOME. Son paquet est obligatoire ; aucune extension Nautilus tierce n'est nécessaire pour cette fonction.

## Appareils et accès distants

Le profil couvre :

- SMB pour les NAS configurés personnellement ;
- SFTP via GVfs pour la VM Rocky Linux et les serveurs SSH ;
- MTP pour les appareils mobiles compatibles ;
- GPhoto2 pour les appareils photo ;
- AFC + `libimobiledevice`/`ifuse` pour les appareils Apple ;
- NFS ;
- services de fichiers exposés par GNOME Online Accounts.

Les raccourcis VM gérés sont documentés dans [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md).

## Démarrage à froid

`fedora-gnome-nautilus-prewarm.service` préchauffe uniquement les portails et GIO. Il ne démarre jamais Nautilus : la première ouverture de Fichiers reste donc une vraie mesure de démarrage à froid.

```bash
./diagnostics/nautilus-coldstart-doctor
```

La cible (1200 ms) et la limite (2000 ms) sont définies dans `config/performance.conf`.

## Contrôle d'intégration

Le contrôle fonctionnel distinct est :

```bash
./diagnostics/nautilus-integration-doctor
```

Il vérifie notamment :

- tous les paquets du profil et les backends activés ;
- le payload `file-roller-nautilus` ;
- l'énumération GIO ;
- la politique de miniatures réellement appliquée ;
- le script et le service utilisateur de préchauffage ;
- le dossier XDG Desktop lorsque disponible.

Ce contrôle fait partie de `workstation-doctor`, du postcheck du module Nautilus et de la certification finale sur le PC. La mesure du démarrage à froid reste une preuve séparée, pour ne pas confondre fonctionnement et latence.

## Hors profil

- `nautilus-python` : non installé tant qu'aucune extension Python indispensable n'est versionnée et testée ;
- AFP : non requis pour le périmètre actuel ;
- montage automatique de comptes cloud : le backend GOA est présent, mais aucun compte utilisateur n'est créé automatiquement ;
- pré-démarrage de Nautilus : interdit, car il fausserait la mesure du démarrage à froid.

## Dépannage

Commencer par :

```bash
./diagnostics/nautilus-integration-doctor
./diagnostics/nautilus-coldstart-doctor
```

Puis consulter [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) avant de modifier GVfs, portals, SELinux ou les services de session.

Pour Fedora 45, `gvfs-archive` n'est plus fourni (backend supprimé/désactivé en amont). Le profil utilise File Roller et son extension Nautilus pour ouvrir et extraire les archives ; il ne promet pas l'ancien montage GIO des archives. Voir le [changelog Fedora GVfs](https://packages.fedoraproject.org/pkgs/gvfs/gvfs/fedora-45.html).

# Nautilus — profil Golden complet

La version applicable est celle de [`../VERSION`](../VERSION).

## Objectif

Nautilus reste le gestionnaire de fichiers GNOME natif. Le projet complète volontairement l'installation Fedora sans remplacer Files, sans ajouter un fork et sans dépendre d'extensions Python non nécessaires.

Le contrat vise quatre propriétés :

1. navigation locale rapide ;
2. accès distant et périphériques complet ;
3. previews et archives intégrés ;
4. comportement mesurable et certifiable.

## Paquets Golden

Le manifeste [`../manifests/packages-nautilus.txt`](../manifests/packages-nautilus.txt) installe :

- `nautilus` ;
- `gvfs` ;
- `gvfs-gphoto2` pour les appareils photo ;
- `gvfs-fuse` pour l'exposition FUSE des montages GIO ;
- `gvfs-archive` pour ZIP/TAR/ISO ;
- `gvfs-afc` pour les appareils Apple/AFC ;
- `gvfs-goa` pour l'intégration des services de fichiers GNOME Online Accounts lorsqu'un compte est configuré ;
- `gvfs-nfs` pour les partages NFS ;
- `sushi` pour l'aperçu rapide ;
- `file-roller-nautilus` pour les actions d'archives dans Files.

Les backends `gvfs-smb` et `gvfs-mtp` sont validés par [`../manifests/packages-nautilus-optional.txt`](../manifests/packages-nautilus-optional.txt) puis installés selon les flags versionnés :

```text
NAUTILUS_ENABLE_SMB=true
NAUTILUS_ENABLE_MTP=true
```

Ils sont activés dans le profil Golden courant.

## Previews

La politique reste :

```text
NAUTILUS_ENABLE_PREVIEWS=true
NAUTILUS_PREVIEW_POLICY=local-only
```

`local-only` conserve les miniatures utiles sur les NVMe locaux tout en évitant qu'un partage réseau ou un périphérique lent pénalise le premier affichage.

Si `NAUTILUS_ENABLE_PREVIEWS=false`, le module converge explicitement `show-image-thumbnails` vers `never`.

`ffmpegthumbnailer` est géré par le socle multimédia et complète les miniatures vidéo.

## Archives et aperçu rapide

`file-roller-nautilus` fournit l'extension Nautilus native de File Roller et `gvfs-archive` permet l'accès GIO aux archives prises en charge.

`Sushi` est le previewer GNOME de référence. Son paquet est obligatoire dans le Golden ; aucune extension Nautilus tierce n'est nécessaire pour cette fonction.

## Appareils et accès distants

Le profil couvre :

- SMB pour Windows/NAS ;
- SFTP via GVfs pour la VM Ubuntu et les serveurs SSH ;
- MTP pour les appareils mobiles compatibles ;
- GPhoto2 pour les appareils photo ;
- AFC + `libimobiledevice`/`ifuse` pour les appareils Apple ;
- NFS ;
- services de fichiers exposés par GNOME Online Accounts.

Les raccourcis VM gérés sont documentés dans [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md).

## Cold start

`fedora-gnome-nautilus-prewarm.service` préchauffe uniquement Portal/GIO. Il ne démarre jamais Nautilus : la première ouverture de Files reste donc une vraie mesure cold-start.

```bash
./diagnostics/nautilus-coldstart-doctor
```

La cible et la limite dure restent définies dans `config/performance.conf`.

## Doctor d'intégration

Le contrôle fonctionnel distinct est :

```bash
./diagnostics/nautilus-integration-doctor
```

Il vérifie notamment :

- tous les paquets Golden et les backends activés ;
- le payload `file-roller-nautilus` ;
- l'énumération GIO ;
- la politique de miniatures réellement appliquée ;
- le helper et le service user de prewarm ;
- le dossier XDG Desktop lorsque disponible.

Le doctor d'intégration fait partie du `workstation-doctor`, du postcheck du module Nautilus et de la certification bare-metal finale. La performance cold-start reste une preuve séparée afin de ne pas confondre fonctionnalité et latence.

## Ce qui reste volontairement hors du Golden

- `nautilus-python` : non installé tant qu'aucune extension Python indispensable n'est versionnée et testée ;
- AFP : non requis pour le périmètre actuel ;
- montage automatique de comptes cloud : le backend GOA est présent, mais aucun compte utilisateur n'est créé automatiquement ;
- pré-démarrage de Nautilus : interdit, car il fausserait la mesure cold-start.

## Dépannage

Commencer par :

```bash
./diagnostics/nautilus-integration-doctor
./diagnostics/nautilus-coldstart-doctor
```

Puis consulter [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) avant de modifier GVfs, portals, SELinux ou les services de session.

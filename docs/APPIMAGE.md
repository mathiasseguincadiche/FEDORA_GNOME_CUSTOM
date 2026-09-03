# AppImage — compatibilité complète Fedora 44

## Objectif

Le HOST Golden prend en charge les AppImages **actuels et anciens** sans remplacer le kernel Fedora, sans désactiver SELinux et sans installer de pile graphique tierce.

Le contrat couvre :

- AppImage **Type 2** actuel, basé sur SquashFS ;
- AppImage **Type 1** historique/legacy, basé sur ISO9660 ;
- runtimes x86_64 ;
- anciens runtimes 32 bits i686 lorsque leur architecture reste exécutable sur le HOST x86_64 ;
- FUSE 2, encore utilisé par de nombreux runtimes AppImage ;
- FUSE 3 en coexistence avec FUSE 2 ;
- exécution sans FUSE via mécanismes d'extraction de secours ;
- intégration GNOME via Gear Lever.

## Paquets Fedora

`manifests/packages-appimage.txt` installe :

- `fuse`, `fuse-libs.x86_64`, `fuse-libs.i686` ;
- `fuse3`, `fuse3-libs.x86_64`, `fuse3-libs.i686` ;
- `bsdtar` pour inspecter/extraire les images Type 1 ISO9660 ;
- `squashfs-tools` pour le payload SquashFS Type 2 ;
- `file`, `desktop-file-utils`, `shared-mime-info`, `xdg-utils` pour inspection et intégration desktop.

FUSE 2 et FUSE 3 restent installés côte à côte. Le profil ne remplace pas FUSE 3 par FUSE 2.

## Commande de compatibilité

Le module installe :

```bash
/usr/local/bin/appimage-run
```

Identification sans exécution :

```bash
appimage-run --identify MonApplication.AppImage
```

Résultats possibles :

```text
type1
type2
not-appimage
```

Exécution :

```bash
appimage-run MonApplication.AppImage
```

La commande ajoute le bit exécutable utilisateur si nécessaire.

### Type 2

Lorsque `/dev/fuse` est disponible, le runtime AppImage est exécuté normalement.

Si FUSE n'est pas exposé, le runner utilise :

```text
APPIMAGE_EXTRACT_AND_RUN=1
```

Il s'agit du fallback prévu par les runtimes Type 2 qui le supportent. Les très anciens Type 2 qui ne proposent pas ce mécanisme peuvent toujours être extraits manuellement avec `--appimage-extract` puis exécutés via `squashfs-root/AppRun`.

### Type 1 legacy

Lorsque FUSE est disponible, l'image est lancée normalement.

Sans FUSE, `appimage-run` extrait l'image ISO9660 dans un répertoire temporaire privé avec `bsdtar`, exécute `AppRun`, puis supprime le répertoire temporaire.

## Intégration GNOME

Le profil installe également **Gear Lever** depuis Flathub :

```text
it.mijorus.gearlever
```

Gear Lever sert à :

- ranger les AppImages dans un emplacement géré ;
- créer les entrées `.desktop` ;
- exposer icônes et métadonnées dans GNOME ;
- mettre à jour une AppImage lorsque le fournisseur expose un mécanisme compatible ;
- conserver plusieurs versions si nécessaire.

Gear Lever améliore l'intégration desktop mais n'est pas le runtime de compatibilité : un AppImage reste exécutable via `appimage-run` même sans Gear Lever.

## Sécurité

Une AppImage est du code natif fourni par un tiers. Le fait que le fichier soit portable ne constitue **aucune sandbox**.

Règles Golden :

1. télécharger uniquement depuis la source officielle du logiciel ;
2. vérifier checksum/signature lorsqu'ils sont publiés ;
3. ne jamais exécuter une AppImage inconnue en root ;
4. ne jamais désactiver SELinux pour faire fonctionner une AppImage ;
5. ne jamais appliquer `chmod 777` ;
6. préférer RPM Fedora/éditeur ou Flatpak vérifié lorsqu'ils offrent le même logiciel avec une chaîne de mise à jour mieux intégrée ;
7. utiliser `appimage-run --identify` pour identifier le format sans exécuter le payload.

## Doctor

```bash
./diagnostics/appimage-doctor
```

Le doctor vérifie :

- FUSE 2 x86_64/i686 ;
- FUSE 3 x86_64/i686 ;
- `fusermount` et `fusermount3` ;
- `bsdtar` et `unsquashfs` ;
- intégration XDG/desktop ;
- `appimage-run` ;
- Gear Lever si Flathub est activé ;
- `/dev/fuse` sur bare metal ;
- détection synthétique Type 1 et Type 2 sans lancement d'un binaire tiers.

L'absence de `/dev/fuse` dans un conteneur ou certaines VM est un avertissement et non une preuve de panne bare-metal.

## CI Fedora 44

Le workflow `Fedora 44 AppImage compatibility pretest` vérifie :

- résolution de tous les RPM sur Fedora 44 ;
- installation simultanée FUSE 2/FUSE 3 et multilib ;
- disponibilité des extracteurs Type 1/Type 2 ;
- reconnaissance des marqueurs Type 1 (`AI\\x01`) et Type 2 (`AI\\x02`) ;
- présence de Gear Lever sur Flathub ;
- contrat statique du projet.

La CI **n'exécute aucun AppImage téléchargé depuis Internet**. La compatibilité d'une application AppImage particulière reste dépendante de son propre packaging, de son architecture et de ses dépendances externes éventuelles.

## Limites réelles de « prise en charge totale »

Le système fournit toutes les briques génériques raisonnables pour exécuter les formats AppImage Type 1 et Type 2 sur Fedora 44. Il ne peut toutefois pas garantir qu'un binaire arbitraire datant de plusieurs décennies fonctionnera si celui-ci dépend d'un ABI retiré, d'un pilote propriétaire obsolète, d'une architecture CPU non supportée ou d'un comportement incompatible avec un kernel moderne.

Dans ce cas, le problème appartient au payload spécifique, pas au socle AppImage Golden.

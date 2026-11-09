# AppImage — compatibilité sur Fedora 45

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — paquets, runner et doctor relus contre `manifests/packages-appimage.txt` et `manifests/flatpaks-appimage.txt`, CI contre `fedora-appimage-pretest.yml` — matériel : non vérifié

## Objectif

L'hôte prend en charge les AppImage **actuelles et anciennes** sans remplacer le noyau Fedora, sans désactiver SELinux et sans installer de pile graphique tierce.

Le contrat couvre :

- AppImage **Type 2** actuel, basé sur SquashFS ;
- AppImage **Type 1** historique/legacy, basé sur ISO9660 ;
- runtimes x86_64 ;
- anciens runtimes 32 bits i686 lorsque leur architecture reste exécutable sur l'hôte x86_64 ;
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

Le module installe **le fichier exécutable** suivant (ce chemin n'est pas une commande à lancer sans argument) :

```text
/usr/local/bin/appimage-run
```

Depuis un terminal Fedora, après l'APPLY, se placer dans le dossier contenant une AppImage issue d'une source de confiance. Dans les exemples suivants, remplacer `MonApplication.AppImage` par son véritable nom ; le préfixe `./` indique que le fichier se trouve dans le dossier courant. Ne pas exécuter un fichier inconnu.

Identification sans exécution :

```bash
appimage-run --identify ./MonApplication.AppImage
```

Résultats possibles :

```text
type1
type2
not-appimage
```

`type1` ou `type2` indique que le marqueur du format est reconnu, **pas** que le programme est authentique. `not-appimage` renvoie un code de sortie non nul ; un fichier absent ou illisible renvoie `invalid` avec un échec. Cette identification n'exécute pas le programme.

Exécution :

```bash
appimage-run ./MonApplication.AppImage
```

**Attention :** cette commande exécute réellement le logiciel tiers avec les droits du compte utilisateur et ajoute le bit exécutable utilisateur au fichier si nécessaire. Passer par `--identify` ne dispense pas de vérifier la provenance, ainsi que l'empreinte ou la signature lorsqu'elles sont publiées.

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

Si l'installation des Flatpak professionnels via Flathub est activée, le profil installe également **Gear Lever** :

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

Règles du projet :

1. télécharger uniquement depuis la source officielle du logiciel ;
2. vérifier checksum/signature lorsqu'ils sont publiés ;
3. ne jamais exécuter une AppImage inconnue en root ;
4. ne jamais désactiver SELinux pour faire fonctionner une AppImage ;
5. ne jamais appliquer `chmod 777` ;
6. préférer RPM Fedora/éditeur ou Flatpak vérifié lorsqu'ils offrent le même logiciel avec une chaîne de mise à jour mieux intégrée ;
7. utiliser `appimage-run --identify` pour identifier le format sans exécuter le payload.

## Contrôles

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

L'absence de `/dev/fuse` dans un conteneur ou certaines VM est un avertissement et non une preuve de panne du matériel physique.

**Résultat attendu sur Fedora installé :** zéro `KO`, puis `APPIMAGE COMPATIBILITY HEALTHY` / `TYPE 1 + TYPE 2 READY`. Le doctor crée deux petits fichiers de test temporaires et les supprime ; il ne lance aucune AppImage tierce. Un `WARN` sur FUSE dans une VM ne certifie pas FUSE sur le PC.

### Si le contrôle ou une AppImage échoue

| Signal observé | Vérifier d'abord | Suite prudente |
|---|---|---|
| `Package ... missing`, outil d'extraction absent ou `Compatibility runner ... missing` | Les manifestes et le journal d'APPLY | Corriger l'installation gérée et relancer le doctor ; ne pas installer un runtime aléatoire. |
| `/dev/fuse` absent sur le PC | La présence du périphérique et les journaux du noyau | Diagnostiquer le pilote et les permissions, sans désactiver SELinux ni appliquer `chmod 777`. |
| `not-appimage` ou `invalid` | Nom, lisibilité, architecture, provenance et empreinte du fichier | Reprendre le téléchargement depuis la source officielle et vérifier l'artefact ; ne pas forcer son exécution. |
| Type 2 sans FUSE ou Type 1 sans FUSE | La possibilité d'extraction prévue par le runtime et les messages du runner | Consulter les alternatives décrites ci-dessus ; certaines AppImages anciennes ne les prennent pas en charge. |
| Gear Lever absent | L'activation effective de Flathub et des Flatpak professionnels | Distinguer l'intégration GNOME du runtime CLI, puis suivre le profil d'installation. |

Pour confirmer le cas d'une **application particulière**, essayer une AppImage officielle vérifiée sur le PC, observer l'ouverture puis la fermeture et consigner le résultat dans la [Gate 3](QUALIFICATION.md). Un doctor vert ne valide pas tous les binaires AppImage existants.

## CI Fedora 45

Le workflow `Fedora 45 AppImage compatibility pretest` vérifie :

- résolution de tous les RPM sur Fedora 45 ;
- installation simultanée FUSE 2/FUSE 3 et multilib ;
- disponibilité des extracteurs Type 1/Type 2 ;
- reconnaissance des marqueurs Type 1 (`AI\\x01`) et Type 2 (`AI\\x02`) ;
- présence de Gear Lever sur Flathub ;
- contrat statique du projet.

La CI **n'exécute aucun AppImage téléchargé depuis Internet**. La compatibilité d'une application AppImage particulière reste dépendante de son propre packaging, de son architecture et de ses dépendances externes éventuelles.

## Limites

Le système fournit toutes les briques génériques raisonnables pour exécuter les formats AppImage Type 1 et Type 2 sur Fedora 45. Il ne peut toutefois pas garantir qu'un binaire arbitraire datant de plusieurs décennies fonctionnera si celui-ci dépend d'un ABI retiré, d'un pilote propriétaire obsolète, d'une architecture CPU non supportée ou d'un comportement incompatible avec un noyau moderne.

Dans ce cas, le problème vient de l'application elle-même, pas du socle AppImage du projet.

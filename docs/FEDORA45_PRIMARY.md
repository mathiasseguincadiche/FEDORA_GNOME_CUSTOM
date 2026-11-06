# Installation neuve Fedora 45 / GNOME 51 : référence du projet

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — média et profil relus contre `installer/fedora45-media.lock` et `profiles/fedora45/` ; ordre de préinstallation relu contre le guide Live — matériel : non vérifié

Fedora 45 Workstation et GNOME 51 sont la cible unique de l'installation neuve : `config/workstation.conf` sélectionne `HOST_RELEASE="45"`. Le [guide d'installation](INSTALLATION_GUIDE.md) est le parcours principal. Aucun Fedora 44 préalable et aucune commande de migration ne sont nécessaires.

## Configuration sélectionnée et installation autorisée

La sélection du profil est distincte de sa promotion. `profiles/fedora45/profile.json` est `ready` depuis le 3 novembre 2026 : l'APPLY et les générateurs Kickstart de production ne sont plus bloqués par le profil, mais restent soumis à leurs autres gardes (bare metal, baseline, dry-run, sauvegarde pré-APPLY, Secure Boot).

Le média final a été publié par Fedora ([page officielle Workstation](https://fedoraproject.org/workstation/download/)) et authentifié avant la création du verrou. L'image Cloud utilisée par les laboratoires CI est un support de test ; elle ne sert jamais à installer le PC.

## Média promu

| Élément | Valeur |
|---|---|
| ISO | `Fedora-Workstation-Live-45-1.4.x86_64.iso` (2 925 092 864 octets) |
| SHA-256 | `68338c6bfe4f0d64151f2e47efe9f44a8855ad05b460e56b844fb3fa2c9a3beb` |
| CHECKSUM signé | `Fedora-Workstation-45-1.4-x86_64-CHECKSUM` |
| Clé de signature | `4F50A6114CD5C6976A7F1179655A4B02F577861E` (paquet `fedora-gpg-keys-45-1`) |
| RPM stables | `gnome-shell-extension-dash-to-dock-110-1.fc45`, `gnome-shell-extension-appindicator-66-1.fc45` |

Le verrou `installer/fedora45-media.lock` et les empreintes de `profile.json` ont été écrits par `promote-fedora45.py`, dans un conteneur Fedora 45 jetable et depuis un clone propre de `main`.

La promotion exige :

1. une ISO Workstation 45 finale, son CHECKSUM signé et la clé Fedora 45 épinglée ;
2. les archives GNOME 51 revues, leurs empreintes et les réglages vérifiés ;
3. les RPM exacts Dash to Dock et AppIndicator du verrou `profiles/fedora45/gnome-rpms.json`, disponibles dans les dépôts stables ;
4. une PR de promotion revue, puis une CI verte sur son commit exact.

`scripts/development/promote-fedora45.py` refuse Beta/RC, mauvaise signature, empreinte incohérente, dépôt Git modifié et RPM absents des dépôts stables. Consulter son aide pour les paramètres de média. La promotion ne constitue pas une certification matérielle.

## Profil GNOME 51

| Besoin | Composant retenu |
|---|---|
| Dock | Dash to Dock, RPM Fedora épinglé |
| Indicateurs d'applications | AppIndicator, RPM Fedora épinglé |
| Bureau et Corbeille | Gtk4 DING v145, review 75162 |
| Afficher le bureau | Show Desktop Button v59, review 75965 |
| CPU, RAM, réseau | Vitals v85, review 74743 |
| Tuilage | Tiling Assistant v56 |

`config/gnome-extensions.lock` et le verrou du profil Fedora 45 doivent rester identiques. Même règle pour les manifestes Nautilus : Fedora 45 utilise File Roller et son extension Nautilus, sans `gvfs-archive` supprimé en amont. Le validateur détecte toute divergence avant promotion.

Les noms internes `SHOW_DESKTOP_PLUS_*` et `RESOURCE_MONITOR_*` restent des rôles de configuration pour conserver l'interface existante. Ils sélectionnent respectivement Show Desktop Button et Vitals sur Fedora 45. Voir [GNOME.md](GNOME.md).

## Ce que vérifie la CI

Les conteneurs principaux (paquets, installation en dry-run, Borg, bureau, jeux, AppImage et télémétrie) utilisent Fedora 45. Les deux laboratoires obligatoires démarrent Fedora 45 / GNOME 51 : l'un natif, l'autre avec les six extensions. Le second installe les deux RPM d'extensions aux versions exactes du verrou, en ajoutant `updates-testing` dans la VM jetable seulement ; ces mêmes versions sont présentes dans les dépôts stables depuis la promotion. Aucun dépôt de test n'est activé sur la machine de production ([laboratoire](FEDORA_GNOME_CI_LAB.md)).

Un résultat `pending` ou `DEFERRED` reste une absence de qualification, même si le rapport d'état se termine correctement. Le laboratoire [Fedora 44 historique](history/HISTORICAL_FEDORA44.md) est facultatif et lancé manuellement.

Le scénario QEMU ferme ses applications de test (action D-Bus `quit` de Nautilus) avant la déconnexion et vérifie l'absence réelle des processus Nautilus et Ptyxis. Nautilus utilise une instance D-Bus : l'arrêt de son seul lanceur ne suffit pas. Les journaux, les états de service et les processus avant/après fermeture sont conservés ; un blocage du compositeur, une unité en échec ou un coredump fait échouer le scénario. Cette vérification ne remplace pas l'essai de déconnexion avec des applications ouvertes lors de la qualification interactive.

Le module `gnome.core` installe aussi un drop-in utilisateur `org.gnome.Shell@user.service.d/50-fgc-child-lifecycle.conf` et vérifie que `KillMode=mixed` est effectif. Le signal d'arrêt est d'abord envoyé à Shell pour que Mutter ferme ses enfants Xwayland dans son ordre normal ; systemd conserve le nettoyage final de tout le groupe. Le délai d'arrêt reste celui du paquet en production. Le laboratoire utilise exactement le même fichier et exerce cet ordre avec deux services de test réels, dont un témoin négatif reproduisant l'arrêt prématuré d'un enfant. Les déconnexions GNOME complètes restent contrôlées séparément.

## Données et parcours final

Le second Crucial T705 reste monté en EXT4 sur `/data` : `Documents/`, `Projets/`, `ISO/`, `Jeux/`, `IA/Openclaw/` et `libvirt/`. Borg protège `/data/IA/Openclaw` comme `/data/Projets`, en conservant les exclusions des disques de VM. Aucune migration d'OS ne doit reformater ce disque.

Le parcours d'installation fait foi dans le [guide](INSTALLATION_GUIDE.md#le-parcours). Le [contrôle Live](FEDORA45_LIVE_PREFLIGHT.md) précède l'installation sur SSD ; **ses résultats sont revus et le propriétaire donne son accord avant toute installation**. La configuration finale, le dry-run, la sauvegarde vérifiée et l'APPLY se font sur Fedora installé ; les mesures complètes du matériel, le bureau et Rocky appartiennent à la [Gate 3](QUALIFICATION.md#4-gate-3--système-installé).

La [mise à niveau 44 → 45](UPGRADE_FEDORA_45.md) ne concerne que les anciens systèmes déjà installés.

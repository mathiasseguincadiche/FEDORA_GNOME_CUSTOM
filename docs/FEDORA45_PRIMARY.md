# Installation neuve Fedora 45 / GNOME 51 : référence du projet

Fedora 45 Workstation et GNOME 51 sont la cible unique de l’installation neuve : `config/workstation.conf` sélectionne `HOST_RELEASE="45"`. Le [guide d’installation](INSTALLATION_GUIDE.md) est le parcours principal. Aucun Fedora 44 préalable et aucune commande de migration ne sont nécessaires.

## Configuration sélectionnée et installation autorisée

La sélection du profil est distincte de sa promotion. `profiles/fedora45/profile.json` reste `pending` : on peut consulter la configuration, le centre de contrôle et le dry-run, mais l’APPLY et les générateurs Kickstart de production refusent de continuer.

Le 21 octobre 2026, la [page officielle Workstation](https://fedoraproject.org/workstation/download/) présente encore Fedora 44 comme téléchargement final. Aucun verrou de média final Fedora 45 n’est inventé. Les images Beta utilisées par les laboratoires restent des supports de test.

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
| Indicateurs d’applications | AppIndicator, RPM Fedora épinglé |
| Bureau et Corbeille | Gtk4 DING v145, review 75162 |
| Afficher le bureau | Show Desktop Button v59, review 75965 |
| CPU, RAM, réseau | Vitals v85, review 74743 |
| Tuilage | Tiling Assistant v56 |

`config/gnome-extensions.lock` et le verrou du profil Fedora 45 doivent rester identiques. Même règle pour les manifestes Nautilus : Fedora 45 utilise File Roller et son extension Nautilus, sans `gvfs-archive` supprimé en amont. Le validateur détecte toute divergence avant promotion.

Les noms internes `SHOW_DESKTOP_PLUS_*` et `RESOURCE_MONITOR_*` restent des rôles de configuration pour conserver l’interface existante. Ils sélectionnent respectivement Show Desktop Button et Vitals sur Fedora 45. Voir [GNOME_EXTENSIONS.md](GNOME_EXTENSIONS.md).

## Ce que vérifie la CI

Les conteneurs principaux (paquets, installation en dry-run, Borg, bureau, jeux, AppImage et télémétrie) utilisent Fedora 45. Les deux laboratoires obligatoires démarrent Fedora 45 / GNOME 51 : l’un natif, l’autre avec les six extensions. Le second peut installer deux RPM Fedora signés de `updates-testing`, strictement dans la VM jetable ; cela ne les rend pas stables pour le PC. Aucun dépôt de test n’est activé sur la machine de production.

Un résultat `pending` ou `DEFERRED` reste une absence de qualification, même si le rapport d’état se termine correctement. Le laboratoire [Fedora 44 historique](HISTORICAL_FEDORA44.md) est facultatif et lancé manuellement.

Le scénario QEMU ferme ses applications de test (action D-Bus `quit` de Nautilus) avant la déconnexion et vérifie l’absence réelle des processus Nautilus et Ptyxis. Nautilus utilise une instance D-Bus : l’arrêt de son seul lanceur ne suffit pas. Les journaux, les états de service et les processus avant/après fermeture sont conservés ; un blocage du compositeur, une unité en échec ou un coredump fait échouer le scénario. Cette vérification ne remplace pas l’essai de déconnexion avec des applications ouvertes lors de la qualification interactive.

## Données et parcours final

Le second Crucial T705 reste monté en EXT4 sur `/data` : `Documents/`, `Projets/`, `ISO/`, `Jeux/`, `IA/Openclaw/` et `libvirt/`. Borg protège `/data/IA/Openclaw` comme `/data/Projets`, en conservant les exclusions des disques de VM. Aucune migration d’OS ne doit reformater ce disque.

Après promotion du profil et contrôle du média :

**Configuration définitive → dry-run final → sauvegarde vérifiée → APPLY → redémarrage → qualification matérielle Gate 3.**

Le [contrôle Live](FEDORA45_LIVE_PREFLIGHT.md) et la [Gate 2 visuelle](GATE2_GUIDE_PAS_A_PAS.md) précèdent l’APPLY selon les gardes du projet. Les mesures B580, écran, veille, réseau et T705 appartiennent ensuite à la Gate 3 physique.

La [mise à niveau 44 → 45](UPGRADE_FEDORA_45.md) ne concerne que les anciens systèmes déjà installés.

# Mise à niveau facultative de Fedora 44 vers Fedora 45

> Mise à jour : 2026-11-04 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-04 — phases, préconditions et codes de sortie relus dans `scripts/maintenance/upgrade-fedora.sh` — matériel : non vérifié

Cette page ne concerne qu'un poste qui exécute déjà Fedora 44. **Une installation neuve passe directement à Fedora 45 / GNOME 51 par le [guide d'installation](INSTALLATION_GUIDE.md) ; aucune mise à niveau n'est nécessaire.**

La configuration principale cible Fedora 45. Un poste encore sous Fedora 44 garde `HOST_RELEASE="44"` dans `config/local.conf` jusqu'à la fin de la mise à niveau. Le profil Fedora 45 est promu ([fiche Fedora 45](FEDORA45_PRIMARY.md)) ; la mise à niveau l'exige.

## Vue d'ensemble

| Phase | Commande | Résultat |
|---|---|---|
| Mettre Fedora 44 à jour | `./control.sh update all`, `update reboot`, `update finalize` | système source à jour, aucune mise à jour en attente |
| Planifier | `./control.sh upgrade plan` | étapes affichées, profil 45 vérifié ; rien n'est modifié |
| Préparer | `./control.sh upgrade prepare` | sauvegarde vérifiée, transaction Fedora 45 téléchargée ; état `prepared` |
| Redémarrer | `./control.sh upgrade reboot` | installation hors ligne de Fedora 45 |
| Finaliser | `./control.sh upgrade finalize`, deux fois | profil 45 activé, extensions installées puis vérifiées ; état `completed` |

`./control.sh upgrade status` affiche la phase en cours à tout moment.

## 1. Mettre Fedora 44 à jour

```bash
./control.sh update all
./control.sh update reboot
./control.sh update finalize
```

Réussite : `./control.sh update status` ne signale aucune transaction en attente. DNF exige un système source à jour avant une mise à niveau de version.

## 2. Planifier et préparer

```bash
./control.sh upgrade plan
./control.sh upgrade prepare
./control.sh upgrade status
```

`prepare` refuse de continuer sans : le PC physique, Fedora 44 avec `HOST_RELEASE="44"`, le profil 45 promu, Secure Boot désactivé, un dépôt Git propre, un système à jour et aucune mise à jour du projet en attente.

Il résout ensuite la dernière version stable de Linux amont pour Fedora 45, puis fait une sauvegarde Borg de l'hôte et des fichiers de l'utilisateur, certifiée par `backup-doctor`. Cette sauvegarde n'arrête, ne copie et n'exporte aucune VM : disques, XML, NVRAM et TPM des VM restent sous la responsabilité du propriétaire, par [export manuel préventif](KVM_EXPORT_RESTORE.md) avant le changement de version.

Enfin, il télécharge la transaction `dnf5 system-upgrade`, sans `--allowerasing`, sans ignorer de paquet et sans redémarrer.

**Arrêt** : relire dans la sortie de DNF les suppressions et conflits éventuels avant de continuer.

## 3. Redémarrer

```bash
./control.sh upgrade reboot
```

Le redémarrage revérifie la sauvegarde complète et son absence de VM, puis lance l'installation hors ligne.

## 4. Finaliser

Depuis la session GNOME de l'utilisateur, sans `sudo` :

```bash
./control.sh upgrade finalize
```

Le premier passage exige le même commit et la même configuration, un nouveau démarrage, Fedora 45, GNOME 51, le journal DNF, une base de paquets cohérente, et le noyau amont prévu réellement démarré. Il inscrit alors `HOST_RELEASE="45"` dans `config/local.conf` sans toucher aux autres réglages, et installe les quatre archives GNOME 51 du profil, en vérifiant leur empreinte, leur UUID, la version de GNOME et leurs schémas.

Il s'arrête ensuite volontairement avec le code 20 (`EXIT_PRECHECK_FAILED`), en phase `extensions-installed` : **se déconnecter normalement, se reconnecter, puis relancer** :

```bash
./control.sh upgrade finalize
```

Ce second passage exécute `scripts/validation/gnome51-extension-audit.py --live` : six rôles actifs, métadonnées GNOME 51, provenance des quatre archives. Puis il lance `./diagnostic.sh` et enregistre l'état `completed`.

En cas d'échec, la phase reste `extensions-installed`. Corriger le paquet ou l'extension en cause, se déconnecter, se reconnecter, relancer `finalize`. Ne jamais désactiver le vérificateur pour obtenir `completed`.

## Après la mise à niveau

Le profil, le média et les verrous entrent dans l'empreinte de configuration : les preuves Golden antérieures deviennent obsolètes (`STALE`). Refaire le contrôle Live, la [qualification](QUALIFICATION.md) en Gate 3, la [reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md) et la reprise de la VM Rocky.

Mesurer sur le PC : GNOME et Wayland, Arc B580 sur `xe`, Vulkan, Steam et Proton, écran 1440p à environ 240 Hz, veille et reprise, réseau, audio, périphériques. Le redémarrage direct avec la session GNOME ouverte, déjà observé dans le [laboratoire](FEDORA_GNOME_CI_LAB.md#démarrage-et-redémarrage), reste à qualifier.

## Retour arrière

Revenir au noyau N-1 ne ramène **pas** à Fedora 44. Revenir à un état antérieur repose sur la sauvegarde, le média connu et la reconstruction isolée ([sauvegardes](BACKUP_RESTORE.md), [reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md)).

Références : [DNF5 system-upgrade](https://dnf5.readthedocs.io/en/latest/commands/system-upgrade.8.html), [clés Fedora](https://fedoraproject.org/security/), [calendrier GNOME](https://release.gnome.org/calendar/).

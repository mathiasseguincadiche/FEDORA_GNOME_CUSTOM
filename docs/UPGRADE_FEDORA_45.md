# Passer la Golden Workstation à Fedora 45 / GNOME 51

## Pourquoi ce document

Le projet vise **la Fedora GNOME la plus récente**. Fedora 45 (GNOME 51) est en bêta depuis le 15 septembre 2026 ; sa sortie finale est planifiée au **20 octobre 2026** (date de repli : 27 octobre).

Le profil Golden n'installe jamais une bêta : il attend la version finale, puis vérifie que **chaque composant épinglé** existe pour la nouvelle version avant de changer quoi que ce soit.

## Étape 1 — Mesurer : l'outil de préparation

```bash
./scripts/development/release-readiness.sh            # Fedora 45 / GNOME 51 par défaut
./scripts/development/release-readiness.sh --pin      # + lignes de configuration prêtes à copier
```

L'outil est **en lecture seule**. Pour chaque composant tiers, il répond « prêt » ou « bloqué » :

| Composant | Ce qui est vérifié |
|---|---|
| Noyau CachyOS, noyau Vanilla | le COPR publie un chroot `fedora-45-x86_64` |
| DING, Show Desktop Plus, Resource Monitor | extensions.gnome.org publie une version pour GNOME Shell 51 |
| Tiling Assistant | la dernière release GitHub déclare GNOME Shell 51 |
| Dash to Dock, AppIndicator, adw-gtk3 | le paquet se résout dans les dépôts Fedora 45 (sur l'hôte Fedora) |

Avec `--pin`, il télécharge les candidats et affiche les lignes `*_SOURCE_URL`, `*_VERSION` et `*_SHA256` à reporter dans `config/gnome.conf` ou `config/gnome-polish.conf`.

Le même rapport tourne **chaque lundi** dans la CI (workflow *Fedora next-release readiness*) : l'onglet *Actions* montre donc en permanence ce qui manque encore.

**Règle : on ne migre que lorsque toutes les lignes sont `READY`.**

## Étape 2 — Porter le dépôt (branche dédiée)

1. Reporter les nouvelles valeurs épinglées produites par `--pin`.
2. Adapter la cible GNOME Shell (`50` → `51`) dans les scripts d'installation d'extensions (`scripts/gnome/install-*.sh`) et dans les `*_SHELL_VERSION`.
3. Créer `installer/fedora45-media.lock` à partir de l'ISO finale et de son fichier `CHECKSUM` signé, puis faire pointer le générateur Kickstart dessus.
4. Rejouer la **Gate 1** (WSL2) et la **Gate 2** (GNOME / VirtualBox), puis ouvrir une Pull Request : la CI doit être verte.

## Étape 3 — Installer sur la machine

Deux chemins possibles :

- **Installation neuve (recommandée tant que la Gate 3 n'a jamais été passée)** : Kickstart Fedora 45, baseline, sauvegarde, APPLY. On certifie directement la version finale.
- **Mise à niveau d'une Fedora 44 déjà certifiée** : sauvegarde Borg complète, puis `sudo dnf system-upgrade download --releasever=45`, `sudo dnf offline reboot`, puis un APPLY pour reconverger.

Dans les deux cas, terminer par :

```bash
./diagnostics/kernel-doctor
./control.sh doctor polish
./diagnostics/final-certification certify   # Gate 3
```

Un changement de version Fedora invalide l'ancienne certification : la Gate 3 doit être rejouée.

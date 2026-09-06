# Workstation Control Center

`./control.sh` est la façade opérateur de FEDORA_GNOME_CUSTOM. Elle reste volontairement mince : l'installation, Restic, DNF5, kernel lifecycle, KVM et les doctors restent implémentés dans leurs moteurs dédiés.

```bash
./control.sh
```

`./menu.sh` lance la même interface pour compatibilité.

## Tableau de bord

```bash
./control.sh status
```

Le dashboard affiche version/SHA, Fedora/runtime, kernel, B580/xe, Git, backup, certification, KVM et état reboot. Une certification dont le fingerprint runtime ne correspond plus est affichée `STALE`.

## Installation

```bash
./control.sh install dry-run
./control.sh install backup
./control.sh install apply
```

Ces commandes appellent respectivement :

```text
install.sh --dry-run
prepare-preapply-backup.sh
install.sh --apply
```

Le chemin APPLY garde donc les protections natives : bare-metal, Git propre, baseline, même commit/configuration effective/plan matériel que le dry-run, **backup complet Restic** dont le snapshot exact est relu, et confirmation opérateur.

## Mises à jour

```bash
./control.sh update check
./control.sh update all
./control.sh update dnf
./control.sh update flatpak
./control.sh update firmware
```

`update all` et `update dnf` ne remplacent plus les paquets RPM dans la session GNOME active. Ils préparent une transaction **DNF5 offline** après un backup Restic complet :

```text
backup complet Restic
        ↓
dnf5 --refresh upgrade --offline
        ↓
transaction stockée, aucun RPM remplacé dans la session active
```

Le moteur détaillé est `scripts/maintenance/update-system.sh`.

### 1. Préparer

```bash
./control.sh update all
# ou Fedora seulement
./control.sh update dnf
```

`all` mémorise qu'après l'update RPM il faudra également converger les Flatpaks. `dnf` n'exécutera pas cette étape.

### 2. Déclencher l'update offline

```bash
scripts/maintenance/update-system.sh --offline-status
sudo scripts/maintenance/update-system.sh --offline-reboot
```

DNF5 redémarre alors dans son environnement minimal, applique la transaction, puis revient sur Fedora normal.

### 3. Finaliser après retour sur Fedora

```bash
scripts/maintenance/update-system.sh --finalize
```

La finalisation :

```text
journal dernière transaction DNF5 offline
        ↓
dnf5 check
        ↓
Flatpak update si mode "all"
        ↓
fwupd get-updates uniquement
        ↓
diagnostic global
```

Pour inspecter la dernière transaction sans rien modifier :

```bash
scripts/maintenance/update-system.sh --offline-log
```

Une évolution du kernel, Mesa, firmware, Mutter ou GNOME Shell peut rendre la certification `STALE`; le `software-matrix-doctor diff` explique alors précisément ce qui a changé.

Pour le firmware : **aucun flash automatique**. `fwupdmgr` reste une surface d'inventaire/consultation.

## Kernel

La politique Golden reste `kernel-vanilla/stable`, mais latest-stable signifie **source des candidats**, pas promotion automatique.

```bash
./control.sh kernel candidate
./control.sh kernel boot-candidate
./control.sh kernel certify
./control.sh kernel rollback
./control.sh kernel rollback-fedora
```

`control.sh` route directement ces actions vers le moteur `scripts/kernel/kernel-lifecycle.sh` afin de ne pas dupliquer la logique.

Séquence normale :

```text
candidat résolu dans le repo Kernel Vanilla stable
      ↓
NEVRA exactes + Fedora fallback obligatoire
      ↓
boot-candidate one-shot
      ↓
reboot + qualification hardware/runtime
      ↓
certify
      ↓
default persistant
```

Un kernel Fedora 44 officiel doit rester installé comme fallback pendant tout le lifecycle.

## Diagnostics

```bash
./control.sh doctor all
./control.sh doctor baseline
./control.sh doctor kernel
./control.sh doctor graphics
./control.sh doctor storage
./control.sh doctor display
./control.sh doctor gnome
./control.sh doctor apps
./control.sh doctor media
./control.sh doctor kvm
./control.sh doctor backup
```

Les doctors matériels stricts sont également exécutés par la certification finale. `diagnostics/software-matrix-doctor diff` compare l'état courant au dernier état known-good certifié.

## Backup / restauration

```bash
./control.sh backup now
./control.sh backup now-with-vms
./control.sh backup daily
./control.sh backup list
./control.sh backup check
./control.sh backup deep
./control.sh backup restore latest
./control.sh backup dr-plan
./control.sh backup prune
```

Les restores restent staging-first ; aucune restauration n'écrase silencieusement le système actif.

## Certification

```bash
./control.sh cert status
./control.sh cert record-suspend
./control.sh cert certify
./control.sh cert baseline-status
./control.sh cert baseline-certify
```

La certification Golden exige notamment cinq cycles veille/réveil physiques uniques, le cold-start Nautilus, SMART/PCIe T705, B580/ReBAR/x8, EDID certifié, VA-API fonctionnel, OpenCL fonctionnel et KVM si activé. Elle génère ensuite le bundle `state/releases/.../golden-release.json`.

## CLI kernel avancée

Les actions candidat sont disponibles directement :

```bash
./control.sh kernel candidate
./control.sh kernel boot-candidate
./control.sh kernel certify
```

## Couleurs

`NO_COLOR=1` désactive les couleurs ANSI :

```bash
NO_COLOR=1 ./control.sh status
```

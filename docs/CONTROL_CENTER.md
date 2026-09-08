# Workstation Control Center

`./control.sh` est la façade opérateur de FEDORA_GNOME_CUSTOM. Elle reste volontairement mince : la validation, l'installation, Restic, DNF5, kernel lifecycle, KVM et les doctors restent implémentés dans leurs moteurs dédiés.

```bash
./control.sh
```

`./menu.sh` lance la même interface pour compatibilité.

## Tableau de bord

```bash
./control.sh status
```

Le dashboard affiche version/SHA, Fedora/runtime, kernel, B580/xe, Git, backup, certification, KVM et état reboot. Une certification dont le fingerprint runtime ne correspond plus est affichée `STALE`.

## Validation en trois gates

La prévalidation et la certification sont désormais ordonnées :

```text
Gate 1 — Fedora 44 / WSL2
  système + logique, hardware DEFERRED
        ↓
Gate 2 — Fedora 44 GNOME / VirtualBox
  GNOME + extensions + Nautilus + Ptyxis + contrôle visuel
        ↓
Gate 3 — Fedora 44 / bare-metal
  certification Golden complète
```

Afficher le statut :

```bash
./control.sh validate status
```

### Gate 1 — WSL2

```bash
./control.sh validate gate1 run
./control.sh validate gate1 status
./control.sh validate export 1 /chemin/export
```

Gate 1 exécute le doctor WSL2, la validation de configuration et la suite des contrats, puis produit une preuve JSON portable avec `hardware_certification=DEFERRED`.

### Gate 2 — VirtualBox

Importer d'abord Gate 1 :

```bash
./control.sh validate import /chemin/gate1-<commit>.json
```

Puis :

```bash
./control.sh validate gate2 plan
./control.sh validate gate2 apply
./control.sh validate gate2 check
./control.sh validate gate2 sign
./control.sh validate export 2 /chemin/export
```

La signature `gate2 sign` relance les doctors puis exige une validation visuelle humaine. La preuve Gate 2 contient le SHA-256 exact de la preuve Gate 1 importée.

### Gate 3 — bare-metal

Importer Gate 1 puis Gate 2 dans cet ordre :

```bash
./control.sh validate import /chemin/gate1-<commit>.json
./control.sh validate import /chemin/gate2-<commit>.json
./control.sh validate gate3 status
```

Enregistrer les cycles physiques puis certifier :

```bash
./control.sh validate gate3 record-suspend
./control.sh validate gate3 certify
```

Le moteur `diagnostics/final-certification` vérifie lui-même la chaîne Gate 1 → Gate 2 : appeler directement le doctor ne contourne pas cette règle. Seul Gate 3 peut produire `final-certification PASS` et `golden-release.json`.

Voir [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md).

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
./control.sh update status
./control.sh update log
./control.sh update reboot
./control.sh update finalize
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
./control.sh update status
./control.sh update reboot
```

DNF5 redémarre alors dans son environnement minimal, applique la transaction, puis revient sur Fedora normal.

### 3. Finaliser après retour sur Fedora

```bash
./control.sh update finalize
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
./control.sh update log
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

La certification Golden exige désormais la chaîne de preuves Gate 1 → Gate 2 en plus des preuves physiques : cinq cycles veille/réveil uniques, cold-start Nautilus, SMART/PCIe T705, B580/ReBAR/x8, EDID certifié, VA-API fonctionnel, OpenCL fonctionnel et KVM si activé. Elle génère ensuite le bundle `state/releases/.../golden-release.json` avec `gate1-proof.json` et `gate2-proof.json`.

### Archive Golden longue durée

Après une certification Golden réelle, un archivage hors dépôt peut sceller le bundle certifié avec des payloads conservés par l'opérateur :

```bash
./control.sh cert archive /mnt/archive/golden-2026 \
  /chemin/Fedora-Workstation-Live-44.iso \
  /chemin/offline-rpm-flatpak-cache \
  /chemin/Windows11.iso \
  /chemin/virtio-win.iso
```

Le moteur `scripts/release/seal-golden-archive.sh` exige une certification finale `PASS`, vérifie d'abord le `MANIFEST.sha256` du bundle Golden, refuse une destination située dans le checkout Git et produit un nouveau `MANIFEST.sha256` couvrant release + payloads. Il ne télécharge jamais automatiquement de média externe.

Cet archivage est optionnel et destiné à la conservation historique/off-machine ; il ne remplace ni Restic ni la certification runtime.

## Logs et rétention

Les logs ordinaires et rapports transitoires ont une politique versionnée dans `config/operator-retention.policy` :

```text
logs = 90 jours
reports = 180 jours
state/ = conservé
state/releases/ = conservé
```

Afficher ce qui serait supprimé :

```bash
./control.sh logs retention
```

Appliquer explicitement la rétention :

```bash
./control.sh logs prune
```

`scripts/maintenance/prune-project-artifacts.sh` ne touche jamais aux markers de certification, à `state/` ni aux Golden releases.

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

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

La prévalidation et la certification sont ordonnées :

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

Le moteur `diagnostics/final-certification` vérifie lui-même la chaîne Gate 1 → Gate 2. Seul Gate 3 peut produire `final-certification PASS` et `golden-release.json`.

Voir [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md).

## Installation

```bash
./control.sh install dry-run
./control.sh install backup
./control.sh install apply
```

Ces commandes appellent respectivement `install.sh --dry-run`, `prepare-preapply-backup.sh` et `install.sh --apply`.

Le chemin APPLY conserve les protections natives : bare-metal, Git propre, baseline, même commit/configuration effective/plan matériel que le dry-run, backup complet Restic dont le snapshot exact est relu, et confirmation opérateur.

## Mises à jour

Surface opérateur complète :

```bash
./control.sh update check
./control.sh update all
./control.sh update dnf
./control.sh update reboot
./control.sh update finalize
./control.sh update status
./control.sh update log
./control.sh update flatpak
./control.sh update firmware
```

`update all` et `update dnf` ne remplacent pas les paquets RPM dans la session GNOME active. Ils préparent une transaction **DNF5 offline** après un backup Restic complet :

```text
backup complet Restic
        ↓
dnf5 --refresh upgrade --offline
        ↓
transaction stockée
        ↓
./control.sh update reboot
        ↓
DNF5 offline + redémarrage normal
        ↓
./control.sh update finalize
        ↓
dnf5 check → Flatpak si mode all → firmware check → diagnostic global
```

### Préparer

```bash
./control.sh update all
# ou Fedora seulement
./control.sh update dnf
```

### Redémarrer dans la transaction offline

```bash
./control.sh update status
./control.sh update reboot
```

### Finaliser après retour sur Fedora

```bash
./control.sh update finalize
```

La commande historique directe :

```bash
scripts/maintenance/update-system.sh --post-offline
```

reste acceptée comme alias de compatibilité, mais `finalize` est le nom canonique.

Pour inspecter la dernière transaction :

```bash
./control.sh update log
```

Une évolution du kernel, Mesa, firmware, Mutter ou GNOME Shell peut rendre la certification `STALE`; `software-matrix-doctor diff` explique alors ce qui a changé.

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

Séquence normale :

```text
candidat latest-stable
      ↓
NEVRA exactes + Fedora fallback
      ↓
boot-candidate one-shot
      ↓
qualification hardware/runtime
      ↓
certify
      ↓
default persistant
```

Un kernel Fedora 44 officiel reste installé comme fallback pendant tout le lifecycle.

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

## Logs, rapports et rétention

Lister les preuves opérateur :

```bash
./control.sh logs list
./control.sh logs tail
./control.sh logs boot-failure
```

La politique `config/log-retention.policy` conserve les logs ordinaires 90 jours et les rapports ordinaires 365 jours. `state/` et `state/releases/` ne sont jamais supprimés par le helper. Un log ou rapport encore référencé dans l'état Golden est également protégé.

La prévisualisation est non destructive :

```bash
./control.sh logs prune
```

L'application est volontairement explicite :

```bash
./control.sh logs prune-apply
```

Le menu interactif demande en plus une confirmation avant l'APPLY de la rétention.

## Certification

```bash
./control.sh cert status
./control.sh cert record-suspend
./control.sh cert certify
./control.sh cert baseline-status
./control.sh cert baseline-certify
```

La certification Golden exige la chaîne Gate 1 → Gate 2 en plus des preuves physiques : cinq cycles veille/réveil uniques, cold-start Nautilus, SMART/PCIe T705, B580/ReBAR/x8, EDID certifié, VA-API, OpenCL et KVM si activé. Elle génère ensuite le bundle `state/releases/.../golden-release.json`.

## Archivage long terme des payloads

Après une certification PASS, les payloads que l'opérateur souhaite conserver indépendamment des mirrors peuvent être liés à la release Golden dans une archive externe :

```bash
bash scripts/release/archive-golden-payloads.sh \
  --destination /media/backup-golden \
  --payload /chemin/Fedora-Workstation-Live-44-1.7.x86_64.iso \
  --payload /chemin/payloads-rpm
```

Le helper refuse d'écrire les payloads dans Git et produit des manifests SHA-256. Voir [`GOLDEN_PAYLOAD_ARCHIVE.md`](GOLDEN_PAYLOAD_ARCHIVE.md).

## Couleurs

`NO_COLOR=1` désactive les couleurs ANSI :

```bash
NO_COLOR=1 ./control.sh status
```

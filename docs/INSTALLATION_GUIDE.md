# Guide d'installation — Fedora 44 GNOME 50 Golden Workstation

## A. Installation Fedora 44 reproductible

Option recommandée sur disque vierge : générer un Kickstart depuis un environnement Linux de confiance.

```bash
installer/generate-fedora44-kickstart.sh --disk /dev/nvme0n1
```

Le générateur affiche modèle/serial/taille et exige `EFFACER /dev/nvme0n1`. Le fichier Kickstart efface uniquement le disque explicitement choisi. Le second T705 n'est jamais sélectionné automatiquement.

Le Kickstart installe Fedora Workstation, SELinux/firewalld et clone le dépôt. Il ne lance pas l'APPLY : la qualification bare-metal reste obligatoire.

Une installation Fedora 44 Workstation manuelle reste supportée.

## B. Préparer `/data`

Le second T705 destiné à KVM doit être préparé et monté manuellement en EXT4 sur `/data`. Cette opération reste hors automatisation destructive du dépôt.

## C. Configuration locale

```bash
cp config/local.conf.example config/local.conf
$EDITOR config/local.conf
```

`REAL_MACHINE_APPROVED` reste `false` jusqu'à la fin des contrôles.

## D. Baseline pré-APPLY

La baseline ne demande plus cinq cycles suspend avant correction. Elle certifie seulement la santé nécessaire pour autoriser l'APPLY.

```bash
./diagnostics/baseline-doctor snapshot
./diagnostics/baseline-doctor run-memory-test 5600
```

Passer ensuite le profil mémoire BIOS à 6000 MT/s, redémarrer et lancer :

```bash
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

Les tests NVMe utilisent un fichier temporaire de 4 Gio avec fio/CRC32C et n'écrivent jamais sur le block device brut.

## E. Dry-run et backup

```bash
./install.sh --dry-run
./prepare-preapply-backup.sh
```

Le backup Restic doit être vérifié et correspondre au même SHA Git.

## F. APPLY

Après avoir revu la cible, passer `REAL_MACHINE_APPROVED=true` dans `config/local.conf`, puis :

```bash
./install.sh --apply
```

Le kernel profile active `@kernel-vanilla/stable` et exige au minimum 7.2.2. Si Secure Boot est actif, l'APPLY kernel est bloqué par défaut afin d'éviter un kernel Vanilla non amorçable.

Les anciens kernels Fedora sont conservés.

## G. Reboot et premier login

Redémarrer sur le dernier kernel installé et vérifier :

```bash
./diagnostics/kernel-doctor
./diagnostics/display-doctor
./diagnostics/graphics-doctor
```

Immédiatement après le premier login, avant d'ouvrir Files :

```bash
./diagnostics/nautilus-coldstart-doctor
```

## H. Suspend/resume final

Effectuer cinq cycles veille/réveil. Après chaque reprise, attendre quelques secondes pour le repair puis :

```bash
./diagnostics/final-certification record-suspend
```

Le contrôle exige display repair récent, Arc B580/xe sain et absence de signatures critiques xe/PCIe/NVMe.

Après cinq cycles :

```bash
./diagnostics/final-certification certify
```

## I. Recovery

Affichage :

```bash
./repair.sh display
```

Kernel :

```bash
./diagnostics/kernel-doctor
scripts/kernel/rollback-to-fedora.sh
```

Le rollback désactive le COPR Vanilla et distro-sync les packages vers Fedora ; il ne supprime pas aveuglément les kernels installés.

## J. KVM / VM / Backup

Une fois le HOST certifié, continuer avec les procédures KVM/Ubuntu/Windows et Restic décrites dans `docs/VIRTUALIZATION.md`, `docs/VM_PROFILES.md` et `docs/BACKUP_RESTORE.md`.

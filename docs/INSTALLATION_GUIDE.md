# Guide d'installation — Fedora 44 GNOME 50 Golden Workstation

Pour une première lecture, le portail documentaire est [`README.md`](README.md) et le vocabulaire est défini dans [`GLOSSARY.md`](GLOSSARY.md).

## A. Installation Fedora 44 reproductible

Option recommandée sur disque vierge : générer un Kickstart **depuis le checkout Git exact que l'on veut installer**.

```bash
installer/generate-fedora44-kickstart.sh --disk /dev/nvme0n1
```

Le générateur affiche modèle/serial/taille, imprime le SHA Git incorporé et exige `EFFACER /dev/nvme0n1`.

Le Kickstart efface uniquement le disque explicitement choisi, puis fetch/checkout exactement ce SHA. Une panne réseau ou un SHA non récupérable fait échouer le `%post` au lieu de continuer avec un checkout inconnu. Le second T705 n'est jamais sélectionné automatiquement.

Le Kickstart installe Fedora Workstation, SELinux/firewalld et le checkout versionné. Il ne lance pas l'APPLY : la qualification bare-metal reste obligatoire. Une installation Fedora 44 Workstation manuelle reste supportée.

## B. Préparer `/data`

Le second T705 destiné à KVM doit être préparé et monté manuellement en EXT4 sur `/data`.

Cette opération reste hors automatisation destructive du dépôt : le projet ne choisit, ne partitionne et ne formate jamais automatiquement ce disque.

Avant de poursuivre :

```bash
findmnt /data
lsblk -f
```

## C. Configuration locale

```bash
cp config/local.conf.example config/local.conf
$EDITOR config/local.conf
```

`REAL_MACHINE_APPROVED` reste `false` jusqu'à la fin des contrôles.

## D. Baseline pré-APPLY

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

## E. Preflight et backup

```bash
./install.sh --dry-run
./prepare-preapply-backup.sh
```

`--dry-run` est un **preflight non-mutant** : il valide catalogue, préconditions et plans, puis journalise les mutations qui seraient exécutées sans les lancer.

La réussite transactionnelle des dépôts/outils est couverte en complément par les prétests Fedora/Ubuntu. Le backup Restic doit être vérifié et correspondre au même SHA Git.

## F. APPLY

Après avoir revu la cible, passer `REAL_MACHINE_APPROVED=true` dans `config/local.conf`, puis :

```bash
./install.sh --apply
```

Le kernel profile active `@kernel-vanilla/stable`, exige au minimum 7.2.2 et vérifie que le `kernel-core` le plus récent disponible est installé.

Si Secure Boot est actif, l'APPLY kernel est bloqué par défaut. Les anciens kernels Fedora sont conservés comme fallback.

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

Effectuer cinq cycles veille/réveil. Après chaque reprise :

```bash
./diagnostics/final-certification record-suspend
```

Les preuves sont liées au matériel, kernel, firmware GPU, Mesa, Mutter et GNOME Shell : une évolution de cette stack exige de nouvelles preuves.

Après cinq cycles :

```bash
./diagnostics/final-certification certify
```

La certification inclut aussi le socle KVM host lorsqu'il est activé.

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

Voir également [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) avant toute restauration en place.

## J. KVM / VM après certification du HOST

Une fois le HOST certifié, commencer par :

1. [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) — commandes et création des VM ;
2. [`VIRTUALIZATION.md`](VIRTUALIZATION.md) — architecture complète ;
3. [`KVM_NETWORK.md`](KVM_NETWORK.md) — NAT custom et isolation fail-closed ;
4. [`VM_PROFILES.md`](VM_PROFILES.md) — profils Ubuntu/Windows ;
5. [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — sauvegarde des VM.

Avant de créer les VM :

```bash
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

### Ubuntu

Conserver ensemble l'image Canonical et ses preuves :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

La création authentifie la liste signée et vérifie le SHA-256 de l'image avant de créer le disque.

### Réseau

`devops-nat` reste volontairement IPv4. L'activation IPv6 est refusée tant qu'une isolation dual-stack équivalente n'est pas implémentée et certifiée.

Lors d'un changement Ethernet/Wi-Fi, le guard KVM passe d'abord en mode d'urgence et ne rend le forwarding normal qu'après redécouverte/validation du nouvel uplink.

## K. En cas d'échec

Ne désactiver ni SELinux ni firewalld pour contourner un problème.

Utiliser le runbook :

[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)

Les diagnostics y sont organisés par symptôme avec commandes attendues et causes probables.

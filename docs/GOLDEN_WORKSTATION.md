# Golden Workstation — architecture de référence

## Objectif

Le projet sépare deux notions :

1. **baseline pré-APPLY** — prouver que le matériel est suffisamment sain pour autoriser les mutations ;
2. **certification runtime post-APPLY** — prouver que la pile réellement installée est saine sur le vrai matériel.

Cette séparation est essentielle : un défaut que l'APPLY doit corriger ne doit pas empêcher l'installation de son correctif.

La version applicable du projet est celle de [`../VERSION`](../VERSION).

## Chaîne de confiance

```text
Fedora 44 fraîche
      ↓
baseline RAM / NVMe / hardware
      ↓
dry-run non-mutant
      ↓
backup Restic + restore canary
      ↓
APPLY protégé
      ↓
second T705 persistant /data
  Documents + Projets + ISO + Jeux + libvirt
      ↓
reboot sur Kernel Vanilla N
      ↓
certification hardware / desktop / KVM / backup
      ↓
5 cycles suspend/resume
      ↓
matrice known-good
```

## Kernel

Le profil installe directement le dernier kernel stable disponible via Fedora Kernel Vanilla `@kernel-vanilla/stable`, avec plancher 7.2.2.

La politique est rolling **N / N-1** :

```text
N   = dernier stable installé, défaut GRUB
N-1 = version immédiatement précédente, rollback
max = 2 versions kernel-core
```

Les versions plus anciennes que N-1 sont purgées via DNF5 `oldinstallonly`. Un kernel Fedora supplémentaire n'est plus conservé en permanence ; le retour vers les paquets Fedora reste un chemin de récupération explicite.

Secure Boot actif bloque ce chemin par défaut. Le projet ne désactive pas Secure Boot automatiquement et ne génère/importera pas une clé MOK sans décision opérateur explicite.

## Hardware

La baseline certifie notamment :

- RAM à 5600 puis 6000 MT/s avec `stress-ng --verify` ;
- T705 système et `/data` avec `fio` filesystem-safe et vérification CRC32C ;
- root et `/data` sur deux NVMe physiques distincts ;
- fingerprint BIOS/plateforme/CPU/GPU/NVMe/EDID.

Aucun test n'écrit volontairement sur un block device brut.

## Stockage persistant

Le premier T705 est le disque système Fedora Btrfs. Le second T705 est un EXT4 monté sur `/data` et doit survivre aux réinstallations normales du système.

```text
/data/
├── Documents/       XDG Documents
├── Projets/         projets de travail
├── ISO/             bibliothèque ISO persistante
├── Jeux/            bibliothèque de jeux persistante
└── libvirt/         stockage KVM séparé
```

L'APPLY ne partitionne et ne formate jamais le second SSD. Il crée les répertoires manquants sans supprimer leur contenu, normalise uniquement leurs racines et applique les labels SELinux attendus.

`/data/Documents` et `/data/Projets` sont aussi protégés par Restic externe. `/data/ISO` et `/data/Jeux` restent hors backups automatiques par défaut afin d'éviter de dupliquer des payloads volumineux généralement reproductibles ou retéléchargeables. La séparation des SSD protège contre une réinstallation du disque système ; Restic protège les données importantes contre la panne du second SSD lui-même.

Voir ADR 0011 et [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md).

## Arc B580

Le GPU attendu est :

```text
8086:e20b
pilote xe
```

Le projet valide kernel/firmware/Mesa/Vulkan/VA-API/compute au lieu d'ajouter des `force_probe` ou dépôts GPU expérimentaux.

## Cold-start Nautilus

La métrique est volontairement stricte : Nautilus doit être absent avant le test. Le chronomètre démarre juste avant `nautilus --new-window` et s'arrête lorsque `org.gnome.Nautilus` possède son nom D-Bus.

Le prewarm de login touche Portal/GIO mais ne démarre jamais Nautilus.

Seuils par défaut :

- cible : `1200 ms` ;
- hard limit : `2000 ms`.

## Display recovery

Un texte/polices dégradé après veille ou power-cycle écran est traité d'abord comme un problème potentiel de chaîne DRM/KMS/Mutter/link, pas comme un défaut Fontconfig présumé.

Le repair réapplique via `gdctl` :

- 2560×1440 ;
- mode proche de 240 Hz ;
- scale 1.0 ;
- color mode SDR/default ;
- Full RGB.

Le watcher de session réagit à la reprise logind, aux changements Mutter et aux événements DRM prévus. Chaque application conserve un rapport dans l'état utilisateur du projet.

## GNOME

Le bureau reste proche de Fedora/GNOME upstream.

Extensions fonctionnelles gérées :

- Dash to Dock ;
- AppIndicator ;
- Desktop Icons NG ;
- Show Desktop Plus ;
- Resource Monitor.

Blur My Shell reste désactivé dans l'état Golden afin de réduire les variables de rendu/compositor.

Le répertoire standard GNOME « Documents » pointe vers `/data/Documents`, de sorte que les applications et Nautilus utilisent directement le stockage persistant sans symlink bricolé dans le HOME.

## KVM

Le socle KVM fait partie de la certification finale lorsqu'il est activé :

```text
qemu:///system
/data EXT4 persistant
/data/libvirt/images = pool devops-data
network devops-nat
Ubuntu Server 26.04
Windows 11
```

Le réseau KVM est IPv4-only tant qu'une isolation dual-stack équivalente n'est pas implémentée.

Le guard `fedora_gnome_custom_kvm` est fail-closed lors d'un changement d'uplink : il installe d'abord un blocage d'urgence du forwarding via `virbr50`, puis repasse en mode normal uniquement après redécouverte/validation du LAN.

L'image Ubuntu doit être authentifiée à partir de `SHA256SUMS` signé par Canonical avant création du disque.

Voir [`KVM_NETWORK.md`](KVM_NETWORK.md) et [`VIRTUALIZATION.md`](VIRTUALIZATION.md).

## Backup / recovery

Le pré-APPLY Restic exige :

- dépôt chiffré ;
- cible externe/remote ;
- backup lié au commit ;
- `restic check` ;
- restauration réelle d'un canary.

Le backup quotidien protège notamment `/data/Documents` et `/data/Projets`. Le backup full les inclut également. `/data/ISO` et `/data/Jeux` restent hors sauvegarde automatique par défaut.

Les disques QCOW2 ne sont sauvegardés que VM arrêtée, via staging cohérent et validation `qemu-img`.

La restauration reste staging-first : aucune procédure ne doit formater ou écraser automatiquement le second T705.

## Certification finale

Après APPLY/reboot :

1. vérifier `diagnostics/data-storage-doctor` ;
2. lancer `diagnostics/nautilus-coldstart-doctor` immédiatement après login ;
3. effectuer cinq cycles suspend/resume ;
4. après chaque cycle lancer `diagnostics/final-certification record-suspend` ;
5. terminer avec `diagnostics/final-certification certify`.

Un cycle est refusé si kernel, Arc/xe, display ou USB resume échouent, ou si des signatures critiques xe/PCIe/NVMe apparaissent. La certification finale refuse également un stockage persistant `/data` non conforme via les doctors desktop/backup.

## Politique de remédiation

Le projet applique :

```text
mesurer → reproduire → corriger → recertifier
```

Il n'ajoute pas globalement `xe.force_probe`, `i915.force_probe`, `pcie_aspm=off`, des changements APST/C-State ou `mem_sleep_default` sans preuve matérielle spécifique.

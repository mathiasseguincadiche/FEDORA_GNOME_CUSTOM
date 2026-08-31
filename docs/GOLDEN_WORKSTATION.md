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
reboot
      ↓
certification hardware / desktop / KVM
      ↓
5 cycles suspend/resume
      ↓
matrice known-good
```

## Kernel

Le profil installe le dernier kernel stable disponible via Fedora Kernel Vanilla `@kernel-vanilla/stable`, avec plancher 7.2.2. Les kernels Fedora existants ne sont pas supprimés et restent disponibles comme fallback.

Secure Boot actif bloque ce chemin par défaut. Le projet ne désactive pas Secure Boot automatiquement et ne génère/importera pas une clé MOK sans décision opérateur explicite.

## Hardware

La baseline certifie notamment :

- RAM à 5600 puis 6000 MT/s avec `stress-ng --verify` ;
- T705 système et `/data` avec `fio` filesystem-safe et vérification CRC32C ;
- root et `/data` sur deux NVMe physiques distincts ;
- fingerprint BIOS/plateforme/CPU/GPU/NVMe/EDID.

Aucun test n'écrit volontairement sur un block device brut.

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
- AppIndicator.

Blur My Shell reste désactivé dans l'état Golden afin de réduire les variables de rendu/compositor.

## KVM

Le socle KVM fait partie de la certification finale lorsqu'il est activé :

```text
qemu:///system
/data EXT4
pool devops-data
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

Les disques QCOW2 ne sont sauvegardés que VM arrêtée, via staging cohérent et validation `qemu-img`.

## Certification finale

Après APPLY/reboot :

1. lancer `diagnostics/nautilus-coldstart-doctor` immédiatement après login ;
2. effectuer cinq cycles suspend/resume ;
3. après chaque cycle lancer `diagnostics/final-certification record-suspend` ;
4. terminer avec `diagnostics/final-certification certify`.

Un cycle est refusé si kernel, Arc/xe, display ou USB resume échouent, ou si des signatures critiques xe/PCIe/NVMe apparaissent.

## Politique de remédiation

Le projet applique :

```text
mesurer → reproduire → corriger → recertifier
```

Il n'ajoute pas globalement `xe.force_probe`, `i915.force_probe`, `pcie_aspm=off`, des changements APST/C-State ou `mem_sleep_default` sans preuve matérielle spécifique.

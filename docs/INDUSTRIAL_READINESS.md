# Industrial Readiness — Fedora 44 + GNOME 50

Ce document décrit le niveau de maturité atteint par le dépôt après alignement avec les pratiques du projet Ubuntu de référence.

## Pipeline de confiance

```text
HARDWARE BASELINE
      ↓
SYSTEM
      ↓
HARDWARE INTEGRATION
      ↓
GNOME 50 / WAYLAND
      ↓
APPLICATIONS
      ↓
KVM / LIBVIRT
      ↓
VM RUNTIME
      ↓
BACKUP / RESTORE / DR
```

Chaque couche dispose de prechecks, plan, convergence contrôlée et postchecks. L'APPLY réel reste derrière un gate interactif, un worktree propre, une baseline hardware certifiée, un dry-run du même commit et un backup Restic vérifié du même commit.

## Preuves automatisées

- tests de contrats ;
- ShellCheck et syntaxe Bash ;
- résolution Fedora 44 ;
- installation réelle du contrat packages dans `fedora:44` ;
- garde-fous d'architecture/non-régression ;
- VM Ubuntu 26.04 réelle sous QEMU/KVM-or-TCG ;
- bootstrap DevOps réel ;
- smoke Docker ;
- test après reboot ;
- preuves GitHub Actions conservées en artifacts.

## Preuves on-machine

Sur la workstation réelle : hardware baseline, Arc B580/`xe`, Vulkan/VA-API, Mutter/Wayland, écran 1440p/240 Hz, GNOME extensions, suspend/resume, T705, KVM `qemu:///system`, `devops-nat`, Ubuntu/Windows, Secure Boot/TPM/VirtIO Windows, SSH/SFTP/SMB et isolation LAN.

## Recovery

Le projet possède maintenant un pipeline backup/recovery séparé : inventaire, repository, HOST, métadonnées KVM, disques VM, intégrité/rétention, restore staging et disaster recovery. Aucune restauration destructrice n'est automatisée.

## Définition de « prêt »

Le dépôt est **code-ready** lorsque toutes les CI sont vertes. La machine n'est **runtime-certified** qu'après exécution des diagnostics et certifications sur le vrai matériel. Cette distinction évite de confondre qualité du dépôt et preuve physique impossible à obtenir dans GitHub Actions.

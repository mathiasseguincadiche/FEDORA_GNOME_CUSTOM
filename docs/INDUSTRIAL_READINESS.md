# Industrial Readiness — Golden Workstation 0.8

## Chaîne de confiance

```text
FEDORA 44 INSTALL
      ↓
PRE-APPLY HARDWARE BASELINE
      ↓
DRY-RUN + RESTIC BACKUP
      ↓
SYSTEM + KERNEL 7.2.2+
      ↓
HARDWARE + GNOME + DISPLAY RECOVERY
      ↓
APPLICATIONS + KVM + BACKUP
      ↓
REBOOT
      ↓
POST-APPLY GOLDEN CERTIFICATION
```

## Code-ready

La CI vérifie structure/contrats, ShellCheck, résolution et installation Fedora 44, RPM Fusion/vendor/Flathub, GNOME 50, KVM, backup/recovery, VM Ubuntu 26.04 et invariants Golden Workstation.

## Runtime-certified

La machine réelle doit ensuite prouver : kernel courant >= 7.2.2, B580 liée à `xe`, display 1440p/~240 Hz sain, cold-start Nautilus courant, baseline RAM/NVMe et cinq cycles suspend/resume post-APPLY avec display repair récent.

Le dépôt ne confond jamais succès CI et preuve physique.

## Recovery

Les kernels Fedora restent disponibles en fallback. Un rollback désactive Kernel Vanilla puis distro-sync vers Fedora. Restic reste staging-first pour les restaurations et aucun helper n'écrase automatiquement le système live.

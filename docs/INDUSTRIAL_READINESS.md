# Industrial Readiness — Golden Workstation

La version applicable est celle de [`../VERSION`](../VERSION).

## Chaîne de confiance

```text
FEDORA 44 INSTALL
      ↓
PRE-APPLY HARDWARE BASELINE
      ↓
DRY-RUN + RESTIC BACKUP
      ↓
SYSTEM + KERNEL + FIRMWARE
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

La CI vérifie :

- structure et contrats ;
- ShellCheck/Bash ;
- résolution/installation Fedora 44 ;
- RPM Fusion, dépôts vendor et Flathub ;
- GNOME 50 ;
- multimédia ;
- KVM/libvirt ;
- backup/recovery ;
- VM Ubuntu 26.04 réelle ;
- supply-chain ;
- cohérence documentation ↔ code pour les invariants automatisables.

Un succès CI signifie que le dépôt est intégrable selon ses contrats automatisés. Il ne certifie pas le matériel physique.

## Runtime-certified

La machine réelle doit prouver notamment :

- kernel courant conforme ;
- Arc B580 liée à `xe` ;
- hardware/firmware sains ;
- display 1440p/~240 Hz sain ;
- cold-start Nautilus courant ;
- baseline RAM/NVMe ;
- desktop/portals/applications/lifecycle/Bash conformes ;
- socle KVM host sain ;
- guard `devops-nat` en mode normal avec isolation uplink ;
- cinq cycles suspend/resume post-APPLY ;
- matrice software known-good.

Le dépôt ne confond jamais succès CI et preuve physique.

## KVM readiness

Le réseau KVM entre en mode d'urgence restrictif avant tout recalcul lié à un changement de connectivité. Une reconstruction normale échouée ne doit donc jamais laisser une ancienne liste de LAN considérée comme encore sûre.

La création de la VM Ubuntu exige en outre l'authentification de l'image Canonical à partir de sa liste SHA-256 signée.

## Recovery

Les kernels Fedora restent disponibles comme fallback. Un rollback Kernel Vanilla ne supprime pas agressivement les kernels de secours.

Restic reste staging-first pour les restaurations et aucun helper n'écrase automatiquement le système live.

Les disques QCOW2 ne sont intégrés au backup qu'après arrêt de la VM et staging contrôlé via `qemu-img`.

## Critère pré-1.0

La 1.0 doit être décidée après :

```text
installation bare-metal propre
        +
certification finale PASS
        +
KVM/VM réellement exploités
        +
backup/restore réellement vérifiés
        +
période d'usage quotidien stable
```

L'ajout de nouvelles fonctions n'est pas, à lui seul, un critère de maturité.

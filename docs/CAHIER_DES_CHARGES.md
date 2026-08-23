# Cahier des charges V1.2 — Fedora 44 GNOME Workstation

## Finalité

Créer une workstation Fedora 44 GNOME 50 reproductible, stable et observable pour un usage DevOps/Ops, sans transformer Fedora en distribution FrankenLinux.

## Phase 0 — Hardware Baseline Certification

Avant toute convergence réelle, la machine de référence doit être certifiée sur son matériel et son BIOS courants. Cette certification est un gate P0 et comprend :

- plateforme/UEFI/BIOS identifiés ;
- Ryzen 7 7700 et AMD-V ;
- 48 Go de RAM ;
- test mémoire validé en DDR5-5600 SPD ;
- test mémoire validé en DDR5-6000 XMP ;
- Intel Arc B580 `8086:e20b` attachée à `xe` ;
- deux Crucial T705 présents ;
- test I/O soutenu validé sans reboot ni erreur fatale ;
- au moins 5 cycles suspend/resume propres ;
- absence de signatures critiques MCE/EDAC, kernel panic/oops, GPU wedged/reset failure, PCIe uncorrected et NVMe reset/I/O error pendant la certification.

Le certificat est lié à une empreinte matériel + BIOS. Une modification de cette empreinte invalide automatiquement la certification et bloque `--apply` jusqu'à nouvelle validation.

Voir `HARDWARE_BASELINE_CERTIFICATION.md`.

## P0 — bloquants

- Phase 0 certifiée avant APPLY réel.
- Fedora 44 et SELinux Enforcing.
- Ryzen 7 7700 et 48 Go de RAM correctement détectés.
- Intel Arc B580 `8086:e20b` attachée au pilote `xe`.
- Aucun dépôt GPU tiers, `force_probe` ou paramètre kernel expérimental par défaut.
- Wayland comme session GNOME de référence.
- Collecte des resets/hangs `xe`, erreurs DRM, PCIe AER, ACPI et NVMe.
- 2× Crucial T705 présents et contrôlables.
- Instrumentation suspend/resume pré/post sans modifier automatiquement `s2idle`/`deep`.
- Analyse du boot précédent, coredumps et pstore après redémarrage anormal.
- Dry-run du même commit et backup pré-APPLY vérifié avant mutation réelle.
- Aucun partitionnement/formatage automatique.

## P1 — expérience et exploitation

- GNOME/Nautilus : GVfs, SMB, MTP, portails et intégration desktop cohérente.
- Applications graphiques gérées automatiquement : **GTK4 + libadwaita uniquement**.
- **Ptyxis** comme terminal de référence et intégration terminal Nautilus conforme au comportement Fedora.
- Catalogue applicatif versionné dans `manifests/packages-applications-gtk4.txt` et documenté dans `GTK4_APPLICATIONS.md`.
- Codecs/miniatures via RPM Fusion explicitement géré.
- KVM/QEMU/libvirt + OVMF/TPM, NAT dédié et GPU principal conservé par le HOST.
- Restic pour backup/restauration.
- Diagnostics lisibles et rapports persistants.

## Politique applicative

Les applications graphiques installées par le dépôt doivent être validées contre Fedora 44 et déclarer les composants GTK4/libadwaita attendus. Toute nouvelle application graphique doit passer le contrat CI avant intégration au manifeste.

Cette règle ne concerne pas les outils CLI, les services système, les composants de virtualisation ni les outils DevOps sans interface graphique.

## P2 — options

- Extensions GNOME tierces uniquement en opt-in.
- HDR/VRR : observation d'abord, activation seulement après validation matérielle/régression.
- VM DevOps automatisée : phase suivante, profil explicite et non créée pendant l'installation HOST par défaut.

## Ordre d'exécution

```text
BASELINE
  ↓
SYSTEM
  ↓
HARDWARE
  ↓
GNOME
  ↓
APPLICATIONS
  ↓
KVM
  ↓
BACKUP
```

Les futures phases VM_DEVOPS et FINAL compléteront cet ordre conformément au cahier des charges global.

## Critère de réussite

La machine ne doit pas seulement fonctionner : lorsqu'un incident graphique, une mauvaise reprise de veille ou un redémarrage survient, le dépôt doit conserver assez de preuves pour isoler la couche fautive avant toute correction. Aucune personnalisation ne doit masquer une baseline matérielle non certifiée, et aucune application graphique non conforme à la politique GTK4/libadwaita ne doit être auto-gérée.

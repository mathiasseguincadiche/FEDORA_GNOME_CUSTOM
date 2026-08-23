# Cahier des charges — Fedora 44 GNOME Workstation

## Finalité

Créer une workstation Fedora 44 GNOME 50 reproductible, stable et observable pour un usage DevOps/Ops, sans transformer Fedora en distribution FrankenLinux.

## P0 — bloquants

- Fedora 44 et SELinux Enforcing.
- Ryzen 7 7700 et 48 Go de RAM correctement détectés.
- Intel Arc B580 `8086:e20b` attachée au pilote `xe`.
- Aucun dépôt GPU tiers, `force_probe` ou paramètre kernel expérimental par défaut.
- Wayland comme session GNOME de référence.
- Collecte des resets/hangs `xe`, erreurs DRM, PCIe AER, ACPI et NVMe.
- 2× Crucial T705 présents et contrôlables avec `nvme-cli`.
- Instrumentation suspend/resume pré/post sans modifier automatiquement `s2idle`/`deep`.
- Analyse du boot précédent, coredumps et pstore après redémarrage anormal.
- Dry-run du même commit et backup pré-APPLY vérifié avant mutation réelle.
- Aucun partitionnement/formatage automatique.

## P1 — expérience et exploitation

- GNOME/Nautilus : GVfs, SMB, MTP, archives, previews, portails et terminal contextuel.
- Codecs/miniatures via RPM Fusion explicitement géré.
- KVM/QEMU/libvirt + OVMF/TPM, NAT dédié et GPU principal conservé par le HOST.
- Restic pour backup/restauration.
- Diagnostics lisibles et rapports persistants.

## P2 — options

- Extensions GNOME tierces uniquement en opt-in.
- HDR/VRR : observation d'abord, activation seulement après validation matérielle/régression.
- VM DevOps automatisée : phase suivante, profil explicite et non créée pendant l'installation HOST par défaut.

## Critère de réussite

La machine ne doit pas seulement fonctionner : lorsqu'un incident graphique, une mauvaise reprise de veille ou un redémarrage survient, le dépôt doit conserver assez de preuves pour isoler la couche fautive avant toute correction.

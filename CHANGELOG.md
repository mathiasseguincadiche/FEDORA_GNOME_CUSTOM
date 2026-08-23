# Changelog

## 0.3.0 — 2026-08-22

- Ajout d'un scope `APPLICATIONS` séparé du socle GNOME.
- Politique stricte : seules les applications graphiques GTK4/libadwaita vérifiées sont gérées automatiquement.
- Ptyxis devient le terminal de référence du projet.
- Ajout d'un manifeste applicatif dédié et d'un catalogue documenté.
- Nautilus reste centré sur GVfs/SMB/MTP/FUSE et utilise l'intégration Fedora prévue avec Ptyxis.
- Ajout d'un contrat CI pour contrôler la politique GTK4/libadwaita et la résolution des paquets Fedora 44.

## 0.2.0 — 2026-08-22

- Ajout de la Phase 0 `BASELINE` avant toute convergence réelle.
- Certification liée à une empreinte matériel + BIOS.
- Preuves séparées DDR5-5600 SPD et DDR5-6000 XMP.
- Gate de test I/O soutenu des Crucial T705.
- Minimum de 5 cycles suspend/resume validés avant certification.
- Ajout de `diagnostics/baseline-doctor` pour snapshots, preuves, statut et certification.
- `--apply` est désormais fail-closed si la baseline matérielle n'est pas certifiée.
- Documentation V1.1 et tests de politique mis à jour.

## 0.1.0 — 2026-08-22

- Fondation Fedora 44 GNOME 50 workstation-as-code.
- Moteur PRECHECK / PLAN / APPLY / POSTCHECK avec dry-run et gates.
- Profil matériel Ryzen 7 7700 / 48 Go DDR5-6000 / Intel Arc B580 / OLED 1440p 240 Hz.
- Modules P0 stabilité graphique, NVMe, suspend/resume et post-incident.
- Intégration GNOME/Nautilus, KVM/libvirt et Restic.
- CI ShellCheck, tests de structure et préflight des paquets Fedora 44.

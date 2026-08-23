# Cahier des charges V1.3 — Fedora 44 GNOME Workstation

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
- Applications graphiques du bureau gérées automatiquement : **GTK4 + libadwaita uniquement**, hors exception virtualisation définie ci-dessous.
- **Ptyxis** comme terminal de référence et intégration terminal Nautilus conforme au comportement Fedora.
- Catalogue applicatif versionné dans `manifests/packages-applications-gtk4.txt` et documenté dans `GTK4_APPLICATIONS.md`.
- Pile multimédia complète et explicite : GStreamer Fedora + OpenH264 + FFmpeg complet et plugins freeworld RPM Fusion.
- `ffmpeg-free` doit être remplacé proprement par le fournisseur `ffmpeg` RPM Fusion quand le profil multimédia complet est actif.
- Arc B580 : VA-API H.264/HEVC/AV1/VP9 mesuré avec `vainfo`; aucun changement de pilote média sur simple supposition.
- KVM/QEMU/libvirt + OVMF/TPM, NAT dédié et GPU principal conservé par le HOST.
- Environnement de virtualisation complet avec **virt-manager** et **virt-viewer**, même s'ils ne suivent pas la politique GTK4/libadwaita du bureau.
- Restic pour backup/restauration.
- Diagnostics lisibles et rapports persistants.

## Politique applicative

Les applications graphiques de bureau installées par le dépôt doivent être validées contre Fedora 44 et déclarer les composants GTK4/libadwaita attendus. Toute nouvelle application graphique ajoutée au catalogue desktop doit passer le contrat CI avant intégration au manifeste.

### Exception explicite : virtualisation

La règle GTK4/libadwaita ne s'applique **pas** aux outils graphiques de virtualisation nécessaires à un environnement KVM/libvirt complet. `virt-manager` et `virt-viewer` sont donc conservés comme outils de référence, y compris s'ils reposent encore sur une pile GTK antérieure.

Cette exception est strictement limitée au scope `KVM` / virtualisation. Elle ne permet pas d'introduire arbitrairement des applications GTK3 dans le bureau GNOME général.

Les outils CLI, services système, composants de virtualisation et outils DevOps sans interface graphique sont également hors du contrat GTK4 desktop.

## Politique multimédia

La pile multimédia doit être reproductible et contrôlée par paquets explicites, sans dépendre d'un groupe de paquets opaque.

La base Fedora fournit GStreamer `base`, `good`, `bad-free` et le plugin OpenH264. RPM Fusion complète cette base avec `ffmpeg`, `ffmpegthumbnailer`, `bad-freeworld`, `ugly` et `libav`.

Le pilote média Intel Fedora `libva-intel-media-driver` est conservé par défaut. Avec `INTEL_MEDIA_DRIVER_POLICY=auto`, le projet ne bascule vers `intel-media-driver` RPM Fusion que si un probe VA-API valide sur l'Arc B580 montre qu'un ou plusieurs profils H.264/HEVC/AV1/VP9 requis sont absents. Si le probe est impossible, le projet conserve le fournisseur courant et remonte un avertissement au lieu de deviner.

Voir `MULTIMEDIA_CODECS.md` et `diagnostics/media-doctor`.

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

La machine ne doit pas seulement fonctionner : lorsqu'un incident graphique, une mauvaise reprise de veille ou un redémarrage survient, le dépôt doit conserver assez de preuves pour isoler la couche fautive avant toute correction. Aucune personnalisation ne doit masquer une baseline matérielle non certifiée. Le catalogue desktop doit rester GTK4/libadwaita, le scope de virtualisation peut conserver les outils graphiques nécessaires à une stack KVM/libvirt complète et maintenable, et la pile multimédia doit être vérifiable avec un fournisseur FFmpeg complet et des capacités VA-API mesurées.

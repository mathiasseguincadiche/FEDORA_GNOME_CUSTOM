# FEDORA_GNOME_CUSTOM

Workstation-as-code pour **Fedora Linux 44 Workstation / GNOME 50**, conçue autour d'une workstation AMD Ryzen 7 7700 + Intel Arc B580 et d'un usage DevOps/Ops orienté infrastructure.

## Objectif

Construire une Fedora GNOME cohérente, stable, reproductible et observable tout en conservant les fondations Fedora : DNF5/RPM, SELinux, firewalld, Wayland, PipeWire, Flatpak et KVM/libvirt.

La priorité absolue est la **stabilité** : graphique, veille/réveil, CPU/RAM, PCIe/NVMe, virtualisation et redémarrages. Aucun tweak kernel, C-State, ASPM, sysctl ou paramètre GPU expérimental n'est appliqué sans preuve diagnostique.

## Machine de référence

- MSI MAG B850M Mortar WiFi — BIOS 1.A63 (26/06/2026)
- AMD Ryzen 7 7700 — 8C/16T
- 48 Go DDR5-6000 — 2×24 Go G.Skill F5-6000J3036F24G
- Intel Arc B580 12 Go — PCI 8086:e20b — pilote attendu `xe`
- 2× Crucial T705 1 To + SSD externe XS1000 1 To
- ASUS ROG Strix OLED XG27AQDMES — 2560×1440 / 240 Hz
- Logitech Brio 100

## Principes

1. **Hardware baseline d'abord** : aucune convergence réelle avant certification de la machine de référence.
2. **Read-only d'abord** : diagnostic et inventaire avant mutation.
3. **Dry-run obligatoire** avant `--apply`.
4. **Fail-closed** : un contrôle P0 en échec bloque l'APPLY.
5. **Fedora officiel d'abord** ; RPM Fusion uniquement pour les besoins multimédia explicitement activés.
6. **Aucun dépôt GPU tiers** : kernel, firmware, Mesa et pilote `xe` Fedora.
7. **Aucun partitionnement/formatage automatique**.
8. **SELinux reste Enforcing** et firewalld actif.
9. **Wayland est la session de référence**.
10. **Applications GNOME cohérentes** : GTK4/libadwaita pour le bureau ; Ptyxis comme terminal. Les outils KVM essentiels disposent d'une exception documentée.
11. **Multimédia complet mais contrôlé** : GStreamer Fedora, OpenH264, FFmpeg complet RPM Fusion, oneVPL/QSV et VA-API Arc B580 mesuré avant changement de fournisseur média.
12. **Virtualisation complète mais isolée** : QEMU/KVM/libvirt, OVMF, TPM 2.0, VirtioFS, libosinfo, virt-manager/virt-viewer, stockage dédié et réseau privé.
13. **Diagnostic post-incident** : boot précédent, coredumps, pstore, xe/DRM, ACPI, PCIe AER, NVMe.
14. **Intel Arc B580 au HOST** : aucun VFIO/passthrough automatique.

## Phase 0 — Hardware Baseline Certification

Avant toute personnalisation réelle, la machine doit être certifiée sur la configuration matérielle/BIOS courante. La certification demande notamment :

- un test mémoire validé en DDR5-5600 SPD ;
- un test mémoire validé en DDR5-6000 XMP ;
- un test I/O soutenu des T705 sans reboot ni erreur fatale ;
- au moins 5 cycles suspend/resume propres ;
- Ryzen 7 7700, Arc B580/`xe` et deux T705 présents ;
- aucune signature kernel critique détectée pendant la certification.

Le marqueur de certification est lié à une empreinte matériel + BIOS. Une modification significative du matériel ou du BIOS invalide automatiquement l'ancien certificat.

```bash
bash diagnostics/baseline-doctor status
bash diagnostics/baseline-doctor snapshot
bash diagnostics/baseline-doctor record-memory 5600 PASS
bash diagnostics/baseline-doctor record-memory 6000 PASS
bash diagnostics/baseline-doctor record-nvme-io PASS
bash diagnostics/baseline-doctor record-suspend PASS   # à répéter au moins 5 fois
bash diagnostics/baseline-doctor certify
```

Les commandes `record-*` enregistrent une preuve opérateur et un snapshot ; elles ne remplacent pas les tests matériels eux-mêmes.

## Pré-requis stockage KVM

Le second Crucial T705 est réservé à la virtualisation. Le projet **ne le partitionne et ne le formate jamais**. Avant un APPLY incluant KVM, il doit être monté manuellement à :

```text
/data
filesystem attendu : EXT4
```

Le projet crée ensuite uniquement l'arborescence `/data/libvirt/`, les labels SELinux appropriés et le pool `devops-data`.

## Flux d'exécution

```text
Fedora 44 fraîche
        ↓
Hardware Baseline Certification
        ↓
Montage manuel du T705 KVM sur /data
        ↓
Diagnostic read-only
        ↓
Dry-run complet
        ↓
Backup pré-APPLY vérifié
        ↓
APPLY protégé
        ↓
Postchecks
        ↓
workstation-doctor
```

```bash
./diagnostic.sh
./install.sh --dry-run
./install.sh --apply
./menu.sh
```

## Domaines

- `baseline` : certification matérielle/firmware, DDR5 5600/6000, NVMe I/O, Arc B580 et suspend/resume.
- `system` : Fedora 44, DNF5, firmware, sécurité, sources de paquets.
- `hardware` : CPU/RAM, Intel Arc, Wayland/display, NVMe, périphériques, suspend/resume.
- `gnome` : GNOME, Nautilus, GVfs/SMB/MTP, portails, multimédia, réglages prudents.
- `applications` : catalogue GTK4/libadwaita et Ptyxis.
- `virtualization` : KVM/QEMU/libvirt, OVMF/TPM, VirtioFS, osinfo, pool T705, `devops-nat`, virt-manager/virt-viewer et profils VM.
- `backup` : Restic, validation et préparation pré-APPLY.
- `diagnostics` : baseline/workstation/graphics/suspend/storage/GNOME/applications/media/virtualization doctors.

## Virtualisation

La connexion libvirt de référence est `qemu:///system`. Le pipeline KVM est :

```text
preflight
  ↓
stack libvirt Fedora
  ↓
UEFI / TPM
  ↓
stockage T705 / SELinux
  ↓
devops-nat / firewalld / isolation LAN
  ↓
libosinfo
  ↓
CLI
  ↓
virt-manager / virt-viewer
  ↓
profils Ubuntu Server / Fedora / Windows 11
  ↓
validation
```

Le réseau de référence est `192.168.50.0/24` sur `virbr50`. HOST↔VM, VM↔VM et VM→Internet sont prévus ; VM→LAN et LAN→VM sont bloqués par un guard nftables possédé uniquement par le projet, sans désactiver firewalld.

Diagnostic :

```bash
bash diagnostics/virtualization-doctor
```

Les preuves de trafic réseau bout-en-bout nécessitent des VM réellement démarrées et sont donc certifiées sur la vraie workstation après installation ; aucune VM n'est créée automatiquement pour un test.

## Applications et multimédia

La sélection graphique est documentée dans `docs/GTK4_APPLICATIONS.md`. La source de vérité installable est `manifests/packages-applications-gtk4.txt`.

La politique codecs/FFmpeg/GStreamer/VA-API est documentée dans `docs/MULTIMEDIA_CODECS.md` :

```bash
bash diagnostics/media-doctor
```

## État du projet

- `0.1.0` : fondation Fedora 44 ;
- `0.2.0` : Hardware Baseline Certification ;
- `0.3.0` : applications GTK4/libadwaita + Ptyxis ;
- `0.4.0` : pile multimédia complète ;
- `0.5.0` : stack KVM/QEMU/libvirt complète et Fedora-native.

Lire `docs/CAHIER_DES_CHARGES.md`, `docs/HARDWARE_BASELINE_CERTIFICATION.md`, `docs/GTK4_APPLICATIONS.md`, `docs/MULTIMEDIA_CODECS.md`, `docs/VIRTUALIZATION.md`, `docs/VM_PROFILES.md` et `docs/EXECUTION_CONTRACT.md` avant le premier APPLY réel.

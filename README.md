# FEDORA_GNOME_CUSTOM

Workstation-as-code pour **Fedora Linux 44 Workstation / GNOME 50**, conçue autour d'une workstation AMD Ryzen 7 7700 + Intel Arc B580 et d'un usage DevOps/Ops orienté infrastructure.

## Objectif

Construire une Fedora GNOME aussi cohérente et intégrée qu'une Ubuntu Desktop bien finie, tout en conservant les fondations Fedora : DNF5/RPM, SELinux, firewalld, Wayland, PipeWire, Flatpak et KVM/libvirt.

La priorité absolue est la **stabilité** : graphique, veille/réveil, CPU/RAM, PCIe/NVMe et redémarrages. Aucun tweak kernel, C-State, ASPM, sysctl ou paramètre GPU expérimental n'est appliqué sans preuve diagnostique.

## Machine de référence

- MSI MAG B850M Mortar WiFi — BIOS 1.A63 (26/06/2026)
- AMD Ryzen 7 7700 — 8C/16T
- 48 Go DDR5-6000 — 2×24 Go G.Skill F5-6000J3036F24G
- Intel Arc B580 12 Go — PCI 8086:e20b — pilote attendu `xe`
- 2× Crucial T705 1 To + SSD externe XS1000 1 To
- ASUS ROG Strix OLED XG27AQDMES — 2560×1440 / 240 Hz
- Logitech Brio 100

## Principes

1. **Read-only d'abord** : diagnostic et inventaire avant mutation.
2. **Dry-run obligatoire** avant `--apply`.
3. **Fail-closed** : un contrôle P0 en échec bloque l'APPLY.
4. **Fedora officiel d'abord** ; RPM Fusion uniquement pour les besoins multimédia explicitement activés.
5. **Aucun dépôt GPU tiers** : kernel, firmware, Mesa et pilote `xe` Fedora.
6. **Aucun partitionnement/formatage automatique**.
7. **SELinux reste Enforcing** et firewalld actif.
8. **Wayland est la session de référence**.
9. **Diagnostic post-incident** : boot précédent, coredumps, pstore, xe/DRM, ACPI, PCIe AER, NVMe.
10. **KVM/libvirt** pour les laboratoires et VM DevOps ; pas de VFIO/passthrough du GPU principal.

## Flux d'exécution

```text
Diagnostic read-only
        ↓
Dry-run complet
        ↓
Backup pré-APPLY vérifié (si exigé)
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

- `system` : Fedora 44, DNF5, firmware, sécurité, sources de paquets.
- `hardware` : CPU/RAM, Intel Arc, Wayland/display, NVMe, périphériques, suspend/resume.
- `gnome` : GNOME, Nautilus, GVfs/SMB/MTP, portails, multimédia, réglages prudents.
- `virtualization` : KVM/QEMU/libvirt, UEFI/TPM, réseau NAT.
- `backup` : Restic, validation et préparation pré-APPLY.
- `diagnostics` : workstation/graphics/suspend/storage/GNOME doctors.

## État du projet

Version initiale : `0.1.0`. Lire `docs/CAHIER_DES_CHARGES.md` et `docs/EXECUTION_CONTRACT.md` avant le premier APPLY réel.

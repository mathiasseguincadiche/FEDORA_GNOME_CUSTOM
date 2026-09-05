# Documentation — commencer ici

Cette documentation explique comment installer, administrer, certifier et dépanner FEDORA_GNOME_CUSTOM sans devoir lire tous les scripts internes.

La version du projet est celle du fichier [`../VERSION`](../VERSION).

## Utilisation quotidienne

```bash
./control.sh
```

Lire [`CONTROL_CENTER.md`](CONTROL_CENTER.md) pour le cockpit interactif et le mode CLI.

## Parcours recommandé

1. [`../README.md`](../README.md) — contrat Golden et invariants ;
2. [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — interface opérateur ;
3. [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture ;
4. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — installation bare-metal ;
5. [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) — qualification physique ;
6. [`GOLDEN_RELEASE.md`](GOLDEN_RELEASE.md) — reproductibilité et manifeste ;
7. [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — runbook principal ;
8. [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md) — ReBAR/PCIe/NVMe/EDID/kernel/offline ;
9. [`adr/README.md`](adr/README.md) — décisions d'architecture.

## Validation avant production

Le parcours est progressif :

1. [`WSL2_VALIDATION.md`](WSL2_VALIDATION.md) — CLI/read-only ;
2. [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) — LAB GNOME 50/Wayland ;
3. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — bare-metal.

Le LAB VirtualBox possède son propre entrypoint limité et **ne déverrouille jamais `install.sh --apply`**.

## Chaîne bare-metal

```text
Fedora 44 fraîche
      ↓
baseline hardware
      ↓
./install.sh --dry-run
      ↓
backup Restic + restore canary
      ↓
./install.sh --apply
      ↓
kernel candidate → boot one-shot
      ↓
qualification physique
      ↓
final certification + golden-release.json
```

## Domaines

### Hardware / kernel

- [`HARDWARE_STABILITY.md`](HARDWARE_STABILITY.md)
- [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md)
- [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md)

### GNOME / desktop

- [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md)
- [`GNOME_PROFILE.md`](GNOME_PROFILE.md)
- [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md)
- [`RESOURCE_MONITOR.md`](RESOURCE_MONITOR.md)
- [`NAUTILUS.md`](NAUTILUS.md)
- [`PTYXIS.md`](PTYXIS.md)
- [`DOCK_FAVORITES.md`](DOCK_FAVORITES.md)

### Applications / multimédia

- [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md)
- [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md)
- [`MULTIMEDIA_CODECS.md`](MULTIMEDIA_CODECS.md)
- [`APPIMAGE.md`](APPIMAGE.md)
- [`GAMING.md`](GAMING.md)

### KVM / VM

- [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md)
- [`VIRTUALIZATION.md`](VIRTUALIZATION.md)
- [`KVM_NETWORK.md`](KVM_NETWORK.md)
- [`VM_PROFILES.md`](VM_PROFILES.md)
- [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md)
- [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md)
- [`UBUNTU_DEVOPS_READY.md`](UBUNTU_DEVOPS_READY.md)

### Exploitation / sécurité

- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md)
- [`DESKTOP_LIFECYCLE.md`](DESKTOP_LIFECYCLE.md)
- [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md)
- [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md)
- [`CI_VALIDATION.md`](CI_VALIDATION.md)
- [`GITHUB_GOVERNANCE.md`](GITHUB_GOVERNANCE.md)

## Ordre d'autorité

```text
code + config + tests CI
        ↓
document normatif courant
        ↓
document historique / release note
```

Une contradiction code/documentation est un bug.

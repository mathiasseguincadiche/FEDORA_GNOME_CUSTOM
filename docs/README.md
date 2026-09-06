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
2. [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) — validation officielle WSL2 → VirtualBox → bare-metal ;
3. [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — interface opérateur ;
4. [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture ;
5. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — installation bare-metal ;
6. [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) — qualification physique ;
7. [`STACK_CERTIFICATION.md`](STACK_CERTIFICATION.md) — drivers, KVM/libvirt et applications en runtime ;
8. [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md) — fermeture CPU/cooling/BT/network/audio/GPU/VRR-HDR/Windows/backup ;
9. [`GOLDEN_RELEASE.md`](GOLDEN_RELEASE.md) — reproductibilité et manifeste ;
10. [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — runbook principal ;
11. [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md) — ReBAR/PCIe/NVMe/EDID/kernel/offline ;
12. [`adr/README.md`](adr/README.md) — décisions d'architecture.

## Validation avant production

Le parcours officiel est désormais une chaîne de preuves ordonnée :

1. **Gate 1** — [`WSL2_VALIDATION.md`](WSL2_VALIDATION.md) + [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) : Fedora 44/WSL2, système et logique uniquement ;
2. **Gate 2** — [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) : Fedora 44 GNOME 50/Wayland, Nautilus, Ptyxis, extensions et validation visuelle ;
3. **Gate 3** — [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md) + [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) : Fedora 44 bare-metal et certification Golden complète.

Gate 1 et Gate 2 produisent des preuves JSON portables avec `hardware_certification=DEFERRED`. Gate 2 référence le SHA-256 exact de Gate 1. Gate 3 refuse `final-certification PASS` si cette chaîne est absente ou périmée.

Le LAB VirtualBox possède son propre entrypoint limité et **ne déverrouille jamais `install.sh --apply`**.

## Chaîne bare-metal

```text
Gate 1 PASS + Gate 2 PASS
      ↓
Fedora 44 fraîche
      ↓
baseline hardware + CPU soak + BT/cooling locks
      ↓
./install.sh --dry-run
      ↓
backup Restic + restore canary
      ↓
./install.sh --apply
      ↓
kernel candidate → boot one-shot
      ↓
qualification physique + drivers/runtime
      ↓
GPU/network/audio/VRR-HDR + KVM/Windows live proofs
      ↓
Gate 3 final certification + golden-release.json
```

## Domaines

### Hardware / kernel / drivers

- [`HARDWARE_STABILITY.md`](HARDWARE_STABILITY.md)
- [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md)
- [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md)
- [`STACK_CERTIFICATION.md`](STACK_CERTIFICATION.md)
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

- [`STACK_CERTIFICATION.md`](STACK_CERTIFICATION.md)
- [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md)
- [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md)
- [`MULTIMEDIA_CODECS.md`](MULTIMEDIA_CODECS.md)
- [`APPIMAGE.md`](APPIMAGE.md)
- [`GAMING.md`](GAMING.md)

### KVM / VM

- [`STACK_CERTIFICATION.md`](STACK_CERTIFICATION.md)
- [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md)
- [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md)
- [`VIRTUALIZATION.md`](VIRTUALIZATION.md)
- [`KVM_NETWORK.md`](KVM_NETWORK.md)
- [`VM_PROFILES.md`](VM_PROFILES.md)
- [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md)
- [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md)
- [`UBUNTU_DEVOPS_READY.md`](UBUNTU_DEVOPS_READY.md)

### Exploitation / sécurité

- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md)
- [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md)
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

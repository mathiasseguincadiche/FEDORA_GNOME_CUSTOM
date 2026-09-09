# Documentation — Fedora 44 Golden Workstation

Ce portail regroupe la documentation d'installation, d'exploitation, de certification et de dépannage de **FEDORA_GNOME_CUSTOM**.

La version active est celle du fichier [`../VERSION`](../VERSION).

## Commencer ici

Pour l'utilisation quotidienne :

```bash
./control.sh
```

Puis lire, selon le besoin :

- [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — cockpit interactif et CLI ;
- [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — installation bare-metal complète ;
- [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture et invariants ;
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — dépannage par symptôme.

Le README racine [`../README.md`](../README.md) reste la vitrine et le guide d'entrée du projet.

---

## Installer et préparer la machine

1. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — média, Kickstart, `/data`, baseline, dry-run, backup, APPLY ;
2. [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) — qualification CPU/RAM/NVMe/hardware ;
3. [`HARDWARE_STABILITY.md`](HARDWARE_STABILITY.md) — stabilité et critères de rejet ;
4. [`HOST_SECURITY_POLICY.md`](HOST_SECURITY_POLICY.md) — politique Secure Boot / chiffrement local / sécurité HOST.

---

## Comprendre l'architecture

- [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture globale ;
- [`CAHIER_DES_CHARGES.md`](CAHIER_DES_CHARGES.md) — exigences normatives ;
- [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md) — règles d'exécution et mutations ;
- [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md) — inventaire logiciel ;
- [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md) — provenance et intégrité ;
- [`GLOSSARY.md`](GLOSSARY.md) — vocabulaire ;
- [`adr/README.md`](adr/README.md) — décisions d'architecture.

### Hardware / kernel / drivers

- [`STACK_CERTIFICATION.md`](STACK_CERTIFICATION.md)
- [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md)
- [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md)

### GNOME / desktop

- [`GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md`](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md)
- [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md)
- [`GNOME_PROFILE.md`](GNOME_PROFILE.md)
- [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md)
- [`RESOURCE_MONITOR.md`](RESOURCE_MONITOR.md)
- [`NAUTILUS.md`](NAUTILUS.md)
- [`PTYXIS.md`](PTYXIS.md)
- [`DOCK_FAVORITES.md`](DOCK_FAVORITES.md)

### Applications / multimédia / Gaming

- [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md)
- [`MULTIMEDIA_CODECS.md`](MULTIMEDIA_CODECS.md)
- [`APPIMAGE.md`](APPIMAGE.md)
- [`GAMING.md`](GAMING.md)

---

## Virtualisation

Pour démarrer : [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md).

Puis :

- [`VIRTUALIZATION.md`](VIRTUALIZATION.md) — architecture KVM/libvirt ;
- [`KVM_NETWORK.md`](KVM_NETWORK.md) — réseau `devops-nat` fail-closed ;
- [`VM_PROFILES.md`](VM_PROFILES.md) — Ubuntu DevOps / Windows 11 ;
- [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md) — accès fichiers ;
- [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md) — commandes avancées ;
- [`UBUNTU_DEVOPS_READY.md`](UBUNTU_DEVOPS_READY.md) — bootstrap Ubuntu.

---

## Exploitation quotidienne

- [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — surface opérateur ;
- [`DESKTOP_LIFECYCLE.md`](DESKTOP_LIFECYCLE.md) — maintenance desktop ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — Restic, restore et disaster recovery ;
- [`GOLDEN_RELEASE.md`](GOLDEN_RELEASE.md) — bundle Golden et archivage ;
- [`CI_VALIDATION.md`](CI_VALIDATION.md) — validation automatisée ;
- [`GITHUB_GOVERNANCE.md`](GITHUB_GOVERNANCE.md) — gouvernance du dépôt.

Pour contribuer au dépôt : [`../CONTRIBUTING.md`](../CONTRIBUTING.md).

---

## Dépannage

Commencer par :

```bash
./control.sh status
./control.sh doctor all
```

Puis utiliser :

- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — runbook principal ;
- [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md) — ReBAR/PCIe/NVMe/EDID/kernel/offline ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — restauration ;
- [`KVM_NETWORK.md`](KVM_NETWORK.md) — réseau KVM.

Ne pas désactiver SELinux, firewalld ou les garde-fous fail-closed pour masquer une erreur.

---

# Validation officielle

La validation est une chaîne de preuves. Elle ne remplace pas l'installation ; elle encadre ce qui peut être affirmé comme Golden.

```text
Gate 1 — Fedora 44 / WSL2
  système + contrats, hardware DEFERRED
        ↓
Gate 2 — Fedora 44 GNOME / VirtualBox
  desktop + UX, hardware DEFERRED
        ↓
Installation Fedora 44 bare-metal
        ↓
Gate 3 — vraie machine
  hardware + runtime + KVM + Gaming + backup
        ↓
final-certification PASS
```

### Gate 1

- [`WSL2_VALIDATION.md`](WSL2_VALIDATION.md)
- [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md)

### Gate 2

- [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md)
- [`GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md`](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md)

### Gate 3

- [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md)
- [`GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md`](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md)
- [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md)

Gate 1 et Gate 2 produisent des preuves JSON avec `hardware_certification=DEFERRED`. Gate 2 référence le SHA-256 exact de Gate 1. Gate 3 refuse `final-certification PASS` si la chaîne de preuves est absente, périmée ou si le runtime physique ne correspond plus.

Le LAB VirtualBox reste strictement limité au desktop et **ne déverrouille jamais `install.sh --apply`**.

---

## Ordre d'autorité

```text
code + config + tests CI
        ↓
document normatif courant
        ↓
document historique / release note
```

Une contradiction entre code, configuration et documentation est un bug.

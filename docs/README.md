# Documentation — Fedora 44 Golden Workstation

Ce portail est la table des matières officielle de **FEDORA_GNOME_CUSTOM**. Le README racine reste la vitrine ; ici, la documentation est organisée par rôle afin de savoir immédiatement si l'on cherche une norme, une procédure, une référence ou un runbook.

La version active est celle de [`../VERSION`](../VERSION).

## Commencer ici

Utilisation quotidienne :

```bash
./control.sh
```

Parcours recommandés :

- installer : [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) ;
- exploiter : [`CONTROL_CENTER.md`](CONTROL_CENTER.md) ;
- comprendre la Golden : [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) ;
- utiliser KVM : [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) ;
- dépanner : [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

Le modèle documentaire et l'ordre d'autorité sont définis dans [`DOCUMENTATION_MODEL.md`](DOCUMENTATION_MODEL.md).

---

# 1. Normes — ce que la workstation doit être

- [`CAHIER_DES_CHARGES.md`](CAHIER_DES_CHARGES.md) — exigences normatives ;
- [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture et invariants Golden ;
- [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md) — dry-run/APPLY/mutations ;
- [`HOST_SECURITY_POLICY.md`](HOST_SECURITY_POLICY.md) — politique sécurité HOST ;
- [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md) — inventaire logiciel de référence ;
- [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md) — provenance et intégrité ;
- [`adr/README.md`](adr/README.md) — décisions d'architecture acceptées/superseded.

---

# 2. Installation — construire et préparer la machine

1. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — média, Kickstart, second T705, baseline, dry-run, backup, APPLY ;
2. [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) — qualification CPU/RAM/NVMe/hardware ;
3. [`HARDWARE_STABILITY.md`](HARDWARE_STABILITY.md) — stabilité et critères de rejet ;
4. [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) — chaîne Gate 1 → Gate 2 → installation → Gate 3 ;
5. [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) — LAB Gate 2 isolé de l'APPLY production.

---

# 3. Guides opérateur — quoi lancer au quotidien

- [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — cockpit interactif et CLI ;
- [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) — cycle de vie VM courant ;
- [`GAMING.md`](GAMING.md) — Steam/Vulkan/GameMode/`/data/Jeux` ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — Restic, restore et disaster recovery ;
- [`DESKTOP_LIFECYCLE.md`](DESKTOP_LIFECYCLE.md) — maintenance desktop ;
- [`DOCK_FAVORITES.md`](DOCK_FAVORITES.md) — favoris GNOME ;
- [`APPIMAGE.md`](APPIMAGE.md) — politique AppImage lorsque nécessaire.

---

# 4. Références techniques — comment c'est construit

## Hardware / kernel / drivers

- [`STACK_CERTIFICATION.md`](STACK_CERTIFICATION.md) — contrat de stack ;
- [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md) — fermeture des socles ;
- [`GLOSSARY.md`](GLOSSARY.md) — vocabulaire.

## GNOME / desktop

- [`GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md`](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md) ;
- [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md) ;
- [`GNOME_PROFILE.md`](GNOME_PROFILE.md) ;
- [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md) ;
- [`RESOURCE_MONITOR.md`](RESOURCE_MONITOR.md) ;
- [`NAUTILUS.md`](NAUTILUS.md) ;
- [`PTYXIS.md`](PTYXIS.md).

## Applications / multimédia

- [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md) ;
- [`MULTIMEDIA_CODECS.md`](MULTIMEDIA_CODECS.md).

## Virtualisation

- [`VIRTUALIZATION.md`](VIRTUALIZATION.md) — architecture KVM/libvirt ;
- [`VM_PROFILES.md`](VM_PROFILES.md) — profils exécutables Ubuntu/Windows ;
- [`KVM_NETWORK.md`](KVM_NETWORK.md) — réseau `devops-nat` fail-closed ;
- [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md) — accès fichiers ;
- [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md) — référence CLI avancée ;
- [`UBUNTU_DEVOPS_READY.md`](UBUNTU_DEVOPS_READY.md) — état attendu du guest Ubuntu ;
- [`UBUNTU_DEVOPS_PROVISIONING.md`](UBUNTU_DEVOPS_PROVISIONING.md) — provisioning Ubuntu.

---

# 5. Runbooks — partir d'un symptôme

Commencer par :

```bash
./control.sh status
./control.sh doctor all
```

Puis choisir le domaine :

- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — triage transversal ;
- [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md) — BIOS, P-State, ReBAR, PCIe, NVMe, EDID, kernel, offline update ;
- [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md) — libvirt, pool, réseau, guard, Ubuntu, Windows, QGA, TPM, sauvegarde VM ;
- [`RUNBOOK_PERSISTENT_DATA_GAMING.md`](RUNBOOK_PERSISTENT_DATA_GAMING.md) — `/data`, EXT4, ownership, SELinux, XDG Documents, Restic, Steam/Vulkan ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — restauration et DR ;
- [`KVM_NETWORK.md`](KVM_NETWORK.md) — détails d'isolation réseau.

Ne pas désactiver SELinux, firewalld ou les garde-fous fail-closed pour masquer une erreur.

---

# 6. Certification, CI et gouvernance

- [`CI_VALIDATION.md`](CI_VALIDATION.md) — validation automatisée ;
- [`GOLDEN_RELEASE.md`](GOLDEN_RELEASE.md) — bundle Golden et archivage ;
- [`GITHUB_GOVERNANCE.md`](GITHUB_GOVERNANCE.md) — gouvernance du dépôt ;
- [`DOCUMENTATION_MODEL.md`](DOCUMENTATION_MODEL.md) — règles de cohérence documentation ↔ code ;
- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — contribution.

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

- [`WSL2_VALIDATION.md`](WSL2_VALIDATION.md) ;
- [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md).

### Gate 2

- [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) ;
- [`GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md`](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md).

### Gate 3

- [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md) ;
- [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) ;
- [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md) ;
- [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md) ;
- [`RUNBOOK_PERSISTENT_DATA_GAMING.md`](RUNBOOK_PERSISTENT_DATA_GAMING.md).

Gate 1 et Gate 2 produisent des preuves JSON avec `hardware_certification=DEFERRED`. Gate 2 référence le SHA-256 exact de Gate 1. Gate 3 refuse `final-certification PASS` si la chaîne de preuves est absente, périmée ou si le runtime physique ne correspond plus.

Le LAB VirtualBox reste strictement limité au desktop et **ne déverrouille jamais `install.sh --apply`**.

---

## Ordre d'autorité

```text
code + config + tests CI
        ↓
document normatif courant
        ↓
guide / référence / runbook
        ↓
document historique / release note
```

Une contradiction active entre code, configuration et documentation est un bug.

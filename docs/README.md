# Documentation — commencer ici

Cette documentation explique comment **comprendre, installer, utiliser, valider et dépanner** FEDORA_GNOME_CUSTOM sans devoir lire les scripts internes en premier.

La version du projet est toujours celle du fichier [`../VERSION`](../VERSION). Les documents normatifs évitent volontairement de recopier un numéro de version dans leur titre afin de ne pas devenir obsolètes à chaque release.

## Je découvre le projet

Commencer dans cet ordre :

1. [`../README.md`](../README.md) — objectif global et contrat Golden Workstation ;
2. [`GLOSSARY.md`](GLOSSARY.md) — vocabulaire Fedora, KVM, libvirt, stockage et réseau ;
3. [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture et chaîne de confiance ;
4. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — installation bare-metal complète.

Un débutant n'a pas besoin de comprendre `virt-qemu-qmp-proxy`, `guestfish` ou les détails nftables avant d'installer la workstation. Ces sujets appartiennent aux documents de référence avancée.

## Je veux installer la workstation

Lire :

- [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — parcours principal ;
- [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) — tests RAM/NVMe avant APPLY ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — backup Restic obligatoire avant APPLY ;
- [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md) — différence diagnostic / dry-run / APPLY et protections.

Le parcours de confiance est :

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
reboot
      ↓
certification bare-metal
```

## Je veux utiliser KVM et les VM

Lire dans cet ordre :

1. [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) — commandes quotidiennes et premier démarrage ;
2. [`VIRTUALIZATION.md`](VIRTUALIZATION.md) — architecture KVM, stockage et réseau ;
3. [`KVM_NETWORK.md`](KVM_NETWORK.md) — fonctionnement précis de `devops-nat` et de l'isolation LAN ;
4. [`VM_PROFILES.md`](VM_PROFILES.md) — profils Ubuntu et Windows ;
5. [`UBUNTU_DEVOPS_READY.md`](UBUNTU_DEVOPS_READY.md) — contenu de la VM Ubuntu DevOps ;
6. [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md) — SFTP Ubuntu et SMB Windows depuis Nautilus ;
7. [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md) — référence CLI avancée.

## Je veux dépanner

Commencer par [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

Le runbook est organisé par symptôme :

- APPLY refusé ;
- paquet/repository en erreur ;
- GNOME/Wayland/portals ;
- GPU Arc B580 ;
- `/data` ou pool libvirt ;
- VM sans IP ;
- `devops-nat` / nftables ;
- cloud-init Ubuntu ;
- VirtIO/TPM/Guest Agent Windows ;
- Restic et restauration ;
- veille, affichage ou reboot anormal.

Ne désactiver ni SELinux ni firewalld pour « voir si ça marche ». Les doctors et logs sont conçus pour diagnostiquer sans supprimer les protections.

## Documents d'architecture

- [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture générale ;
- [`HARDWARE_STABILITY.md`](HARDWARE_STABILITY.md) — stratégie matériel/firmware/kernel ;
- [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md) — bureau GNOME 50/Wayland ;
- [`MULTIMEDIA_CODECS.md`](MULTIMEDIA_CODECS.md) — FFmpeg/GStreamer/VA-API/oneVPL ;
- [`DESKTOP_LIFECYCLE.md`](DESKTOP_LIFECYCLE.md) — services quotidiens et mises à jour ;
- [`VIRTUALIZATION.md`](VIRTUALIZATION.md) — hyperviseur, stockage et réseau ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — backup/recovery ;
- [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md) — provenance et signatures.

## Documents de référence

- [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md) — outils KVM/libvirt avancés ;
- [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md) — catalogue graphique et exceptions ;
- [`GNOME_PROFILE.md`](GNOME_PROFILE.md) — profil GNOME de référence ;
- [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md) — extensions gérées ;
- [`DOCK_FAVORITES.md`](DOCK_FAVORITES.md) — favoris certifiés ;
- [`HOST_BASH_UX.md`](HOST_BASH_UX.md) — Bash/Ptyxis ;
- [`CI_VALIDATION.md`](CI_VALIDATION.md) — ce que la CI prouve et ce qui reste bare-metal ;
- [`GITHUB_GOVERNANCE.md`](GITHUB_GOVERNANCE.md) — politique de branche/release.

## Documents historiques ou de transition

Certains documents décrivent une étape ayant conduit au contrat actuel. Ils restent utiles pour comprendre les décisions, mais ne sont pas la première source de vérité opérationnelle :

- [`PRE1_HARDENING.md`](PRE1_HARDENING.md) — consolidation de la release 0.10.0 ;
- [`WSL2_VALIDATION.md`](WSL2_VALIDATION.md) — validation intermédiaire sous WSL2 ;
- [`HARDWARE_KVM_COMPLETION.md`](HARDWARE_KVM_COMPLETION.md) — décisions de complétion hardware/KVM, désormais intégrées au contrat courant.

En cas de contradiction, l'ordre d'autorité est :

```text
code + config + tests CI
        ↓
document normatif courant
        ↓
document historique / release note
```

Une contradiction entre code et documentation est considérée comme un bug et doit faire échouer le contrat documentaire CI lorsque le cas est automatisable.

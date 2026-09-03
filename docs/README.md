# Documentation — commencer ici

Cette documentation explique comment **comprendre, administrer, installer, utiliser, valider et dépanner** FEDORA_GNOME_CUSTOM sans devoir lire les scripts internes en premier.

La version du projet est toujours celle du fichier [`../VERSION`](../VERSION). Les documents normatifs évitent volontairement de recopier un numéro de version dans leur titre afin de ne pas devenir obsolètes à chaque release.

## Je veux administrer la workstation au quotidien

Le point d'entrée recommandé est :

```bash
./control.sh
```

Lire [`CONTROL_CENTER.md`](CONTROL_CENTER.md) pour le cockpit interactif, son tableau de bord, les neuf socles opérateur et le mode CLI scriptable.

`./menu.sh` reste un alias de compatibilité. Les scripts spécialisés restent directement utilisables pour CI, dépannage et automatisation.

## Je découvre le projet

Commencer dans cet ordre :

1. [`../README.md`](../README.md) — objectif global et contrat Golden Workstation ;
2. [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — interface opérateur quotidienne ;
3. [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md) — inventaire explicite HOST Fedora + VM Ubuntu DevOps, dont le socle Python ;
4. [`GLOSSARY.md`](GLOSSARY.md) — vocabulaire Fedora, KVM, libvirt, stockage et réseau ;
5. [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture et chaîne de confiance ;
6. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — installation bare-metal complète.

Un débutant n'a pas besoin de comprendre `virt-qemu-qmp-proxy`, `guestfish` ou les détails nftables avant d'installer la workstation. Ces sujets appartiennent aux documents de référence avancée.

## Je veux valider avant le bare-metal

Le parcours de qualification est volontairement progressif :

1. [`WSL2_VALIDATION.md`](WSL2_VALIDATION.md) — GATE 1 CLI/read-only : scripts, runtime guards et contrats sans fabriquer de preuve hardware ;
2. [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) — GATE 2 Fedora 44 GNOME 50/Wayland : vraie convergence graphique DING + Show Desktop + Resource Monitor dans une VM strictement identifiée VirtualBox ;
3. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — GATE 3 bare-metal et APPLY production.

Le LAB VirtualBox possède son propre entrypoint limité et **ne déverrouille jamais `install.sh --apply`**.

## Je veux installer la workstation

Lire :

- [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — parcours principal ;
- [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) — tests RAM/NVMe avant APPLY ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — backup Restic obligatoire avant APPLY ;
- [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md) — différence diagnostic / dry-run / APPLY et protections ;
- [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — accès au même parcours depuis le cockpit.

Le parcours de confiance bare-metal reste :

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

Le Control Center appelle ces mêmes moteurs ; il ne crée aucun chemin parallèle moins sécurisé.

## Je veux mettre à jour le poste

Le cockpit fournit un socle **Mises à jour** :

```bash
./control.sh update check
./control.sh update all
```

La mise à jour complète suit :

```text
backup Restic obligatoire
      ↓
DNF --refresh
      ↓
Flatpak
      ↓
firmware check read-only
      ↓
diagnostic global
      ↓
reboot status
```

Aucun firmware n'est flashé automatiquement. Le kernel Golden reste `kernel-vanilla/stable` en politique `latest-stable`, avec le kernel Fedora conservé comme fallback.

## Je veux utiliser KVM et les VM

Lire dans cet ordre :

1. [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) — commandes quotidiennes et premier démarrage ;
2. [`VIRTUALIZATION.md`](VIRTUALIZATION.md) — architecture KVM, stockage et réseau ;
3. [`KVM_NETWORK.md`](KVM_NETWORK.md) — fonctionnement précis de `devops-nat` et de l'isolation LAN ;
4. [`VM_PROFILES.md`](VM_PROFILES.md) — profils Ubuntu et Windows ;
5. [`UBUNTU_DEVOPS_READY.md`](UBUNTU_DEVOPS_READY.md) — contenu de la VM Ubuntu DevOps ;
6. [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md) — inventaire commun HOST/VM et dépendances directes ;
7. [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md) — SFTP Ubuntu et SMB Windows depuis Nautilus ;
8. [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md) — référence CLI avancée.

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

- [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — cockpit terminal et mode CLI ;
- [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md) — paquets et outils explicitement gérés sur le HOST et la VM Ubuntu ;
- [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) — contrat et checklist du GATE 2 ;
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

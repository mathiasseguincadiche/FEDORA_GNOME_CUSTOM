# Cahier des charges V1.5 — Fedora 44 GNOME Workstation

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
- Applications graphiques du bureau général : GTK4 + libadwaita uniquement, hors exceptions professionnelles et virtualisation documentées.
- Ptyxis comme terminal de référence.
- GNOME Text Editor comme éditeur texte natif.
- Profil professionnel obligatoire : VS Code, Brave, VLC, Bitwarden, Slack, ONLYOFFICE, LibreOffice, FileZilla et MarkText.
- Pile multimédia complète : GStreamer Fedora + OpenH264 + FFmpeg complet/freeworld RPM Fusion + oneVPL/QSV.
- Arc B580 : VA-API H.264/HEVC/AV1/VP9 mesuré ; aucun changement de pilote média sur simple supposition.
- KVM/QEMU/libvirt complet et **CLI-first**, OVMF, TPM 2.0, VirtioFS, libguestfs, libosinfo, virt-manager et virt-viewer.
- Stockage KVM dédié sur le second T705 monté manuellement en EXT4.
- Réseau `devops-nat` isolé du LAN physique, intégré à firewalld.
- Profils Ubuntu Server LTS, Fedora et Windows 11 sans création automatique.
- Restic pour backup/restauration.
- Diagnostics lisibles et rapports persistants.

## Politique applicative

### Bureau GNOME natif

Les applications graphiques du bureau général installées par le dépôt doivent être validées contre Fedora 44 et déclarer GTK4/libadwaita. Toute nouvelle application du catalogue GNOME natif doit passer le contrat CI avant intégration.

### Exception explicite : applications professionnelles

Les outils nécessaires au travail professionnel ne sont pas rejetés uniquement parce qu'ils n'utilisent pas GTK4/libadwaita. Ils doivent toutefois avoir une source explicite, reproductible et contrôlée :

```text
Visual Studio Code          dépôt RPM Microsoft signé
Brave                       dépôt RPM Brave signé
VLC                         Fedora
LibreOffice + français      Fedora
FileZilla                   Fedora
Bitwarden                   Flathub
Slack                       Flathub
ONLYOFFICE Desktop Editors  Flathub
MarkText                    Flathub
```

Le CI vérifie la disponibilité des paquets/App IDs et interdit les installateurs non maîtrisés de type `curl | bash`.

### Exception explicite : virtualisation

La règle GTK4/libadwaita ne s'applique pas aux outils nécessaires à un environnement KVM/libvirt complet. `virt-manager` et `virt-viewer` restent disponibles même s'ils utilisent une pile GTK antérieure.

## Politique multimédia

La base Fedora fournit GStreamer `base`, `good`, `bad-free`, OpenH264 et oneVPL. RPM Fusion complète avec le `ffmpeg` complet, `ffmpegthumbnailer`, `bad-freeworld`, `ugly` et `libav`.

Le pilote média Intel Fedora reste le choix initial. Le projet ne bascule vers `intel-media-driver` RPM Fusion que si un probe VA-API valide révèle un manque de profils requis. Voir `MULTIMEDIA_CODECS.md`.

## Politique de virtualisation

### Hyperviseur et modèle d'administration

La connexion de référence est `qemu:///system`. Le projet utilise les daemons modulaires libvirt Fedora (`virtqemud`, `virtnetworkd`, `virtstoraged`) lorsqu'ils sont disponibles et conserve un fallback `libvirtd.socket` uniquement pour compatibilité.

La virtualisation est **CLI-first** : les opérations de cycle de vie, création, clonage, XML, stockage, snapshots, inspection hors ligne, préparation de templates, cloud-init, monitoring et conversion doivent pouvoir être effectuées sans interface graphique.

La stack doit fournir au minimum :

```text
virsh
virt-admin
virt-host-validate
virt-xml-validate
virt-install
virt-clone
virt-xml
qemu-img
qemu-io
qemu-nbd
qemu-storage-daemon
guestfish
virt-filesystems
virt-customize
virt-sysprep
virt-resize
virt-sparsify
virt-builder
cloud-localds
virt-top
virt-v2v
virt-qemu-qmp-proxy
osinfo-query
ssh / scp / sftp / rsync
```

`virt-manager`, `virt-viewer` et `remote-viewer` restent disponibles comme GUI complémentaire.

### Stockage

Le second Crucial T705 est destiné aux VM/labs et doit être monté **manuellement** à `/data` en EXT4 avant APPLY KVM.

```text
/data/libvirt/
├── images/
├── iso/
├── cloud-init/
├── nvram/
├── snapshots/
├── exports/
└── shared/
```

Le pool `devops-data` cible `/data/libvirt/images`, est persistant/autostart et reçoit des labels SELinux `virt_image_t` via `semanage fcontext` + `restorecon`.

Le projet ne partitionne, ne formate et ne monte jamais automatiquement le SSD.

### Réseau

```text
devops-nat
192.168.50.0/24
virbr50 = 192.168.50.254
DHCP = .100-.200
DNS = 9.9.9.9 + 1.1.1.1
```

Contrat :

```text
HOST ↔ VM       autorisé
VM ↔ VM         autorisé
VM → Internet   autorisé
VM → LAN        bloqué
LAN → VM        bloqué
Internet → VM   aucun forwarding entrant implicite
```

Le bridge appartient à la zone firewalld `libvirt`. Un guard nftables possédé uniquement par le projet bloque le forwarding avec les réseaux physiques détectés sans modifier ou vider les tables de firewalld/libvirt. Un hook NetworkManager recharge ce guard quand la connectivité change.

### UEFI / TPM / Windows 11

Ubuntu/Fedora utilisent UEFI. Windows 11 utilise UEFI Secure Boot et TPM 2.0 swtpm. Les pilotes VirtIO Windows sont un média externe explicite : le projet ne télécharge ni n'ajoute automatiquement un dépôt tiers pour ces binaires.

### Cloud-init et templates

`cloud-localds`, `virt-install`, `virt-builder`, `virt-customize` et `virt-sysprep` doivent permettre la préparation reproductible des VM en CLI. Aucune VM ni ISO n'est créée/téléchargée automatiquement durant la convergence HOST.

### Profils

- Ubuntu Server 26.04 LTS : VM DevOps principale ;
- Fedora 44 : VM Linux de test ;
- Windows 11 : VM Windows UEFI Secure Boot/TPM/VirtIO.

`CREATE_DEVOPS_VM=false` et `VM_PROFILE_AUTOSTART=false` restent les valeurs par défaut.

### GPU

La B580 reste au HOST et au pilote `xe`. Aucun VFIO/passthrough automatique ou profil passthrough n'est autorisé.

### Diagnostic et preuve runtime

`diagnostics/virtualization-doctor` valide toute la configuration observable sans mutation, y compris la présence de la surface CLI complète et `virt-host-validate`.

La preuve réseau bout-en-bout HOST↔VM, VM↔VM, VM→Internet et VM→LAN bloqué exige des VM réellement démarrées. Elle doit être effectuée sur la machine réelle après installation ; le dépôt ne crée pas des VM uniquement pour satisfaire un test.

Voir `VIRTUALIZATION.md`, `VIRTUALIZATION_CLI.md` et `VM_PROFILES.md`.

## P2 — options

- HDR/VRR : observation d'abord, activation seulement après validation matérielle/régression.
- Provisionnement automatisé de la VM DevOps : phase `VM_DEVOPS`, séparée de la convergence HOST/KVM.

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

Dans APPLICATIONS :

```text
GTK4 natif → applications professionnelles → validation
```

Dans KVM :

```text
preflight → stack → firmware → storage → network → catalog → CLI → SSH → virt-manager → VM profiles → validation
```

## Critère de réussite

La workstation doit être reproductible, observable et fail-closed. Une baseline matérielle invalide bloque l'APPLY. Le bureau général reste GTK4/libadwaita ; seules les exceptions professionnelles et KVM documentées sont admises. La pile multimédia doit être mesurée. La stack KVM doit être administrable principalement en CLI, respecter SELinux/firewalld, utiliser le stockage dédié, isoler le LAN, conserver la B580 au HOST et fournir toutes les briques nécessaires à Ubuntu Server, Fedora et Windows 11 sans créer de VM implicitement.

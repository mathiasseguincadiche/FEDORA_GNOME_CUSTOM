# Inventaire logiciel — hôte Fedora 45 et VM Rocky DevOps

> Mise à jour : 2026-11-04 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-04 — partie hôte régénérée depuis `manifests/` et comparée par `tests/test_docs_integrity.py` ; partie VM relue contre `guest/rocky-devops/bootstrap-devops.sh` — matériel : non vérifié

Cette page liste ce que le projet demande explicitement : les paquets et applications des manifests de l'hôte, puis les outils installés dans la VM Rocky. Les dépendances transitives (bibliothèques, dépendances RPM) ne sont pas figées : DNF les résout à l'installation.

Ce catalogue ne donne pas le droit d'installer : l'APPLY exige toujours le profil promu, la baseline, le dry-run et la sauvegarde ([guide d'installation](INSTALLATION_GUIDE.md)). Les outils de la VM ne sont jamais installés sur l'hôte.

## Vue d'ensemble

| Famille | Outils principaux | Rôle |
|---|---|---|
| Système Fedora | DNF5, RPM, SELinux, firewalld, fwupd | mises à jour contrôlées, sécurité, diagnostic |
| Bureau GNOME | GNOME Shell, Mutter (Wayland), Nautilus, Ptyxis | bureau cohérent et réactif |
| Affichage Arc B580 | pilote `xe`, Mesa, Vulkan, VA-API | rendu, décodage et encodage vidéo |
| DevOps et VM | Git, Python, Bash, KVM, QEMU, libvirt, Rocky Linux | environnements isolés de développement |
| Jeux | Steam, Proton, GameMode, MangoHud | lancer et mesurer les jeux |
| Récupération | Borg, `/data` en EXT4 | reprendre le travail après un incident |
| Contrôle | `control.sh`, doctors, CI, Gate 3 | vérifier l'état réel avant de l'annoncer |

La vision d'ensemble est dans l'[architecture](ARCHITECTURE.md), la provenance de chaque source dans la [chaîne d'approvisionnement](SUPPLY_CHAIN.md).


## 1. Hôte Fedora 45

Chaque liste reproduit un manifeste de `manifests/`, qui fait foi ; `tests/test_docs_integrity.py` vérifie qu'elles restent identiques.

### 1.1 Socle système

**`manifests/packages-system.txt`**

- bash
- coreutils
- curl
- ca-certificates
- git
- jq
- unzip
- pciutils
- usbutils
- util-linux
- fwupd
- linux-firmware
- amd-ucode-firmware
- intel-gpu-firmware
- policycoreutils
- policycoreutils-python-utils
- firewalld
- dnf5-plugins
- mokutil
- grubby
- stress-ng
- dmidecode
- fio
- drm_info
- python3
- python3-pip
- python3-gobject
- python3-devel
- pipx

Python est un outil du poste, pas une simple dépendance de KVM. Le postcheck exige `python3 --version`, `python3 -m pip --version`, `pipx` et la création réelle d'un environnement `python3 -m venv`. Les paquets Python d'un projet s'installent dans un `venv` ou avec `pipx`, jamais dans le Python système.

### 1.2 Matériel et diagnostic

**`manifests/packages-hardware.txt`** — Pilotes, outils GPU, stockage et capteurs

- mesa-dri-drivers
- mesa-vulkan-drivers
- mesa-libGL
- vulkan-tools
- libva-utils
- libva-intel-media-driver
- igt-gpu-tools
- wayland-utils
- nvme-cli
- smartmontools
- lm_sensors
- lshw
- ethtool
- v4l-utils
- powertop
- rasdaemon
- dmidecode
- kernel-tools
- pipewire-utils
- iw
- bluez
- alsa-utils

**`manifests/packages-baseline.txt`** — Outils exigés avant l'enrôlement de la baseline

- pciutils
- kmod
- util-linux
- smartmontools
- stress-ng
- dmidecode
- fio

### 1.3 Shell

**`manifests/packages-shell.txt`**

- bash-completion
- fzf
- zoxide
- direnv

Ptyxis, terminal natif de référence, appartient au catalogue des applications GTK4. Toolbx et Podman ne sont pas des dépendances implicites de l'hôte : KVM reste la frontière DevOps.

### 1.4 GNOME et portails

Le socle GNOME est séparé de Nautilus : chacun a son module et son doctor.

**`manifests/packages-gnome.txt`**

- gnome-shell
- mutter
- gnome-control-center
- xdg-desktop-portal
- xdg-desktop-portal-gnome
- xdg-user-dirs
- xdg-user-dirs-gtk
- flatpak

### 1.5 Nautilus et fichiers

**`manifests/packages-nautilus.txt`** — Socle obligatoire

- nautilus
- localsearch
- gvfs
- gvfs-gphoto2
- gvfs-fuse
- gvfs-afc
- gvfs-goa
- gvfs-nfs
- sushi
- file-roller-nautilus
- file-roller

**`manifests/packages-nautilus-optional.txt`** — Backends optionnels, définis dans `config/gnome.conf`

- gvfs-smb — activé par `NAUTILUS_ENABLE_SMB`
- gvfs-mtp — activé par `NAUTILUS_ENABLE_MTP`

`gvfs-goa` sert quand l'utilisateur configure des comptes en ligne GNOME ; aucun compte n'est créé automatiquement. Fedora 45 ne fournit plus `gvfs-archive` : File Roller et son extension Nautilus ouvrent les archives. Le socle est validé par `diagnostics/nautilus-integration-doctor` ; le démarrage à froid est mesuré à part par `diagnostics/nautilus-coldstart-doctor`.

### 1.6 Extensions et finition GNOME

**`manifests/packages-gnome-extensions.txt`** — Extensions empaquetées par Fedora

- gnome-shell-extension-dash-to-dock
- gnome-shell-extension-blur-my-shell — installé mais désactivé dans le profil actuel
- gnome-shell-extension-appindicator

**`manifests/packages-gnome-polish.txt`** — Finition (ADR 0013)

- adw-gtk3-theme — apparence libadwaita pour les applications GTK3

Les versions exactes des RPM d'extensions sont épinglées dans `profiles/fedora45/gnome-rpms.json`. Gtk4 DING, Show Desktop Button et Vitals viennent de GNOME Extensions, Tiling Assistant de sa release GitHub officielle : ces quatre archives sont épinglées dans `config/gnome-extensions.lock`. Avec Dash to Dock et AppIndicator, elles forment les six extensions du profil ([GNOME](GNOME.md)).

### 1.7 Intégration du bureau

**`manifests/packages-desktop-integration.txt`**

*Secrets*

- gnome-keyring
- gnome-keyring-pam
- libsecret
- seahorse

*Portails Wayland et Flatpak*

- xdg-desktop-portal-gtk
- pipewire
- wireplumber

*Impression et numérisation sans pilote*

- cups
- cups-client
- ipp-usb
- avahi
- sane-airscan
- system-config-printer

*VPN dans NetworkManager*

- NetworkManager-openvpn
- NetworkManager-openvpn-gnome
- NetworkManager-openconnect
- NetworkManager-openconnect-gnome

*Profils d'énergie*

- tuned
- tuned-ppd

*Français, correcteur et polices*

- glibc-langpack-fr
- hunspell-fr
- hyphen-fr
- mythes-fr
- google-noto-sans-fonts
- google-noto-color-emoji-fonts
- liberation-fonts-all

*Client d'administration à distance*

- remmina
- remmina-plugins-rdp
- remmina-plugins-vnc
- remmina-plugins-secret
- remmina-plugins-spice

*Téléphone et iPhone*

- libimobiledevice
- libimobiledevice-utils
- ifuse

*Calcul Intel Arc (Level Zero, OpenCL)*

- intel-compute-runtime
- intel-level-zero
- intel-opencl
- clinfo

*Mises à jour : téléchargement seul, jamais d'installation ni de redémarrage automatiques*

- dnf5-plugin-automatic
- dnf5-plugins

*Disques et diagnostic des flux du portail*

- gnome-disk-utility
- dconf
- python3-gobject
- pipewire-gstreamer
- gstreamer1-plugins-base

### 1.8 Performance

**`manifests/packages-performance.txt`**

- scx_rusty — capacité sched_ext, désactivée par défaut jusqu'au test sur le PC
- zram-generator-defaults — swap en zram aux valeurs Fedora
- gamemode — optimisation par jeu, sans overclocking du GPU

Voir [performance](PERFORMANCE.md).

### 1.9 Applications GTK4

**`manifests/packages-applications-gtk4.txt`**

- ptyxis
- gnome-tweaks
- gnome-software
- gnome-system-monitor
- baobab
- gnome-calculator
- file-roller
- gnome-text-editor
- loupe
- papers
- showtime
- snapshot
- gnome-calendar
- gnome-clocks
- gnome-weather
- gnome-maps
- gnome-contacts
- simple-scan

Ptyxis est contrôlé par `diagnostics/ptyxis-doctor` ; le Bash chargé dans le terminal l'est séparément par `diagnostics/shell-doctor`.

### 1.10 Applications professionnelles

**`manifests/packages-applications-professional-fedora.txt`** — Dépôts Fedora

- vlc
- libreoffice
- libreoffice-langpack-fr
- libreoffice-gtk4 — intégration GTK4 de LibreOffice
- filezilla

**`manifests/packages-applications-professional-vendor.txt`** — Dépôts éditeurs signés

- code — Visual Studio Code
- brave-browser

**`manifests/flatpaks-applications-professional.txt`** — Flathub

- com.bitwarden.desktop
- com.slack.Slack
- com.github.marktext.marktext
- com.jgraph.drawio.desktop
- com.github.tchx84.Flatseal — manifeste maintenu par l'amont, sans badge éditeur supposé

La classe de confiance de chaque application est dans `manifests/application-provenance.tsv` ([provenance](SUPPLY_CHAIN.md#applications-de-lhôte)).

### 1.11 Multimédia et codecs

**`manifests/packages-multimedia-fedora.txt`** — Fondation Fedora

- gstreamer1-plugins-base
- gstreamer1-plugins-good
- gstreamer1-plugins-bad-free
- gstreamer1-plugin-openh264
- libvpl
- intel-vpl-gpu-rt

**`manifests/packages-rpmfusion.txt`** — Complément RPM Fusion

- ffmpegthumbnailer
- gstreamer1-plugins-bad-freeworld
- gstreamer1-plugins-ugly
- gstreamer1-plugin-libav

Le module multimédia remplace `ffmpeg-free` par le `ffmpeg` de RPM Fusion lorsque c'est nécessaire. Le pilote `intel-media-driver` de RPM Fusion n'est installé que si la mesure VA-API de la B580 le rend nécessaire ; sinon le pilote Fedora reste en place ([codecs](MULTIMEDIA_CODECS.md)).

### 1.12 Jeux

**`manifests/packages-gaming.txt`** — Socle Fedora, x86_64 et i686

- gamemode — optimisation par jeu, sans overclocking du GPU
- gamescope
- mangohud
- goverlay
- steam-devices
- vulkan-tools
- mesa-vulkan-drivers.x86_64
- mesa-vulkan-drivers.i686
- mesa-dri-drivers.x86_64
- mesa-dri-drivers.i686
- vulkan-loader.x86_64
- vulkan-loader.i686

**`manifests/packages-gaming-rpmfusion.txt`** — Steam, isolé dans son manifeste

- steam — dépôt `rpmfusion-nonfree-steam`, activé pour cette seule transaction

Proton est géré par Steam ; aucun Mesa git, COPR ou noyau de jeu n'est ajouté ([Gaming](GAMING.md)).

### 1.13 AppImage

**`manifests/packages-appimage.txt`** — Prise en charge FUSE 2 et FUSE 3, inspection et intégration au bureau

- fuse
- fuse-libs.x86_64
- fuse-libs.i686
- fuse3
- fuse3-libs.x86_64
- fuse3-libs.i686
- bsdtar
- squashfs-tools
- file
- desktop-file-utils
- shared-mime-info
- xdg-utils

**`manifests/flatpaks-appimage.txt`** — Flathub

- it.mijorus.gearlever — Gear Lever, gestion des AppImage

Voir [AppImage](APPIMAGE.md).

### 1.14 Virtualisation

**`manifests/packages-virtualization.txt`**

- qemu-kvm
- qemu-img
- libvirt
- libvirt-client
- libvirt-client-qemu
- libvirt-nss
- libvirt-daemon-common
- libvirt-daemon-kvm
- libvirt-daemon-config-network
- virt-install
- virt-manager
- virt-viewer
- virt-top
- virt-v2v
- cloud-utils-cloud-localds
- openssl
- gnupg2
- edk2-ovmf
- swtpm
- swtpm-tools
- swtpm-selinux
- guestfs-tools
- guestfs-tools-bash-completion
- osinfo-db
- osinfo-db-tools
- libosinfo
- openssh-clients
- iputils
- rsync
- nftables
- dnsmasq
- python3
- policycoreutils-python-utils

Voir [virtualisation](VIRTUALIZATION.md).

### 1.15 Accès distant (optionnel, désactivé par défaut)

Installé seulement avec `REMOTE_ENABLE="true"`.

**`manifests/packages-remote-fedora.txt`** — Paquets Fedora

- openssh-server
- ethtool
- polkit

**`manifests/packages-remote-vendor.txt`** — Dépôt éditeur signé Tailscale (`config/repos/tailscale.repo`)

- tailscale

**`manifests/packages-remote-sunshine.txt`** — COPR LizardByte

- Sunshine — seulement si `REMOTE_SUNSHINE_ENABLE="true"`

Voir [accès distant](REMOTE_ACCESS.md) et l'[ADR 0017](adr/0017-remote-access.md).

## 2. VM Rocky Linux 10.2 DevOps

La VM `rocky-devops` est un poste DevOps en ligne de commande : cloner, construire, tester, conteneuriser, déployer. Tout est installé par `guest/rocky-devops/bootstrap-devops.sh`, puis contrôlé par `guest/rocky-devops/verify-devops.sh`.

### 2.1 Dépôts

| Dépôt | Fournit |
|---|---|
| Rocky Linux (BaseOS, AppStream, CRB activé) | socle, langages, outils de build |
| EPEL 10 (paquet `epel-release` officiel) | paquets absents de Rocky, dont `glab` |
| Docker officiel RHEL 10 | Docker Engine et ses plugins |
| GitHub CLI officiel | `gh` |
| HashiCorp officiel RHEL 10 | `terraform` |
| Microsoft RHEL 10 (clé `microsoft-2025`) | `azure-cli` |
| `pkgs.k8s.io`, branche `v1.37` | `kubectl` |

Chaque dépôt vérifie les signatures (`gpgcheck=1`) ; aucun repli EL9, `--nogpgcheck` ni `--skip-broken`.

### 2.2 Paquets

| Usage | Paquets |
|---|---|
| Système | dnf-plugins-core, ca-certificates, curl, wget, gnupg2, policycoreutils, container-selinux, jq, unzip, zip, rsync, less, groff, grubby, kmod |
| Git et forges | git, git-lfs, gh, glab |
| Python | python3, python3-pip, python3-devel, pipx |
| Automatisation | ansible-core |
| Build et shell | gcc, gcc-c++, make, shellcheck, bash-completion, htop, tree, tmux, ripgrep |
| Réseau et accès | openssh-server, qemu-guest-agent, bind-utils, traceroute, iproute, net-tools, nmap-ncat |
| JavaScript | nodejs (22 ou plus exigé), npm |
| Java | java-21-openjdk-devel (OpenJDK 21 exigé), maven |
| Conteneurs | docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin |
| Cloud et IaC | terraform, azure-cli, kubectl |

### 2.3 Outils hors paquets, versions épinglées

| Outil | Version | Source et vérification |
|---|---|---|
| Corepack | 0.34.5 | npm, contrôle d'intégrité du registre |
| Helm | v4.3.0 | archive get.helm.sh, SHA-256 versionné |
| kind | v0.33.0 | release GitHub, SHA-256 versionné |
| Minikube | v1.38.1 | release GitHub, SHA-256 versionné ; pilote Docker par défaut |
| yq | v4.53.3 | release GitHub, SHA-256 versionné |
| K9s | v0.51.0 | release GitHub, SHA-256 versionné |
| kubectx et kubens | v0.11.0 | release GitHub, SHA-256 versionné (EPEL 10.2 n'en fournit pas de RPM) |
| AWS CLI v2 | dernière | ZIP officiel et signature GPG vérifiée contre l'empreinte versionnée |

Changer une version impose de changer son empreinte dans le même commit ([provenance](SUPPLY_CHAIN.md#outils-de-la-vm-rocky-devops)).

### 2.4 Services

`sshd` et `docker` sont activés ; l'utilisateur DevOps entre dans le groupe `docker`. `qemu-guest-agent` fonctionne lorsque le canal virtio est exposé. La connexion SSH par mot de passe reste désactivée ([KVM au quotidien](KVM_QUICKSTART.md)).

Le doctor de la VM vérifie aussi Python (`python3 -m pip`, `pipx`, création réelle d'un `venv`), Node.js 22 ou plus et OpenJDK 21.

## 3. État réel d'une installation

Cette page décrit le contrat. Pour l'état exact d'une machine, sur l'hôte comme dans la VM :

```bash
rpm -qa | sort
dnf repoquery --userinstalled
```

Ces sorties peuvent être archivées comme inventaire d'exécution ; elles complètent ce contrat sans le remplacer.

L'afficheur de l'AIO LD240 est une option communautaire épinglée, inactive par défaut et indépendante de la ventilation ([qualification](QUALIFICATION.md)).

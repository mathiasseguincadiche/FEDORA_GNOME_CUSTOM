# Inventaire logiciel — HOST Fedora 44 et VM Ubuntu DevOps

Ce document décrit le **contrat logiciel explicite** du projet. Il liste les paquets, applications et outils directement demandés par les manifests Fedora ou par le bootstrap Ubuntu.

Les dépendances transitives (`glibc`, bibliothèques GTK/Qt, bibliothèques Python, dépendances RPM/DEB, etc.) ne sont volontairement pas figées ici : DNF et APT les résolvent au moment de l'installation et leur liste peut évoluer sans changement du projet.

## 1. HOST — Fedora 44 Golden Workstation

### 1.1 Socle système

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
- firewalld
- dnf5-plugins
- mokutil
- grubby
- stress-ng
- fio
- drm_info

### 1.2 Python HOST

Python est un outil workstation explicite, et non une simple dépendance de KVM :

- python3
- python3-pip
- python3-devel
- pipx

Le post-check exige également :

- `python3 --version`
- `python3 -m pip --version`
- `pipx`
- création réelle d'un environnement `python3 -m venv`

Les packages Python d'un projet applicatif doivent être installés dans un `venv` ou via `pipx`, pas globalement dans le Python système Fedora.

### 1.3 Shell opérateur

- bash-completion
- fzf
- zoxide
- direnv

### 1.4 Matériel / diagnostic / Intel Arc B580

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

### 1.5 GNOME / fichiers / portails

- gnome-shell
- mutter
- gnome-control-center
- nautilus
- gvfs
- gvfs-smb
- gvfs-mtp
- gvfs-gphoto2
- gvfs-fuse
- xdg-desktop-portal
- xdg-desktop-portal-gnome
- xdg-user-dirs
- flatpak

### 1.6 Extensions GNOME Fedora

- gnome-shell-extension-dash-to-dock
- gnome-shell-extension-blur-my-shell
- gnome-shell-extension-appindicator

DING et Show Desktop Plus ne viennent pas d'un RPM Fedora : ils sont installés depuis les artefacts GNOME Extensions revus et contrôlés par le projet.

### 1.7 Intégration desktop

Secrets / credentials :

- gnome-keyring
- gnome-keyring-pam
- libsecret
- seahorse

Wayland / Flatpak :

- xdg-desktop-portal-gtk
- pipewire
- wireplumber

Impression / scan :

- cups
- cups-client
- ipp-usb
- avahi
- sane-airscan
- system-config-printer

VPN NetworkManager / GNOME :

- NetworkManager-openvpn
- NetworkManager-openvpn-gnome
- NetworkManager-openconnect
- NetworkManager-openconnect-gnome

Énergie :

- tuned
- tuned-ppd

Français / dictionnaires / polices :

- glibc-langpack-fr
- hunspell-fr
- hyphen-fr
- mythes-fr
- google-noto-sans-fonts
- google-noto-color-emoji-fonts
- liberation-fonts-all

Administration distante :

- remmina
- remmina-plugins-rdp
- remmina-plugins-vnc
- remmina-plugins-secret
- remmina-plugins-spice

Téléphone / iPhone :

- libimobiledevice
- libimobiledevice-utils
- ifuse

Intel Arc compute :

- intel-compute-runtime
- intel-level-zero
- intel-opencl
- clinfo

Lifecycle :

- dnf5-plugin-automatic
- dnf5-plugins

### 1.8 Applications GNOME GTK4 / libadwaita

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

### 1.9 Applications professionnelles RPM

Fedora :

- vlc
- libreoffice
- libreoffice-langpack-fr
- filezilla

Dépôts éditeurs signés :

- code (Visual Studio Code)
- brave-browser

### 1.10 Applications professionnelles Flatpak

- com.bitwarden.desktop
- com.slack.Slack
- org.onlyoffice.desktopeditors
- com.github.marktext.marktext
- com.jgraph.drawio.desktop

### 1.11 Multimédia / codecs

Fondation Fedora :

- gstreamer1-plugins-base
- gstreamer1-plugins-good
- gstreamer1-plugins-bad-free
- gstreamer1-plugin-openh264
- libvpl
- intel-vpl-gpu-rt

Complément RPM Fusion :

- ffmpeg (remplace `ffmpeg-free` lorsque nécessaire)
- ffmpegthumbnailer
- gstreamer1-plugins-bad-freeworld
- gstreamer1-plugins-ugly
- gstreamer1-plugin-libav

Le driver `intel-media-driver` RPM Fusion n'est installé que si la mesure VA-API de l'Arc B580 montre qu'il est réellement nécessaire ; sinon le driver Fedora est conservé.

### 1.12 KVM / libvirt / virtualisation

Hyperviseur :

- qemu-kvm
- qemu-img
- libvirt
- libvirt-client
- libvirt-client-qemu
- libvirt-nss
- libvirt-daemon-common
- libvirt-daemon-kvm
- libvirt-daemon-config-network

Administration :

- virt-install
- virt-manager
- virt-viewer
- virt-top
- virt-v2v

Images / cloud-init / intégrité :

- cloud-utils-cloud-localds
- openssl
- xorriso
- gnupg2

UEFI / TPM / guest images :

- edk2-ovmf
- swtpm
- swtpm-tools
- swtpm-selinux
- guestfs-tools
- guestfs-tools-bash-completion

Métadonnées OS :

- osinfo-db
- osinfo-db-tools
- libosinfo

Administration HOST → VM :

- openssh-clients
- iputils
- rsync

Réseau / sécurité :

- nftables
- dnsmasq
- policycoreutils-python-utils

`python3` est aussi requis historiquement par cette couche, mais le contrat Python HOST est désormais défini dans le socle système.

## 2. VM — Ubuntu 26.04 DevOps

La VM est une workstation CLI DevOps prête à cloner, construire, tester, conteneuriser et déployer.

### 2.1 Base APT / système

- software-properties-common
- apt-transport-https
- ca-certificates
- curl
- wget
- gnupg
- lsb-release
- jq
- unzip
- zip
- rsync
- less
- groff

### 2.2 Git / forge

- git
- git-lfs
- gh — GitHub CLI
- glab — GitLab CLI

### 2.3 Python VM

- python3
- python3-pip
- python3-venv
- python3-dev
- pipx

`python3-dev` fournit les en-têtes nécessaires pour compiler proprement les extensions Python natives dans la VM de build/DevOps.

Le doctor Ubuntu vérifie :

- Python 3
- `python3 -m pip`
- `pipx`
- création réelle d'un `python3 -m venv`

### 2.4 Ansible / automation

- ansible
- ansible-core

### 2.5 Outils de build et shell

- build-essential
- make
- shellcheck
- bash-completion
- htop
- tree
- tmux
- ripgrep

### 2.6 Réseau et accès VM

- openssh-server
- qemu-guest-agent
- dnsutils
- traceroute
- iproute2
- net-tools
- netcat-openbsd

SSH par mot de passe reste désactivé ; l'accès opérateur suit le contrat SSH/SFTP du projet.

### 2.7 JavaScript / Node

- nodejs — Node.js 22+ exigé
- npm
- node-corepack

### 2.8 Java

- openjdk-21-jdk
- maven

Le bootstrap exige OpenJDK 21.

### 2.9 Docker / conteneurs

Dépôt officiel Docker :

- docker-ce
- docker-ce-cli
- containerd.io
- docker-buildx-plugin
- docker-compose-plugin

Le service Docker est activé et l'utilisateur DevOps est ajouté au groupe `docker`.

### 2.10 Kubernetes

Dépôts / paquets :

- kubectl — branche Kubernetes v1.37.x contractuelle
- helm
- kubectx (et `kubens` fourni avec l'outillage associé)

Binaires contrôlés / pinnés :

- kind v0.33.0
- Minikube v1.38.1
- K9s v0.51.0
- yq v4.53.3

Minikube utilise Docker comme driver par défaut.

### 2.11 Infrastructure as Code / Cloud

- terraform — dépôt HashiCorp officiel
- azure-cli — dépôt Microsoft, avec fallback de suite contrôlé si nécessaire
- AWS CLI v2 — archive officielle dont la signature GPG est vérifiée

### 2.12 Services VM

Activés / validés :

- ssh
- docker
- qemu-guest-agent lorsque le canal virtio est exposé

## 3. Dépendances transitives

DNF et APT installent automatiquement les bibliothèques requises par les paquets ci-dessus. Cette liste est volontairement dynamique.

Pour connaître la vérité exacte d'une installation donnée :

HOST Fedora :

```bash
rpm -qa | sort
```

Paquets explicitement installés par l'utilisateur / projet :

```bash
dnf repoquery --userinstalled
```

VM Ubuntu :

```bash
dpkg-query -W -f='${binary:Package}\n' | sort
```

Après installation, ces sorties peuvent être archivées comme inventaire runtime ; elles complètent le contrat versionné de ce document.

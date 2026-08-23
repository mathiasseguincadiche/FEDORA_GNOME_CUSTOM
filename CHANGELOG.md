# Changelog

## 0.6.0 — 2026-08-23

- Contrat final limité à deux VM de référence : `ubuntu-devops` et `windows-11`; suppression du profil Fedora invité.
- `ubuntu-devops` fixé à 6 vCPU, 16 Gio RAM et 160 Gio qcow2.
- `windows-11` fixé à 4 vCPU, 12 Gio RAM et 128 Gio qcow2.
- Ajout de `create_ubuntu_devops_vm.sh` avec image cloud opérateur, UEFI, VirtIO, cloud-init, clé SSH et VirtioFS.
- Le mot de passe Ubuntu est saisi au runtime puis hashé; aucun mot de passe en clair n'est versionné.
- Ajout d'un bootstrap Ubuntu Server 26.04 pour Git/gh, Docker/Compose/Buildx, Ansible, Terraform, Azure CLI, AWS CLI v2, kubectl, Helm, kind, Python et outils d'exploitation.
- Ajout de `devops-verify.sh` dans l'invité et d'un contrat CI dédié au bootstrap.
- Ajout de `create_windows11_vm.sh` avec UEFI Secure Boot, TPM 2.0 swtpm, VirtIO et média `virtio-win.iso` explicite.
- Ajout de `runtime_certification.sh` pour la certification on-machine après création des invités.
- `virtualization-doctor`, validation KVM, menu et documentation alignés sur le contrat final.
- Ajout d'OpenSSL au manifeste KVM pour la génération locale du hash cloud-init.
- Réseau physique volontairement dynamique : aucun nom d'interface Ethernet/Wi-Fi codé en dur.

## 0.5.0 — 2026-08-23

- Refonte complète du scope KVM/QEMU/libvirt pour Fedora 44.
- Stack CLI-first : libvirt, QEMU, libguestfs, virt-v2v, cloud-localds, SSH/rsync et outils de diagnostic.
- Pool `devops-data` sur `/data` EXT4, SELinux `virt_image_t`.
- Réseau `devops-nat` isolé du LAN physique avec firewalld + guard nftables.
- Applications professionnelles : VS Code, Brave, VLC, Bitwarden, Slack, ONLYOFFICE, LibreOffice, FileZilla et MarkText.
- Dash to Dock + Blur My Shell + Extension Manager; Just Perfection/Dash to Panel exclus.

## 0.4.0 — 2026-08-23

- Pile multimédia Fedora/RPM Fusion complète.
- FFmpeg complet, GStreamer, OpenH264, oneVPL/QSV et politique VA-API Arc B580 mesurée.

## 0.3.0 — 2026-08-22

- Scope applications GTK4/libadwaita et Ptyxis.

## 0.2.0 — 2026-08-22

- Hardware Baseline Certification avec DDR5, T705 I/O et suspend/resume.

## 0.1.0 — 2026-08-22

- Fondation Fedora 44 GNOME 50 workstation-as-code.

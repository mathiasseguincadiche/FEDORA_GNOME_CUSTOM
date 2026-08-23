# Changelog

## 0.5.0 — 2026-08-23

- Refonte complète du scope KVM/QEMU/libvirt pour Fedora 44.
- Détection AMD-V, `/dev/kvm`, `kvm_amd`, conflits de sous-réseau et maintien de l'Intel Arc B580 sur le pilote HOST `xe`.
- Adoption du modèle de daemons libvirt modulaires Fedora lorsque disponible, avec fallback compatible `libvirtd.socket`.
- Complétion des paquets : QEMU/KVM, virt-manager/virt-viewer, OVMF, swtpm + politique SELinux, VirtioFS, guestfs et libosinfo.
- Passage de la virtualisation en mode **CLI-first** : `virsh`, `virt-admin`, `virt-host-validate`, `virt-install`, `virt-clone`, `virt-xml`, `qemu-img`, `qemu-io`, `qemu-nbd`, `qemu-storage-daemon`, `virt-top`, `virt-v2v` et accès QMP.
- Ajout de la chaîne libguestfs complète pour inspection et maintenance hors ligne : `guestfish`, `virt-customize`, `virt-sysprep`, `virt-resize`, `virt-sparsify`, `virt-builder` et outils associés.
- Ajout de `cloud-localds` pour générer des disques NoCloud/cloud-init, ainsi que SSH/SCP/SFTP/rsync et `libvirt-nss` pour l'administration HOST↔VM.
- Ajout d'un pool `devops-data` sur le second T705 monté manuellement à `/data` en EXT4 ; aucun partitionnement ou formatage automatique.
- Gestion persistante des labels SELinux `virt_image_t` avec `semanage fcontext` + `restorecon`.
- Refonte de `devops-nat` : `192.168.50.0/24`, bridge `virbr50`, DNS Quad9/Cloudflare, zone firewalld `libvirt`.
- Ajout d'un guard nftables possédé par le projet pour bloquer VM↔LAN physique sans perturber HOST↔VM, VM↔VM ou le NAT Internet.
- Ajout d'un hook NetworkManager pour recalculer l'isolation lors des changements de connectivité.
- Ajout des profils Ubuntu Server 26.04 LTS, Fedora 44 et Windows 11 UEFI Secure Boot/TPM 2.0, sans création automatique.
- Ajout de `diagnostics/virtualization-doctor` et intégration au diagnostic global/menu opérateur.
- Extension du pipeline KVM à preflight → stack → firmware → storage → network → catalog → CLI → SSH → virt-manager → VM profiles → validation.
- Ajout d'un contrat CI/non-régression virtualisation et de la documentation CLI dédiée.
- Ajout du profil d'applications professionnelles : Visual Studio Code, Brave, VLC, Bitwarden, Slack, ONLYOFFICE, LibreOffice, FileZilla et MarkText ; GNOME Text Editor reste l'éditeur texte natif.
- VS Code et Brave utilisent leurs dépôts RPM éditeurs signés ; VLC/LibreOffice/FileZilla utilisent Fedora ; Bitwarden/Slack/ONLYOFFICE/MarkText utilisent Flathub.
- La règle GTK4/libadwaita reste la norme pour le bureau GNOME général ; les applications professionnelles requises et la virtualisation sont des exceptions explicites, documentées et testées.

## 0.4.0 — 2026-08-23

- Complétion de la pile multimédia Fedora 44 avec GStreamer base/good/bad-free et OpenH264.
- Ajout de `libvpl` et `intel-vpl-gpu-rt` pour les chemins oneVPL/QSV sur Intel Arc.
- `ffmpeg-free` est remplacé explicitement par le `ffmpeg` complet de RPM Fusion via un swap contrôlé.
- Conservation des plugins RPM Fusion `bad-freeworld`, `ugly`, `libav` et de `ffmpegthumbnailer`.
- Politique Intel Arc B580 VA-API `auto` : le pilote Fedora libre est conservé s'il expose H.264/HEVC/AV1/VP9, sinon le projet bascule proprement vers `intel-media-driver` RPM Fusion.
- Ajout de `media-doctor` pour contrôler paquets, décodage FFmpeg, chemins QSV/VA-API et profils VA-API.
- CI Fedora 44 enrichie avec validation des deux swaps de fournisseurs multimédia.
- Ajout d'un contrat de non-régression multimédia.

## 0.3.0 — 2026-08-22

- Ajout d'un scope `APPLICATIONS` séparé du socle GNOME.
- Politique stricte : seules les applications graphiques GTK4/libadwaita vérifiées sont gérées automatiquement.
- Ptyxis devient le terminal de référence du projet.
- Ajout d'un manifeste applicatif dédié et d'un catalogue documenté.
- Nautilus reste centré sur GVfs/SMB/MTP/FUSE et utilise l'intégration Fedora prévue avec Ptyxis.
- Ajout d'un contrat CI pour contrôler la politique GTK4/libadwaita et la résolution des paquets Fedora 44.

## 0.2.0 — 2026-08-22

- Ajout de la Phase 0 `BASELINE` avant toute convergence réelle.
- Certification liée à une empreinte matériel + BIOS.
- Preuves séparées DDR5-5600 SPD et DDR5-6000 XMP.
- Gate de test I/O soutenu des Crucial T705.
- Minimum de 5 cycles suspend/resume validés avant certification.
- Ajout de `diagnostics/baseline-doctor` pour snapshots, preuves, statut et certification.
- `--apply` est désormais fail-closed si la baseline matérielle n'est pas certifiée.
- Documentation V1.1 et tests de politique mis à jour.

## 0.1.0 — 2026-08-22

- Fondation Fedora 44 GNOME 50 workstation-as-code.
- Moteur PRECHECK / PLAN / APPLY / POSTCHECK avec dry-run et gates.
- Profil matériel Ryzen 7 7700 / 48 Go DDR5-6000 / Intel Arc B580 / OLED 1440p 240 Hz.
- Modules P0 stabilité graphique, NVMe, suspend/resume et post-incident.
- Intégration GNOME/Nautilus, KVM/libvirt et Restic.
- CI ShellCheck, tests de structure et préflight des paquets Fedora 44.

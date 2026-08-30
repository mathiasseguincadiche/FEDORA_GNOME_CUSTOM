# Cahier des charges V1.7 — Golden Workstation Fedora 44

## Finalité

Construire une workstation Fedora 44 + GNOME 50 stable, reproductible, mesurée et récupérable pour usage DevOps/Ops sur le matériel cible.

## P0 — installation et sécurité

- générateur Kickstart ciblant uniquement le NVMe explicitement choisi ;
- aucun choix destructif automatique de disque ;
- SELinux Enforcing et firewalld ;
- dry-run + baseline + backup Restic avant APPLY ;
- rollback kernel disponible.

## P0 — matériel

- Ryzen 7 7700 ;
- 48 Gio RAM testés automatiquement à 5600 puis 6000 MT/s ;
- Intel Arc B580 `8086:e20b` sur `xe` ;
- deux Crucial T705, root et `/data` sur deux NVMe physiques distincts ;
- fingerprint BIOS/plateforme/GPU/NVMe/EDID ;
- aucun tweak kernel/power expérimental aveugle.

## P0 — kernel

- Fedora Kernel Vanilla stable ;
- minimum 7.2.2 ;
- kernels Fedora conservés comme fallback ;
- Secure Boot actif bloque ce chemin par défaut sans workflow de confiance explicite.

## P1 — GNOME

- GNOME 50 / Wayland / GTK4 / libadwaita ;
- Nautilus + GVfs SMB/MTP/FUSE ;
- vrai cold-start Files mesuré, cible 1200 ms, hard limit 2000 ms ;
- prewarm Portal/GIO sans pré-démarrer Nautilus ;
- Dash to Dock activé ; Blur My Shell désactivé dans l'état Golden certifié ;
- Ptyxis comme terminal.

## P1 — affichage

- 2560×1440 ~240 Hz ;
- scale 1.0 ;
- SDR/default ;
- Full RGB ;
- recovery après resume, Mutter MonitorsChanged et hotplug DRM ;
- capture gdctl/drm_info/journal.

## P1 — certification finale

Après APPLY/reboot : kernel/xe/display/GNOME sains, cold-start Nautilus dans la limite, puis cinq cycles suspend/resume avec repair display récent et sans signature critique xe/PCIe/NVMe.

## P1 — virtualisation et backup

Le contrat KVM/libvirt, Ubuntu Server 26.04, Windows 11, réseau privé, second T705 `/data` et Restic fail-closed reste celui de la version précédente.

## Critère de réussite

Le dépôt peut être code-ready via CI. La workstation n'est **Golden runtime-certified** que lorsque `diagnostics/final-certification certify` produit un PASS sur le vrai matériel et le kernel courant.

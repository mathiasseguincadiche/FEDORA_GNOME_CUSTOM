# Cahier des charges — Golden Workstation Fedora 44

**Révision documentaire : 1.7**  
**Version du projet : voir [`../VERSION`](../VERSION)**

La révision du cahier des charges n'est pas le numéro de release du logiciel.

## Finalité

Construire une workstation Fedora 44 + GNOME 50 stable, reproductible, mesurée, récupérable et exploitable au quotidien pour un usage DevOps/Ops sur le matériel cible.

## P0 — installation et sécurité

- générateur Kickstart ciblant uniquement le NVMe explicitement choisi ;
- aucun choix destructif automatique de disque ;
- SELinux Enforcing et firewalld actifs ;
- dry-run non-mutant + baseline + backup Restic avant APPLY ;
- rollback kernel disponible ;
- aucune confiance implicite dans une image Ubuntu fournie uniquement par son nom : checksum signé Canonical requis avant création de `ubuntu-devops`.

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
- Secure Boot actif bloque ce chemin tant qu'un workflow de confiance/signature explicite n'est pas mis en œuvre.

## P1 — GNOME

- GNOME 50 / Wayland / GTK4 / libadwaita ;
- Nautilus + GVfs SMB/MTP/FUSE ;
- vrai cold-start Files mesuré, cible 1200 ms, hard limit 2000 ms ;
- prewarm Portal/GIO sans pré-démarrer Nautilus ;
- Dash to Dock **et AppIndicator** activés comme extensions fonctionnelles ;
- Blur My Shell désactivé dans l'état Golden certifié ;
- Ptyxis comme terminal.

## P1 — affichage

- 2560×1440 ~240 Hz ;
- scale 1.0 ;
- SDR/default ;
- Full RGB ;
- recovery après resume, Mutter `MonitorsChanged` et hotplug DRM ;
- capture `gdctl` / `drm_info` / journal.

## P1 — virtualisation

- KVM/libvirt sur `qemu:///system` ;
- `/data` EXT4 dédié sur le second T705 ;
- pool `devops-data` ;
- profils `ubuntu-devops` et `windows-11` créés uniquement sur demande ;
- réseau `devops-nat` / `virbr50` / `192.168.50.0/24` ;
- VM → Internet autorisé ;
- forwarding VM ↔ LAN uplink bloqué ;
- changement de réseau traité en **fail-closed** : mode d'urgence avant recalcul, conservé si la reconstruction normale échoue ;
- IPv6 KVM refusé tant qu'une isolation dual-stack équivalente n'est pas certifiée ;
- aucun GPU passthrough de l'Arc B580.

## P1 — backup et recovery

- Restic chiffré ;
- backup pré-APPLY lié au commit ;
- `restic check` et restore-canary ;
- sauvegarde QCOW2 uniquement VM arrêtée ;
- restauration staging-first ;
- disaster-recovery non destructif.

## P1 — certification finale

Après APPLY/reboot :

- kernel/firmware/hardware sains ;
- Arc B580/`xe` saine ;
- display 1440p/~240 Hz ;
- desktop/portals/applications/lifecycle/Bash conformes ;
- socle KVM host sain ;
- cold-start Nautilus dans la limite ;
- cinq cycles suspend/resume physiques uniques ;
- matrice software known-good enregistrée.

## Critère de réussite

Le dépôt peut être **code-ready** via CI. La workstation n'est **Golden runtime-certified** que lorsque :

```bash
./diagnostics/final-certification certify
```

produit un PASS sur le vrai matériel et la pile logicielle courante.

La 1.0 doit être justifiée par une installation bare-metal complète et une période d'usage réel stable, pas par l'ajout artificiel de fonctionnalités.

# Cahier des charges — Golden Workstation Fedora 44

**Révision documentaire : 1.9**  
**Version du projet : voir [`../VERSION`](../VERSION)**

La révision du cahier des charges n'est pas le numéro de release du logiciel.

## Finalité

Construire une workstation Fedora 44 + GNOME 50 stable, reproductible, mesurée, récupérable et exploitable au quotidien pour un usage DevOps/Ops sur le matériel cible.

## P0 — installation et sécurité

- générateur Kickstart ciblant uniquement le NVMe explicitement choisi ;
- aucun choix destructif automatique de disque ;
- SELinux Enforcing et firewalld actifs ;
- dry-run non-mutant + baseline + backup Restic avant APPLY ;
- rollback kernel disponible vers N-1 ;
- récupération explicite vers les paquets kernel Fedora disponible en cas d'urgence ;
- aucune confiance implicite dans une image Ubuntu fournie uniquement par son nom : checksum signé Canonical requis avant création de `ubuntu-devops`.

## P0 — matériel

- Ryzen 7 7700 ;
- 48 Gio RAM testés automatiquement à 5600 puis 6000 MT/s ;
- Intel Arc B580 `8086:e20b` sur `xe` ;
- deux Crucial T705, root et `/data` sur deux NVMe physiques distincts ;
- premier T705 : Fedora Btrfs système ;
- second T705 : EXT4 persistant monté sur `/data`, réutilisable après réinstallation du système sans formatage automatique ;
- fingerprint BIOS/plateforme/GPU/NVMe/EDID ;
- aucun tweak kernel/power expérimental aveugle.

## P0 — kernel

- Fedora Kernel Vanilla stable ;
- minimum 7.2.2 ;
- dernier stable installé directement comme N lors de la convergence et des mises à jour Fedora complètes ;
- N devient le défaut GRUB normal ;
- N-1 reste installé comme rollback ;
- maximum deux versions `kernel-core` installées (`installonly_limit=2`) ;
- les versions plus anciennes que N-1 sont purgées via DNF5 `oldinstallonly` ;
- aucun fallback Fedora permanent obligatoire ;
- Secure Boot actif bloque ce chemin tant qu'un workflow de confiance/signature explicite n'est pas mis en œuvre ;
- une évolution kernel peut rendre la certification Golden `STALE`, mais n'attend pas une promotion préalable avant le premier boot.

## P1 — données persistantes

- `/data/Documents`, `/data/Projets`, `/data/ISO` et `/data/Jeux` créés idempotemment sur le second T705 sans suppression du contenu existant ;
- `Documents` XDG pointe vers `/data/Documents` ;
- répertoires utilisateur en mode `0750`, propriétaire workstation et labels SELinux persistants adaptés aux données utilisateur ;
- `/data/libvirt` reste un sous-arbre séparé avec son propre contexte SELinux ;
- `/data/Documents` et `/data/Projets` sont protégés par la sauvegarde quotidienne Restic externe ;
- `/data/ISO` et `/data/Jeux` restent persistants mais hors backup automatique par défaut ;
- le second T705 protège contre la perte/réinstallation du disque système, mais ne remplace jamais la sauvegarde off-machine.

## P1 — GNOME

- GNOME 50 / Wayland / GTK4 / libadwaita ;
- Nautilus complet : GVfs SMB/MTP/GPhoto/FUSE/Archive/AFC/GOA/NFS, Sushi et intégration File Roller ;
- vrai cold-start Files mesuré, cible 1200 ms, hard limit 2000 ms ;
- doctor Nautilus fonctionnel distinct du benchmark cold-start ;
- prewarm Portal/GIO sans pré-démarrer Nautilus ;
- Dash to Dock **et AppIndicator** activés comme extensions fonctionnelles ;
- DING, Show Desktop Plus et Resource Monitor intégrés au contrat Golden ;
- Blur My Shell désactivé dans l'état Golden certifié ;
- Ptyxis comme terminal Fedora natif avec Bash géré ; Toolbx non imposé au HOST Golden.

## P1 — affichage

- 2560×1440 ~240 Hz ;
- scale 1.0 ;
- SDR/default ;
- Full RGB ;
- recovery après resume, Mutter `MonitorsChanged` et hotplug DRM ;
- capture `gdctl` / `drm_info` / journal.

## P1 — virtualisation

- KVM/libvirt sur `qemu:///system` ;
- sous-arbre KVM `/data/libvirt` sur le second T705 EXT4 persistant ;
- pool `devops-data` sur `/data/libvirt/images` ;
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
- sauvegarde quotidienne de `/data/Documents` et `/data/Projets` en plus des données utilisateur configurées ;
- `/data/ISO` et `/data/Jeux` hors backup automatique par défaut pour éviter de dupliquer des payloads volumineux reproductibles ;
- sauvegarde QCOW2 uniquement VM arrêtée ;
- restauration staging-first ;
- disaster-recovery non destructif ;
- réinstallation du T705 système sans formatage automatique du second T705 `/data`.

## P1 — certification finale

Après APPLY/reboot :

- kernel N / N-1 conforme à la politique de rétention ;
- firmware/hardware sains ;
- second T705 `/data` EXT4 distinct du root avec `Documents`, `Projets`, `ISO`, `Jeux` conformes ;
- Arc B580/`xe` saine ;
- display 1440p/~240 Hz ;
- desktop/portals/applications/lifecycle/Bash conformes ;
- Nautilus/GVfs/Sushi/File Roller conformes ;
- Ptyxis natif + Bash conformes ;
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

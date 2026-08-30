# Changelog

## 0.8.0 — 2026-08-30

- Ajout du profil **Golden Workstation** séparant baseline pré-APPLY et certification runtime post-APPLY.
- Ajout de Fedora Kernel Vanilla `@kernel-vanilla/stable`, plancher Linux `7.2.2`, contrôle Secure Boot fail-closed, `kernel-doctor` et rollback explicite vers les kernels Fedora.
- Conservation obligatoire des kernels Fedora déjà installés comme fallback de boot ; aucun retrait agressif de kernels.
- Remplacement des preuves RAM/NVMe déclaratives par des tests automatisés : `stress-ng --verify` à 5600/6000 et `fio` filesystem-safe avec CRC32C sur root + `/data`.
- Les preuves automatisées contiennent le SHA-256 de leurs logs ; root et `/data` doivent résoudre vers deux NVMe physiques distincts.
- Fingerprint renforcé : BIOS/UUID plateforme, CPU, GPU/driver, mémoire, serial/firmware NVMe et EDID disponible.
- La validation suspend/resume n'est plus un prérequis pré-APPLY : elle est déplacée après installation/reboot afin de ne pas bloquer l'installation des corrections qu'elle doit mesurer.
- Ajout d'un vrai benchmark **cold-start Nautilus** : processus absent au départ, mesure jusqu'à possession de `org.gnome.Nautilus`, cible 1200 ms et hard limit 2000 ms.
- Ajout d'un prewarm GNOME login limité à Portal/GIO ; Nautilus lui-même n'est jamais pré-démarré.
- Thumbnails Nautilus configurés `local-only` ; suppression optionnelle d'`ibus-typing-booster` pour réduire une dépendance de premier lancement non nécessaire à ce profil.
- Ajout du display recovery GNOME 50 via `gdctl` : 2560×1440, ~240 Hz, scale 1.0, SDR/default et Full RGB.
- Ajout d'un watcher user sur resume logind, `MonitorsChanged` Mutter et hotplug DRM afin de réappliquer le display state après veille ou power-cycle écran.
- Ajout de `display-doctor`, capture `drm_info` et preuve de repair.
- Blur My Shell désactivé par défaut dans le profil Golden Workstation afin de réduire les variables de compositor à 240 Hz ; Dash to Dock reste activé.
- Ajout de `final-certification` exigeant kernel/GPU/display/GNOME sains, cold-start courant et cinq cycles suspend/resume post-APPLY avec repair récent.
- Ajout d'un générateur Kickstart Fedora 44 protégé ciblant uniquement le NVMe explicitement choisi ; aucune sélection destructive automatique de disque.
- Ajout des contrats CI Golden Workstation et mise à jour de la documentation GNOME/installation.

## 0.7.1 — 2026-08-27

- Hardening WSL2 et supply-chain : isolation runtime bare-metal/WSL2/CI, blocage APPLY/certification hors bare-metal, entrypoints contrôlés et GitHub Actions épinglées.

Voir l'historique Git antérieur pour les versions 0.1.0 à 0.7.0.

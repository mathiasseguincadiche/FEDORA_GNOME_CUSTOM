# Changelog

## 0.9.3 — 2026-08-30

- Ajout d'une politique **Curated GNOME Dock** déterministe après installation des applications professionnelles.
- Ordre épinglé : Nautilus → Brave → Ptyxis → VS Code → Bitwarden → Slack → LibreOffice → GNOME Software.
- Remmina reste installé mais volontairement non épinglé.
- Ajout du script idempotent `configure-dock-favorites.sh` qui écrit et relit `org.gnome.shell favorite-apps`.
- Le module `applications.dock_favorites` valide les IDs, interdit les doublons, applique l'ordre et exige que les huit lanceurs `.desktop` soient réellement exportés.
- `applications-doctor` contrôle désormais l'ordre du dock et la présence des lanceurs ; il est ajouté à la certification bare-metal finale.
- Le Fedora 44 host integration pretest exécute la configuration réelle sous un utilisateur de test dans une session D-Bus et relit le GSettings persistant.
- Ajout du contrat CI `test_dock_favorites_contract.sh` et de `docs/DOCK_FAVORITES.md`.

## 0.9.2 — 2026-08-30

- Ajout de la couche **Fedora Host Bash UX** pour que Ptyxis ouvre directement un Bash professionnel et prêt à travailler sur l'OS hôte.
- Ajout des paquets Fedora officiels `bash-completion`, `fzf`, `zoxide` et `direnv`.
- Ajout d'un profil modulaire sous `~/.config/fedora-gnome-custom/bash/` avec historique, aliases, navigation, complétions et prompt séparés.
- Le `.bashrc` utilisateur n'est jamais remplacé : sauvegarde initiale `bashrc.pre-fgc`, puis bloc géré unique et idempotent.
- Historique étendu à 50 000/100 000 entrées, `histappend`, déduplication et synchronisation multi-terminal `history -a` / `history -n`.
- Prompt Bash natif deux lignes avec utilisateur/hôte, chemin, branche Git, état tracked modifié et code retour en erreur ; aucune commande réseau et aucun framework Starship/Oh My Bash.
- Ajout d'aliases DevOps courts pour Git, Docker Compose, Kubernetes et Terraform, sans alias destructif pour `rm`, `mv`, `cp` ou `sudo`.
- Les complétions de `gh`, `glab`, `kubectl`, `helm` et `minikube` sont générées uniquement si les binaires existent puis mises en cache.
- Ajout de `shell-doctor`, intégré à `workstation-doctor` et à la certification bare-metal finale.
- Le prétest Fedora 44 crée un utilisateur réel dans le conteneur, installe le profil Bash et exécute un smoke test interactif.
- Ajout de `docs/HOST_BASH_UX.md` et passage de la Golden Workstation en version 0.9.2.

## 0.9.1 — 2026-08-30

- Passage de la VM Ubuntu Server 26.04 au profil **Ubuntu DevOps Ready** : objectif `clone → build/test → containerize → deploy` dès le premier login après bootstrap.
- Ajout de GitLab CLI `glab` en complément de Git/Git LFS et GitHub CLI.
- Ajout de Node.js 22 LTS, npm et Corepack pour les projets Angular/JavaScript.
- Ajout d'OpenJDK 21 et Maven pour les projets Java/Spring.
- Ajout de Minikube avec Docker comme driver par défaut, en complément de kind, kubectl et Helm.
- Ajout de K9s, kubectx/kubens et du binaire Go `yq` v4.
- Minikube vérifie le checksum publié de sa release ; `yq` v4.53.3 et K9s v0.51.0 sont épinglés avec SHA-256 attendu. Aucun `curl | bash` n'est introduit.
- `verify-devops.sh` certifie les nouveaux outils, les versions minimales Node/OpenJDK, le driver Minikube et conserve les contrôles Docker/QEMU Guest Agent.
- Le vrai prétest Ubuntu 26.04 compile/exécute un programme Java, exécute Node, vérifie Docker Compose, GitLab CLI et les outils Kubernetes, puis exige leur persistance après reboot.
- Ajout de `docs/UBUNTU_DEVOPS_READY.md` et passage de la Golden Workstation en version 0.9.1.

## 0.9.0 — 2026-08-30

- Ajout de la couche **Desktop & Lifecycle Completion** pour transformer la Golden Workstation en poste principal quotidien/professionnel, sans copier Ubuntu/Yaru ni multiplier les extensions cosmétiques.
- AppIndicator officiel Fedora activé et certifié en complément de Dash to Dock ; Blur My Shell reste désactivé par défaut.
- Intégration GNOME Keyring/Secret Service, CUPS/IPP-over-USB/Avahi/AirScan, VPN OpenVPN/OpenConnect, TuneD PPD, français/dictionnaires/polices, Remmina et support mobile/iPhone.
- Ajout du runtime Intel Arc Level Zero/OpenCL et d'`arc-compute-doctor`, qui exige l'énumération réelle de l'Arc B580.
- Ajout de `portal-doctor` pour certifier ScreenCast/FileChooser/OpenURI et Notification via xdg-desktop-portal/PipeWire/Wayland.
- Politique lifecycle DNF5 : téléchargement automatique autorisé, **installation automatique interdite**, **reboot automatique interdit**, avec `fstrim.timer` et refresh metadata fwupd.
- Ajout d'une sauvegarde utilisateur Restic quotidienne par timer systemd, chiffrée, sans prune silencieux et sans inclure la passphrase Restic ; absence du disque externe = skip propre, pas corruption du statut.
- Durcissement de la certification suspend/resume : un cycle physique ne peut être compté qu'une fois et le repair display doit être postérieur au hook de reprise correspondant.
- `display-doctor` vérifie désormais le `Current mode` réellement actif à 2560×1440 ~240 Hz.
- Restauration des preuves runtime KVM du garde réseau : table nft présente, gateway KVM joignable et LAN physique bloqué depuis Ubuntu lorsque la politique l'exige.
- Extension de la matrice known-good aux composants desktop/portal/power/compute et ajout du contrat CI `test_desktop_lifecycle_contract.sh`.

## 0.8.2 — 2026-08-30

- Ajout d'une politique GNOME explicite imposant les trois contrôles de fenêtre **Réduire / Agrandir / Fermer** à droite via `org.gnome.desktop.wm.preferences button-layout`.
- Le module GNOME applique `:minimize,maximize,close` de façon idempotente et refuse la validation post-APPLY si la valeur réellement enregistrée diffère.
- Ajout d'un contrat CI empêchant une régression silencieuse vers le comportement GNOME par défaut sans boutons Réduire/Agrandir.

## 0.8.1 — 2026-08-30

- Ajout explicite de `amd-ucode-firmware` pour le Ryzen 7 7700 et `intel-gpu-firmware` pour l'Arc B580, avec `firmware-doctor` et détection des échecs de chargement firmware.
- Certification de la MSI MAG B850M Mortar WiFi : Realtek 8126-VB/`r8169`/5000baseT, Wi-Fi 7 et 6 GHz détectés dynamiquement, Bluetooth, ALC4080 USB Audio/PipeWire et xHCI.
- Extension du hook suspend/resume aux contrôleurs réseau/audio/USB et ajout de `usb-resume-doctor` dans chaque preuve post-veille.
- Ajout d'une matrice known-good BIOS + kernel + linux-firmware/microcode + Mesa + Mutter + GNOME Shell + Nautilus + QEMU/libvirt, invalidée lors d'un changement de version jusqu'à recertification.
- Ajout du benchmark T705 KVM `io_uring` vs AIO natif, filesystem-safe, avec sélection persistante du meilleur backend ; `cache=none` et discard/unmap restent la base sûre.
- Ubuntu 26.04 et Windows 11 exposent désormais le channel QEMU Guest Agent, VirtIO RNG et balloon mémoire ; Windows expose aussi le channel SPICE.
- Ajout de `Configure-GuestIntegration.ps1` pour installer/certifier les drivers VirtIO et QEMU Guest Agent depuis l'ISO fourni par l'opérateur.
- `runtime_certification.sh` exige désormais la réponse `guest-ping` des deux VMs et valide les périphériques de virtualisation.
- Ajout du contrat CI `test_hardware_kvm_completion_contract.sh` et de la documentation `HARDWARE_KVM_COMPLETION.md`.

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
- Ajout d'un watcher user sur resume logind, `MonitorsChanged` de Mutter et hotplug/change DRM afin de réappliquer le display state après veille ou power-cycle écran.
- Ajout de `display-doctor`, capture `drm_info` et preuve de repair.
- Blur My Shell désactivé par défaut dans le profil Golden Workstation afin de réduire les variables du compositor à 240 Hz ; Dash to Dock reste activé.
- Ajout de `final-certification` exigeant kernel/GPU/display/GNOME sains, cold-start courant et cinq cycles suspend/resume post-APPLY avec repair récent.
- Ajout d'un générateur Kickstart Fedora 44 protégé ciblant uniquement le NVMe explicitement choisi ; aucune sélection destructive automatique de disque.
- Ajout des contrats CI Golden Workstation et mise à jour de la documentation GNOME/installation.

## 0.7.1 — 2026-08-27

- Hardening WSL2 et supply-chain : isolation runtime bare-metal/WSL2/CI, blocage APPLY/certification hors bare-metal, entrypoints contrôlés et GitHub Actions épinglées.

Voir l'historique Git antérieur pour les versions 0.1.0 à 0.7.0.

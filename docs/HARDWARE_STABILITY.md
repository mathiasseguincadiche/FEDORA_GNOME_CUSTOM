# Stabilité matérielle — Golden Workstation

Politique : **mesurer → reproduire → corriger → recertifier**, jamais appliquer une collection de tweaks kernel au hasard.

## Arc B580 / xe

Le GPU doit rester `8086:e20b` lié à `xe`. Les contrôles couvrent Vulkan, VA-API, journal xe/DRM et état Wayland/Mutter. Aucun `force_probe` n'est autorisé.

## Kernel

Le profil 0.8 utilise Fedora Kernel Vanilla stable avec minimum 7.2.2 et garde les kernels Fedora installés comme fallback. Secure Boot actif bloque ce chemin par défaut tant qu'un workflow de confiance/signature n'a pas été choisi explicitement.

## Display

Après resume ou power-cycle écran, le problème de texte dégradé est traité d'abord comme une renégociation display/KMS/Mutter. Le repair réapplique 1440p/~240 Hz, scale 1.0, SDR/default et Full RGB via `gdctl`. `drm_info` et les journaux xe/DRM/PCIe sont capturés pour corrélation.

## Suspend/resume

Le hook système conserve les captures pre/post. Le watcher user observe logind, Mutter et DRM puis exécute le display repair dans la vraie session GNOME. Cinq cycles sont requis après APPLY/reboot par `final-certification`.

Aucun `s2idle`/`deep`, ASPM, APST ou C-State n'est forcé globalement sans preuve spécifique.

## Stockage

Les deux T705 sont identifiés par modèle/serial/firmware. La baseline exécute un fio filesystem-safe séparé sur `/` et `/data` et vérifie qu'il s'agit de deux NVMe physiques distincts. SMART/NVMe et PCIe errors restent surveillés.

## Reboot anormal

`scripts/collect-boot-failure.sh` reste le collecteur de référence pour journal précédent, xe/DRM, ACPI, PCIe AER, NVMe, MCE/EDAC, watchdog, coredumps et pstore.

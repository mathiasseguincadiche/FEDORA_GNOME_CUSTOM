# Stabilité matérielle

La politique est **mesurer → reproduire → isoler → corriger**, jamais tweaker au hasard.

## Graphique

Les preuves couvrent PCI `8086:e20b`, binding `xe`, Mesa/Vulkan, VA-API, journal `xe`/DRM, session Wayland et état Mutter. Un rendu de police qui se dégrade après veille est traité d'abord comme une possible régression du pipeline graphique/compositeur, pas comme un problème Fontconfig présumé.

## Suspend/resume

Le hook `/usr/lib/systemd/system-sleep/fedora-gnome-custom` capture l'état pré/post. `suspend-doctor` expose le mode `mem_sleep` et les signaux ACPI/DRM/PCIe. Aucun mode `s2idle` ou `deep` n'est forcé automatiquement.

## Redémarrage anormal

`scripts/collect-boot-failure.sh` inspecte le boot précédent : journal, xe/DRM, ACPI, PCIe AER, NVMe, MCE/EDAC, watchdog, coredumps et pstore.

## Stockage

Les T705 sont observés via NVMe SMART. Aucun réglage APST, scheduler ou ASPM n'est appliqué sans preuve.

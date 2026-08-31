# Consolidation pré-1.0 — 0.10.0

Cette release est une phase de durcissement : elle réduit les ambiguïtés plutôt qu'ajouter des fonctions.

## Garanties renforcées

- VM et conteneurs sont détectés explicitement et ne peuvent pas être pris pour du bare-metal ;
- le preflight `--dry-run` est défini comme un plan non-mutant, pas comme une simulation transactionnelle ;
- Kernel Vanilla doit être le `kernel-core` le plus récent réellement disponible dans les dépôts activés, avec plancher 7.2.2 et fallback Fedora ;
- la tolérance de refresh display est réellement pilotée par la configuration ;
- les preuves Nautilus/suspend sont liées au hardware, au kernel, au firmware GPU, à Mesa, Mutter et GNOME Shell ;
- le socle KVM du host est obligatoire dans la certification Golden Workstation lorsqu'il est activé ;
- le Kickstart embarque le SHA Git audité et checkout exactement ce commit ;
- Ubuntu SSH est key-only ; le mot de passe runtime reste utilisable pour console/sudo ;
- le réseau KVM reste IPv4 et refuse l'activation IPv6 tant qu'une isolation dual-stack équivalente n'est pas implémentée ;
- les mises à jour Flatpak restent explicites/manuelles ;
- la provenance des applications professionnelles est documentée ;
- les dépendances externes Fedora/Flathub/Ubuntu sont retestées chaque semaine.

## Ce que la CI ne remplace toujours pas

La certification physique reste obligatoire pour l'Arc B580/`xe`, l'affichage 1440p/240 Hz, les cycles suspend/resume, les deux T705, le comportement firmware/BIOS et l'isolation runtime réelle du LAN KVM.

## Objectif 1.0

La 1.0 doit être déclenchée par une installation bare-metal complète et une période d'usage réel stable, pas par l'ajout de nouvelles fonctionnalités.

# Golden Workstation 0.8.0

## Objectif

La version 0.8 sépare volontairement deux notions qui étaient mélangées :

1. **baseline pré-APPLY** : prouver que le matériel est suffisamment sain pour autoriser les mutations ;
2. **certification runtime post-APPLY** : prouver que la pile réellement installée corrige les problèmes ciblés et reste stable sur le vrai matériel.

Cette séparation est essentielle pour suspend/resume : un défaut que le nouvel APPLY doit corriger ne doit jamais empêcher l'installation du correctif.

## Kernel

Le profil installe le dernier kernel stable upstream via Fedora Kernel Vanilla `@kernel-vanilla/stable`, avec un plancher `7.2.2`. Les packages Fedora kernel existants ne sont pas supprimés et servent de fallback.

Secure Boot actif provoque un blocage avant mutation par défaut. Le projet ne désactive jamais Secure Boot automatiquement et ne génère/importera jamais une clé MOK sans décision opérateur explicite.

## Cold-start Nautilus

La métrique est volontairement stricte : Nautilus doit être absent avant le test. Le chronomètre démarre juste avant `nautilus --new-window` et s'arrête lorsque `org.gnome.Nautilus` possède son nom D-Bus.

Le prewarm de login ne démarre donc jamais Nautilus. Il touche uniquement Portal/GIO et lit les préférences nécessaires afin de sortir ces coûts de la première interaction Files sans fausser la mesure.

Seuils par défaut :

- cible : `1200 ms` ;
- hard limit de certification : `2000 ms`.

## Display recovery

Le symptôme « caractères/polices dégradés après veille ou power-cycle écran » est traité comme un problème potentiel de chaîne DRM/KMS/Mutter/link plutôt que comme un problème Fontconfig présumé.

Le repair via `gdctl` réapplique :

- 2560×1440 ;
- mode le plus proche de 240 Hz ;
- scale 1.0 ;
- color mode `default` (SDR) ;
- RGB range `full`.

Le watcher de session déclenche le repair après reprise logind, changement Mutter et hotplug DRM. Chaque application conserve un rapport dans `~/.local/state/fedora-gnome-custom/`.

## Extensions

Dash to Dock reste autorisé. Blur My Shell est désactivé par défaut : il ajoute un coût/chemin de rendu cosmétique sans bénéfice fonctionnel et complique la recherche de régressions à 240 Hz ou après resume.

## Baseline automatisée

RAM : `stress-ng --verify` à 5600 puis 6000 MT/s ; la vitesse configurée est vérifiée par SMBIOS avant le test.

NVMe : `fio` travaille sur un fichier temporaire de 4 Gio dans le filesystem root puis `/data`, avec I/O direct et vérification CRC32C. Aucun test n'écrit sur le block device brut. Les deux mountpoints doivent résoudre vers deux disques NVMe physiques différents.

Les preuves contiennent le SHA-256 du log. Le fingerprint matériel incorpore BIOS/UUID plateforme, CPU, GPU/driver, classe mémoire, modèle/serial/firmware NVMe et EDID disponible.

## Certification finale

Après APPLY et reboot :

1. lancer `diagnostics/nautilus-coldstart-doctor` immédiatement après login ;
2. effectuer cinq cycles suspend/resume ;
3. après chaque cycle lancer `diagnostics/final-certification record-suspend` ;
4. terminer avec `diagnostics/final-certification certify`.

Le cycle suspend est refusé si kernel, Arc/xe ou display doctor échouent, si des signatures xe/PCIe/NVMe critiques sont apparues, ou si le marker du repair display n'est pas récent.

## Politique de remédiation

Le projet n'ajoute aucun `xe.force_probe`, `i915.force_probe`, `pcie_aspm=off`, `nvme_core.default_ps_max_latency_us` ou forçage `mem_sleep_default` global sans preuve matérielle spécifique. Les versions modernes Fedora/kernel/Mutter sont essayées et mesurées avant toute exception permanente.

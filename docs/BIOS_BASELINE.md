# BIOS / UEFI baseline

La carte cible est la MSI MAG B850M MORTAR WIFI. Le projet valide UEFI natif, Secure Boot, virtualisation AMD et un grand BAR/ReBAR pour l'Intel Arc B580. Il documente également l'attente CSM désactivé.

Aucun script ne flashe le BIOS, ne modifie EXPO/PBO/Curve Optimizer, ne change C-states/ASPM et ne réinitialise le CMOS. Toute modification firmware reste une action opérateur explicite suivie d'une nouvelle certification matérielle.

La DDR5-6000 est un profil d'overclock mémoire : après toute modification UEFI/EXPO, relancer le stress de stabilité et les cycles de veille.

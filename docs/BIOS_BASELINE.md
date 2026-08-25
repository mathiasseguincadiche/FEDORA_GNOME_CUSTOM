# BIOS / UEFI baseline

La carte cible est la MSI MAG B850M MORTAR WIFI. Le projet valide UEFI natif, Secure Boot, virtualisation AMD/IOMMU et un grand BAR/ReBAR pour l'Intel Arc B580. Il documente également l'attente CSM désactivé.

Aucun script ne flashe le BIOS, ne modifie A-XMP/EXPO/PBO/Curve Optimizer, ne change C-states/ASPM et ne réinitialise le CMOS. Toute modification firmware reste une action opérateur explicite suivie d'une nouvelle certification matérielle.

Le kit de la workstation utilise son profil XMP 3.0 à 6000 MT/s via la prise en charge A-XMP de la carte mère. Le projet traite donc DDR5-6000 comme un profil d'overclock mémoire à **certifier**, pas comme la valeur JEDEC/POR garantie par le Ryzen 7 7700. `stability-stress.sh` refuse désormais de produire un PASS si SMBIOS ne rapporte pas exactement 6000 MT/s pour les DIMM configurées.

Après toute modification UEFI/A-XMP, relancer le stress de stabilité et les cycles de veille avant de considérer la workstation certifiée.

# GNOME / Nautilus — intégration Golden Workstation

Le bureau reste Fedora GNOME 50/Wayland proche de l'upstream. L'objectif n'est pas de copier Ubuntu/Yaru mais d'obtenir une pile GNOME maintenable, mesurable et spécifique au matériel cible.

## Nautilus

Le socle installe Nautilus + GVfs SMB/MTP/caméra/FUSE et les portals GNOME. La politique de previews est `local-only` afin que les volumes réseau/amovibles ne pénalisent pas le premier lancement.

Un service user `fedora-gnome-nautilus-prewarm.service` préchauffe uniquement Portal/GIO. Il ne démarre jamais Nautilus : `diagnostics/nautilus-coldstart-doctor` mesure donc un vrai premier démarrage Files après login.

Ptyxis reste le terminal natif géré. Les bookmarks SFTP/SMB des VM sont maintenus séparément par `scripts/kvm/configure_nautilus_vm_access.sh`.

## Display / rendu

Les réglages de rasterisation des polices restent upstream. Le projet ne masque pas une dégradation post-resume avec des tweaks Fontconfig : le display recovery rétablit le mode Mutter/KMS attendu, notamment 1440p/240 Hz, SDR/default et Full RGB.

## Extensions

- Dash to Dock : activé, paquet Fedora, defaults upstream conservés.
- Blur My Shell : **désactivé par défaut** dans 0.8 pour réduire les variables du compositor à 240 Hz et pendant la certification suspend/resume.
- Extension Manager : installé pour l'administration.
- Just Perfection : exclu.

Toute nouvelle extension doit être testée A/B et ne peut pas être utilisée pour masquer un problème Mutter/Wayland/GPU.

## Applications

Les applications graphiques natives sélectionnées utilisent GTK4/libadwaita quand une solution GNOME de qualité existe. Les applications professionnelles non-GTK4 restent des exceptions fonctionnelles explicitement documentées.

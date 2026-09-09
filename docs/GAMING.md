# Gaming — Fedora 44 / GNOME 50 / Intel Arc B580

## Périmètre

Le profil Gaming fait partie de la **Golden Workstation canonique**. Il ajoute le runtime de jeu Linux sans modifier la frontière DevOps/KVM, sans remplacer le kernel/Mesa Fedora et sans appliquer de tuning global agressif.

La configuration canonique est :

```bash
GAMING_ENABLE="true"
```

Une surcharge locale peut servir au dépannage ou à un build volontairement réduit, mais une machine avec Gaming désactivé n'est pas la Golden cible et ne peut pas obtenir la certification finale attendue.

Pour le dépannage, voir [`RUNBOOK_PERSISTENT_DATA_GAMING.md`](RUNBOOK_PERSISTENT_DATA_GAMING.md).

## Stockage persistant des jeux

Le second T705 fournit la racine canonique :

```text
/data/Jeux
```

Cette racine existe indépendamment de Steam, survit à une réinstallation normale du SSD système Btrfs et suit le même contrat utilisateur/SELinux que `/data/Documents`, `/data/Projets` et `/data/ISO`.

`diagnostics/data-storage-doctor` vérifie le layout. Lorsque Gaming est actif, `diagnostics/gaming-doctor` exige en plus que `/data/Jeux` soit disponible et inscriptible.

Steam est installé en RPM natif : aucune permission filesystem Flatpak n'est nécessaire pour `/data/Jeux`.

Le projet ne génère et ne réécrit pas `libraryfolders.vdf`. Après le premier lancement, enregistrer `/data/Jeux` depuis **Steam → Settings → Storage**. Le contrat Golden reste ainsi indépendant du format privé de Steam et le même répertoire peut être utilisé ultérieurement par d'autres launchers.

`/data/Jeux` est exclu des backups Restic daily/full automatiques par défaut, car les jeux installés sont volumineux et généralement retéléchargeables. Toute donnée non reproductible stockée directement sous `/data/Jeux` nécessite une politique de backup explicite.

## Stack Golden

### Steam

Steam est installé comme RPM natif depuis le dépôt dédié `rpmfusion-nonfree-steam`.

Le projet provisionne explicitement les métadonnées requises, vérifie `/etc/yum.repos.d/rpmfusion-nonfree-steam.repo` et active ce dépôt uniquement pour la transaction d'installation Steam avec :

```text
--enablerepo=rpmfusion-nonfree-steam
```

Aucun dépôt GPU tiers n'est ajouté.

### Proton

Ordre de compatibilité :

1. Valve Proton géré par Steam ;
2. Proton Experimental si un titre demande une couche Valve plus récente ;
3. Proton-GE uniquement comme exception explicite par titre.

Le profil Golden ne télécharge pas Proton-GE automatiquement, ne l'impose pas globalement et n'installe pas Wine système simplement parce que Steam est activé.

### Vulkan et multilib 32 bits

Steam/Proton nécessitent les bibliothèques graphiques x86_64 et i686. Le profil converge notamment :

- `mesa-vulkan-drivers.x86_64` et `.i686` ;
- `mesa-dri-drivers.x86_64` et `.i686` ;
- `vulkan-loader.x86_64` et `.i686` ;
- `vulkan-tools`.

Le GPU reste sur le pilote kernel Fedora `xe` et Mesa/ANV Fedora. Aucun `mesa-git`, COPR Mesa, dépôt GPU Intel tiers, `force_probe` ou kernel gaming n'appartient au contrat Golden.

### Helpers Gaming

- GameMode — politique temporaire par jeu ;
- MangoHud — FPS/frametime/GPU/CPU ;
- GOverlay — configuration graphique des overlays ;
- Gamescope — micro-compositeur optionnel par titre ;
- `steam-devices` — règles udev pour périphériques/manettes supportés.

Aucun de ces outils n'est injecté globalement dans tous les jeux.

## Politique de lancement

Option par défaut : **aucune**.

Commencer avec le lancement Steam normal puis ajouter un helper seulement si utile :

```text
gamemoderun %command%
mangohud %command%
mangohud gamemoderun %command%
```

Les options Gamescope dépendent du titre et de l'affichage et ne doivent pas devenir une chaîne universelle.

## CI versus preuve bare-metal

Le pretest Gaming Fedora 44 valide en conteneur headless :

- disponibilité des paquets Fedora/RPM Fusion ;
- définition du dépôt `rpmfusion-nonfree-steam` ;
- installation/ownership du RPM Steam sans lancer la GUI ;
- payload Vulkan x86_64/i686 ;
- GameMode, MangoHud, GOverlay, Gamescope et Steam Input ;
- politique de dépôts ;
- contrats statiques du projet.

La CI **ne prouve pas** le rendu GPU, le VRR, le 240 Hz ou le lancement réel d'un jeu.

Sur la workstation physique, `diagnostics/gaming-doctor` vérifie en plus :

- `/data/Jeux` sur le second T705 EXT4 conforme ;
- Intel Arc B580 attachée à `xe` ;
- renderer Vulkan Intel visible via `vulkaninfo` ;
- GNOME/Wayland ;
- 2560×1440 à la cible ~240 Hz ;
- visibilité VRR/adaptive-sync lorsque l'outillage GNOME l'expose ;
- présence de Proton géré par Steam après initialisation.

Un Proton absent sur une installation Steam fraîche est un WARN, pas un KO : Steam télécharge les compatibility tools à la demande.

## Certification

Après APPLY et reboot :

```bash
./control.sh doctor data
./control.sh doctor gaming
```

Puis utiliser la chaîne Golden normale. `diagnostics/final-certification certify` exécute le Gaming doctor parce que `GAMING_ENABLE=true` fait partie du profil cible.

La preuve Gaming possède donc deux niveaux :

1. GitHub Actions prouve provisioning, résolution des paquets, RPM Steam, Vulkan multilib et contrats ;
2. Gate 3 prouve stockage persistant, B580/`xe`, Vulkan, GNOME/Wayland, affichage et payload Gaming sur la vraie machine.

Un premier lancement de jeu réel reste un test d'acceptation opérateur : authentification Steam, anti-cheat, DRM et compatibilité Proton d'un titre sont des variables externes.

## Exclusions volontaires

La Golden Gaming ne :

- remplace pas Fedora par un kernel gaming ;
- ajoute pas Mesa git/COPR ni dépôt GPU tiers ;
- applique pas de `sysctl`, scheduler ou governor hack global ;
- force pas Gamescope ou MangoHud partout ;
- force pas Proton-GE globalement ;
- installe pas Heroic/Lutris/Wine dans le socle Steam initial.

Heroic ou Lutris pourront être évalués plus tard comme intégrations optionnelles après certification de la base Steam/Proton sur bare-metal.

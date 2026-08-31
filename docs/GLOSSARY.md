# Glossaire Fedora / KVM / Golden Workstation

Ce glossaire donne une définition courte des termes utilisés dans le projet. Il vise d'abord la compréhension pratique, pas l'exhaustivité académique.

## Système et projet

**HOST** — la machine Fedora physique. Ici, il s'agit de la workstation principale.

**Guest / invité** — système d'exploitation exécuté dans une machine virtuelle, par exemple `ubuntu-devops` ou `windows-11`.

**Bare-metal** — système exécuté directement sur le matériel physique, et non dans une VM, un conteneur ou WSL2.

**Golden Workstation** — état de référence recherché par le projet : configuration installée, mesurée, sauvegardable et certifiée sur le matériel réel.

**Convergence / APPLY** — phase qui modifie réellement le système afin qu'il corresponde au contrat versionné.

**Preflight / dry-run** — contrôles et plan non-mutants exécutés avant APPLY. Le projet ne prétend pas simuler transactionnellement toutes les mutations.

**Doctor** — script de diagnostic/validation du projet, généralement read-only.

**Certification** — preuve que plusieurs contrôles exigés sont réellement passés sur l'environnement prévu.

## Fedora et sécurité

**RPM** — format et écosystème de paquets natifs Fedora.

**DNF5** — gestionnaire de paquets de Fedora 44 utilisé pour installer et résoudre les RPM.

**RPM Fusion** — dépôts complémentaires utilisés notamment pour certains codecs multimédias non fournis directement par Fedora.

**Flatpak** — format d'applications sandboxées utilisé pour certaines applications graphiques.

**SELinux** — contrôle d'accès obligatoire de Fedora. Le projet exige `Enforcing` et ne le désactive pas pour contourner un problème.

**firewalld** — couche de gestion du pare-feu Fedora. Elle organise notamment les interfaces dans des zones.

**nftables** — moteur de filtrage réseau Linux sous-jacent. Le projet possède une table nftables dédiée au guard KVM sans purger le firewall global.

**Secure Boot** — mécanisme UEFI qui n'autorise que des composants de démarrage reconnus comme fiables. Le chemin Kernel Vanilla du projet bloque actuellement lorsqu'il est actif sans workflow de signature explicite.

## Virtualisation

**QEMU** — moteur d'émulation/virtualisation utilisé pour exécuter les VM.

**KVM** — accélération matérielle du noyau Linux permettant à QEMU d'exécuter efficacement les VM sur le CPU réel.

**libvirt** — couche d'administration qui gère domaines, réseaux, pools et autres ressources de virtualisation.

**`qemu:///system`** — connexion libvirt système utilisée par le projet. Les VM sont gérées au niveau du host, pas dans une session libvirt privée de l'utilisateur.

**Domain / domaine** — nom libvirt d'une VM.

**Q35** — type de machine virtuelle moderne basé sur un chipset PCIe émulé ; c'est la base des deux profils de référence.

**OVMF** — implémentation UEFI utilisée par les VM QEMU/KVM.

**swtpm** — émulation logicielle d'un TPM. Windows 11 utilise un TPM 2.0 émulé.

**VirtIO** — familles de périphériques para-virtualisés performants pour disque, réseau, RNG, balloon mémoire, etc.

**QEMU Guest Agent / QGA** — agent exécuté dans le guest permettant à libvirt/QEMU d'obtenir des informations et d'effectuer certaines opérations propres dans la VM.

**SPICE** — protocole d'affichage/console utilisé pour la VM Windows. Il ne fournit pas les performances d'un GPU passé directement au guest.

**GPU passthrough / VFIO** — attribution directe d'un GPU physique à une VM. Ce projet l'interdit pour l'Arc B580, qui reste au HOST.

## Stockage KVM

**Pool libvirt** — emplacement de stockage déclaré à libvirt. `devops-data` pointe vers `/data/libvirt/images`.

**qcow2** — format d'image disque QEMU permettant notamment allocation dynamique et certaines fonctions de snapshot.

**`/data`** — point de montage EXT4 du deuxième Crucial T705, réservé au stockage KVM et aux données associées.

**IOThread** — thread QEMU dédié aux entrées/sorties d'un disque lorsque le backend et `virt-install` le permettent.

**`cache=none`** — mode de cache QEMU choisi par le projet pour éviter une double mise en cache inutile et conserver un comportement I/O prévisible.

**`discard=unmap`** — permet au guest de signaler les blocs libérés afin que la chaîne de stockage puisse récupérer l'espace lorsque cela est supporté.

## Réseau KVM

**Bridge** — interface virtuelle reliant plusieurs interfaces/VM sur un même segment. `virbr50` est le bridge libvirt de `devops-nat`; ce n'est ni le port Ethernet ni l'interface Wi-Fi physique.

**NAT** — traduction d'adresses permettant aux VM privées d'accéder à Internet en utilisant la connectivité du HOST sans être directement exposées comme des machines du LAN.

**DHCP** — attribution automatique d'adresses IP. `devops-nat` distribue des adresses `192.168.50.100-200`.

**DNS** — résolution de noms. Le réseau libvirt transfère les requêtes vers Quad9 et Cloudflare selon le contrat versionné.

**`devops-nat`** — réseau KVM privé du projet : `192.168.50.0/24`, passerelle `192.168.50.254`, bridge `virbr50`.

**LAN physique** — réseau directement connecté au HOST via son uplink courant. Le guard empêche les VM de l'atteindre et empêche son trafic d'être forwardé vers les VM.

**Fail-closed** — en cas d'échec d'un contrôle de sécurité, le système reste dans l'état restrictif. Le guard KVM entre désormais d'abord en mode d'urgence avant de recalculer les règles normales.

## Provisionnement VM

**Cloud image** — image disque préinstallée destinée à être personnalisée au démarrage. `ubuntu-devops` part d'une image Ubuntu Server 26.04 Canonical.

**cloud-init** — système de configuration initiale d'une image cloud : utilisateur, clé SSH, fichiers, commandes de premier démarrage, etc.

**Seed / NoCloud** — petit média contenant `user-data` et `meta-data` que cloud-init lit au premier boot.

**SHA-256** — fonction de hachage utilisée pour vérifier qu'un fichier correspond exactement au contenu attendu.

**Signature GPG** — mécanisme permettant de vérifier qu'une liste de checksums a été signée par la clé attendue. Le workflow Ubuntu authentifie `SHA256SUMS` avant de faire confiance au SHA-256 de l'image.

## Bureau GNOME

**GNOME Shell** — shell graphique principal du bureau GNOME.

**Mutter** — compositeur et gestionnaire de fenêtres de GNOME.

**Wayland** — protocole d'affichage utilisé comme contrat graphique du projet.

**Portal / xdg-desktop-portal** — interfaces D-Bus utilisées par les applications sandboxées/Wayland pour des actions comme FileChooser ou ScreenCast.

**GNOME Keyring / Secret Service** — stockage de secrets intégré à la session GNOME.

**Dash to Dock** — extension GNOME Shell gérée et activée par le projet.

**AppIndicator** — extension fournissant la compatibilité avec les applications utilisant AppIndicator/KStatusNotifierItem ; elle est également activée dans le profil courant.

## Backup

**Restic** — outil de sauvegarde chiffrée et dédupliquée utilisé par le projet.

**Canary restore** — petit fichier réellement restauré puis comparé afin de prouver qu'un backup n'est pas seulement lisible mais restaurable.

**Staging-first** — restauration d'abord dans un répertoire intermédiaire afin d'inspecter le contenu avant de modifier le système live.

# Glossaire

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — terminologie de Gate 2, Gate 3 et GO / NO-GO relue contre `lib/validation_gates.sh` et le guide Live USB — matériel : non vérifié

Définitions courtes des termes du projet, pour la compréhension pratique. Les conventions de rédaction sont dans le [guide du contributeur](../CONTRIBUTING.md#écrire-la-documentation).

## Termes retenus

Un même concept porte le même nom dans tous les guides. Les variantes anglaises restent permises dans les commandes, les noms de fichiers, les variables et les noms propres, qui gardent leur orthographe exacte.

| Terme retenu | Variantes à éviter dans le texte | Où la variante reste correcte |
|---|---|---|
| hôte | HOST, host | `HOST_BASH_UX.md`, variables comme `HOST_*` |
| matériel physique, PC physique | bare-metal | messages affichés par le code |
| noyau | kernel | `./control.sh kernel`, paquets `kernel-*`, Kernel Vanilla, kernel.org |
| sauvegarde | backup | `./control.sh backup`, `scripts/backup/`, `backup-doctor` |
| garde réseau | guard | `guard-check`, `guard_mode`, `kvm-network-guard` |
| restauration canari, fichier témoin | canary | — |
| laboratoire | labo | — |
| fermé par défaut | — | *fail-closed*, entre parenthèses, à la première occurrence |

## Système et projet

**Golden / installation Golden** — recette versionnée d'un environnement, reproductible, récupérable et vérifiable. Ce n'est **pas** une distribution Fedora dérivée ni une ISO modifiée.

**Profil de release** — combinaison approuvée de Fedora, GNOME, média signé, manifestes et verrou d'extensions.

**`pending` (profil)** — release non encore autorisée en production : impossible de la promouvoir par simple changement de numéro.

**`ready` (profil)** — identité finale et verrous promus ; ce n'est **ni un PASS CI, ni une qualification physique**.

**`Golden runtime-certified`** — état du véritable PC après preuve Gate 3, lié à son commit et sa configuration.

**`STALE`** — preuve devenue obsolète après changement significatif de code, matériel, noyau ou configuration : requalification nécessaire.

**Gate 1 / CI** — contrôles logiciels exécutés sur les machines de la plateforme GitHub, pour un commit donné. Aucune preuve physique sur le PC cible.

**Gate 2 / Live USB** — observations sur le PC physique avant installation. Le rapport porte `PREINSTALL_ONLY` et ne certifie pas le système installé.

**Gate 3** — qualification finale de Fedora installé et configuré sur le PC physique, après les essais prescrits ([qualification](QUALIFICATION.md)).

**`GO`, `NO-GO`, `A_VERIFIER` (contrôle Live)** — décision calculée à partir des observations de Gate 2 : requis réussis sans échec, défaut constaté, ou observation requise manquante. Le résultat `GO` n'est pas une autorisation de formater le disque.

**Décision humaine GO / NO-GO** — accord ou refus explicite du propriétaire *après* examen et export des résultats Live USB. C'est un point d'arrêt avant installation, **pas une quatrième Gate** ni un remplacement de la Gate 3.

**Compte rendu Live** — résultat du contrôle depuis le Live USB, lié au commit et au matériel ; exporté puis importé sur le système installé. Il vaut `PREINSTALL_ONLY` et ne déverrouille jamais l'APPLY.

**Baseline** — empreinte matérielle et logicielle enregistrée avant l'APPLY. L'APPLY exige une baseline valide pour l'empreinte courante.

**Sauvegarde pré-APPLY** — point de retour de l'état du système, pris juste avant l'APPLY et vérifié par restauration d'un témoin. Elle ne contient pas `/data` ([sauvegardes](BACKUP_RESTORE.md)).

**`DEFERRED`** — preuve reportée à un environnement capable de la donner (le PC, une session réelle). Ce n'est ni un succès ni un échec.

**ADR** — Architecture Decision Record : décision écrite, avec son contexte et ses conséquences ([liste](adr/README.md)).

**N / N-1** — le noyau Linux amont courant et le précédent, gardé pour le retour arrière ; un noyau Fedora signé reste en secours ([Linux amont](UPSTREAM_LINUX.md)).

**Hôte** (*host*) — la machine Fedora physique, le poste de travail principal.

**Invité (guest)** — système d'exploitation exécuté dans une machine virtuelle, ici `rocky-devops`.

**Matériel physique** (*bare-metal*) — système exécuté directement sur le PC, et non dans une VM, un conteneur ou WSL2.

**Golden Workstation** — état de référence recherché par le projet : configuration installée, mesurée, sauvegardable et certifiée sur le matériel réel.

**Convergence / APPLY** — phase qui modifie réellement le système afin qu'il corresponde au contrat versionné.

**Preflight / dry-run** — contrôles et plan non-mutants exécutés avant APPLY. Le projet ne prétend pas simuler transactionnellement toutes les mutations.

**Doctor** — script de diagnostic ou de validation du projet, en général en lecture seule.

**Certification** — preuve que plusieurs contrôles exigés sont réellement passés sur l'environnement prévu.

## Fedora et sécurité

**RPM** — format et écosystème de paquets natifs Fedora.

**DNF5** — gestionnaire de paquets de Fedora 45 utilisé pour installer et résoudre les RPM.

**RPM Fusion** — dépôts complémentaires, utilisés pour certains codecs multimédia et pour Steam ([provenance](SUPPLY_CHAIN.md#dépôts-rpm-fusion)).

**COPR** — service de dépôts communautaires de Fedora, signés par COPR. Le projet en utilise deux : le noyau amont (`@kernel-vanilla/stable`) et, en option, Sunshine.

**Flatpak** — format d'applications sandboxées utilisé pour certaines applications graphiques.

**SELinux** — contrôle d'accès obligatoire de Fedora. Le projet exige `Enforcing` et ne le désactive pas pour contourner un problème.

**firewalld** — couche de gestion du pare-feu Fedora. Elle organise notamment les interfaces dans des zones.

**nftables** — moteur de filtrage réseau Linux sous-jacent. Le projet possède une table nftables dédiée au garde réseau KVM sans purger le firewall global.

**Secure Boot** — mécanisme UEFI qui n'autorise que des composants de démarrage signés par une clé reconnue. La politique de l'hôte l'exige désactivé, et l'installation du noyau amont est bloquée s'il est actif ([politique de sécurité](HOST_SECURITY_POLICY.md)).

## Virtualisation

**QEMU** — moteur d'émulation/virtualisation utilisé pour exécuter les VM.

**KVM** — accélération matérielle du noyau Linux permettant à QEMU d'exécuter efficacement les VM sur le CPU réel.

**libvirt** — couche d'administration qui gère domaines, réseaux, pools et autres ressources de virtualisation.

**`qemu:///system`** — connexion libvirt système utilisée par le projet. Les VM sont gérées au niveau du host, pas dans une session libvirt privée de l'utilisateur.

**Domain / domaine** — nom libvirt d'une VM.

**Q35** — type de machine virtuelle moderne basé sur un chipset PCIe émulé ; c'est la base des deux profils de référence.

**OVMF** — implémentation UEFI utilisée par les VM QEMU/KVM.

**swtpm** — émulation logicielle d'un TPM, utilisée par certains exercices Linux de reprise CI. Le profil Rocky géré ne l'exige pas.

**VirtIO** — familles de périphériques para-virtualisés performants pour disque, réseau, RNG, balloon mémoire, etc.

**QEMU Guest Agent / QGA** — agent exécuté dans le guest permettant à libvirt/QEMU d'obtenir des informations et d'effectuer certaines opérations propres dans la VM.

**SPICE** — protocole d'affichage/console de machines virtuelles. Le profil Rocky du projet est headless, administré par SSH.

**GPU passthrough / VFIO** — attribution directe d'un GPU physique à une VM. Ce projet l'interdit pour l'Arc B580, qui reste à l'hôte.

## Stockage persistant et KVM

**Pool libvirt** — emplacement de stockage déclaré à libvirt. `devops-data` pointe vers `/data/libvirt/images`.

**qcow2** — format d'image disque QEMU permettant notamment allocation dynamique et certaines fonctions de snapshot.

**`/data`** — point de montage EXT4 du deuxième Crucial T705, le stockage persistant du poste : `/data/Documents`, `/data/Projets`, `/data/ISO`, `/data/Jeux`, `/data/IA/Openclaw` et `/data/libvirt`, réservé à KVM.

**Données persistantes** — données placées sur le second T705 afin qu'une réinstallation du SSD système Btrfs ne les efface pas. Cette séparation physique ne remplace pas une sauvegarde externe contre la panne du second SSD.

**XDG Documents** — répertoire standard « Documents » de la session graphique. Dans le profil Golden, il est redirigé vers `/data/Documents`.

**IOThread** — thread QEMU dédié aux entrées/sorties d'un disque lorsque le backend et `virt-install` le permettent.

**`cache=none`** — mode de cache QEMU choisi par le projet pour éviter une double mise en cache inutile et conserver un comportement I/O prévisible.

**`discard=unmap`** — permet au guest de signaler les blocs libérés afin que la chaîne de stockage puisse récupérer l'espace lorsque cela est supporté.

## Réseau KVM

**Bridge** — interface virtuelle reliant plusieurs interfaces/VM sur un même segment. `virbr50` est le bridge libvirt de `devops-nat`; ce n'est ni le port Ethernet ni l'interface Wi-Fi physique.

**NAT** — traduction d'adresses permettant aux VM privées d'accéder à Internet en utilisant la connectivité de l'hôte sans être directement exposées comme des machines du LAN.

**DHCP** — attribution automatique d'adresses IP. `devops-nat` distribue des adresses `192.168.50.100-200`.

**DNS** — résolution de noms. Le réseau libvirt transfère les requêtes vers Quad9 et Cloudflare selon le contrat versionné.

**`devops-nat`** — réseau KVM privé du projet : `192.168.50.0/24`, passerelle `192.168.50.254`, bridge `virbr50`.

**LAN physique** — réseau directement connecté à l'hôte par son lien actif. Le garde réseau KVM empêche les VM de l'atteindre, et son trafic d'être transmis vers les VM.

**Fail-closed** — en cas d'échec d'un contrôle de sécurité, le système reste dans l'état restrictif. Le garde réseau KVM passe d'abord en mode d'urgence avant de recalculer les règles normales.

## Provisionnement VM

**Cloud image** — image disque préinstallée destinée à être personnalisée au démarrage. `rocky-devops` part d'une image officielle Rocky Linux 10.2.

**cloud-init** — système de configuration initiale d'une image cloud : utilisateur, clé SSH, fichiers, commandes de premier démarrage, etc.

**Seed / NoCloud** — petit média contenant `user-data` et `meta-data` que cloud-init lit au premier boot.

**SHA-256** — fonction de hachage utilisée pour vérifier qu'un fichier correspond exactement au contenu attendu.

**Signature GPG** — mécanisme permettant de vérifier qu'une liste de checksums a été signée par la clé attendue. Le workflow Rocky Linux authentifie `CHECKSUM` avant de faire confiance au SHA-256 de l'image.

## Bureau GNOME

**GNOME Shell** — shell graphique principal du bureau GNOME.

**Mutter** — compositeur et gestionnaire de fenêtres de GNOME.

**Wayland** — protocole d'affichage utilisé comme contrat graphique du projet.

**Portal / xdg-desktop-portal** — interfaces D-Bus utilisées par les applications sandboxées/Wayland pour des actions comme FileChooser ou ScreenCast.

**GNOME Keyring / Secret Service** — stockage de secrets intégré à la session GNOME.

**Six extensions** — Dash to Dock et AppIndicator (RPM Fedora), Gtk4 DING, Show Desktop Button, Vitals et Tiling Assistant (archives épinglées). Chacune remplit un rôle précis ([GNOME](GNOME.md)).

**Dash to Dock** — extension qui transforme le dash de GNOME en dock permanent.

**AppIndicator** — extension qui affiche les icônes d'état des applications (AppIndicator, KStatusNotifierItem).

## Sauvegarde

**Borg (BorgBackup)** — outil de sauvegarde dédupliquée et compressée utilisé par le projet, ici avec un dépôt **non chiffré** ([ADR 0014](adr/0014-borg-unencrypted-backups.md)).

**Restauration canari** (*canary restore*) — petit fichier témoin réellement restauré puis comparé, pour prouver qu'une sauvegarde n'est pas seulement lisible mais restaurable.

**Staging-first** — restauration d'abord dans un répertoire intermédiaire afin d'inspecter le contenu avant de modifier le système live.

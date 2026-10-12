# Feuille de route technique — Fedora Golden Workstation, octobre 2026

**Périmètre :** Fedora Workstation sur un PC fixe MSI MAG B850M MORTAR WIFI, Ryzen 7 7700, 48 Gio DDR5, Intel Arc B580, deux Crucial T705, moniteur QD-OLED 2560×1440/240 Hz, réseau Wi-Fi 7 / 5 GbE, GNOME Wayland, VMs Rocky Linux et Windows, sauvegardes Borg et accès distant facultatif depuis tablette Android.

**But :** une workstation **stable, explicable, reproductible, réversible et mesurable**, utilisée quotidiennement pour l'apprentissage et le travail DevOps, sans compromis silencieux sur la sécurité ni sur les données.

Ce document est un **plan d'ingénierie**, pas une proclamation de résultats. Toute amélioration doit rester proportionnée : le mieux est parfois **moins d'extensions, moins de services permanents et plus de preuves**.

## Décision de release au 12 octobre 2026

- **GNOME 51 “A Coruña”** est sorti le **16 septembre 2026**.
- **Fedora 45 finale** est prévue pour le **20 octobre 2026** selon le calendrier Fedora ; un report est possible.
- `profiles/fedora45/profile.json` reste `pending`. Pas d'APPLY Fedora 45 ni de verrou média fictif avant signature et hash final authentifiés.
- Les tests du dépôt peuvent être verts sans certificat de la machine réelle. La qualification sur PC est une phase **distincte**.

Sources officielles : [calendrier Fedora 45](https://fedorapeople.org/groups/schedule/f-45/f-45-key-tasks.html), [GNOME 51](https://release.gnome.org/51/), [Fedora 45 ChangeSet](https://fedoraproject.org/wiki/Releases/45/ChangeSet).

## Matrice de qualité : ce qui devra être démontré

| Priorité | Chantier | Critère d'acceptation mesurable | Statut |
|---|---|---|---|
| **P0** | Authentification de l'ISO Fedora 45 | `CHECKSUM` signé, empreinte ISO et compose final correspondants ; profil promu en PR | **En attente** de la release finale |
| **P0** | Préqualification Live non destructive | CPU/carte mère/GPU/pilote et deux T705 contrôlés ; absence de mutations ; `FAIL` explicite | **Renforcé** dans cette évolution, à tester |
| **P0** | Chaîne Gate 1 / 2 / 3 | preuves du **même commit**, Gate 2 GNOME 51 réellement observée, puis Gate 3 PC | **À exécuter** après promotion |
| **P0** | Stockage/récupération | T705 système Btrfs et `/data` EXT4 distincts ; Borg externe ; restauration témoin réussie | En place dans le code ; **qualification physique restante** |
| **P0** | Sécurité de l'hôte | SELinux Enforcing, firewalld, intégrité des sources et réseau KVM fail-closed | Contrats existants ; tests physiques restants |
| **P1** | GNOME 51 stable et sobre | six **rôles** essentiels compatibles et vraiment actifs ; aucune extension supplémentaire sans justification | Verrous candidats ; tests GNOME 51 du profil final restants |
| **P1** | Intel Arc B580, écran et blancs | liaison `xe`, Vulkan/VA-API, RGB Full/Limited, SDR/HDR, ICC et reprise documentés | Inventaire lecture seule ajouté ; A/B visuel restant |
| **P1** | Double écran, VRR et 240 Hz | arrangement et fréquences réels confirmés, absence d'artefacts sur cinq cycles | Tests réels restants |
| **P1** | Performance et température | essais reproductibles de charge Ryzen/B580/NVMe ; pas de tuning global sans gain mesuré | Policy existante ; mesures à établir |
| **P1** | DevOps Rocky Linux | VM réinstallable, cloud-init vérifié, Docker, Terraform/Ansible et réseau isolé | Labo VM automatisé existant ; qualification HOST restante |
| **P1** | Accès distant tablette | réveil WoL depuis arrêt complet, Tailscale, SSH clés, Sunshine/Moonlight et AV1 matériel | Profil opt-in existant ; essais réels à effectuer |
| **P2** | Observabilité et maintenance | diagnostics horodatés, procédures d'incident, état des noyaux N/N-1 et restauration N-1 | Outillage existant ; tests de routine |
| **P2** | Provenance et reproductibilité | actions CI épinglées SHA, sources et médias vérifiés, manifeste de release lié à Gate 3 | Contrats existants ; scellage après certification |
| **P2** | Documentation et ergonomie | guides cohérents avec le code, architecture lisible, pas de statuts trompeurs | Travail documentaire continu |

## Points techniques propres à Fedora 45

**Les nouveautés intéressantes ne justifient pas de modifier tous les réglages.** La validation de transition doit vérifier en particulier :

- **RPM 6.1 et dépôt RPM déplacé vers `/usr` :** les scripts ne doivent pas supposer que tous les dépôts fournis par les paquets résident uniquement sous `/etc/yum.repos.d`. Vérifier l'origine effective avec DNF ; ne pas écraser les repos du système pour la commodité d'un test.
- **Services de secrets GNOME (oo7) :** vérifier le trousseau, `libsecret`, l'ouverture de session et les portails. Garder `gnome-keyring` tant qu'une migration réelle n'a pas prouvé l'équivalence et les cas d'usage SSH/Flatpak.
- **NetworkManager IPv6-mostly :** tester DNS, IPv4/IPv6 et réseau NAT isolé des VMs, y compris si le LAN évolue vers IPv6 ; ne pas désactiver IPv6 globalement pour masquer un échec.
- **GNOME 51 :** profiter du frame scheduling amélioré, de la capture d'écran optimisée et de la disposition multi-écran ; aucun patch Mutter non vérifié n'est ajouté.
- **Média Live/Anaconda :** le nouveau mode de construction de média Fedora 45 impose une vérification du vrai boot USB et de la provenance, pas une adaptation cosmétique du Kickstart.

**Ces points sont des domaines de compatibilité à vérifier**, pas une affirmation que chaque changement proposé est définitivement livré dans Fedora 45 finale avant sa publication. Référence : [ChangeSet Fedora 45](https://fedoraproject.org/wiki/Releases/45/ChangeSet).

## Décisions de sécurité à préserver

Les choix existants sont **explicites**, avec leurs risques :

- Secure Boot désactivé : prévu par le contrat actuel de noyau Linux amont. Ne jamais modifier automatiquement les réglages UEFI.
- Pas de LUKS sur les SSD locaux et Borg **non chiffré** : choix de l'architecture présente ; la possession physique du support donne accès aux données. Priorité aux protections physiques, à la conservation hors site et à la gestion des accès ; aucun chiffrement caché ne doit être ajouté.
- Aucun `curl | bash`, aucun pilote ou `Mesa` expérimental forcé, aucun service distant ouvert automatiquement.
- Sunshine, login automatique et extinction distante restent des **opt-in distincts** ; le port web d'administration doit rester privé.
- Aucun formatage automatique du second T705, aucune restauration en écrasement direct sans staging.

Une évolution de ces choix exige une décision explicite avec ADR et migration testée, pas une optimisation opportuniste.

## Ordre d'exécution retenu

**Étape A — Préparer le code :** tests de robustesse des probes Fedora Live, diagnostic couleur strictement en lecture seule et documentation des constats. Ne rien appliquer sur la workstation.

**Étape B — Compatibilité Fedora 45 finale :** une fois les médias officiellement disponibles, vérifier signature, manifestes RPM, extensions GNOME 51, démarrage de la session et procédures de récupération ; promouvoir les verrous en PR séparée.

**Étape C — Consolider les fonctionnalités déjà présentes :** KVM et réseau IPv6, DevOps Rocky, backup Borg, Wake-on-LAN et streaming AV1 ; corriger uniquement ce que des preuves montrent insuffisant.

**Étape D — Tests finaux :** CI sur la PR exacte, puis contrôles du `push` sur `main`. Enfin USB Live sur matériel, Gates 1 et 2 selon la release réellement promue, baseline, sauvegarde, APPLY protégé et Gate 3 physique.

## Ce qu'est un « 10/10 » ici

Pas un score marketing. Un volet atteint l'excellence quand il a :

1. **Une spécification claire** et des risques explicités.
2. **Du code modulaire**, versionné, réversible, sans privilèges excessifs.
3. **Des tests positifs et négatifs** qui refusent les faux PASS.
4. **Une preuve sur l'environnement pertinent** : une VM ne certifie jamais la B580 ni les T705 réels.
5. **Un runbook de récupération** et des signes concrets indiquant quand s'arrêter.

Le résultat final doit rester simple à utiliser depuis GNOME, compréhensible pour l'opérateur et utile pour un véritable poste de travail DevOps.

# Vision du projet — pourquoi FEDORA_GNOME_CUSTOM existe

Ce document est la **boussole** du projet. Il dit ce que le propriétaire veut obtenir et pourquoi. Le code, la configuration, les tests et la documentation doivent servir cette vision ; en cas de contradiction, c'est la vision qui tranche, puis on corrige le reste (ou on change la vision, explicitement, par une ADR).

## Le but

Faire de **Fedora + GNOME l'OS principal** du propriétaire, sur **son PC exact**, et que ce soit la meilleure installation Fedora GNOME possible :

- **la plus récente** : dernière Fedora et dernier GNOME stables (Fedora 44 / GNOME 50 aujourd'hui, Fedora 45 / GNOME 51 dès qu'ils sont finaux et qualifiés, voir [`UPGRADE_FEDORA_45.md`](UPGRADE_FEDORA_45.md)) ;
- **la plus finie** : Fedora livre GNOME brut, ce projet lui donne la finition qu'Ubuntu apporte à GNOME ;
- **la plus performante et réactive** pour un usage de bureau quotidien ;
- **reproductible et récupérable** : on peut tout réinstaller à l'identique, et ne rien perdre.

Pourquoi un dépôt plutôt qu'une installation à la main : pour que chaque réglage soit écrit, expliqué, vérifiable et rejouable, et pour apprendre en le construisant les pratiques DevOps (configuration déclarative, tests, CI, preuves) que le propriétaire vise dans son métier.

## Les quatre piliers, d'importance égale

| Pilier | Ce qu'on veut | Où c'est dans le projet |
| --- | --- | --- |
| **Finition GNOME façon Ubuntu** | Dock, bureau avec icônes, tuilage amélioré, apps GTK3 harmonisées, soin de l'écran QD-OLED | [`GNOME.md`](GNOME.md) (guide d'entrée), [`GNOME_POLISH.md`](GNOME_POLISH.md), ADR 0013, `config/gnome-polish.conf` |
| **Performance et réactivité** | Noyau stable le plus récent, réglages mesurés du CPU, de la mémoire et du GPU, aucun réglage aveugle | [`PERFORMANCE.md`](PERFORMANCE.md), [`UPSTREAM_LINUX.md`](UPSTREAM_LINUX.md), ADR 0015, `config/kernel.conf`, `config/performance.conf` |
| **Fiabilité et sauvegardes** | Rien n'est appliqué sans dry-run, baseline et sauvegarde ; mises à jour sûres ; restauration prouvée | [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md), [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md), ADR 0014, [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) |
| **Outils DevOps** | KVM/libvirt isolé, labo DevOps en VM, terminal et Bash soignés | [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md), [`VIRTUALIZATION.md`](VIRTUALIZATION.md), [`ROCKY_DEVOPS_READY.md`](ROCKY_DEVOPS_READY.md), [`PTYXIS.md`](PTYXIS.md) |

Aucun pilier n'a le droit d'en casser un autre : une optimisation de performance qui rend la machine instable ou impossible à sauvegarder est refusée, une finition visuelle qui fige l'écran OLED est refusée.

## Le matériel cible

| Composant | Modèle | Ce que le projet en fait |
| --- | --- | --- |
| Processeur | AMD Ryzen 7 7700 (8C/16T, 65 W) | amd-pstate, profils d'énergie, contrôle de stabilité |
| Carte mère | MSI MAG B850M Mortar WiFi, BIOS **1.A66 minimum** | identité vérifiée ; le BIOS est mis à jour régulièrement par le propriétaire, aucune version exacte n'est imposée |
| Mémoire | 48 Go DDR5-6000 CL30 (2 × 24 Go G.Skill) | vitesse 6000 MT/s vérifiée (profil EXPO/XMP) |
| GPU | ASRock Intel Arc B580 Challenger 12 Go | pilote `xe` et Mesa de Fedora, réservé à l'hôte |
| Stockage | 2 × Crucial T705 1 To (PCIe 5.0) | système Btrfs sur le premier, `/data` EXT4 persistant sur le second |
| Sauvegarde | Disque externe XS1000 (~1,8 To) | cible Borg externe, formatée en ext4 |
| Réseau | Wi-Fi 7 Qualcomm FastConnect 7800, Realtek 5 GbE, Bluetooth Qualcomm | identités et pilotes vérifiés |
| Audio / webcam | Realtek ALC4080, Logitech Brio 100 | identités vérifiées |
| Écran | ASUS ROG Strix XG27AQDMES, 27" QD-OLED 1440p 240 Hz | 2560×1440 à 240 Hz, reprise après veille, soin OLED |
| Refroidissement | DeepCool LD240 (AIO 240 mm), 3 × Arctic P12 Pro | surveillance des températures ; afficheur LD240 en option manuelle |
| Alimentation / boîtier | Corsair RM650e, ASUS Prime AP201 | — |

## Les décisions du propriétaire

Ces choix sont volontaires. Ils ne doivent pas être « corrigés » par une maintenance future sans nouvelle décision écrite :

- **aucun chiffrement** : ni des disques (ADR 0002), ni des sauvegardes (ADR 0014) ;
- **BIOS** : 1.A66 est un minimum ; les mises à jour du BIOS sont normales et attendues ;
- **noyau** : Linux amont officiel stable (ADR 0015, qui remplace l'essai CachyOS de l'ADR 0012) ; un retard de publication du noyau ne bloque jamais les autres mises à jour ;
- **labo DevOps** : Rocky Linux 10.2 en VM KVM, créé uniquement sur demande ;
- **Secure Boot** : désactivé (ADR 0002).

## Ce que le projet ne fait pas

- pas de refonte permanente : on améliore par petites étapes vérifiées ;
- pas de fonctionnalité ajoutée « parce qu'on peut » : chaque ajout doit servir un des quatre piliers ;
- **pas de nouvelle fonctionnalité avant la Gate 3** : la priorité est la première installation réelle certifiée.

## Où en est le projet

Le dépôt est **prêt côté code** (CI verte). La machine n'est pas encore certifiée : il reste la Gate 2 (VM GNOME, voir [`GATE2_GUIDE_PAS_A_PAS.md`](GATE2_GUIDE_PAS_A_PAS.md)), puis l'installation réelle et la Gate 3.

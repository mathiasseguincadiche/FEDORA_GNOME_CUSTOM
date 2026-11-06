# Fedora Golden Workstation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — parcours et commandes contrôlés contre le code ; tests documentaires exécutés — matériel : non vérifié

**Transformer une installation Fedora classique en un poste de travail personnalisé, reproductible et vérifiable.** Fedora Golden Workstation réunit les scripts, les réglages, les contrôles et les procédures nécessaires pour préparer, configurer, protéger et maintenir un PC sous **Fedora 45 Workstation / GNOME 51**.

Le projet distingue ce que le code peut vérifier automatiquement de ce qui doit encore être essayé sur le vrai PC. **État actuel : code contrôlé en CI ; essais Live USB et certification physique à réaliser.** [Voir les preuves et leurs limites](#état-réel).

**Accès rapide :** [Comprendre](#pourquoi-ce-projet) · [Tester sans installer](#premiers-pas) · [Suivre l'installation](docs/INSTALLATION_GUIDE.md) · [Exploiter le poste](docs/CONTROL_CENTER.md) · [Toute la documentation](docs/README.md)

## Pourquoi ce projet

Après une réinstallation classique, il faut retrouver les logiciels, reconstruire les réglages et vérifier que rien n'a été oublié. Deux installations faites à la main peuvent ainsi donner deux environnements différents, difficiles à dépanner ou à restaurer.

Ici, les choix importants sont enregistrés dans Git. Les scripts préparent et contrôlent les opérations ; les guides expliquent **pourquoi** les effectuer, **comment** reconnaître leur réussite et **quand s'arrêter**. L'installation initiale de Fedora reste une opération distincte, réalisée après les contrôles de préinstallation.

Ce projet personnel de [@mathiasseguincadiche](https://github.com/mathiasseguincadiche) sert également à pratiquer l'exploitation et l'automatisation d'infrastructure : **Bash, gestion des changements, CI/CD, sauvegardes Borg et virtualisation KVM**.

## Choisir son parcours

- **Découvrir le projet** : comprendre les [notions essentielles](docs/CONCEPTS.md), l'[architecture](docs/ARCHITECTURE.md) et les [décisions techniques](docs/adr/README.md).
- **Contrôler le PC avant installation** : suivre le [guide Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md), conserver les résultats puis décider si l'installation peut commencer.
- **Installer et certifier Fedora** : appliquer le [guide d'installation](docs/INSTALLATION_GUIDE.md), puis la [qualification finale](docs/QUALIFICATION.md).
- **Entretenir ou dépanner le poste** : ouvrir le [centre de contrôle](docs/CONTROL_CENTER.md), les [sauvegardes](docs/BACKUP_RESTORE.md) ou le [dépannage](docs/TROUBLESHOOTING.md).

## Ce que le dépôt automatise

- **Préparer** : vérifier les prérequis, l'identité du matériel et les fichiers nécessaires avant de modifier le système.
- **Configurer** : appliquer des modules versionnés après un essai à blanc et une sauvegarde vérifiée.
- **Observer** : diagnostiquer Fedora, GNOME, les pilotes, le stockage, le réseau et les périphériques.
- **Protéger et récupérer** : sauvegarder avec Borg et éprouver les restaurations dans un emplacement isolé.
- **Prouver** : conserver des résultats distincts pour les tests logiciels, le Live USB et le système réellement installé.

![Vue de l'architecture du poste Fedora : système, stockage, composants et services](docs/assets/diagrams/architecture-poste.svg)

Ce schéma donne la vue d'ensemble du poste. Consulter sa [source modifiable draw.io](docs/assets/diagrams/architecture-poste.drawio) ou les [explications techniques de l'architecture](docs/ARCHITECTURE.md) pour comprendre chaque composant.

### Quatre notions utiles pour lire la suite

- **Gate** : point de validation qui détermine si les conditions sont réunies pour poursuivre une étape.
- **Baseline** : état de référence du PC, mesuré et certifié avant les changements.
- **Dry-run** : simulation qui présente les opérations prévues sans les appliquer.
- **APPLY** : exécution réelle de la configuration, autorisée seulement après les contrôles et la sauvegarde exigés.

Les autres termes sont définis dans le [glossaire](docs/GLOSSARY.md).

## Le parcours du poste

Le [guide d'installation](docs/INSTALLATION_GUIDE.md#le-parcours) fait foi pour les commandes, les critères de réussite et les conditions d'arrêt. Voici **l'ordre réel** des opérations, de la clé USB jusqu'à l'exploitation courante.

### Avant de toucher aux SSD

1. **Préparer** : authentifier l'ISO Fedora 45 signée, préparer la clé USB et retenir un commit Git contrôlé ([installation](docs/INSTALLATION_GUIDE.md#1-vérifier-le-média-fedora-45)).
2. **Gate 2 — tester depuis « Try Fedora »** : observer les 16 points du PC sans installer Fedora, puis exporter le rapport `PREINSTALL_ONLY` et sa somme SHA-256 sur un support externe ([guide Live](docs/FEDORA45_LIVE_PREFLIGHT.md)).
3. **Examiner et décider** : relire les résultats, traiter les échecs et les points non testés, puis obtenir un **GO humain explicite** avant l'installation ([décision GO / NO-GO](docs/FEDORA45_LIVE_PREFLIGHT.md#6-décider-avant-toute-installation)).

### Installer et configurer Fedora

4. **Installer Fedora** : après accord seulement, utiliser le T705 système identifié par son numéro de série ; laisser intact le second T705 réservé à `/data`, puis importer la preuve Live au même commit ([installation](docs/INSTALLATION_GUIDE.md#2-contrôler-le-pc-en-live-puis-installer-fedora)).
5. **Préparer le système** : configurer `/data`, mesurer et certifier la baseline matérielle, puis effectuer le dry-run ([installation](docs/INSTALLATION_GUIDE.md#le-parcours)).
6. **Créer le point de retour** : effectuer et vérifier la sauvegarde Borg pré-APPLY ([sauvegardes](docs/BACKUP_RESTORE.md#sauvegarde-pré-apply)).
7. **Appliquer la configuration** : lancer l'APPLY sous ses protections, redémarrer et contrôler le premier démarrage GNOME ([installation](docs/INSTALLATION_GUIDE.md#le-parcours)).

### Qualifier et maintenir le poste

8. **Gate 3 — certification finale** : tester le système installé, ses périphériques, ses applications, la veille, les sauvegardes et KVM s'il est activé, puis certifier uniquement si les critères sont remplis ([qualification](docs/QUALIFICATION.md#4-gate-3--système-installé)).
9. **Exploiter et récupérer** : vérifier les sauvegardes régulières et essayer les restaurations dans un dossier isolé ([sauvegardes et restauration](docs/BACKUP_RESTORE.md)).

> [!IMPORTANT]
> **Entre la Gate 2 et l'installation, le parcours s'arrête volontairement.** Un `GO` calculé signifie que les six points requis sont `PASS` et qu'aucun des seize points n'est `FAIL` ; certains points complémentaires peuvent rester `NOT_TESTED`. Ce résultat n'autorise pas, à lui seul, l'effacement du disque. Conserver le compte rendu, l'analyser et obtenir la décision explicite du propriétaire avant de lancer l'installateur Fedora.

## Premiers pas

### Découvrir le dépôt sans modifier le PC

Depuis un poste disposant de Git et Python 3, ces commandes permettent uniquement de récupérer le code, vérifier la documentation et afficher l'aide :

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
python3 -B tests/test_docs_integrity.py   # contrôler liens, ancres et parcours de documentation
./control.sh help                         # consulter les commandes sans les exécuter
```

Le dry-run final de l'installation n'est **pas** un exercice générique à lancer sur n'importe quel ordinateur : il appartient au parcours du PC cible, après ses prérequis.

### Tester le PC cible en Live USB, sans installer Fedora

Sur le **PC cible démarré depuis la clé USB**, choisir « Try Fedora ». Dans le dépôt positionné sur le **commit contrôlé en CI**, suivre le guide Live pour préparer les périphériques et le support d'export, puis :

```bash
./control.sh validate live plan                                  # lire les 16 points à contrôler
./control.sh validate live run                                   # effectuer les observations
./control.sh validate live status                                # consulter la décision calculée
./control.sh validate export live /chemin/support-externe/preinstallation # conserver les preuves hors du Live
```

Le chemin d'export doit désigner un volume externe accessible en écriture, **distinct des deux SSD internes**. Le [guide Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md) précise les réponses humaines, les fichiers à conserver et la revue des résultats. Ces commandes ne lancent ni installation ni formatage.

### Après accord : installer et configurer sans brûler les étapes

L'installation graphique précède les scripts de configuration. Une fois Fedora démarré sur le SSD, les opérations de baseline, de dry-run et de sauvegarde pré-APPLY sont **des conditions de sécurité**, pas des étapes facultatives. L'APPLY refuse de s'exécuter si ses preuves ne correspondent plus à l'état courant du système.

Après l'APPLY, la **Gate 3** vérifie notamment le bureau réel, les périphériques, le réseau, la veille, les sauvegardes et la virtualisation. La commande `./control.sh validate gate3 status` consulte un état : elle ne remplace pas `./control.sh validate gate3 certify` ni les essais qui la précèdent.

**À retenir :** Gate 1 = logiciel en CI ; Gate 2 = compatibilité observée en Live USB ; Gate 3 = qualification du poste installé. Ces trois preuves ne sont pas interchangeables.

## Le centre de contrôle

`./control.sh` est l'entrée commune du projet : sans argument, il ouvre un menu ; avec `help`, il affiche ses commandes sans les exécuter. Il oriente vers les scripts spécialisés, avec des protections adaptées à chaque opération.

- **Observer** : `./control.sh status`, `./control.sh doctor all` ou `./control.sh logs tail` pour lire l'état, les diagnostics et les journaux.
- **Préparer** : `./control.sh install dry-run` pour simuler la configuration, après les prérequis du PC cible.
- **Valider** : `./control.sh validate live status` pour la preuve Live ; `./control.sh validate gate3 status` pour l'état du système installé.
- **Protéger** : `./control.sh backup now` et `./control.sh backup restore` pour gérer les sauvegardes et la restauration.
- **Exploiter** : `./control.sh kernel status`, `./control.sh kvm status` et `./control.sh remote status` pour consulter les principaux sous-systèmes.

L'**APPLY** n'est jamais une commande de découverte : il exige une baseline, un dry-run à jour, une sauvegarde pré-APPLY vérifiée et une confirmation sur le PC physique. Le [centre de contrôle](docs/CONTROL_CENTER.md) répertorie **toutes les commandes et leurs effets**, notamment les actions de mise à jour, de performance et de certification. Les réglages propres au poste sont définis dans `config/local.conf`.

## Le poste cible

Le dépôt vise un matériel précis ; ses paramètres ne doivent pas être appliqués à un autre PC sans vérification :

- **Plateforme** : AMD Ryzen 7 7700 (8 cœurs / 16 threads), MSI MAG B850M Mortar WiFi et 48 Go DDR5-6000 (2 × 24 Go).
- **Graphisme et affichage** : Intel Arc B580 Challenger 12 Go, pilote `xe` / Mesa de Fedora, écran ASUS ROG Strix 27 pouces QD-OLED 1440p à 240 Hz.
- **Stockage et sauvegarde** : deux Crucial T705 1 To PCIe 5.0 ; le premier pour Fedora en Btrfs, le second pour `/data` en EXT4 ; SSD externe Kingston XS1000 pour Borg.
- **Réseau** : Wi-Fi 7 Qualcomm et Ethernet Realtek 5 GbE.

La [description technique du matériel](docs/ARCHITECTURE.md#le-matériel-cible) explique les contrôles d'identité, les pilotes et les mesures attendues. Cette liste décrit la **cible prévue**, pas une certification déjà obtenue.

## Documentation de référence

Les parcours de découverte et d'installation sont indiqués [en haut de cette page](#choisir-son-parcours). Pour approfondir un domaine précis :

- **Environnement de travail** : [GNOME](docs/GNOME.md), [applications et jeu](docs/GAMING.md), [KVM et Rocky Linux](docs/KVM_QUICKSTART.md).
- **Vérification et évolution** : [CI/CD et diagnostics des jobs](docs/CI_VALIDATION.md), [feuille de route](docs/ROADMAP.md), [historique des versions](CHANGELOG.md).
- **Répertoire complet** : le [portail documentaire](docs/README.md) regroupe les guides techniques, les décisions d'architecture et les archives.

## État réel

| Élément | Ce qui est établi | Où vérifier |
|---|---|---|
| Code, configurations et scripts | Présents et soumis aux tests automatisés ; un succès vaut pour **le commit et l'environnement testés** | [GitHub Actions de `main`](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions?query=branch%3Amain), [comprendre la CI](docs/CI_VALIDATION.md) |
| Profil et média Fedora 45 / GNOME 51 | Profil `ready` et média final authentifié ; cette promotion ne certifie pas le matériel | [Fiche Fedora 45](docs/FEDORA45_PRIMARY.md) |
| Gate 2 sur Live USB, installation et Gate 3 sur le PC | **Non vérifiés physiquement** : observations et certification à réaliser sur le poste cible | [Qualification](docs/QUALIFICATION.md), [feuille de route](docs/ROADMAP.md) |

**Comment lire les preuves ?** Les résultats courants de la CI se consultent sur le **SHA exact** de la branche ou de la PR : un ancien succès ne valide pas automatiquement un nouveau commit. À titre de trace, la [PR #200](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/pull/200) a obtenu 18 contrôles réussis avant fusion. **Une CI verte ne certifie pas le PC** : seule la Gate 3, exécutée sur la machine installée, peut établir le statut « Golden runtime-certified ».

Les [versions publiées](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases), dont la [préversion v0.24.1-rc.1](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases/tag/v0.24.1-rc.1), sont distinctes de cette qualification physique.

## Contribuer et licence

Les changements passent par pull request, avec les tests adaptés à leur portée ([consignes de contribution](CONTRIBUTING.md)), et sont fusionnés par le propriétaire. Licence : [Apache License 2.0](LICENSE) ; version courante : [`VERSION`](VERSION).

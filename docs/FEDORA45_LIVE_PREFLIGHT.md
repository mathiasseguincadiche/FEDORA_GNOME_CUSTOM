# Fedora 45 / GNOME 51 — vérifier le PC depuis le Live USB

Ce contrôle se fait directement sur le PC prévu pour l’installation neuve. Il vérifie le démarrage et les fonctions utilisables depuis **Try Fedora**, avant de toucher aux SSD. La CI Linux teste le code séparément ; aucune VM n’est à préparer pour suivre ce parcours.

Un résultat Live réussi signifie **compatibilité de préinstallation observée** (`PREINSTALL_ONLY`). La configuration personnalisée, les services installés, les sauvegardes et Rocky Linux seront qualifiés après l’installation. Le profil Fedora 45 reste `pending` jusqu’à la qualification et la promotion du média final signé et des composants stables : le contrôle Live ne le promeut pas.

## 1. Préparer le média et le compte rendu

Utiliser le média officiel **Fedora 45 Workstation final**, avec son CHECKSUM signé vérifié, selon le [guide d’installation](INSTALLATION_GUIDE.md). Une Beta ou une RC ne constitue pas le média final du projet. Démarrer ce média puis choisir **Try Fedora**, sans lancer l’installation.

Prévoir aussi un **support externe accessible en écriture** pour conserver le compte rendu. Le HOME du Live est temporaire et disparaît au redémarrage ; la clé de démarrage peut être en lecture seule. Le support de transfert ne doit pas être l’un des SSD internes à installer ou à préserver.

Ouvrir les paramètres GNOME, connecter le réseau, vérifier l’écran et préparer les périphériques à essayer. Utiliser un terminal de la session graphique, en utilisateur ordinaire.

## 2. Utiliser le commit audité

Git et Python 3 sont nécessaires pour le dépôt et son rapport. Vérifier leur présence avec `command -v git python3`. Si Git manque, le préparer explicitement dans la session Live avec `sudo dnf install git`, puis reprendre ci-dessous. Cette installation d’outil utilise l’environnement temporaire du Live ; le contrôleur ne l’effectue pas automatiquement. La disponibilité des outils d’inventaire sera aussi vérifiée lors de la qualification du média final.

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
git switch --detach SHA_DU_COMMIT_AUDITE
git rev-parse HEAD
./control.sh validate live plan
```

Remplacer `SHA_DU_COMMIT_AUDITE` par le commit réellement retenu après revue et CI. Conserver ce SHA : le système installé devra utiliser **le même commit**, avec le même plan de modules et les mêmes identités matérielles. Ne pas modifier les fichiers versionnés pendant les essais. Si le dépôt a été préparé avant le démarrage Live, vérifier de la même manière le SHA et la propreté de cette copie.

## 3. Les 16 points observés

Le catalogue affiché par `plan` fait foi. Il distingue les observations automatiques, les essais humains et les points non essayés.

| Point | Niveau | Ce qui est réellement vérifié |
| --- | --- | --- |
| Session | Requis | Fedora 45, GNOME Shell 51 réellement démarré, Wayland, exécution native |
| Intel Arc B580 | Requis | Carte `8086:e20b` réellement liée au pilote `xe` |
| Stockage | Requis | Présence de deux Crucial T705 NVMe ; inventaire sans écriture |
| Mode de l’écran | Requis | Mode actif 2560 × 1440 à 240 Hz, lu automatiquement ou confirmé dans Paramètres → Écrans |
| Image affichée | Requis | Observation humaine : blancs lisibles, mouvements, absence d’artefacts ou d’écran noir |
| Internet | Requis | Accès HTTPS réellement réussi, automatiquement ou confirmé après un essai |
| Ethernet | Complémentaire | Requête HTTPS par l’interface Ethernet connectée |
| Wi-Fi | Complémentaire | Requête HTTPS par l’interface Wi-Fi connectée |
| Périphériques audio | Complémentaire | Inventaire PipeWire des sorties et entrées |
| Sortie audio | Complémentaire | Son gauche/droite entendu sur la sortie choisie |
| Microphone | Complémentaire | Réaction du niveau d’entrée à la voix et au silence |
| Contrôleur Bluetooth | Complémentaire | Inventaire des contrôleurs BlueZ |
| Usage Bluetooth | Complémentaire | Connexion et utilisation effective d’un périphérique |
| Périphériques USB | Complémentaire | Inventaire USB ; la présence d’un appareil ne prouve pas son fonctionnement |
| Usage USB | Complémentaire | Utilisation des périphériques prévus, sans ouvrir les SSD internes |
| Veille/reprise | Complémentaire | Un cycle lancé manuellement, retour observé et traces noyau correspondantes |

Les points complémentaires permettent de distinguer un périphérique non essayé d’un échec. Ils ne sont jamais déclarés réussis par déduction à partir d’un simple inventaire. Aucun débit Wi-Fi/5GbE, benchmark, stress test, certification colorimétrique ou performance GPU n’est affirmé par ces observations.

## 4. Lancer les observations

```bash
./control.sh validate live run
./control.sh validate live status
```

Répondre aux questions depuis le terminal : **o** pour un essai réussi, **n** pour un défaut constaté, **?** pour un point non essayé. Pour la veille, utiliser le menu GNOME au moment indiqué ; le script ne met pas le PC en veille automatiquement. Une réponse positive sans trace noyau de reprise reste non vérifiée.

Le rapport TSV est enregistré dans `state/validation/live-preflight.tsv`. Les statuts sont :

- `PASS` : l’observation décrite a réussi ;
- `FAIL` : un défaut a été constaté ;
- `NOT_TESTED` : la preuve manque ou l’essai n’a pas été effectué.

La décision est recalculée à partir des résultats :

| Décision | Conditions | Suite |
| --- | --- | --- |
| `GO` | Les six points requis sont `PASS`, aucun des 16 points n’est `FAIL` | Enregistrer le compte rendu portable, puis suivre l’installation |
| `NO-GO` | Au moins un `FAIL`, même sur un point complémentaire | Comprendre et corriger le défaut, puis refaire les observations |
| `A_VERIFIER` | Aucun `FAIL`, mais un point requis reste `NOT_TESTED` | Effectuer le contrôle requis manquant et relancer |

Un `GO` peut conserver des points complémentaires `NOT_TESTED` : ils restent explicitement visibles et ne deviennent pas des fonctions certifiées. La commande réussit seulement pour `GO` et produit alors un JSON portable `state/validation/outbox/live-COMMIT.json`.

## 5. Exporter avant le redémarrage

Adapter ce chemin au support externe réellement monté et accessible en écriture :

```bash
SUPPORT="/run/media/$USER/SUPPORT_FGC/preinstallation"
./control.sh validate export live "$SUPPORT"
```

L’export copie le JSON et son fichier SHA-256. Vérifier dans Fichiers que ces deux fichiers sont bien sur le support externe, puis conserver aussi le SHA du commit. Le TSV peut être copié sur ce support pour relire les détails ; **le fichier à importer est le JSON**, pas le TSV.

Les identités physiques du PC sont utilisées pour reconnaître la machine après installation. Ce compte rendu contient donc des informations de matériel ; le conserver personnellement et le relire avant un partage public.

## 6. Après l’installation de Fedora

Redémarrer sur le SSD, cloner le dépôt au **même SHA audité**, puis importer le fichier sauvegardé :

```bash
./control.sh validate import /chemin/du/support/live-COMMIT.json
./control.sh validate status
```

L’import vérifie les résultats, le commit, le plan des modules et les identités physiques. Le noyau Live peut différer du noyau installé ; cela ne transforme pas le contrôle Live en preuve du noyau installé. Un autre commit ou un autre matériel demande un nouveau compte rendu Live correspondant.

Poursuivre le [guide d’installation](INSTALLATION_GUIDE.md) : outils et configuration locale, `/data`, baseline, dry-run final, sauvegarde vérifiée, APPLY, redémarrage, contrôles du système installé, Rocky puis **Gate 3**.

Le contrôle Live ne sélectionne pas le SSD à effacer et ne valide pas sa santé. Voir deux T705 ne suffit pas : identifier séparément le SSD système et le SSD `/data` par leurs numéros de série. Le script ne lance ni installation, ni formatage, ni montage des SSD, ni modification de firmware, ni installation de paquets.

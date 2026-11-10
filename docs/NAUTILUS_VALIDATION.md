# Valider Nautilus après l'installation — parcours fonctionnel

> Version documentaire : V11 · Mise à jour : 2026-11-10 · Responsable : @mathiasseguincadiche
> État : procédure et tests isolés disponibles ; **aucun essai sur le PC physique n'est revendiqué**.

## Pourquoi cette validation ?

La présence de Nautilus et de ses extensions ne prouve pas que les fichiers s'affichent vite, qu'un téléphone est détecté ou qu'un partage réseau fonctionne. Cette procédure sépare **l'inventaire logiciel**, les **tests locaux**, les **essais avec les vrais périphériques** et la **perception visuelle**. Un résultat non exécuté doit rester `NON TESTÉ`, jamais `PASS`.

## 1. Préparer le poste (precheck)

Effectuer ces contrôles dans **une vraie session Fedora 45 / GNOME 51**, après l'APPLY et le redémarrage approprié. Depuis la racine du dépôt :

```bash
echo "$XDG_CURRENT_DESKTOP"                  # doit inclure GNOME
test -x ./diagnostics/nautilus-experience-doctor  # code retour 0 = outil présent
./diagnostics/nautilus-integration-doctor   # paquets, GVfs, miniatures, préchauffage
```

**Résultat attendu :** le diagnostic d'intégration n'indique aucun `KO`. Si des paquets manquent, ne pas les masquer : consulter [NAUTILUS.md](NAUTILUS.md) et [TROUBLESHOOTING.md](TROUBLESHOOTING.md) avant toute réinstallation.

## 2. Mesurer le premier démarrage (avant toute ouverture de Fichiers)

Cette étape fait partie de la qualification physique. Après une connexion fraîche, sans Nautilus actif et **avant de cliquer sur Fichiers** :

```bash
./diagnostics/nautilus-coldstart-doctor
```

Le script enregistre un temps en millisecondes entre le lancement et l'acquisition du nom D-Bus `org.gnome.Nautilus`. Il compare ce temps à la cible de 1 200 ms et à la limite de 2 000 ms du profil. **Ce temps n'est pas une mesure du premier rendu visuel ni de la fluidité réelle.** Un test CI ou un conteneur ne peut pas certifier le matériel.

## 3. Vérifier les opérations locales avec GIO

```bash
./diagnostics/nautilus-experience-doctor --local
```

Le test crée un dossier temporaire privé dans ton répertoire personnel, vérifie `gio info`, copie un petit fichier, relit le contenu puis supprime la copie. Le dossier temporaire est retiré à la fin, y compris après un échec. Le rapport `reports/nautilus-experience-<RUN_ID>.txt` indique `PASS` ou `FAIL`.

Ce contrôle valide les opérations **locales du backend GIO**, pas la navigation graphique, les NAS ou les téléphones.

## 4. Vérifier les fonctions GNOME intégrées

| Fonction | Action à réaliser | Critère de réussite |
| --- | --- | --- |
| Recherche | `./diagnostics/localsearch-doctor`, puis recherche depuis Fichiers | Fichier de test retrouvé sans erreur |
| Terminal | `./diagnostics/nautilus-ptyxis-doctor --functional`, puis clic droit « Ouvrir dans la console » | Ptyxis s'ouvre dans le dossier choisi |
| Aperçu Sushi | Sélectionner une image ou un PDF local et appuyer sur `Espace` | Aperçu lisible, retour à Fichiers sans blocage |
| Archives | Depuis Nautilus, ouvrir et extraire une petite archive de test | Contenu extrait et vérifié |
| Miniatures | Ouvrir un dossier d'images et de vidéos locales compatibles | Aperçus visibles ; pas de ralentissement excessif |
| Dossier de données | Parcourir `/data` et les répertoires configurés sur le second NVMe | Données accessibles avec les permissions attendues |

Le diagnostic automatique n'inspecte **pas** l'aperçu visuel, le menu contextuel rendu ou l'extraction graphique. Consigner ces points manuellement.

## 5. Observer la fenêtre réellement utilisable

À faire **lors d'une nouvelle connexion GNOME**, après le test D-Bus précédent, ou après un redémarrage. Nautilus ne doit pas déjà fonctionner.

```bash
./diagnostics/nautilus-experience-doctor --manual
```

Le programme attend ton accord, ouvre Fichiers et te demande d'appuyer sur Entrée lorsque la fenêtre est affichée et navigable. Il consigne `observed_ms` dans un rapport distinct.

**Interprétation :** `status=OBSERVE` signifie *observation humaine effectuée* ; le délai inclut ton temps de réaction. Il ne faut ni utiliser ce nombre comme un benchmark automatisé, ni en faire une preuve `Gate 3` ou un `PASS` de latence. Un affichage anormalement lent doit être décrit et investigué (première connexion, indexation en cours, dossier sur réseau, miniatures, I/O NVMe).

## 6. Tester les périphériques disponibles sans inventer de résultats

| Support | Condition | Contrôle à faire | Si absent |
| --- | --- | --- | --- |
| Android MTP | Téléphone déverrouillé, câble de données, autorisation USB | Apparition dans Fichiers ; ouverture et lecture d'un fichier test | `NON TESTÉ` |
| SMB/NAS | Partage de test et identifiants autorisés | Connexion `smb://`, lecture puis écriture/suppression d'un **fichier de test** uniquement si autorisé | `NON TESTÉ` |
| NFS | Export prévu et accessible | Ouverture et lecture d'un fichier de test | `NON TESTÉ` |
| Cloud/GOA | Compte configuré par l'utilisateur | Affichage et lecture d'un fichier de test | `NON TESTÉ` |
| Rocky Linux SFTP | VM démarrée, SSH opérationnel, accès autorisé | `./diagnostics/nautilus-vm-live-doctor --status` ; `--certify` uniquement pour un essai **avec écriture distante** | `NON TESTÉ` |

L'installation des backends (`gvfs-smb`, `gvfs-mtp`, `gvfs-nfs`, `gvfs-goa`) ne configure ni compte cloud, ni NAS, ni téléphone à ta place. Le test SFTP `--certify` crée puis retire un fichier de contrôle sur la VM : le lancer seulement après avoir vérifié la cible.

## 7. Consigner les résultats et dépanner

Pour chaque point, noter : **date, commit, appareil/dossier, état (`PASS`, `FAIL`, `NON TESTÉ`, `OBSERVÉ`), message d'erreur et rapport associé**. Ne pas considérer `NON TESTÉ` comme une réussite.

En cas de problème :

1. Exécuter `./control.sh logs tail` et conserver le `RUN_ID` concerné.
2. Vérifier `./diagnostics/nautilus-integration-doctor` pour les paquets et `gio mount -l` pour les montages disponibles.
3. Pour les recherches, commencer par `./diagnostics/localsearch-doctor` ; pour Ptyxis, `./diagnostics/nautilus-ptyxis-doctor --functional`.
4. Pour le SFTP, contrôler d'abord la VM et SSH, puis suivre [KVM_QUICKSTART.md](KVM_QUICKSTART.md).
5. **Ne pas désactiver SELinux, supprimer les caches ou lancer une purge globale** sans cause identifiée.

Cette validation complète les preuves de [QUALIFICATION.md](QUALIFICATION.md) ; elle ne remplace ni la Gate 3 ni les tests de démarrage du noyau, de l'Arc B580 et des NVMe.

# Fedora 45 — contrôle rapide sur clé USB Live (10 à 15 minutes)

**But unique :** décider si Fedora 45 Workstation / GNOME 51 démarre et fonctionne suffisamment bien sur le PC réel pour **préparer son installation neuve**. Ce n'est ni une certification matérielle, ni un test de performance, ni une autorisation automatique de modifier un SSD.

La CI du dépôt vérifie les scripts ; **elle ne remplace pas les observations physiques**. La configuration personnalisée et la Gate 3 seront vérifiées sur le système installé. Le profil Fedora 45 est actuellement **pending** : aucun GO Live ne contourne cette protection, la vérification de l'ISO finale, le choix explicite du disque ni la sauvegarde préalable.

## Les cinq contrôles — et pas davantage

| # | Contrôle | Comment vérifier | Critère |
|---|---|---|---|
| 1 | **Démarrage Fedora 45 / GNOME 51 / Wayland** | Ouvrir « Try Fedora », vérifier que le bureau est utilisable ; identification par script | Session correcte, aucun gel ou écran noir |
| 2 | **Intel Arc B580** | Script : PCI 8086:e20b réellement lié au pilote xe | B580 et pilote actif reconnus |
| 3 | **2 SSD Crucial T705** | Script : inventaire non destructif avec lsblk | Les deux modèles reconnus, sans écrire |
| 4 | **Affichage** | Paramètres GNOME → Écrans : vérifier 2560 × 1440, sélectionner 240 Hz ; regarder une fenêtre blanche et déplacer une fenêtre | Image normale, pas d'artefacts ni d'instabilité visible |
| 5 | **Internet** | La commande git clone a réussi, ou une page HTTPS s'ouvre réellement | Accès Internet utilisable (Wi-Fi **ou** Ethernet) |

**Les contrôles 1 à 3 sont automatiques.** Pour 4 et 5, le script demande une réponse **o** (oui), **n** (non) ou **?** (non vérifié). On ne prétend pas mesurer ce qui demande une observation humaine. Si le 240 Hz manque ou si les blancs semblent gris, répondre **n** et examiner le cas au lieu de déclarer le contrôle réussi.

## Exécution dans « Try Fedora »

1. Démarrer sur une **clé Live officielle Fedora Workstation 45 finale**, téléchargée et authentifiée, sans installer ni modifier les partitions. Si la version finale n'est pas publiée/authentifiée, ne pas traiter une Beta comme le média final.
2. Ouvrir **Paramètres → Écrans** et vérifier résolution, fréquence et image. Connecter Internet, puis ouvrir un terminal.
3. En utilisateur ordinaire (**jamais sudo**) :

~~~bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
git rev-parse HEAD
set -o pipefail
bash diagnostics/live-preflight.sh | tee "$HOME/fedora45-live-preflight.tsv"
~~~

La commande imprime exactement **cinq lignes de contrôles**, puis un résumé et une décision. Les deux questions interactives sont affichées dans le terminal même si le rapport est envoyé à tee.

### Lire la décision

- **GO (5 PASS)** : compatibilité Live de base vérifiée. Passer ensuite à la **préparation sécurisée** de l'installation (média final, profil Fedora 45 promu, sauvegarde, identification du SSD système). Ce n'est pas un APPLY automatique.
- **NO-GO (au moins un FAIL)** : ne pas installer avant d'avoir compris et corrigé le défaut constaté.
- **A_VERIFIER (aucun FAIL mais un contrôle non testé)** : ce n'est pas un GO. Confirmer le point manquant ; si aucune console interactive n'est disponible, les confirmations humaines resteront NOT_TESTED.

Le script renvoie le code **0 seulement pour GO** ; un FAIL ou un contrôle non vérifié donne un code non nul. Le rapport se trouve uniquement dans le HOME temporaire de la session Live. Ne pas le publier automatiquement : vérifier les informations matérielles avant tout partage.

### Ce qui est volontairement hors périmètre

**Ne pas faire sur le Live USB :** benchmarks et stress tests CPU/RAM/GPU/SSD, montage des SSD en écriture, vérification KVM/Docker/VM, tests prolongés de veille/réveil, installation des six extensions, mesure HDR/ICC/AV1 ou certification complète de l'audio et des périphériques.

Les vérifications détaillées des services personnalisés, extensions, sauvegardes, noyau, KVM, pilotes de calcul, périphériques et persistance appartiennent **au système installé**, selon les contrôles de production du dépôt. La prévalidation courte ne les supprime pas et ne change pas les garde-fous de ./install.sh --apply.

**Attention aux SSD :** voir deux T705 en Live n'identifie **pas** le SSD à effacer. Avant toute installation, utiliser les identifiants persistants /dev/disk/by-id et vérifier les numéros de série, les sauvegardes et la cible prévue dans [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md).

Le script refuse les machines non Fedora, une session non Live, l'exécution en root et les arguments non reconnus. Il ne lance ni installation, ni formatage, ni montage de partitions, ni modification du firmware ou de l'EFI.

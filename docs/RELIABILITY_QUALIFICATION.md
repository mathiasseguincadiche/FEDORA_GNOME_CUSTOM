# Qualification de fiabilité après audit

Ordre opérateur : **corriger les erreurs et faux PASS → installation vierge →
restauration → matériel → optimisations mesurées**. La baseline matérielle minimale
reste un prérequis de sécurité de l'APPLY ; la qualification exhaustive vient ensuite.

## Ce qui est corrigé

- Exécution des modules dans un vrai processus Bash : une commande en échec,
  un helper imbriqué ou une substitution de commande ne doit plus être masqué
  par le succès d'une commande suivante. Les rapports conservent phase et code retour.
- Installation du manifeste système par le module de production, y compris
  Python/pip/pipx, dmidecode et les bindings Python GNOME.
- Dry-run sans Restic/virsh déjà installés ; le contrôle réel reste obligatoire après APPLY.
- Sortie noyau sans messages parasites et validation du format enregistré.
- Lecture PCI par périphérique ; absence d'association du pilote d'un autre contrôleur.
- Journaux conservés lors des appels imbriqués et certificats invalidés par les
  identités configuration/matériel/runtime/chaîne de validation.
- Bundles de sauvegarde identifiés par commit et configuration, jamais par le seul commit.
- Restauration contrôlée par Restic, couverture NVRAM/swtpm et données applicatives.
- Test fio sur fichier temporaire unique, même pour la racine non inscriptible
  par l'utilisateur ; aucune écriture sur le périphérique brut.
- Preuves réseau liées à l'interface testée (DNS et HTTPS), sorties analysées en locale C.
- État GNOME 50 `ACTIVE` réellement exigé pour les extensions attendues.
- Reprise écran conservant les choix utilisateur et tous les moniteurs.
- Kickstart lié à `/dev/disk/by-id` et au numéro de série, revérifiés en `%pre`.

## Ce qui constitue une preuve

| Étape | Preuve requise | Limite des tests automatisés |
|---|---|---|
| Code | Tests comportementaux + ShellCheck + syntaxe | Ne démontre pas un démarrage |
| Installation vierge | Fedora 44 GNOME 50 neuve, APPLY, reboot, diagnostics et second APPLY | Le prétest Fedora exécute le module système réel en conteneur ; pas l'installation complète |
| Restauration fichiers | Snapshot exact, lecture complète, restauration `--verify`, contenu/permissions | Le roundtrip CI utilise un vrai Restic et un disque externe simulé |
| Reprise OS/VM | Démarrage de Fedora et d'une VM récupérée isolée, données accessibles | Non démontrable par un test de fichiers |
| Matériel | Gate 3 sur le Ryzen 7700 / B580 / B850M / T705 | Aucun résultat matériel issu d'un conteneur |
| Performance | Répétitions A/B, dispersion, frametimes, thermique | Aucun gain revendiqué avant mesure |

## Parcours restant sur la machine

1. Utiliser le [guide d'installation](INSTALLATION_GUIDE.md) et conserver le SHA
   exact testé. Qualifier Gate 1 puis Gate 2 selon [la validation](THREE_GATE_VALIDATION.md).
   Choisir le disque système par son numéro de série, vérifier le second T705
   et le support externe. Ne pas transformer les deux T705 en cibles interchangeables.
2. Suivre la baseline, sauvegarder avant APPLY et exécuter le dry-run sur la même
   configuration. Réaliser l'APPLY, redémarrer, lancer les diagnostics. Archiver
   rapports et journaux. Rejouer la convergence pour vérifier l'idempotence.
3. Effectuer une [restauration](BACKUP_RESTORE.md) vers un staging vide et le test
   de reprise OS/VM isolé. Garder les clés de récupération hors de la machine.
4. Qualifier les pilotes et usages : B580/xe, écran 240 Hz, HDR/VRR si utilisés,
   plusieurs veilles/reprises, WCN785x/Wi-Fi, Bluetooth réel, RTL8126/5 GbE,
   ALC4080 lecture/capture, USB/webcam, températures et les deux SSD.
   Le test HTTPS réseau ne prouve ni 5 Gb/s ni une connexion Wi-Fi 7/6 GHz.
5. Exécuter Gate 3, puis [mesurer](PERFORMANCE.md) avant de retenir une optimisation.

Les politiques de noyau et de Secure Boot existantes ne sont pas changées par
ce correctif. Leur choix n'est pas une preuve de performance ou d'équivalence
avec la politique de sécurité du noyau Fedora officiel.

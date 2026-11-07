# Couverture transversale des mises à jour

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — routes et tests de mise à jour relus contre le code — matériel : non vérifié

Références d'exécution : `scripts/maintenance/update-system.sh`, `lib/control_center.sh`, modules système, GNOME, applications et Gaming ; tests `test_update_transversal_behavior.sh` et `test_update_kernel_deferral_behavior.sh`.

Ce guide répond à une question précise : **quels composants le centre de contrôle met-il réellement à jour, et que reste-t-il à faire ou à vérifier ?** Il ne confond pas « paquet installé », « version disponible », « transaction préparée » et « fonctionnement validé ». Le centre de contrôle reste l'entrée de l'opérateur ; un module extérieur ne devient pas automatiquement géré parce que son application apparaît dans le menu.

## 1. Vérifier le périmètre avant toute opération

Depuis la racine du dépôt :

```bash
./control.sh update scope  # expliquer les domaines gérés, épinglés ou extérieurs
./control.sh update check  # rechercher les mises à jour, sans les installer
./control.sh update status # lire la phase DNF5 hors ligne existante
```

Dans le menu `./control.sh`, choisir **Mises à jour → Périmètre des mises à jour** pour le même bilan. `scope` est en lecture seule du point de vue du système ; le démarrage des moteurs peut néanmoins créer une session de journalisation. L'inventaire ne vérifie pas à lui seul la compatibilité de chaque version ni la santé physique du PC.

La vérification `update check` passe successivement sur Fedora/DNF5, noyau, Flatpak, firmware et périmètre complémentaire. Si la consultation Flatpak échoue, elle affiche `KO` et le bilan global échoue ; une erreur réseau ne devient plus un faux « aucune mise à jour ». Si Steam est installé comme RPM mais que son dépôt n'est pas identifiable et vérifiable, la couverture Steam est également `KO`.

## 2. Domaines et limites réelles

| Domaine du poste | Origine et moteur | Comportement du centre de contrôle | Limite / contrôle complémentaire |
| --- | --- | --- | --- |
| Fedora, utilitaires, composants et codecs RPM | Dépôts DNF5 activés, dont RPM Fusion lorsqu'il est configuré | `update all` prépare les paquets **déjà installés** dont une version est disponible | Ne promet pas d'installer un module nouveau ni de résoudre un dépôt désactivé ou disparu |
| Noyau Vanilla stable et pilotes intégrés (`xe`, etc.) | Canal noyau prévu par le projet | Sélection stricte, transaction hors ligne, rétention N/N−1 et secours Fedora | Le noyau peut être `DEFERRED` si sa version exacte n'est pas disponible ; les tests du matériel restent indispensables |
| Mesa, bibliothèques Vulkan x86_64/i686, firmware Linux et microcode AMD | Paquets RPM | Mises à jour DNF5 si les RPM sont accessibles | Vérifier le rendu graphique, l'initialisation GPU, Vulkan/VA-API et les journaux du nouveau noyau |
| Applications et runtimes Flatpak | Remotes Flatpak de l'utilisateur et du système | `update flatpak` ; en mode complet, pendant `update finalize` ou directement si aucun RPM n'est en attente | Les apps peuvent demander une relance ; un échec de la recherche est une erreur et non un système à jour |
| Steam natif | RPM du dépôt `rpmfusion-nonfree-steam` | Si Steam RPM est installé, vérifie la définition de dépôt fournie par Fedora et l'active pour **cette** transaction DNF5 | Si source absente, non fiable ou invisible, la préparation est bloquée avant DNF5, sans changer de dépôt silencieusement |
| Jeux Steam, Proton et outils téléchargés par Steam | Gestionnaire interne de Steam | **Non mis à jour par DNF5** ; signalés comme domaine extérieur au bilan | Ouvrir Steam, laisser terminer ses téléchargements et tester les jeux réellement utilisés |
| GNOME Shell et extensions RPM | Paquets Fedora | DNF5 pour les extensions distribuées en RPM | Refaire le diagnostic GNOME après mise à jour du Shell |
| Extensions GNOME provenant d'artefacts revus/épinglés | Versions et preuves approuvées dans le projet | **Pas de téléchargement de la dernière version au hasard** | Réexaminer la compatibilité GNOME, mettre à jour les références approuvées, puis reconverger le module |
| AppImage et applications autonomes | Éditeur de chaque application | **Pas de promesse de mise à jour universelle** | Vérifier le mécanisme officiel de l'éditeur et les signatures / empreintes nécessaires ; revalider le lancement |
| BIOS/UEFI, SSD et firmware embarqué des périphériques | Constructeur, périphériques exposés à `fwupd` | `update firmware` **consulte** les mises à jour annoncées | Aucun flash automatique ; prendre une décision séparée selon la compatibilité, la sauvegarde et les prérequis du constructeur |
| Configuration, logiciels supplémentaires et nouveaux modules du dépôt | `install.sh` et contrats de modules | Une mise à jour de paquets **ne remplace pas** un nouvel APPLY | Refaire préparation, dry-run, sauvegarde, APPLY et validations lorsqu'une configuration évolue |
| Changement de version majeure de Fedora | Procédure `upgrade` dédiée | **Pas** inclus dans `update all` | Migration distincte, avec contrôles et politique de compatibilité adaptés |

**Ne pas interpréter `PASS` sur une consultation `fwupdmgr` comme « tous les périphériques ont leur firmware le plus récent ».** Cela signifie seulement que la consultation s'est déroulée correctement. Une absence de périphérique supporté, de publication chez le fabricant ou de métadonnées fraîches ne constitue pas une certification.

## 3. Procédure de mise à jour complète

Lancer les commandes **une étape à la fois**, ou utiliser les actions équivalentes du sous-menu **Mises à jour**. Ne jamais enchaîner automatiquement le redémarrage sans vérifier l'état préparé.

1. **Consulter** : `./control.sh update check` et `./control.sh update scope`. Corriger les `KO` de provenance avant de continuer ; noter les domaines extérieurs.
2. **Préparer** : `./control.sh update all`. Le système réalise une sauvegarde Borg obligatoire, sélectionne la cible noyau admissible et prépare la transaction DNF5 hors ligne. La préparation n'est **pas** une installation réussie.
3. **Contrôler** : `./control.sh update status`. Si aucune transaction RPM n'a été créée, le mode complet peut appliquer Flatpak et terminer les diagnostics sans redémarrage DNF5.
4. **Appliquer les RPM préparés** : si le statut réclame un redémarrage, `./control.sh update reboot` lance explicitement le redémarrage dans l'environnement DNF5 hors ligne. Ne pas couper l'alimentation pendant cette opération.
5. **Finaliser sur le système démarré** : `./control.sh update finalize`. Cette étape vérifie la bonne transaction, DNF5, le noyau et sa rétention, puis les Flatpak et diagnostics. Un échec laisse un état à examiner, pas un certificat de réussite.
6. **Vérifier les usages du poste** : `./control.sh doctor all`, `./control.sh doctor graphics`, `./control.sh doctor media`, `./control.sh doctor gaming` et `./control.sh logs tail` selon les composants présents. Vérifier aussi Steam/Proton, extensions épinglées, AppImage et firmwares **par leurs procédures propres**.
7. **Requalifier si nécessaire** : une modification de composants ou de configuration peut invalider les preuves Golden précédentes ; vérifier les états `STALE` et suivre la [qualification physique](QUALIFICATION.md) et les Gates applicables.

Une sauvegarde préalable et un rollback du noyau **ne garantissent pas à eux seuls** la restauration de tout le poste. Suivre les procédures Borg et de récupération si le système ne redémarre pas correctement.

## 4. Échecs et décisions qui ne doivent pas être masqués

| Situation observée | Interprétation | Action sûre |
| --- | --- | --- |
| Recherche Flatpak `KO` | Impossible de déterminer les mises à jour disponibles | Vérifier la connexion, les remotes et relancer la consultation ; ne pas conclure « à jour » |
| Source Steam RPM `KO` | Mise à jour Steam non vérifiable | Vérifier `fedora-workstation-repositories` et la définition `rpmfusion-nonfree-steam` ; ne pas activer une source inconnue |
| Noyau `DEFERRED` | Noyau amont exact non vérifiable ou non disponible en RPM | Conserver le noyau courant ; installer les autres correctifs autorisés et réessayer plus tard |
| Transaction DNF5 `prepared` | Paquets téléchargés et opération en attente | Consulter `update status`, puis décider du redémarrage explicite |
| `update finalize` en échec | Fin de transaction ou fonctionnement non prouvé | Lire `update log`, `logs tail` et les doctors ; ne pas certifier ni refaire aveuglément `update all` |
| Firmware proposé | Un matériel peut nécessiter un flash distinct | Examiner modèle, constructeur, versions, alimentation et plan de récupération ; aucune mutation automatique |
| Extension GNOME / Proton / AppImage plus récents disponibles | Publication extérieure au canal RPM/Flatpak du centre de contrôle | Contrôler compatibilité et source, puis appliquer et tester dans le gestionnaire approprié |

## 5. Critère de fiabilité transverse

Un domaine n'est **validé** que lorsque l'on connaît sa provenance, l'état de l'opération, le résultat d'un contrôle fonctionnel approprié et les limites de récupération. Les états `EXPECTED`, `DEFERRED`, `WARN`, `STALE` et `KO` ne doivent pas être transformés en « tout est vert ». Le [guide opérateur](OPERATOR_RELIABILITY.md) explique les journaux et l'idempotence ; la [procédure du centre de contrôle](CONTROL_CENTER.md) récapitule les commandes.

Les tests CI vérifient le routage, les refus de provenance, les erreurs Flatpak, la préparation DNF5 et des contrats de modules. **Ils ne constituent pas une preuve** qu'un firmware est disponible, qu'un jeu démarre ou que le nouveau noyau fonctionne sur le matériel de l'utilisateur. Ces validations restent à réaliser sur le PC autorisé.

# Les notions clés du projet

> Mise à jour : 2026-11-04 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-04 — chaque notion relue contre le code qu'elle décrit (`lib/apply_gate.sh`, `diagnostics/baseline-doctor`, `diagnostics/software-matrix-doctor`, `lib/backup_runtime.sh`, `scripts/kvm/kvm_network_guard.sh`, `config/kernel.conf`) — matériel : non vérifié

Le projet repose sur sept idées, qui reviennent dans tous les guides. Cette page les explique une à une : le problème qu'elles règlent, leur principe, leur place dans le projet, comment les vérifier et ce qu'elles ne garantissent pas.

**Objectif de la page :** pouvoir expliquer pourquoi `install.sh --apply` refuse parfois de s'exécuter, ce que prouve une CI verte, et pourquoi une preuve devient périmée. Les termes sont définis dans le [glossaire](GLOSSARY.md) ; la vue d'ensemble est dans l'[architecture](ARCHITECTURE.md).

## 1. Fermé par défaut (fail-closed)

**Besoin.** Un contrôle de sécurité peut échouer pour une raison banale : commande absente, fichier illisible, réseau coupé. Si l'échec du contrôle laisse passer l'action, le garde-fou ne protège que lorsque tout va bien.

**Principe.** En cas de doute, l'état restrictif l'emporte. Un contrôle qui ne peut pas conclure compte comme un échec, jamais comme une réussite.

**Dans le projet.** L'APPLY refuse de s'exécuter si une seule précondition manque ou ne peut pas être établie ([contrat d'exécution](ARCHITECTURE.md#contrat-dexécution)). Le garde réseau KVM passe d'abord en mode d'urgence, qui coupe la sortie des VM, avant de recalculer ses règles. En CI, le job `contracts` échoue si une dépendance a été sautée.

**Le vérifier.** Un refus nomme sa cause : `./install.sh --dry-run` montre la précondition manquante, `./control.sh kvm guard-check` affiche `guard_mode`.

**Limites.** Fermé par défaut ne veut pas dire sans défaut : le garde-fou protège contre ce qu'il contrôle, rien de plus. **Erreur fréquente :** contourner le refus (désactiver SELinux, supprimer la table nftables) au lieu de corriger sa cause.

## 2. Une preuve est liée à un état

**Besoin.** Une preuve « le dry-run a réussi » n'a de sens que pour le code et la configuration qui l'ont produite. Réutilisée après un changement, elle autoriserait une action jamais testée.

**Principe.** Chaque preuve enregistre l'état qu'elle atteste, sous forme d'empreintes : commit, configuration effective, plan des modules, empreinte matérielle. Elle n'est acceptée que si cet état n'a pas changé.

**Dans le projet.** Le dry-run, la sauvegarde pré-APPLY, le compte rendu Live et la certification portent ces empreintes. Changer `config/local.conf` impose de refaire le dry-run puis la sauvegarde ; une preuve Live d'un autre commit est refusée à l'import. Une certification devient `STALE` quand la matrice logicielle change.

**Le vérifier.** `./diagnostics/software-matrix-doctor diff` montre ce qui a changé depuis la certification ; `./control.sh validate status` montre les preuves en place.

**Limites.** Une preuve à jour atteste ce qui a été contrôlé ce jour-là, pas ce qui arrivera ensuite. **Erreur fréquente :** recréer un marqueur à la main pour « débloquer » ; le projet le refuse, et ce serait une fausse preuve.

## 3. Trois niveaux de preuve : CI, Live USB, Gate 3

**Besoin.** Un test automatisé, une observation du matériel et une qualification du poste installé ne prouvent pas la même chose. Les confondre ferait annoncer un poste prêt sur la seule foi d'une CI verte.

**Principe.** Chaque niveau a son environnement, et aucun ne remplace le suivant.

| Niveau | Où | Ce qu'il prouve | Ce qu'il ne prouve pas |
|---|---|---|---|
| CI | machines jetables de GitHub | le logiciel au commit testé : contrats, paquets, sessions GNOME et VM en émulation | rien sur le vrai PC |
| Live USB | le PC, avant installation | le matériel tel qu'observé, sans rien écrire (`PREINSTALL_ONLY`) | le système installé |
| Gate 3 | le PC installé | le poste réel, lié au commit et à la configuration | les versions suivantes |

**Dans le projet.** Le Live USB ne déverrouille jamais l'APPLY, et la CI ne certifie jamais le matériel. Le détail de chaque niveau est dans la [qualification](QUALIFICATION.md) et la [page CI](CI_VALIDATION.md).

**Limites.** Même la Gate 3 qualifie un état donné ; une évolution du code ou du matériel la rend `STALE`.

## 4. Baseline avant, certification après

**Besoin.** L'APPLY doit corriger certains défauts du poste. Si l'on exigeait un poste parfait avant l'APPLY, on ne pourrait jamais installer le correctif.

**Principe.** Deux mesures séparées. La **baseline**, avant l'APPLY, enregistre l'identité et la santé du matériel (carte mère, BIOS, disques, Wi-Fi). La **certification**, après l'APPLY et le redémarrage, vérifie le poste complet.

**Dans le projet.** `./diagnostics/baseline-doctor status` montre la baseline ; l'APPLY exige une baseline valide pour l'empreinte courante. La certification fait partie de la [Gate 3](QUALIFICATION.md).

**Limites.** Une mise à jour du BIOS ou un disque remplacé change volontairement l'empreinte : la baseline est à refaire, jamais à recopier.

## 5. Une sauvegarde n'est bonne que restaurée

**Besoin.** Une commande de sauvegarde peut se terminer sans erreur et laisser une archive illisible ou incomplète. On ne le découvre qu'au moment d'en avoir besoin.

**Principe.** Une sauvegarde compte seulement après une vérification intégrale des données et la restauration réelle d'un fichier témoin (le canari). Une restauration se fait toujours d'abord dans un dossier d'essai (staging), jamais en place.

**Dans le projet.** Les sauvegardes pré-APPLY et complètes exécutent `borg check --verify-data` puis restaurent le canari. Le dépôt Borg n'est pas chiffré, par choix du propriétaire ([ADR 0014](adr/0014-borg-unencrypted-backups.md)) : il se range donc comme un document sensible, et ne contient jamais de clé privée ([ADR 0021](adr/0021-no-private-keys-in-unencrypted-backups.md)).

**Le vérifier.** `./control.sh backup check` et la procédure de [restauration](BACKUP_RESTORE.md#restaurer).

**Limites.** Restaurer des fichiers ne prouve pas qu'un système redémarre : c'est l'objet de la [reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md). **Erreur fréquente :** croire que deux SSD valent deux sauvegardes ; le second T705 survit à une réinstallation, pas à sa propre panne.

## 6. Noyau amont N, retour N-1, secours Fedora

**Besoin.** Le projet suit le dernier noyau Linux stable, pour le matériel récent. Un nouveau noyau peut pourtant régresser, et un poste qui ne démarre plus est le pire cas.

**Principe.** Trois niveaux de repli : le noyau amont courant (N), le précédent (N-1) gardé pour revenir en arrière, et un noyau Fedora signé, toujours installé en secours. Aucun noyau n'est retiré tant que le nouveau n'a pas démarré.

**Dans le projet.** Seule la version annoncée stable par kernel.org est acceptée, depuis le COPR `@kernel-vanilla/stable` (`config/kernel.conf`). `./control.sh kernel rollback` revient à N-1 ; `./control.sh kernel fallback` passe au noyau Fedora ([Linux amont](UPSTREAM_LINUX.md)).

**Le vérifier.** `./control.sh kernel status` montre le noyau démarré et les noyaux installés.

**Limites.** Revenir à N-1 ne corrige pas un défaut matériel, et ne ramène pas à une version antérieure de Fedora.

## 7. Le garde réseau isole les VM du réseau local

**Besoin.** Une VM de travail doit atteindre Internet, mais pas les autres machines du réseau local : une VM compromise ne doit pas devenir une porte d'entrée vers le reste de la maison.

**Principe.** Les VM sont sur un réseau privé traduit (NAT), `devops-nat` (`192.168.50.0/24`). Des règles nftables propres au projet bloquent tout trafic des VM vers le réseau local, et seulement celui-là.

**Dans le projet.** Le garde recalcule ses règles quand le réseau de l'hôte change. S'il ne peut pas les établir sûrement, il passe en mode d'urgence et coupe la sortie des VM (notion 1). Détails dans le [réseau KVM](KVM_NETWORK.md).

**Le vérifier.** `./control.sh kvm guard-check` doit afficher `guard_mode=normal`.

**Limites.** Le garde protège le réseau local de l'hôte ; il ne remplace pas la sécurité à l'intérieur de la VM. L'isolement réel du LAN reste à vérifier sur le PC, en Gate 3.

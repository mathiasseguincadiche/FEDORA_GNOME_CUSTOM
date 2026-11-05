# Changelog

## Unreleased

- Documentation (repères d'exécution et alertes de non-retour) :
  - **Résumés d'exécution** : le [guide d'installation](docs/INSTALLATION_GUIDE.md), le [contrôle Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md) et la [reprise isolée](docs/ISOLATED_RECOVERY_RUNBOOK.md) ouvrent sur un résumé de cases à cocher qui dit où en est l'exécution d'un coup d'œil ; la [restauration](docs/BACKUP_RESTORE.md) reçoit le même résumé en tête de sa procédure. Une exécution interrompue s'y reprend à la première case non cochée, règle d'arrêt relue. Les résumés ne remplacent ni les prérequis ni les validations.
  - **Alertes GitHub** : les points de non-retour du guide d'installation et l'étape `APPLY` affichent un encadré `> [!CAUTION]` ; la charte réservait déjà les citations aux avertissements importants. Le contenu des avertissements recopie les conditions déjà écrites (sauvegarde pré-APPLY vérifiée, support branché), sans règle nouvelle.
  - **Métadonnées** : les quatre guides modifiés portent « Mise à jour » au 2026-11-05 et disent que les vérifications de code antérieures n'ont pas été rejouées. `tests/test_docs_integrity.py` passe sur l'archive contrôlée (72 pages, 16 domaines de commandes).

- Corrections :
  - **`./repair.sh display` ne réparait plus rien.** Depuis que le script de réparation de l'affichage vérifie seulement (`--check`) quand il est lancé sans argument, l'action « display » de `repair.sh`, et donc l'entrée « Réparation affichage » du menu, affichait l'état sans le corriger. Elle passe maintenant `--reset-certified`, qui réapplique le mode certifié sur le seul écran certifié et refuse plusieurs écrans. `tests/test_golden_workstation_behavior.sh` vérifie l'argument transmis.
  - **`kvm-io-doctor benchmark` échouait sans la variable `USER`** (`USER: unbound variable`). Le propriétaire du dossier de mesure vient désormais de `id -un`, comme ailleurs dans le dépôt ; `tests/test_hardware_kvm_behavior.sh` passe sans `USER`.
  - **Guide d'installation, section 7** : il dit que `prepare-preapply-backup.sh` installe Borg et ses outils avec `sudo dnf` s'ils manquent, et que la phrase de confirmation n'est demandée qu'à la création d'un dépôt Borg neuf.

- Documentation (troisième passe de relecture) :
  - **Statuts et preuves** : `CONTRIBUTING.md` compte sept statuts (« Abandonné » et « Échec constaté » s'ajoutent) et précise la portée d'une preuve : elle vaut pour le commit et l'environnement contrôlés. Le tableau du matériel de l'architecture décrit ce que le code contrôle, pas un résultat, et dit que la version du BIOS est relevée mais jamais comparée au minimum. Le README reçoit une section « Contexte du projet ».
  - **Procédures** : le guide d'installation nomme ses trois points de non-retour (installation sur le T705 système, formatage d'un second T705 neuf, APPLY) et ce qu'il faut confirmer avant chacun. La durée des essais de baseline devient une estimation tirée de `diagnostics/baseline-doctor`. Le dépannage s'ouvre sur une section « En urgence » : PC qui ne démarre plus, session GNOME absente, `/data` disparu, fichiers perdus.
  - **Commandes** : six routes de `./control.sh` n'étaient documentées nulle part (`help`, `validate help`, `doctor polish`, `doctor remote`, `remote doctor`, `logs list|tail|boot-failure`). Le centre de contrôle les décrit, et `tests/test_docs_integrity.py` échoue désormais si une route manque à cette page ; deux nouveaux cas de `tests/test_docs_integrity_behavior.py` (21 au total) le prouvent.
  - **Vocabulaire** : le glossaire fixe un terme par concept (hôte, noyau, sauvegarde, garde réseau, matériel physique, fermé par défaut), appliqué aux guides courants. `SECURITY.md` est réécrit en français, avec la même politique.
  - **Schémas** : les pages disent que le `.svg` est écrit par le générateur, pas exporté de diagrams.net, et pourquoi un export de diagrams.net ne doit pas le remplacer.
  - **ADR** : l'index marque l'ADR 0001 comme remplacée par l'ADR 0018 et donne le plan d'une nouvelle ADR, avec ses options écartées.

- CI (chantier D6, lisibilité) :
  - **Noms d'étapes** : les huit étapes de workflow sans nom ont maintenant un nom qui dit ce qu'elles vérifient (job `borg-fedora`, et l'étape `safe.directory` de trois workflows). Les étapes `run: bash tests/…` de `logic-contracts` gardent leur libellé : GitHub y affiche déjà le test lancé.
  - **actionlint** : il ne signale plus rien. La variable `attempt`, inutile, disparaît de `release.yml`. Dans `non-regression.yml`, les motifs entre guillemets simples, qui cherchent un `$` littéral, portent la directive ShellCheck qui le dit.
  - **Liens externes** : nouveau workflow hebdomadaire et non bloquant, `external-links.yml` (`scripts/ci/check-external-links.py`). Une page disparue (404, 410) ou un nom introuvable le fait échouer ; un refus anti-robot ou une erreur serveur n'est qu'un avertissement. `tests/test_external_links_behavior.py` vérifie ce classement hors ligne.
  - **Tolérances** : la page CI documente les tolérances d'échec (`|| true`) de `release-readiness.yml`, un workflow d'état des lieux qui ne valide rien.

- Documentation (chantier D5, navigation et cohérence) : les guides d'installation, de qualification et la fiche physique se terminent par une « étape suivante ». Les lignes « Vérifié par la CI » du README donnent leur date, le commit de la préversion v0.24.1-rc.1 et le lien du run. La ligne « Installation » de `CONTRIBUTING.md` nomme le job qui contrôle les PR depuis #182. « Autres workflows » devient « Workflows non obligatoires ». Le superlatif de l'architecture est remplacé par un objectif mesurable. Le compte rendu de la refonte reçoit une section sur la seconde passe de relecture : axes traités et écartés, vérifications réelles, et points non vérifiés.

- Documentation (chantier D4, pédagogie) : nouvelle page [notions clés](docs/CONCEPTS.md). Elle explique sept idées qui reviennent dans tous les guides, chacune par le problème qu'elle règle, son principe, sa place dans le projet, sa vérification, ses limites et l'erreur fréquente : fermé par défaut, preuve liée à un état, trois niveaux de preuve, baseline et certification, sauvegarde vérifiée par restauration, noyau N / N-1 et secours Fedora, garde réseau des VM. Les guides d'installation, de qualification, de sauvegarde et de KVM s'ouvrent sur ce qu'ils permettent de faire, et le README, le portail et l'architecture renvoient à la page.

- Documentation (chantier D3, diagnostic et procédures) :
  - **Restauration** : le guide donnait l'exemple `restore NOM /chemin/du/staging/vide`, que `restore.sh` refuse, car toute cible doit être dans la racine de staging (`~/Restores/fedora-gnome-custom`). Les exemples sont corrigés, et chaque étape reçoit un critère de réussite et une règle d'arrêt.
  - **Création de VM** : critères de réussite et d'arrêt. La reconstruction de l'invité, destructive, est maintenant écrite avec ses commandes exactes et leur portée, au lieu de « retirer explicitement le domaine ».
  - **Dépannage** : un tableau « Pannes fréquentes » donne, pour neuf cas, la cause possible, la vérification sûre, la correction et la nouvelle validation. Chaque commande qui modifie le système porte la mention *(modifie le système)* ; les autres observent seulement.
  - **CI** : la page annonçait, pour chaque job, « où regarder s'il échoue » sans le dire. Le tableau des jobs de `Tests` reçoit une colonne « Si rouge » avec les artefacts à ouvrir, et les autres fiches une ligne « Si rouge ».

- Documentation (chantiers D1 et D2, seconde passe de relecture) :
  - **D1, vérifications réelles.** Rendu GitHub contrôlé dans le navigateur : 35 guides et README, en thème clair, sombre et en largeur mobile ; images chargées, ancres valides, aucune page ne déborde. Les 47 liens externes répondent. Les sept sources `.drawio` se rouvrent dans diagrams.net, avec des libellés identiques à leurs exports. Deux schémas étaient périmés depuis #182 : le laboratoire partait encore d'une « seed Cloud Beta », et le schéma de la CI ignorait l'exception des PR de documentation. Ils sont corrigés, comme la phrase de la fiche Fedora 45 sur les « images Beta » des laboratoires.
  - **D2, schémas maintenables.** Le générateur des schémas, resté hors du dépôt, est versionné dans `tools/diagrams/` avec son mode d'emploi. `tests/test_diagram_sources.py` vérifie que chaque paire est reproduite octet pour octet et que les contrastes passent. `CONTRIBUTING.md` reçoit une charte graphique : structure des pages, et palette des schémas avec la fonction et le contraste mesuré de chaque couleur. Le contrôle des chemins cités couvre aussi `tools/`.

- CI plus rapide, mesurée sur la PR #180 : 22 minutes, fixées par la VM Rocky et le laboratoire GNOME à six extensions, sans attente de runner.
  - **PR de documentation** : le nouveau job `changes` (`.github/scripts/docs-only-change.py`) classe les fichiers modifiés. Si la PR ne touche que du Markdown ou `docs/`, les trois VM, qui ne lisent aucun de ces fichiers, sont sautées. `contracts` n'accepte ce saut que pour ces trois jobs et seulement si `changes` a réussi ; tout autre job sauté reste un échec. Le push sur `main` exécute toujours les trois VM, et `release.yml` exige ce run. `test_fedora_lab_evidence.sh` couvre le classement et chaque refus.
  - **Image des laboratoires** : les deux laboratoires GNOME partent de l'image Cloud finale `Fedora-Cloud-Base-Generic-45-1.4` au lieu de la Beta 1.3. La Beta exigeait 416 mises à jour à chaque démarrage. Le `CHECKSUM` est vérifié par la clé Fedora 45 épinglée, et le contrôle refuse désormais toute autre image que celle de la compose épinglée.
  - **Doublons** : `shell-quality`, `fedora-package-preflight` et `fedora-installer-audit` tournaient deux fois par push de branche (événements `push` et `pull_request`). Leur `push` est limité à `main`. `fedora-installer-audit` ne tourne plus sur les PR, déjà couvertes par le job `installer-audit` de `Tests`.
  - **Runs dépassés** : neuf workflows annulent le run précédent d'une même PR quand un nouveau push arrive ; aucun run n'est annulé sur `main`.

## 0.24.1 — Documentation refondue et corrections avant le Live USB

Préversion à utiliser pour le contrôle Live USB et l'installation du PC. Elle reprend les corrections fusionnées depuis 0.24.0 RC1 :
- vérification du média avec un trousseau donné par son seul nom ;
- installation de RPM Fusion malgré le refus de dnf5 5.4.6 ;
- message explicite du precheck de veille ;
- retrait d'ONLYOFFICE des contrôles de la Gate 3.

Elle apporte aussi la refonte complète de la documentation (chantiers C1 à C9), relue contre le code et protégée par des contrôles stricts. Aucune installation physique ni certification matérielle n'est revendiquée.

- Documentation (chantier C9, audit transversal) : la refonte est terminée ; son compte rendu est dans `docs/history/DOCUMENTATION_OVERHAUL_2026-11.md`.
  - **Contrôles stricts** : les listes de migration `METADATA_PENDING` et `MERMAID_PENDING` sont supprimées. Tout guide de `docs/` doit porter son bloc de métadonnées. Les dates ne peuvent être ni futures ni incohérentes : une « Dernière vérification » antérieure à la « Mise à jour » échoue.
  - **Fins de ligne** : six fichiers étaient entrés dans `main` en CRLF avec C8, contrairement à `.editorconfig` : quatre pages de `docs/`, deux pages d'historique et `tests/test_docs_integrity.py`. Ils sont repassés en LF, et le test refuse désormais tout fichier suivi en CRLF.
  - **Tests** : `test_docs_integrity_behavior.py` passe à 19 cas. Les cas des listes de migration sont remplacés par ceux des nouvelles règles.
  - **Cohérence** : `CI_VALIDATION.md` nomme les huit workflows qu'exige `release.yml`. Le README et le portail renvoient à la feuille de route, qui marque la refonte comme réalisée. Aucun tutoiement ni statut périmé n'a été trouvé dans les pages courantes, et chaque guide figure dans le portail et reçoit au moins deux liens.

- Documentation (chantier C8, développement et référence) : les dix derniers guides sont relus contre le code et reçoivent leurs métadonnées ; `METADATA_PENDING` est vide.
  - **Inventaire logiciel** : il avait dérivé des manifests. Il omettait Gaming, AppImage et Gear Lever, `adw-gtk3-theme`, `localsearch`, `xdg-user-dirs-gtk` et `kmod`, et citait `xorriso`, que le projet n'installe pas. La partie hôte reproduit désormais chaque manifest, et `test_docs_integrity.py` vérifie qu'elle reste identique (trois nouveaux cas dans `test_docs_integrity_behavior.py`, 18 au total). La partie VM est relue contre `bootstrap-devops.sh` : dépôts EPEL et CRB ajoutés, versions épinglées présentées en tableau.
  - **CI** : la page est réorganisée en fiches par contexte obligatoire (ce que vérifie le job, ce qu'il ne prouve pas), puis en tableau des autres workflows. Corrigé : elle disait que certaines images Fedora venaient encore d'ECR Public, alors que toutes viennent de `registry.fedoraproject.org`.
  - **Laboratoire GNOME** : corrigé « GNOME Shell 50 » en 51 et le correctif d'arrêt de DING, présenté comme réservé à la VM alors que l'installateur de production l'applique depuis la promotion du profil. La description du redémarrage est découpée en étapes.
  - **Feuille de route** : celle d'octobre 2026, antérieure à la sortie de Fedora 45, est archivée dans `docs/history/` ; la nouvelle `docs/ROADMAP.md` donne l'état et les prochaines étapes.
  - **Provenance** : ajout du média Fedora 45, du noyau amont et du tableau des extensions.
  - **Dépannage** : tableau d'entrée « symptôme, première commande, section ».
  - **Glossaire** : le terme `CODE-READY`, absent du code, est retiré ; ajout de compte rendu Live, baseline, sauvegarde pré-APPLY, `DEFERRED`, ADR, N/N-1 et COPR ; liste de `/data` complétée.
  - **Mise à niveau 44 → 45** : réécrite par phases ; le code de retour 20 du premier `finalize` est expliqué.
  - **Politique de sécurité, architecture** : contrôles du doctor en tableau, liens vers les ADR ; le BIOS 1.A66 est présenté comme une décision du propriétaire, non contrôlée par le code.

- Documentation (chantier C7, virtualisation) : KVM au quotidien, la référence virtualisation et le réseau `devops-nat` sont relus contre `config/virtualization.conf`, `config/vm-profiles.conf`, le bootstrap Rocky, le garde nftables, son unité systemd et le dispatcher NetworkManager, et reçoivent leurs métadonnées. Les versions des outils de l'invité, la clé Rocky épinglée et le contrat réseau étaient exacts. Ajouts : l'option `--ssh-key` de la création Rocky, l'origine de l'utilisateur de l'invité (`ROCKY_SERVER_USERNAME`) et la protection statique `KVM_EXTRA_PROTECTED_CIDRS`, qui couvre la plage Tailscale. Le dépannage du réseau renvoie directement au dépannage KVM au lieu de TROUBLESHOOTING, qui ne faisait que rediriger. Vocabulaire harmonisé (« garde réseau », « invité », « hôte ») et un tutoiement retiré.

- Applications : `application-usage-doctor` et `manifests/application-runtime-contract.tsv` exigeaient encore ONLYOFFICE (`org.onlyoffice.desktopeditors`), retiré du manifeste Flatpak ; la Gate 3 aurait échoué sur une application que le projet n'installe plus. Les deux sont corrigés, et `test_professional_apps_contract.sh` vérifie désormais que chaque Flatpak exigé par ces contrôles figure dans un manifeste.

- Documentation (chantier C6, bureau et applications) : neuf guides relus contre les manifestes, les verrous et les modules, avec leurs métadonnées. Applications : ONLYOFFICE retiré, Flatseal et `libreoffice-gtk4` ajoutés (ils étaient installés sans être cités) ; inventaire logiciel aligné. Nautilus : `localsearch` cité, doublon File Roller supprimé, cible et limite du démarrage à froid indiquées. Bash : alias `ll`, `la`, `g` et `dps` ajoutés. Jeu vidéo : la page ne contredit plus sa propre section sur l'emplacement du dépôt Steam de Fedora 45. Couleurs : une source étiquetée « GNOME 51 » pointait vers les notes de GNOME 50. Titres en français, registre impersonnel et vocabulaire « Golden » réduit dans tous ces guides.

- Documentation (chantier C5, usage quotidien) : le guide des sauvegardes est réorganisé par tâche (comprendre, ce qui est sauvegardé, sauvegarder, vérifier, restaurer, reprise après sinistre, exports de VM), avec une section de référence pour le fonctionnement interne. Les sections historiques « après l'audit de fiabilité » et « depuis 0.19 » sont fondues dans cette organisation, sans perte de faits. Un tableau précise ce que contient chaque type de sauvegarde ; il corrige une ambiguïté importante : la sauvegarde pré-APPLY est un point de retour de l'état du système, elle **ne contient pas** les données de `/data` ni les dossiers XDG, protégés par les sauvegardes quotidienne et complète. Le centre de contrôle, l'entretien du poste (ex-« Desktop & Lifecycle »), Linux amont, la performance et l'accès distant sont relus contre le code et reçoivent leurs métadonnées : titres en français, registre impersonnel, gras réduit (95 → 41 passages pour l'accès distant), paragraphes trop longs découpés, version de noyau datée remplacée par la commande qui l'affiche, mention périmée d'un Fedora 45 « non promu » corrigée, `doctor polish` documenté, exclusion des clés `.ssh` et `.gnupg` rappelée dans l'entretien du poste. Le message de réussite de `data-storage-doctor` cite désormais `IA/Openclaw`, qu'il contrôlait déjà sans l'afficher.

- Installation : `installer/lib/verify-media.sh` lit désormais un trousseau donné par un simple nom de fichier dans le dossier courant. `gpgv` le cherchait dans `~/.gnupg`, si bien que `--keyring fedora45.gpg` échouait (« No public key ») alors que le média était bon ; le défaut est apparu en rejouant la procédure du guide sur la vraie ISO 1.4. `test_fedora_media_behavior.sh` couvre ce cas.

- Documentation (chantier C4, installation et qualification) : le guide d'installation est réécrit selon une procédure vérifiable. Chaque étape a un but, un critère de réussite et une règle d'arrêt ; un tableau « En cas d'échec » donne, pour les refus probables, la vérification sûre et la correction ; une section « Retour arrière » s'ajoute. La section 1 explique comment obtenir le trousseau Fedora 45 ; elle a été exécutée telle quelle sur l'ISO 1.4 (`Fedora 45 media PASS`). L'APPLY mentionne la phrase de confirmation exacte. Le guide s'arrête à la certification : mises à jour, noyau et récupération renvoient aux guides d'usage, qui les couvraient déjà. Le guide fait foi pour l'ordre des commandes, la qualification pour les critères et la Gate 3 : les commandes de baseline et du Live ne sont plus recopiées dans la qualification. Les six pages du chantier (guide, contrôle Live, fiche Fedora 45, qualification, fiche physique, reprise isolée) reçoivent leur bloc de métadonnées ; la fiche Fedora 45 ne décrit plus les RPM GNOME 51 comme absents des dépôts stables.

- Documentation (chantier C3, schémas) : les sept schémas Mermaid sont remplacés par des paires `.drawio` (source éditable diagrams.net) et `.svg` (export à fond opaque, titre et description) dans `docs/assets/diagrams/`. Chaque image est suivie d'une description textuelle et d'un lien vers sa source. Le contenu a été revérifié contre le code : le schéma des sauvegardes montre désormais toutes les sources de `config/backup.conf` (dont IA/Openclaw, `~/Development` et les réglages) et ce qui reste hors Borg ; celui de la CI montre les six contextes obligatoires, la fusion et la release ; celui de l'accès distant indique que le profil est désactivé par défaut et que le repli RDP se configure à la main. Les trois anciens SVG qu'aucune page n'utilisait sont supprimés. `MERMAID_PENDING` est vide : un bloc Mermaid fait désormais échouer `test_docs_integrity.py`.

- Baseline : le precheck de `baseline.suspend_resume` renvoyait un `1` brut, sans message, quand `/sys/power/mem_sleep` est illisible. Il renvoie maintenant `EXIT_PRECHECK_FAILED` (20) et explique que le noyau n'expose aucun état de veille. Certains runners GitHub n'exposent pas ce fichier : l'audit de l'installateur accepte ce seul blocage, avec ce code précis, comme limite du runner ; `test_ci_gates_behavior.sh` refuse toujours un `rc=1`. Sur le PC, le fichier existe et le comportement est inchangé.

- Documentation (chantier C2, accueil et navigation) : le README est réécrit pour deux publics, l'opérateur du PC et un visiteur qui découvre le projet. Il présente le problème et l'objectif, un tableau des domaines, un état réel par statut (réalisé, vérifié par la CI, vérifié le 2026-11-03, non vérifié sur le matériel) et trois parcours de lecture. Il ne recopie plus de commande d'installation : l'ancien bloc clonait `main` sans se placer sur le commit audité exigé par le contrôle Live. Le parcours d'installation a désormais une seule source de vérité, le tableau « Le parcours » du guide d'installation, vers lequel renvoient le portail `docs/README.md` (qui reçoit son bloc de métadonnées) et l'architecture.

- Documentation (chantier C1, conventions) : `CONTRIBUTING.md` devient la source de vérité de la rédaction, avec les statuts (prévu, en cours, réalisé, vérifié, non vérifié), le registre impersonnel, le lexique, le bloc de métadonnées des guides et les règles des schémas (paires `.drawio` / `.svg` dans `docs/assets/diagrams/`, sans Mermaid). `test_docs_integrity.py` contrôle ces règles, avec des listes de migration qui ne peuvent que diminuer ; `test_docs_integrity_behavior.py` prouve sur 14 cas qu'il accepte et refuse ce qu'il doit. Correction de `FEDORA_GNOME_CI_LAB.md`, qui décrivait encore un profil `pending` et des RPM GNOME 51 absents des dépôts stables.

- RPM Fusion : dnf5 5.4.6 refuse depuis le 3 novembre 2026 les paquets `rpmfusion-free-release-45-1` et `rpmfusion-nonfree-release-45-1`, qui déclarent la dépendance `/usr/share/dnf5/libdnf.conf.d/` avec une barre oblique finale. Ce refus bloquait le check obligatoire `packages`, et aurait bloqué le module `system.sources` sur le PC. Le module et la CI utilisent maintenant le même script, `scripts/packages/install-rpmfusion-release.sh` : `dnf install` d'abord, puis, pour ce seul cas, `rpm -i --nodeps` après vérification de l'identité du paquet, de la liste exacte de ses dépendances et de sa signature par la clé RPM Fusion épinglée (`config/keys/`, empreintes de rpmfusion.org/keys). Tout autre cas échoue sans rien installer. Vérifié dans un conteneur Fedora 45 (dnf5 5.4.6.0-3, rpm 6.1.0-1) ; `tests/test_rpmfusion_release_behavior.sh` couvre le chemin normal, le repli et onze refus.

## 0.24.0 — Profil Fedora 45 promu avec le média final

Le profil de production Fedora 45 / GNOME 51 est promu à `ready` avec le média final 1.4, authentifié par son CHECKSUM signé, et les RPM GNOME 51 revus des dépôts stables. L'APPLY et le Kickstart de production ne sont plus bloqués par le profil ; ils restent soumis à toutes leurs autres gardes. Aucune installation physique ni certification bare-metal n'est revendiquée : la qualification se fait sur le vrai PC jusqu'à la Gate 3.

- Fedora 45 : promotion du profil de production à `ready` avec le média final `Fedora-Workstation-Live-45-1.4.x86_64.iso` (SHA-256 `68338c6b…3beb`). Le CHECKSUM est vérifié avec la clé Fedora 45 épinglée `4F50A611…F577861E`, issue du paquet `fedora-gpg-keys-45-1`. Les RPM Dash to Dock 110-1.fc45 et AppIndicator 66-1.fc45 sont présents dans les dépôts stables. `promote-fedora45.py` a écrit `installer/fedora45-media.lock` et les empreintes du profil dans un conteneur Fedora 45 jetable, depuis un clone propre de `main`. La documentation suit ce statut, et l'audit du laboratoire QEMU rapporte le statut réel du profil au lieu d'un `pending` figé. Aucune certification matérielle n'est revendiquée : la Gate 3 sur le vrai PC reste requise.

## 0.23.1 — Relecture complète du code : sécurité, preuves et qualification physique

Relecture complète du code produit, domaine par domaine, après la 0.23.0. Chaque défaut corrigé est couvert par un test qui échoue sur l'ancien code. Plusieurs auraient bloqué la qualification sur le vrai PC : lecture SMART des T705 sans root, nom du pilote audio, pilotes intégrés au noyau, contrôle du chiffrement sur une installation btrfs standard. Le profil Fedora 45 reste `pending` : aucune installation physique ni certification bare-metal n'est revendiquée.

### Défauts qui auraient bloqué la qualification sur le vrai PC

- Docteurs, seconde passe (relecture ligne à ligne des docteurs restants) : quatre défauts corrigés. **Politique de sécurité de l'hôte** : `host-security-policy-doctor` concluait à une « cible crypt active » dès que `dmsetup table --target crypt` affichait quelque chose, y compris `No devices found`, la réponse d'une installation btrfs standard sans aucun périphérique device-mapper. Sans root, il donnait au contraire un faux OK. Seule une vraie ligne de cible `crypt` compte maintenant, et des tables illisibles ne sont qu'un avertissement. **Contrat des pilotes** : un pilote intégré au noyau (`=y`, par exemple `xhci_hcd`) n'a pas d'étiquette `intree` dans `modinfo`, qui affiche seulement `filename: (builtin)`. Il était donc déclaré hors arbre, ce qui aurait bloqué la baseline et la certification ; il est maintenant accepté comme faisant partie du noyau. **Test NVMe de la baseline** : comme les tests mémoire et CPU, `baseline-doctor run-nvme-test` retire maintenant son ancienne preuve avant un nouvel essai. **Requêtes RPM** : `rpm -q --qf` écrit `package X is not installed` sur sa sortie standard, et ce texte était pris pour une version ; la matrice logicielle ne signalait donc jamais un paquet requis absent. Le nouvel utilitaire `rpm_installed_query` est utilisé partout où ce motif apparaissait. `test_host_security_policy_behavior.sh` et `test_rpm_query_behavior.sh` (nouveaux), `test_stack_certification_behavior.sh` et `test_physical_attempt_invalidation_behavior.sh` échouent sur l'ancien code.

- Installateur (relecture) : le `%post` du Kickstart n'écrivait `HOST_RELEASE` dans `config/local.conf` que pour Fedora 45. Un Kickstart Fedora 44 installait donc un dépôt réglé sur 45, la valeur par défaut, et toutes les vérifications de version échouaient sur la machine installée. La version du Kickstart est maintenant toujours écrite. Le générateur refuse aussi un chemin `--output` qui est un lien symbolique, puisque le fichier contient le hash du mot de passe, et explique une option sans valeur au lieu de s'arrêter en silence. Relu sans défaut : confirmation `EFFACER` liée au disque, identité stable par numéro de série vérifiée de nouveau en `%pre`, SHA du dépôt épinglé, mot de passe saisi deux fois et haché, vérification du média (signature Fedora épinglée, nom et somme sur une seule ligne).

- Matériel (relecture) : deux défauts qui auraient bloqué la qualification sur le vrai PC sont corrigés. **Santé SMART des T705** : `smartctl -j` écrit son JSON quel que soit son code de retour, non nul sans root et quand le journal d'erreurs NVMe a des entrées. Le code relançait alors via `sudo -n` mais gardait la première sortie : deux documents JSON collés, refusés par l'analyse. La baseline, `storage-doctor` et la capture de release échouaient donc pour un utilisateur normal. Seul le premier document qui contient le journal SMART est gardé. **Identité audio** : sysfs nomme le pilote USB `snd-usb-audio` (avec des tirets), alors que l'identification de la carte son ALC4080 et du micro de la Brio exigeait `snd_usb_audio`. Leur enrôlement échouait donc toujours ; les noms de pilote sont maintenant comparés sous leur forme de module. `test_storage_health_behavior.sh` (nouveau) et `test_peripheral_identity_behavior.sh` (vrai nom du pilote, micro de la Brio) échouent sur l'ancien code.


### Sécurité et preuves

- VM Rocky DevOps : Helm, kind et Minikube ont maintenant, comme yq et K9s, un SHA-256 attendu versionné dans le dépôt. Auparavant, leur somme était téléchargée depuis le même serveur que le binaire : une publication compromise qui changeait les deux aurait été acceptée. Changer une version impose de changer sa somme dans le même commit.

- CI (relecture) : la porte de publication (`scripts/ci/check-release-gate.py`) n'exigeait pas `security-scanning.yml`, alors que ce workflow (CodeQL et Gitleaks) tourne sur chaque push vers `main`. Une préversion pouvait donc être publiée malgré un secret détecté par Gitleaks ou une analyse CodeQL en échec. Il est maintenant exigé, et `test_ci_gates_behavior.sh` vérifie que tout workflow lancé à chaque push vers `main` fait partie de la porte ; un workflow filtré par chemin, limité à d'autres branches ou aux seuls tags n'en fait pas partie. Relu sans défaut : toutes les actions sont épinglées par SHA ; aucun `pull_request_target` ; permissions en lecture seule par défaut, l'écriture étant limitée à la publication et au scan de sécurité ; aucune expression `${{ }}` venant d'une PR dans une commande ; tag de release jamais déplacé et toujours résolu sur le commit exact.

- Docteurs (relecture) : trois défauts corrigés. **Certification finale** : une nouvelle tentative `final-certification certify` qui échouait laissait l'ancien certificat en place ; s'il correspondait encore à l'identité actuelle, il paraissait toujours valide. Chaque tentative le retire maintenant d'abord, après les gardes bare-metal et preuve Live, donc un essai depuis une VM ne l'efface pas. **Qualifications réseau et affichage** : comme l'audio et le stress GPU, `physical-runtime-doctor network` et `display-capabilities` retirent maintenant leur ancienne preuve et le certificat avant un nouvel essai. **kernel-doctor** : un kernel.org injoignable comptait comme KO, alors qu'un noyau connu comme en retard n'était qu'un WARN ; `record-suspend`, lancé juste après le réveil souvent avant le retour du réseau, refusait donc le cycle. C'est maintenant un WARN, et un KO seulement avec `--certify`. Tous les docteurs ont été balayés à la recherche des défauts déjà vus ailleurs (incrément sous `set -e`, sorties JSON concaténées, tubes interrompus) ; `final-certification`, `kernel-doctor`, `storage-doctor`, `data-storage-doctor` et `physical-runtime-doctor` ont été relus ligne à ligne. `test_kernel_doctor_behavior.sh` et `test_physical_attempt_invalidation_behavior.sh` (nouveaux) ainsi que `test_desktop_lifecycle_behavior.sh` échouent sur l'ancien code.

- KVM (relecture) : trois défauts corrigés. **Couverture du garde réseau** : la certification KVM cherchait chaque réseau protégé comme texte dans `nft list table`. Or nftables affiche une route `/32` sans suffixe, son set `auto-merge` fusionne un réseau contenu dans un plus grand, et `grep -F` trouvait `10.1.0.0/16` dans `110.1.0.0/16`. On obtenait donc de faux KO sur un réseau bien protégé, ou un faux OK. `scripts/kvm/nft-set-coverage.py` prouve maintenant l'inclusion d'adresses sur la sortie JSON du set. **Marque-pages Nautilus** : le remplacement ou le retrait du marque-page « Rocky DevOps » supprimait aussi tout marque-page personnel dont le libellé contenait ce texte ; seul le libellé exact est maintenant concerné. **Mémoire des VM** : la vérification XML traitait `KB`, `MB` et `GB` (puissances de 1000) comme des puissances de 1024 et ignorait `k`, `M` et `G` ; une unité inconnue est désormais refusée. Relu sans défaut : garde réseau (blocage d'urgence d'abord, IPv4 seulement, accès hôte ↔ VM permis volontairement), vérification signée de l'image Rocky, contrat XML et domcaps. `test_kvm_guard_coverage.py` et `test_nautilus_vm_bookmarks_behavior.sh` (nouveaux) ainsi que `test_kvm_xml_policy_behavior.sh` couvrent ces cas et échouent sur l'ancien code.

- Centre de contrôle (relecture) : le tableau de bord n'affiche plus un état trop optimiste. « Certification VALID » ne vérifiait que quatre champs du certificat (empreinte, configuration, plan, contrat de performance) ; il utilise maintenant le contrôle partagé `validation_final_certificate_valid`, qui vérifie aussi la baseline matérielle, la preuve Live USB importée, le bare-metal et tous les contrats. « Backup PASS » ne comparait que le commit ; il applique maintenant la même règle d'identité que l'APPLY (commit, configuration, plan et matériel). L'aide liste les routes qui manquaient (`install prepare-tools`, `doctor polish|remote`, `remote`, `upgrade`), et une variable d'environnement obsolète transmise à la sauvegarde quotidienne est retirée. Aucune action dangereuse n'a été trouvée : chaque mutation passe par son script protégé, avec une confirmation.

- Moteur : trois vérifications de sécurité échouent maintenant en cas de doute au lieu de passer. La vérification « dépôt Git propre » de l'APPLY et de la sauvegarde pré-APPLY échoue si Git lui-même échoue (dossier hors Git, propriétaire non sûr), au lieu de considérer le dépôt comme propre. Une phrase `APPLY_CONFIRMATION` vidée par la configuration bloque l'APPLY au lieu d'accepter une réponse vide. Une preuve n'est plus reconnue comme l'identité actuelle si son commit n'est pas un vrai SHA Git (`unknown` hors Git), si l'empreinte du plan de modules est vide, ou, en bare-metal, si l'empreinte matérielle est vide (baseline illisible). Ces cas sont couverts par `test_apply_gate_behavior.sh`.


### Fiabilité et messages

- Nettoyage hebdomadaire des journaux (relecture des scripts Python) : les journaux d'un même run étaient assemblés avec les deux caractères `\n` au lieu d'un vrai saut de ligne, dans un ordre de fichiers non fixé. Une règle d'explication pouvait alors correspondre à cheval sur deux fichiers, par exemple la fin de `main.log` et le début de `modules.log`, et la fiche d'incident recevait un faux diagnostic. Les fichiers sont maintenant lus dans un ordre fixe et séparés par un vrai saut de ligne. Relus sans défaut : `fedora-profile.py`, `promote-fedora45.py` (signature épinglée, commit exact, restauration en cas d'échec), `gdm_autologin.py`, `persistent_data_identity.py`, `live_validation.py`, `pin-upstream-target.py`, `upstream-release.py` et `nft-set-coverage.py`.

- Vitals (relecture) : la vérification du module de télémétrie et `resource-monitor-doctor` exigeaient toujours `true` pour l'usage CPU, la mémoire et le réseau, alors que l'APPLY écrit les valeurs configurées. Avec par exemple `RESOURCE_MONITOR_NETWORK=false`, l'APPLY s'exécutait puis la vérification échouait à chaque fois. Ils vérifient maintenant exactement la configuration, y compris la température CPU et l'usage GPU, qui n'étaient pas contrôlés. La même correction s'applique au module Resource Monitor historique (Fedora 44).

- GNOME et bureau (relecture) : deux défauts corrigés. **Réparation d'affichage désactivée** : avec `DISPLAY_REPAIR_ENABLED=false`, le module lançait `systemctl --user disable --now` même si le service n'avait jamais été installé. Cette commande échoue, et l'orchestrateur (`set -e`) arrêtait l'APPLY. Seul un service réellement installé est maintenant arrêté, et un échec de cet arrêt est signalé. **Applications par défaut** : `configure-default-apps.sh` ne cherchait les entrées `.desktop` que dans `/usr/share` et `~/.local/share`, et refusait une application Flatpak ou installée dans `/usr/local`. Il les cherche maintenant aux mêmes endroits que la session. Relu sans défaut : réglages de fenêtres, finition « Ubuntu » (même liste pour l'application et la vérification), codecs et pilote média Intel limités au nœud de rendu de la B580, réparation et surveillance de l'affichage, thème GTK3 qui suit le mode clair ou sombre, favoris du dock, cycle de vie de GNOME Shell, intégration bureau. `test_gnome_desktop_toggles_behavior.sh` (nouveau) échoue sur l'ancien code.

- Noyau (relecture) : le script de secours `rollback-to-fedora.sh` (`./control.sh kernel rollback-fedora`) dit maintenant pourquoi il s'arrête. Auparavant, après la resynchronisation DNF, l'absence de noyau Fedora, une image de démarrage manquante ou un GRUB qui ne changeait pas arrêtaient le script sans aucun message (`set -e`) ; une resynchronisation en échec n'était pas expliquée non plus. Chaque échec laisse le noyau par défaut de GRUB inchangé. `./control.sh kernel fallback` et `./control.sh kernel rollback-fedora` restent permis quand Secure Boot est actif ou indéterminé : ils passent au noyau Fedora signé, le seul qui démarre alors (ADR 0020 mise à jour) ; l'installation d'un noyau amont et le retour à N-1 restent bloqués. `KERNEL_BLOCK_SECURE_BOOT` ne peut plus être mis à `false` : le moteur d'installation bloque toujours un noyau amont non signé quand Secure Boot est actif, et un réglage différent faisait seulement passer le dry-run là où l'APPLY échouait. `test_kernel_recovery_behavior.sh` (nouveau) exécute le vrai script de secours (confirmation exacte, désactivation des deux COPR, levée du verrou de version, resynchronisation limitée à `fedora` et `updates`, choix du noyau Fedora le plus récent, et chaque refus) ainsi que le précontrôle Secure Boot du module noyau.

- Sauvegarde (relecture) : les textes affichés correspondent maintenant à la politique réelle. Le plan du module 50 ne parle plus de mot de passe ni de sauvegarde de VM éteinte : le dépôt Borg n'est pas chiffré, les VM, la NVRAM, le TPM, le cloud-init et les métadonnées libvirt ne sont jamais archivés, et les clés SSH et GnuPG sont exclues. Le plan du module 58 n'annonce plus la reconstruction des disques de VM. Le plan de reprise après sinistre place `/data` sur le second T705 (avec ré-enrôlement de son identité) et non sur un « SSD de VM ». Aucun défaut de fonctionnement n'a été trouvé dans le moteur Borg, les scripts de sauvegarde, de rétention, de restauration et de reprise, ni dans les docteurs.

- Nautilus : un échec de l'installation de l'assistant de préchauffage, du rechargement systemd ou de l'activation de son service renvoie maintenant `EXIT_APPLY_FAILED`. Auparavant, l'orchestrateur (`set -e`) arrêtait déjà l'APPLY, mais avec le code brut de la commande, et un appel direct de la fonction continuait. Le plan n'annonce plus le backend `gvfs-archive`, retiré de Fedora 45. `test_nautilus_integration_contract.sh` ne fige plus le code du module et du docteur. `test_nautilus_integration_behavior.sh` (nouveau) exécute le vrai module et le vrai docteur avec de faux `dnf`, `rpm`, `gsettings`, `gio` et `systemctl`. Il vérifie l'installation de la pile Fedora, SMB et MTP seulement s'ils sont activés, le retrait de l'ancienne extension `gnome-terminal-nautilus`, la politique de miniatures (`never` si les aperçus sont désactivés), et le préchauffage, qui ne lance jamais Nautilus lui-même. Le docteur refuse chaque paquet manquant (sans exiger `gvfs-archive` sur Fedora 45), une extension File Roller absente, GIO en panne, un schéma absent, une politique modifiée, et un assistant ou un service de préchauffage absent ; un Bureau XDG absent avant DING n'est qu'un avertissement. Le contournement IBus reste opt-in, séparé de Nautilus, et ne retire qu'un paquet réellement installé.


### Tests de comportement

- Tests de la validation native : `test_three_gate_validation_contract.sh` ne fige plus ~20 chaînes du code. `test_validation_entrypoints_behavior.sh` (nouveau) passe par le vrai `./control.sh` dans une copie Git propre du dépôt. Une session Live USB enregistre et exporte sa preuve, mais n'atteint jamais une action réservée au système installé ; un essai refusé efface d'abord les anciennes preuves, et un préflight en échec ou des contrôles requis non testés n'écrivent aucune preuve. Le système installé n'importe que la preuve de ce PC et de ce commit. Gate 3, la certification finale et la capture de release refusent une session Live, une VM, une source modifiée, une autre version de Fedora ou une autre distribution, Fedora 45 tant qu'il n'est pas promu, et une preuve absente, d'un autre PC ou d'un autre commit ; ensuite, chaque commande Gate 3 atteint exactement son docteur. `validation_require_selected_fedora` délègue maintenant à la sélection de release et lit donc la même identité de système (`FEDORA_OS_RELEASE_FILE`) au lieu de relire `/etc/os-release` en double ; la fonction inutilisée `validation_fedora_release` est retirée. Relancer un enregistrement Live sur le système installé n'efface jamais la preuve importée.

- Tests du runtime de sauvegarde : `test_backup_runtime_bundle_contract.sh` ne fige plus ~15 chaînes du code. `test_backup_daily_runtime_behavior.sh` (nouveau) exécute le vrai module de sauvegarde quotidienne avec de faux `systemctl` et Borg. L'APPLY installe un runtime immuable, vérifié par manifeste et nommé d'après le commit et la configuration ; les unités quotidienne et de rétention pointent vers ce runtime, jamais vers le dépôt Git. Les anciennes unités Restic sont retirées. La configuration copiée est en mode 600 et ne contient aucune variable d'environnement de l'appelant. Un runtime altéré n'est jamais remplacé (la preuve est gardée) et refuse de s'exécuter ; un runtime ré-étiqueté ou dont la configuration a été modifiée échoue à la vérification. Le runtime installé fonctionne encore après la suppression du dépôt. `backup-now --prune` lance la rétention stricte, et un échec de rétention empêche tout nouveau certificat.

## 0.23.0 — Fedora 45 de référence, corrections avant installation et tests de comportement

Fedora 45 / GNOME 51 devient la référence de l'installation neuve et de la CI principale. Cette version corrige aussi l'installation, le stockage, les sauvegardes et le noyau. Les tests vérifient désormais le comportement réel du code au lieu de chaînes de caractères. Le profil Fedora 45 reste `pending` : aucune installation physique ni certification bare-metal n'est revendiquée.

### Fedora 45 / GNOME 51, installation et exploitation

- Documentation, deuxième passe : 49 → 35 guides. KVM et Rocky DevOps (8 → 2 : `KVM_QUICKSTART.md` pour l'usage et le dépannage, `VIRTUALIZATION.md` pour la référence), dépannage (4 → 1 : `TROUBLESHOOTING.md` couvre désormais matériel, noyau avec secours Fedora, `/data`, Gaming, journaux et incidents), vision et architecture (5 → 1 : `ARCHITECTURE.md`). La page Fedora 44 rejoint `docs/history/`. Le contrôle d'intégrité a repéré deux références du code au runbook supprimé, corrigées.
- Tests : `test_physical_soak_behavior.sh` n'est plus instable. Les PID des fausses charges sont écrits atomiquement et l'instance GPU saine est choisie par `flock` : un `mkdir` concurrent pouvait réussir deux fois sur certains tmpfs.

- Documentation : 75 → 49 guides. Les guides GNOME (7 → 1), qualification et certification (12 → 2) et méta-documentation (4, intégrées à `CONTRIBUTING.md`) sont fusionnés ; le portail `docs/README.md` est réécrit. Les tests qui figeaient la formulation des guides (~110 assertions, 3 fichiers) sont remplacés par `tests/test_docs_integrity.py`, qui vérifie liens, pages atteignables, commandes `./control.sh` citées et chemins cités. `DESKTOP_LIFECYCLE.md` indiquait à tort des mises à jour Flatpak par GNOME Logiciels, que le projet verrouille.

- Sauvegardes : les dossiers `.ssh` et `.gnupg`, à toute profondeur, sont toujours exclus des archives Borg non chiffrées (pré-APPLY, complète, quotidienne), même si la configuration locale les liste (ADR 0021). Le guide de sauvegarde explique comment conserver ces clés à part, dans Bitwarden ou sur un support chiffré. Test avec un vrai dépôt Borg et test sans Borg pour chaque type d'archive.

- Noyau : un noyau Fedora signé est conservé comme entrée GRUB de secours à côté de Linux amont N / N-1 (ADR 0020), jamais par défaut ni supprimé par la rétention. La purge retire des versions exactes au lieu de `--oldinstallonly`, qui aurait retiré le secours en premier ; `installonly_limit=4`. Nouvelles commandes `./control.sh kernel fallback` (secours en défaut GRUB, sans suppression) et `kernel refresh-fallback` ; `kernel-doctor` et le contrôle GRUB vérifient la présence du secours.
- Kickstart : Fedora refuse un Kickstart depuis une image Live ; le générateur déclare maintenant les miroirs officiels `fedora` et `updates` pour que `%packages` (dont le manifeste baseline) soit réellement installé depuis le média Everything netinstall, et retire `bootloader --location=boot`, sans effet en UEFI. Le guide d’installation précise le média requis.
- Centre de contrôle : `kernel rollback` sélectionne N-1 sur toutes les routes (l’ancienne branche interne lançait la récupération Fedora) ; `rollback-fedora`, `install-latest` et `prune` y sont routés explicitement.
- `repair.sh` : une commande inconnue affiche l’aide sur stderr et sort en code 2 au lieu de 0.
- Nettoyage : imports Python inutilisés ; ADR 0001 marquée « remplacée par ADR 0018 ».

- Validation : parcours natif Live USB Fedora 45 / GNOME 51, puis installation sur SSD et qualification Gate 3 ; retrait des étapes opérateur WSL2 et VirtualBox. Rapport portable à 16 points, export avant redémarrage et import sur le même PC/commit après installation ; aucune certification des services installés depuis le Live.
- Preuves : propagation explicite des erreurs d’écriture et de checksum, refus d’une source modifiée et invalidation de l’ancien résultat avant un nouvel essai Live ou une nouvelle qualification GNOME.

- Fiabilité de l’installation Fedora 45 / GNOME 51 : reconnaître l’état réel `ACTIVE` de Tiling Assistant et réutiliser le helper commun dans les contrôles ; conserver CPU/RAM/réseau sans imposer de faux compteurs de charge à la B580 `xe`.
- Préparer les outils matériels avant leur premier usage via `control.sh install prepare-tools` et le manifeste inclus dans Kickstart ; fournir `semanage` dans le socle système avant `/data`.
- Maintenance : mettre aussi à jour Flatpak si DNF ne prépare aucune transaction, sans redémarrage artificiel ; conserver la propagation des échecs.
- KVM : détecter un LAN de même CIDR que le réseau invité et conserver le profil Rocky DevOps avec accès SFTP. Le profil Windows 11, ses scripts invités et ses obligations de certification sont retirés.
- Sauvegardes : appliquer au pré-APPLY l’exclusion du dossier `secrets` déjà utilisée en daily/full ; conserver Borg non chiffré et les exports VM manuels.
- CI : rendre les assertions d’absence réellement bloquantes, y compris en cas d’erreur de lecture, et couvrir les défauts par des scénarios de comportement.
- Documentation : README concis, portail par parcours, guides canoniques alignés et installation neuve Fedora 45 clairement séparée de l’historique Fedora 44. Le profil reste `pending` jusqu’à la qualification du média final signé et des composants stables.

- Fermeture GNOME 51 : appliquer `KillMode=mixed` au service utilisateur Shell pour laisser Mutter terminer ses enfants Xwayland avant le nettoyage final. Installation et laboratoire partagent le même drop-in et sa vérification effective ; test de l’ordre d’arrêt avec un vrai systemd et témoin négatif, sans changement du délai ni des contrôles de coredump.

- Documentation : orienter l'installation neuve vers le profil Fedora 45, harmoniser `pending`/`ready`, corriger le nom du verrou média dans le bundle et documenter Rocky après installation du host. Retirer l'ancienne commande de sauvegarde des VM des guides et de l'aide ; les exports restent manuels. Le README renvoie aux guides pour les procédures détaillées.

- Laboratoire GNOME : fermer l’instance D-Bus réelle de Nautilus et vérifier la fin des processus avant déconnexion ; conserver les diagnostics de fermeture et refuser les clients bloqués. L’essai interactif avec applications ouvertes reste requis.
- Détection de la définition Steam déplacée dans `/usr/share/dnf5/repos.d/` sur Fedora 45, avec vérification du propriétaire RPM, compatibilité du chemin historique et test de comportement.

- Fedora 45 / GNOME 51 devient la référence d’installation neuve, de configuration et de CI principale. Les entrées Kickstart et de vérification de média restent bloquées sur un profil non promu.
- Verrous canoniques Gtk4 DING, Show Desktop Button, Vitals et Tiling Assistant alignés sur le profil 45 ; manifestes Nautilus sans le backend `gvfs-archive` supprimé.
- Préférences GNOME 51 vérifiées sur les vrais schémas ; laboratoires principaux natif et personnalisé sous Fedora 45. Fedora 44 reste disponible par lancement manuel historique.
- Guides d’installation neuve, migration facultative et statut de promotion séparés ; données `/data/IA/Openclaw` et politique Borg conservées.

### Corrections avant installation

- Installation : préserver la configuration Kickstart et placer l’approbation définitive avant le dernier dry-run et le backup vérifié.
- Stockage : lier `/` et `/data` à deux T705 physiques distincts, avec approbation explicite du numéro de série et revalidation des UUID, modèles, séries et WWN.
- Données : préparer `/data/IA/Openclaw` avec les droits et labels utilisateur ; le protéger par Borg daily/full comme `/data/Projets`, sans modifier les exclusions VM.
- Sauvegardes : accepter les URI SSH Borg, inclure la configuration locale ignorée par Git et vérifier sa restauration ; embarquer l’identité approuvée dans le runtime quotidien immuable.
- Maintenance et certification : exiger un nouveau démarrage et l’historique de la transaction DNF5 exacte ; refuser les mesures SMART absentes et les cycles de veille liés à une ancienne configuration ou chaîne de preuves.
- KVM : fusionner les intervalles réseau chevauchants dans nftables et charger les overrides locaux dans les assistants publics.
- GNOME 51 : partager le correctif de fermeture Gtk4-DING et les versions RPM entre CI et installation. La promotion reste bloquée tant que les RPM exacts ne sont pas disponibles en stable et que le média final signé manque.

- Noyau : résolution du dernier Linux stable à partir de la version officielle kernel.org **avant** de sélectionner les RPM du COPR autorisé. Un paquet de numéro supérieur encore en développement ne masque plus un paquet exact déjà disponible ; si aucun RPM exact n'existe, le refus sécurisé reste obligatoire.
- CI : le test bloquant des RPM du noyau utilise Fedora 45, cible prévue de l'installation, au lieu du laboratoire historique Fedora 44. La validation RPM reste réelle et bloquante ; elle ne certifie pas le matériel.
- Fedora 45 : image de conteneur prise depuis le registre officiel Fedora à la place du miroir ECR soumis à des quotas de téléchargement.
- Documentation : navigation, préflight USB Live, gouvernance et traçabilité code ↔ guides ↔ tests remis en cohérence. Aucun GO physique ni installation Fedora 45 n'est revendiqué.

### Tests de comportement

- Tests d'ergonomie du bureau : `test_desktop_ergonomics_contract.sh` ne fige plus ~20 chaînes du code et de la configuration. `test_desktop_ergonomics_behavior.sh` (nouveau) exécute le vrai module d'extensions GNOME et le vrai `gnome-doctor` avec de faux `gsettings`, `xdg-user-dirs`, `gnome-extensions` et `flatpak`. DING et Show Desktop Button s'installent depuis les artefacts GNOME relus du verrou Fedora 45. Le Bureau XDG devient `~/Bureau`, la Corbeille est visible, le dossier personnel et les volumes externes et réseau sont masqués, et le bouton est en haut à gauche avec Super+D. Une extension n'est activée qu'une fois, et seulement si la session la voit ; le préflight ne change rien. La vérification et le docteur refusent chaque écart : réglage modifié, Bureau ailleurs ou absent, extension absente, inactive ou d'une autre source, Just Perfection activé. Hors session GNOME, le docteur n'audite pas les réglages de l'utilisateur.

- Tests de certification de la pile : `test_stack_certification_contract.sh` ne fige plus ~17 chaînes du code. `test_stack_certification_behavior.sh` (nouveau) exécute le contrat des pilotes en entier sur un faux sysfs : il passe quand chaque appareil Golden utilise son pilote Fedora intégré au noyau. Il refuse une VM, une autre carte mère, un Wi-Fi non enrôlé, le LAN sur r8125, USB sans xhci_hcd, un module hors arbre, un module ou un paquet NVIDIA, la B580 sur vfio-pci et un seul T705. L'empreinte des pilotes suit ces changements. L'empreinte de configuration change avec chaque fichier versionné (configuration, dépôts, politiques, manifestes, XML KVM, verrou du média), mais pas avec la documentation ni les tests.

- Tests de l'accès distant : `test_remote_access_contract.sh` ne fige plus le code des modules, déjà exécuté par les tests de comportement `test_remote_*`. `test_remote_modules_behavior.sh` vérifie en plus que, sans configuration, le profil ne fait rien. Il exécute aussi le vrai chemin SSH : la configuration installée est rendue pour ton utilisateur et donne la politique effective attendue (clés uniquement, pas de root, un seul utilisateur, SSH fermé sur le LAN sauf choix explicite). Si `sshd -t` la rejette, l'ancienne configuration est rétablie, ou la nouvelle est retirée s'il n'y en avait pas.

- Tests Gaming : `test_gaming_contract.sh` ne fige plus ~15 chaînes du code. `test_gaming_behavior.sh` (nouveau) exécute le vrai module et le vrai docteur avec de faux `dnf`, `rpm` et outils de jeu. Sans configuration, le profil ne fait rien. Steam ne s'installe que depuis le canal RPM Fusion Steam défini par `fedora-workstation-repositories` (emplacement Fedora 45 ou ancien `/etc`) ; une définition fournie par un autre paquet ou un canal absent bloque l'installation. La bibliothèque est sur `/data/Jeux`, accessible en écriture. Le docteur exige Steam installé par RPM, le multilib 32 bits et steam-devices, et refuse un dépôt Mesa tiers. Il ne certifie le rendu Arc, l'affichage et Vulkan qu'en bare-metal ; un VRR non exposé n'est qu'un avertissement.

- Tests de performance : `test_performance_runtime_contract.sh` ne fige plus ~25 chaînes du code. `test_performance_runtime_behavior.sh` (nouveau) exécute le vrai code avec un faux sysfs et de faux TuneD, systemd et fio. La politique versionnée est validée et une valeur non sûre ou inconnue est refusée. Les profils TuneD ne changent qu'en bare-metal. L'enveloppe GameMode passe en performance le temps du jeu et rétablit le profil précédent, même si le jeu plante. Le banc d'essai de l'ordonnanceur NVMe ne touche que le T705 cible, ne teste que `none` et `mq-deadline`, rétablit l'ordonnanceur même en cas d'échec et ne laisse aucun fichier sur `/data`. Le test sched_ext est borné dans le temps et refuse un échec de chargement et l'exécution hors bare-metal. La certification exige AMD P-State actif, le boost, TuneD et tuned-ppd actifs, le profil équilibré avec l'EPP attendu, et le swap zram actif ; hors certification, ces écarts ne sont que des avertissements.

- Tests de durcissement pré-1.0 : `test_pre1_hardening_contract.sh` ne fige plus ~30 chaînes, dont la plupart étaient déjà couvertes par les tests de comportement du noyau, du poste Golden et du cycle de vie. `test_pre1_hardening_behavior.sh` (nouveau) exécute la vraie détection d'environnement avec un faux `systemd-detect-virt` : bare-metal, VM, conteneur (Docker et Podman), WSL2 et CI sont reconnus ; un résultat ambigu ou l'absence de `systemd-detect-virt` donne `unknown`, jamais bare-metal. `diagnostic.sh` ne lance le diagnostic complet qu'en bare-metal prouvé et échoue sur un environnement inconnu. L'empreinte de certification change avec chaque version de paquet suivi et avec les contrats pilotes et KVM. Le réseau KVM refuse IPv6, le transfert entrant, la levée de l'isolation et un garde réseau en échec. Le mode préflight n'exécute aucune mutation.

- Tests matériel et KVM : `test_hardware_kvm_completion_contract.sh` ne fige plus ~25 chaînes du code. `test_hardware_kvm_behavior.sh` (nouveau) exécute le vrai code avec un faux sysfs et de faux outils matériels. Le module CPU/mémoire charge le pilote Fedora `nct6683` sans option et ne le recharge avec `force=1` que sur demande explicite. Il refuse un autre processeur, l'échec d'AMD P-State, l'absence de télémétrie et moins de 45 Gio de RAM ; la vitesse mémoire reste informative. Les micrologiciels suivent le processeur (AMD ou Intel) et la B580, et fwupd ne fait qu'inventorier. Le docteur des composants exige le LAN 5G r8169, le Wi-Fi 7 sur 6 GHz (configurable), un Wi-Fi enrôlé, xHCI et la télémétrie NCT6687D ; un lien négocié à 1 Gb/s n'est qu'un avertissement. Le docteur USB après réveil lit xHCI et le journal. Le banc d'essai I/O KVM choisit le moteur le plus rapide, seulement en bare-metal, sur un `/data` EXT4 monté, sans VM lancée, et ne laisse pas de fichier de test. Le test de création Rocky vérifie aussi l'agent invité, `--rng` et le ballon mémoire.

- Tests du cycle de vie du bureau : `test_desktop_lifecycle_contract.sh` ne fige plus ~40 chaînes du code. `test_desktop_lifecycle_behavior.sh` (nouveau) exécute le vrai code dans une copie du dépôt. Le module de cycle de vie écrit sa politique DNF et dconf dans un faux `/etc`, que le vrai `lifecycle-doctor` audite ensuite : téléchargement automatique des mises à jour RPM, jamais d'installation ni de redémarrage sans toi, mises à jour en arrière-plan de GNOME Logiciels verrouillées, profil dconf complété sans doublon, timers selon la configuration. Le docteur refuse une installation ou un redémarrage automatiques, un service de mise à jour Flatpak du projet, un greffon manquant, des verrous absents et fstrim désactivé. AppIndicator vient du RPM Fedora, n'est activé qu'une fois et seulement si la session le voit. `final-certification record-suspend` n'enregistre qu'une fois chaque cycle physique de veille, et seulement s'il est récent, si la réparation d'affichage est postérieure au réveil, si le journal noyau est propre et si les docteurs passent, en bare-metal avec la preuve Live USB. Un cycle copié ou issu d'une autre pile logicielle ne compte pas. Le docteur de calcul Arc exige une vraie exécution OpenCL en bare-metal.

- Tests du poste Golden : `test_golden_workstation_contract.sh` ne fige plus ~45 chaînes. `test_golden_workstation_behavior.sh` (nouveau) exécute le vrai code avec de faux `gsettings`, `gdbus`, `udevadm`, `sudo`, `lsblk` et `gdctl`. Il vérifie que GNOME applique les boutons réduire, agrandir et fermer à droite et que la vérification détecte une dérive. La surveillance d'affichage fait une capture à la mise en veille et une restauration au réveil, mais seulement une vérification sur un changement Mutter ou DRM. `/data` est convergé sur place, sans suppression ni réécriture récursive, avec l'étiquette `user_home_t` et Documents en dossier XDG. Le générateur Kickstart, lancé en vrai, épingle le SHA du dépôt et le numéro de série du disque. Il refuse une confirmation `EFFACER` pour un autre disque, des mots de passe différents, une partition ou un dépôt sans Git. Le docteur d'affichage applique la tolérance de fréquence. Le docteur de démarrage à froid de Nautilus n'écrit de preuve qu'en bare-metal. Ce docteur calcule maintenant ses millisecondes avec `date +%s%N`, car certains `date` (uutils) ignorent `%3N` et faussaient la mesure. Les valeurs du canal noyau passent dans le contrat noyau.

- Tests de durcissement : `test_final_hardening_contract.sh` perd ses ~30 recherches de chaînes en doublon et garde ses exécutions réelles (détection du bare-metal, orchestrateur, nœud de rendu de la B580, garde réseau KVM) plus les règles transverses (configuration déclarative, aucune mutation au chargement d'un module, durcissement du service nftables, fichiers de gouvernance). La politique HOST du Kickstart (sshd désactivé, client SSH présent, aucun chiffrement ajouté, installation limitée au disque choisi) est vérifiée sur le Kickstart réellement généré par `test_installation_prerequisites_behavior.sh`. Le contrat noyau vérifie aussi `KERNEL_BLOCK_SECURE_BOOT`.

- Tests Rocky DevOps : `test_rocky_vm_creation_behavior.sh` (nouveau) lance le vrai `create_rocky_devops_vm.sh` avec de faux libvirt, qemu et cloud-localds. L'image est authentifiée avant la création du disque. Le cloud-init n'autorise SSH que par clé, sans root ni sudo sans mot de passe, avec un vrai hash SHA-512 du mot de passe saisi. Les scripts invités copiés sont octet pour octet ceux du dépôt. Image non authentifiée, vérification désactivée, mot de passe vide, `/data` non validé, clé SSH avec options, mauvais nom d'utilisateur, autre version de Rocky et disque existant sont refusés avant tout disque. `test_rocky_devops_bootstrap_contract.sh` ne fige plus les listes d'outils, versions et messages, que le laboratoire Rocky 10.2 vérifie en vrai : il garde les règles de chaîne d'approvisionnement et de sécurité et le garde-fou de régression du noyau.

- Tests du centre de contrôle : `test_workstation_control_center_contract.sh` ne fige plus ~85 chaînes. `test_control_center_behavior.sh` lance le vrai `./control.sh` dans une copie du dépôt dont les moteurs sont des enregistreurs : chacune des ~90 commandes publiques atteint le bon moteur avec les bons arguments, les commandes inconnues ou incomplètes n'en lancent aucun, `menu.sh` est le même centre de contrôle, le tableau de bord marque une certification ou une sauvegarde d'une autre identité comme périmée, et `logs prune` ne supprime que les vieux journaux et rapports. `test_update_dispatch_behavior.sh` vérifie que la sauvegarde précède DNF et qu'un échec l'arrête, que les mises à jour sont réservées au bare-metal et que le firmware est seulement interrogé. Le contrat garde le format de version, la politique de rétention, la règle de façade mince et les garde-fous du scellement d'archive.

- Tests de sauvegarde : `test_backup_recovery_contract.sh` ne fige plus ~45 chaînes du code. `test_daily_backup_sources_behavior.sh` (nouveau, faux Borg) lance la sauvegarde quotidienne depuis un runtime installé : dossiers XDG localisés, exclusions VM/libvirt/clés, refus de `/data` non validé, de `/data/Jeux`, `/data/ISO`, `/etc`, `../`, et d'un runtime modifié. Le test de sauvegarde complète vérifie avec un vrai Borg que Documents et Projets sont archivés, pas Jeux ni ISO, et que l'instantané `/etc` ne contient pas le XML libvirt. Le test aller-retour Borg vérifie que la porte APPLY refuse une sauvegarde pré-APPLY périmée ou d'un autre commit, config, plan ou matériel.

- Tests du noyau : les ~50 recherches de chaînes de `test_kernel_lifecycle_contract.sh` sont remplacées par `test_kernel_lifecycle_behavior.sh`, qui exécute le vrai code contre de faux `rpm`, `dnf5` et `grubby` : rétention DNF, retour N-1, sélection du secours Fedora, blocage Secure Boot et hors bare-metal, surface GRUB à deux entrées, ordre du module. Le contrat ne garde que les valeurs de politique, les commandes publiques et les suppressions interdites. La logique de `enforce-two-entry-grub.sh` passe dans `lib/kernel_lifecycle.sh` ; `KERNEL_BOOT_DIR` permet de tester sans `/boot`.

## 0.22.3 — Durcissement de l'accès distant et vérification des preuves

- Tailscale : signatures des métadonnées ET des RPM exigées (`repo_gpgcheck=1`, `gpgcheck=1`) ; présence d'une véritable clé SSH publique testée par `ssh-keygen`.
- SSH : sauvegarde et restauration du drop-in précédent si `sshd -t` refuse les nouveaux réglages ; zone LAN déterminée depuis l'interface filaire.
- Sunshine : administration limitée à localhost (`origin_web_ui_allowed=pc`), UPnP désactivé, port 47990 refusé par des règles firewalld dédiées IPv4/IPv6 ; les ports de streaming suivis sont retirés lors de la désactivation de l'option.
- GDM : rétablissement des précédents paramètres d'autologin conservés, commande de verrouillage visant la session Wayland réelle et vérifiant `LockedHint` ; la présence d'un service activé reste un WARN tant que la Gate 3 n'est pas réalisée.
- Fedora 45 : `promotion_source_commit` désigne la base du changement, non une certification CI ; la qualification porte sur le nouveau SHA après commit.
- Tests supplémentaires pour Sunshine, GDM, gestion des services et règles firewalld ; nouveaux contrôles CodeQL Python et Gitleaks, avec actions épinglées.
- Les opérations distantes et la promotion Fedora 45 restent opt-in ; `REMOTE_ENABLE=false` par défaut et `profiles/fedora45/profile.json` toujours `pending`. Aucun PASS bare-metal n'est supposé.

## 0.22.2 — Vérification « jour J » avant l'installation de Fedora 45

- `release-readiness.py --latest` (activé dans le workflow hebdomadaire et manuel) compare chaque extension épinglée à la dernière version publiée : `UP-TO-DATE`, `NEWER` (version, review et SHA256 du nouveau build, plus un `latest-gnome-extensions.lock` à relire) ou `UNKNOWN`, et rappelle la dernière stable de kernel.org face au plancher `KERNEL_MIN_VERSION`. Les épingles ne changent jamais toutes seules.
- Correction : le rapport de readiness s'imprimait deux fois (un bloc dupliqué par erreur en 0.22.1, qui relançait aussi les sondes réseau). Un test garantit désormais qu'il n'existe qu'une fois.
- Guide « Vérification jour J » dans `docs/UPGRADE_FEDORA_45.md` : ordre des commandes avant et après l'installation, BIOS et firmware à vérifier à la main.
- Le profil Fedora 45 reste `pending` tant que l'ISO finale n'est pas promue avec `scripts/development/promote-fedora45.py`.

## 0.22.1 — Fedora 45 / GNOME 51 : remplaçants des extensions sans build GNOME 51

- DING, Show Desktop Plus et Resource Monitor ne publiaient aucun build GNOME 51 : le profil Fedora 45 (`profiles/fedora45/gnome-extensions.lock`) les remplace par **Gtk4 Desktop Icons NG** (smedius, v145), **Show Desktop Button** (amivaleo, v59) et **Vitals** (corecoding, v85), et épingle **Tiling Assistant v56**. SHA256, review et compatibilité GNOME 51 ont été relevés par la CI sur le store, pas saisis à la main.
- Les préfixes `DING_*`, `SHOW_DESKTOP_PLUS_*`, `RESOURCE_MONITOR_*` restent des noms de rôle : l'installateur, la mise à niveau et les gardes gardent un seul chemin de code. Le module `24_gnome_extensions.sh` et `24b_resource_monitor.sh` choisissent la configuration d'après l'UUID du verrou (indicateur `LEFT_END` + raccourci Super+D pour Show Desktop Button ; capteurs `_processor_usage_`, `_memory_usage_`, réseau pour Vitals). Le comportement Fedora 44 est inchangé.
- `fedora-profile.py` n'accepte, pour ces trois rôles, que l'identité d'origine ou son remplaçant revu, avec UUID et schéma cohérents ; toute autre identité est refusée.
- Outil de readiness : vérifie l'archive **réellement épinglée** (téléchargement, SHA256, UUID, major 51) et signale si l'ancien DING obtient un build natif GNOME 51. Le COPR de Sunshine est activé pour la résolution des paquets (faux blocage « Sunshine » supprimé).
- Test `test_extension_variants_behavior.sh` (faux `gsettings`) ; la fixture de promotion de `test_fedora_release_behavior.sh` utilise le vrai verrou 45.
- Nouveau `scripts/development/promote-fedora45.py` : promeut le profil Fedora 45 depuis l'ISO finale et son CHECKSUM signé (clé épinglée), écrit le verrou média et `profile.json` avec les vraies empreintes, relance le validateur et restaure les fichiers au moindre refus. Test `test_promote_fedora45_behavior.sh` avec de vraies signatures GPG.
- Nouveau workflow informatif `fedora45-package-preflight.yml` (conteneur Fedora 45) : manifestes, RPM Fusion 45, espace utilisateur Intel Arc (Vulkan ANV, VA-API), échanges ffmpeg/intel-media-driver, dépôts éditeurs, Flathub, contrat GTK4, RPM Linux amont `fc45` et archives GNOME 51. `upstream-kernel.yml` accepte une version Fedora en entrée (44 par défaut).
- Diagnostics et gates : le numéro de Fedora affiché est celui de la machine, plus un « 44 » figé.
- Limite connue : Vitals ne garantit pas la charge de l'Arc B580 dans la barre du haut ; les sources `xe` restent contrôlées comme santé matérielle. Le profil Fedora 45 reste **pending** : média final, qualification et preuves manquent encore.

## 0.22.0 — Accès distant (profil optionnel)

- Nouveau profil **`REMOTE_*`**, désactivé par défaut : Tailscale, SSH par clés uniquement, Wake-on-LAN (profil NetworkManager) et Sunshine en option. Cinq modules (`remote.*`), `diagnostics/remote-doctor`, route `./control.sh remote status|info`. Guide `docs/REMOTE_ACCESS.md` (analyse du cahier des charges, limites, alternatives, qualification Gate 3) et [ADR 0017](docs/adr/0017-remote-access.md).
- Le préflight refuse d'agir sans clé publique dans `authorized_keys`, avec SELinux non Enforcing, avec un port invalide ou avec le port 47990 (interface web de Sunshine). La configuration SSH est validée par `sshd -t` et retirée en cas d'échec.
- Le garde-fou KVM accepte `KVM_EXTRA_PROTECTED_CIDRS` : le profil protège `100.64.0.0/10` (Tailscale) des VM sans attendre un événement NetworkManager. Test `test_remote_kvm_guard_behavior.sh`.
- `scripts/remote/wol-send.py` (relais Wake-on-LAN, bibliothèque standard) et `scripts/remote/gdm_autologin.py` (connexion automatique GDM, idempotent).
- Rien ne change tant que `REMOTE_ENABLE` reste à `false`. Le réveil depuis un arrêt complet, le streaming et l'AV1 restent des mesures du Gate 3.

## 0.21.8 — README cohérent avec la vision

- Le README présentait « 6 piliers Golden » alors que la vision en définit **quatre, d'importance égale**. Il affiche désormais les quatre piliers avec leur guide d'entrée ; l'ancien tableau devient « le socle technique ».
- La section sur l'intégration du bureau et des périphériques, ajoutée en toute fin de fichier après la certification, rejoint la partie bureau, juste après la finition GNOME.
- La section « Mises à jour » mentionne le report du seul noyau quand son paquet n'est pas encore publié ; la table de documentation pointe vers la vision et les nouveaux guides d'entrée ; le bandeau d'état passe sous le titre.
- Documentation uniquement : aucun code ni comportement modifié.

## 0.21.7 — Documentation entièrement en français et à jour

- `GOLDEN_COMPLETENESS_CLOSURE.md`, seul document encore en anglais, est traduit en français ; commandes et contrats inchangés.
- Mentions périmées d'une VM Ubuntu corrigées (le labo est Rocky Linux depuis la 0.21) : la Gate 3 exige le domaine `rocky-devops`, la certification KVM teste Rocky, et `NAUTILUS.md`, `QUALIFICATION_EVIDENCE_TEMPLATE.md`, `VIRTUALIZATION_CLI.md` et `DOCUMENTATION_MODEL.md` parlent désormais de la bonne VM.
- Documentation uniquement : aucun code ni comportement modifié.

## 0.21.6 — Guides d'entrée « certification » et « virtualisation »

- Nouveau `docs/CERTIFICATION.md` : le parcours de preuve dans l'ordre (CI → Gate 1 → Gate 2 → baseline → installation → Gate 3 → version figée), ce que prouve chaque étape et son document, plus les documents de référence. Les principaux documents de certification renvoient vers ce guide.
- `docs/KVM_QUICKSTART.md` devient le guide d'entrée de la virtualisation, avec une carte de tous les documents KVM (architecture, réseau, profils, labo Rocky, fichiers des VM, ligne de commande, dépannage).
- Portail et vision mis à jour. Documentation uniquement : aucun code ni comportement modifié.

## 0.21.5 — Guide d'entrée du bureau GNOME

- Nouveau `docs/GNOME.md` : porte d'entrée du pilier « finition GNOME façon Ubuntu ». Il explique ce que le bureau apporte, associe chaque brique (profil, extensions, finition, dock, Nautilus, terminal, barre système, applications, intégration, usage quotidien, matériel, preuves) à son document de détail, et regroupe les diagnostics et la personnalisation.
- Contradictions corrigées : `GNOME_PROFILE.md` et `GNOME_INTEGRATION.md` disaient que le projet ne cherchait pas à reproduire Ubuntu, alors que la vision et l'ADR 0013 visent la finition d'Ubuntu (sans son thème Yaru). Le texte dit désormais exactement cela.
- Le portail, la vision et les principaux documents du bureau renvoient vers ce guide.
- Documentation uniquement : aucun code ni comportement modifié.

## 0.21.4 — Le projet réaligné sur son intention

- Nouveau `docs/VISION.md` : pourquoi le projet existe (Fedora + GNOME comme OS principal, la plus récente, la plus finie, la plus réactive, reproductible), ses **quatre piliers d'importance égale** (finition GNOME façon Ubuntu, performance et réactivité, fiabilité et sauvegardes, outils DevOps), le matériel cible complet et les décisions du propriétaire (aucun chiffrement, BIOS 1.A66 minimum, noyau officiel, labo Rocky, Secure Boot désactivé).
- `CAHIER_DES_CHARGES.md` : la finalité décrit enfin le projet voulu ; ajout de la section **finition GNOME façon Ubuntu** (absente jusque-là alors que le code l'applique) et du matériel manquant (écran QD-OLED, réseau, audio, webcam, disque de sauvegarde, BIOS minimum).
- ADR 0012 (CachyOS) marquée « remplacée par ADR 0015 » : elle se présentait encore comme acceptée.
- L'audit daté du 27 septembre, dont les exigences sont satisfaites, rejoint `docs/history/` ; le README et le portail pointent vers la vision.
- Documentation uniquement : aucun code ni comportement modifié.

## 0.21.3 — Guide pratique Gate 2

- Nouveau `docs/GATE2_GUIDE_PAS_A_PAS.md` : Gate 1 puis Gate 2 depuis Windows 11, pas à pas — installation de Fedora 44 dans WSL2 (`wsl --install FedoraLinux-44`), réglages conseillés de la VM VirtualBox, dossier partagé pour faire passer les preuves, checklist visuelle à cocher, signature, export et tableau de dépannage. La procédure normative reste `THREE_GATE_VALIDATION.md` et `VIRTUALBOX_GNOME_LAB.md`, qui renvoient désormais vers ce guide.
- Documentation uniquement : aucun code ni comportement modifié.

## 0.21.2 — rétention déterministe des archives refusées

- Correctif trouvé par la CI de `main` (Fedora, Borg 1.4.5) : `borg prune --keep-last` est un alias de `--keep-secondly` et ne garde qu'une archive par seconde. Des archives refusées créées dans la même seconde étaient donc supprimées de façon imprévisible, d'où un échec intermittent. La purge des `fgc-pending-*` trie désormais les noms (horodatage UTC à la nanoseconde) et supprime exactement tout sauf les `BACKUP_KEEP_PENDING` plus récentes.
- Test rejoué 3 fois avec Borg 1.2.8 et 3 fois avec Borg 1.4.5 (binaire officiel) : PASS.

## 0.21.1 — Audit du 6 octobre 2026

- **Mises à jour non bloquées par le noyau** : quand kernel.org est injoignable ou que le RPM du dernier noyau stable n'est pas encore publié, la mise à jour système reporte **uniquement le noyau** (exclu de la transaction DNF, noyau courant conservé) et applique toutes les autres mises à jour, sécurité comprise. Avant, toute la mise à jour s'arrêtait. Nouveau code `EXIT_KERNEL_DEFERRED=75`, état `kernel_deferred`, bilan final explicite, réglage `KERNEL_DEFER_WHEN_UNAVAILABLE` (défaut `true`). Toute autre erreur noyau bloque toujours. Test comportemental sur le vrai script, contrôlé par mutation.
- **Sauvegardes quotidiennes fiables pendant la session** : reproduit avec un vrai Borg, un fichier modifié pendant sa lecture (profil de navigateur, Flatpak) faisait échouer chaque sauvegarde quotidienne. Seul cet avertissement exact est désormais toléré, et seulement pour `daily` ; pré-APPLY et sauvegarde complète restent strictes ; tout autre avertissement refuse l'archive. Le nombre de fichiers concernés est enregistré et affiché.
- **Archives refusées bornées** : les `fgc-pending-*` n'étaient jamais supprimées ni signalées ; la rétention n'en garde plus que les plus récentes (`BACKUP_KEEP_PENDING`, 3) et les diagnostics les signalent.
- Test de certification de sauvegarde rendu indépendant de la place libre de la machine qui l'exécute.

## Corrections de finition — changements après RC2

- Diagnostics des portails : invalidation des preuves interactives avant les préchecks de session et de services ; une tentative échouée ne laisse pas un ancien PASS actif.
- Tests de comportement sur les échecs précoces Gate 2/Gate 3, avec préservation des preuves lors d'une consultation seule.
- Guides GNOME et tests documentaires alignés sur les six extensions du profil canonique et sur le dock OLED réellement configuré.
- README, gouvernance CI, guide du laboratoire et ADR Borg nettoyés ; les textes historiques restent historiques.

## Intégration desktop — changements après RC2

- Politique GNOME Logiciels verrouillée et vérifiée, cohérente avec les mises à jour système sauvegardées et les Flatpak manuels.
- GNOME Disques et Flatseal explicites ; distinction entre smoke de paquets et qualification des usages réels.
- Six extensions actives exercées dans le laboratoire Wayland Fedora 44 ; aller-retour documentaire LibreOffice.
- Laboratoire Fedora 45/GNOME 51 natif sur média Beta signé et épinglé, avec reboot/restauration ; extensions personnalisées explicitement différées, profil de production toujours pending.
- Identités distinctes pour audio Realtek de la carte mère et Brio 100, résolution après reboot, capture 1080p et microphone explicite ; exigences Wi-Fi vérifiées sur le contrôleur enrôlé.
- ScreenCast/Camera : autorisation et images PipeWire réelles exigées, annulation refusée, flux fermés et aucune image conservée.
- Afficheur LD240 communautaire en option, artefact épinglé, service utilisateur et permissions USB limitées ; aucun réglage de pompe/ventilateur modifié.
- Documentation et fiche physique actualisées ; aucune validation matérielle fictive.

## 0.21.0 — Rocky Linux 10.2 DevOps

### RC2 — Qualification réseau et garde-fous physiques

- Réseau Docker local exercé avant/après reboot et après restauration : DNS, HTTP inter-conteneurs, publication localhost, image en cache et nettoyage vérifié.
- Charges CPU/RAM/GPU : durées minimales et écoulées contrôlées, zéro instance refusée, workers arrêtés sur échec/interruption ; arrêt CPU dès perte de capteur ou dépassement thermique.
- Une nouvelle charge invalide sa preuve et la certification courante avant toute mesure ; un échec ne conserve pas un ancien PASS.
- Preuves de charge qualification_policy=2 : anciennes preuves sans mesures désormais refusées ; fiche d'exécution physique et formulaire Rocky alignés.
- Docker stable conservé : avertissements EL10 toujours visibles ; aucun backend nftables expérimental imposé et aucune certification matérielle simulée.

### RC1 — Migration Rocky

- Remplacement du profil Ubuntu par rocky-devops (Rocky Linux 10.2 x86_64), commandes, diagnostics et documentation alignés.
- Image GenericCloud versionnée, signature de production Rocky 10 épinglée, checksum unique et authentifié avant création.
- Bootstrap RPM/DNF natif EL10 : CRB/EPEL, Docker, GitHub, HashiCorp, Microsoft, Kubernetes ; SELinux Enforcing et SSH par clé.
- Chaîne DevOps conservée, Node ≥22, OpenJDK 21, Python/venv/pipx, Helm v4.3.0 ; aucun repli Debian ou EL9.
- Laboratoire Rocky obligatoire : Q35/UEFI, vrai redémarrage, sauvegarde Borg sans chiffrement à froid, suppression des sources et démarrage restauré.
- Ancienne VM préservée : remplacement par création séparée et transfert des données, aucune conversion destructive.


## 0.20.0 — Linux amont et préparation Fedora 45

- Retrait du noyau personnalisé et de ses réglages CPU/SELinux : canal Vanilla unique, dernière stable comparée à kernel.org, RC/linux-next/RPM obsolètes refusés.
- Rétention N/N-1 sur kernel-core ; sources officielles signées récupérables, sans prétendre qu'un téléchargement constitue une installation.
- Profils Fedora 44/50 et transition Fedora 45/51 avec blocage du futur profil tant que média final, archives GNOME 51 et preuves ne sont pas promus.
- Préparation et finalisation DNF5 system-upgrade avec sauvegarde Borg complète des VM arrêtées, identité commit/config et contrôle du boot réel.
- CI preview Fedora 45, inspection des archives d'extensions et rapports de dépendances explicites ; candidats distincts des verrous actifs.
- Contrôle de la clé Fedora et du couple nom/hash du CHECKSUM signé ; installation neuve paramétrée par release.
- Documentation, README, ADR et tests alignés. Qualification physique et promotion Fedora 45 restent à réaliser.


## 0.19.1 — 2026-10-01

- Laboratoire Fedora 44/GNOME 50 sur runner GitHub : image signée et verrouillée, session Wayland réelle, extensions épinglées, Nautilus/Ptyxis et redémarrage avec identifiant de boot distinct.
- Reprise isolée d'une VM QEMU sauvegardée à froid par le vrai Borg non chiffré : disque autonome, NVRAM et état swtpm comparés, démarrage en réseau restrict=on et canary TPM NV persistant.
- Reconstruction depuis une seconde image Fedora neuve avec réinstallation GNOME, extraction de l'archive de fichiers exacte en staging et contrôle contenu/modes/liens.
- Le contexte obligatoire contracts vérifie explicitement, même après un échec, que tous les jobs ont réussi ; les skips/annulations ne peuvent devenir un succès requis. La suite rapide démarre sans attendre les VM. Il attend le laboratoire ; les rapports conservent journaux et états DEFERRED pour les gates officielles, APPLY de production, CachyOS et Windows.
- Guides alignés sur CachyOS BORE, couverture des disques VM et runbook de reprise isolée. La qualification visuelle VirtualBox et matérielle reste à exécuter.

## 0.19.0 — 2026-10-01

- Journaux noyau : lecture complète avant recherche ; erreur de lecture, journal vide et erreur de recherche bloquent les PASS CPU/NVMe/GPU/veille/USB.
- Borg reste sans chiffrement. Tout avertissement de création bloque le succès ; une tentative quotidienne échouée invalide le précédent marker et expose son échec au diagnostic.
- Pré-APPLY et backup complet vérifient l'archive exacte. Le backup complet restaure son canary et enregistre une preuve atomique liée au commit, à la configuration, au matériel et au dépôt. La certification réouvre l'archive et son manifeste.
- Reprise OS/VM basée exclusivement sur une archive complète avec manifeste de récupération, commit et couverture VM explicites. Contrôle d'espace avant la capture système, les disques VM et l'écriture au dépôt ; option `--staging-root`.
- Le check obligatoire `contracts` dépend désormais de l'audit Fedora et du roundtrip Borg Fedora 44. L'audit refuse les blocages inattendus ; la publication attend les workflows réussis du SHA exact sur main.
- Nouveaux tests de journaux, certification/restauration/capacité et portes CI ; documentation de la qualification GNOME, récupération isolée et matériel encore à réaliser sur machine.


## 0.18.1 — 2026-09-27

- **Porte d'APPLY testée par son comportement** : nouveau `tests/test_apply_gate_behavior.sh`, exécuté dans un vrai pseudo-terminal. Chaque condition bloque seule, avec son propre message (runtime non bare-metal, fonction désactivée, machine non approuvée, Git modifié, baseline absente, archive Borg pré-APPLY absente, absence de terminal). La preuve de dry-run est vérifiée avec la vraie bibliothèque de preuves : un changement de commit, de configuration ou de matériel la rend caduque. Seule la phrase exacte ouvre la porte.
- Qualité du test prouvée par mutation : supprimer la vérification du terminal, celle de la sauvegarde, celle de la phrase de confirmation ou celle de l'empreinte de configuration fait échouer le test.

## 0.18.0 — 2026-09-27

- **Sauvegardes sans chiffrement, par décision du propriétaire** (ADR 0014) : Restic chiffre toujours ses dépôts et ne pouvait pas respecter cette exigence. Le moteur devient **Borg 1.x** (`borgbackup`, 1.4 sur Fedora 44) avec un dépôt `--encryption=none`. Un dépôt chiffré est désormais **refusé** par la politique.
- Moteur centralisé : tous les appels Borg passent par `backup_engine_*` dans `lib/backup_runtime.sh` (environnement, création, dernière archive, correspondance exacte, contrôle, extraction, rétention, compactage). Archives `fgc-preapply-*`, `fgc-full-*`, `fgc-daily-*`.
- Pré-APPLY : création confirmée du dépôt, archive relue intégralement (`borg check --verify-data`), canary réellement extrait et comparé ; le marker enregistre nom **et** identifiant de l'archive, revérifiés avec le type attendu au moment de l'APPLY.
- Rétention `borg prune` par classe (`full`, `daily`) puis un seul `borg compact` ; les archives pré-APPLY ne sont jamais supprimées automatiquement. Timer renommé `fedora-gnome-backup-retention` ; les anciennes unités Restic sont désactivées et supprimées par l'APPLY.
- Correctif trouvé en testant : sur un dépôt chiffré, Borg attendait indéfiniment une passphrase. Une passphrase vide explicite le fait échouer immédiatement ; une `BORG_PASSPHRASE` ambiante n'atteint jamais Borg.
- Avertissements Borg (code 1, fichier modifié pendant la lecture) signalés sans invalider l'archive ; codes ≥ 2 = échec.
- Configuration : `BACKUP_ENGINE="borg"`, `BACKUP_ENCRYPTION="none"`, clés `BACKUP_KEEP_*` et `BACKUP_RETENTION_*` ; plus aucun fichier de passphrase. Restauration par nom d'archive (ou `latest`), nom malformé refusé.
- Nouveau test réel `tests/test_borg_roundtrip.sh` (runtime installé, `--verify-data`, permissions, lien symbolique, exclusion des secrets, rétention, preuve pré-APPLY exacte, refus d'un dépôt chiffré) ; garde-fous de tests adaptés à Borg.
- Documentation : ADR 0014, guide de sauvegarde réécrit, une vingtaine de documents alignés ; ADR 0002/0009/0011/0012 annotées.

## 0.17.0 — 2026-09-27 (audit croisé)

Version de consolidation : intègre les PR #69 et #71, corrige leurs échecs de CI et leurs interactions, et ajoute une relecture indépendante. Détail et preuves : `docs/AUDIT_RUNTIME_2026-09-27.md`.

Moteur (PR #71, relu et conservé) :

- **Correctif critique** : une phase de module appelée dans un `if` désactivait `set -e` ; une commande pouvait échouer en plein APPLY sans faire échouer le module. Chaque module tourne désormais dans son propre processus Bash strict (`scripts/engine/run-module.sh`) ; un `exit 0` prématuré est un échec.
- Verrou d'installation par utilisateur ; `--dry-run --collect-all` visite les 72 modules sans jamais émettre de preuve d'APPLY ; CI « Fedora 44 installer audit ».
- Références des extensions GNOME centralisées dans `config/gnome-extensions.lock` (constantes non surchargeables dans `local.conf`) et installateur unique ; compatibilité GNOME validée sur le champ `shell-version` réel (plus de faux positif « 50 n'importe où »).
- Lecture complète des journaux noyau avant recherche d'erreurs CPU/NVMe (plus de faux « aucune erreur » par SIGPIPE ou journal illisible) ; manifestes de paquets manquants refusés ; restaurations confinées à la zone de staging.

Consolidation et relecture :

- CI de la PR #71 réparée : `non-regression.yml` cherchait encore des clés déplacées dans le lock ; le conteneur Fedora refusait Git (*dubious ownership*), ce qui faisait échouer `backup.daily` — reproduit puis corrigé (`safe.directory`).
- Fusion de la PR #69 : 8 conflits résolus. Lanceur de #71 conservé (celui de #69 relançait tout le démarrage pour chaque module et dispersait les journaux) ; protections d'erreur de #69 intégrées au canal noyau CachyOS.
- Interaction corrigée : le confinement des restaurations (#71) cassait le test Restic réel de #69.
- Verrou étendu à la mise à jour, au cycle de vie noyau (sauf `status`), au pré-APPLY et aux sauvegardes ; réentrance réservée aux vrais descendants du détenteur (un PID copié ou forgé est refusé).
- Postchecks mémoire et veille : ne renvoient plus un échec quand une information facultative est illisible. La vitesse RAM configurée est comparée aux **6000 MT/s** du kit (avertissement si le profil EXPO/XMP est désactivé).

PR #69 — fiabilité après audit :

- Correction des faux PASS du moteur, prérequis manquants, sorties noyau et preuves périmées.
- Sauvegarde liée à la configuration, restauration vérifiée et couverture NVRAM/TPM.
- Identification PCI, fio non privilégié, réseau par interface et disque Kickstart stable.
- Reprise écran préservant la disposition et HDR ; nouveaux tests comportementaux et Restic réel.
- Parcours d’installation vierge et qualification physique explicitement distincts des preuves CI.

## 0.16.0 — 2026-09-26

- **Vrai noyau CachyOS** : nouveau canal `KERNEL_CHANNEL="cachyos"` (défaut Golden) basé sur le COPR officiel `bieszczaders/kernel-cachyos` (BORE, sched_ext, x86-64-v3). Le canal `vanilla` reste disponible. Jusqu'ici la couche « Fedora-Cachy » ne faisait que du réglage runtime : le noyau restait Kernel Vanilla (ADR 0012).
- Garde-fous CachyOS avant toute mutation : CPU `x86-64-v3` prouvé par le chargeur dynamique, accord explicite `KERNEL_CACHYOS_SELINUX_MODULE_LOAD` pour `domain_kernel_load_modules`, motif de dépôt excluant `-addons`/`-lto`/`-lts`/`-rc`.
- Le `kernel-core` Fedora reste installé comme entrée de secours ; `rollback-to-fedora.sh` désactive aussi le COPR CachyOS et remet un noyau Fedora par défaut.
- kernel-doctor, politique GRUB, Control Center et état `rolling.env` indiquent le canal actif. Correction du défaut affiché `Fedora fallback true` alors que la politique est `false`.
- **Finition « Ubuntu-grade »** : nouveau module `gnome.polish` et `config/gnome-polish.conf` — dock Ubuntu (gauche, pleine hauteur, focus/réduire/aperçus), démarrage sur le bureau, accent, jour dans l'horloge, fenêtres centrées, `adw-gtk3` avec suivi clair/sombre automatique, Tiling Assistant v55 épinglé par URL GitHub et SHA-256 (ADR 0013).
- Nouveau `diagnostics/polish-doctor`, intégré au workstation doctor et à `./control.sh doctor polish` ; APPLY, postcheck et doctor partagent une seule table d'état désiré.
- **Tests comportementaux** : `test_kernel_channel_behavior.sh` et `test_gnome_polish_behavior.sh` exécutent le vrai code contre de faux `dnf5`/`rpm`/`gsettings` au lieu de chercher du texte. Ils ont révélé un bug réel : la détection `x86-64-v3` pouvait échouer aléatoirement (`grep -q` + `pipefail` → SIGPIPE).
- Garde-fou CI : tout `tests/test_*.sh` doit être exécuté par un workflow.
- Schéma de configuration : énumérations ajoutées pour le canal noyau, l'accent, la position et le clic du dock.
- **Correctif critique** : trois modules applicatifs (`applications.professional`, `applications.appimage`, `applications.dock_favorites`) définissaient des fonctions dont le nom ne correspondait pas au contrat de l'orchestrateur ; le premier APPLY réel se serait arrêté sur « contract missing ». Nouveau test `test_module_catalog_behavior.sh` qui source chaque module du catalogue réel.
- **Soin de l'écran QD-OLED** (fiche matérielle) : dock en *intellihide*, style sombre appliqué une seule fois (le choix clair/sombre de l'utilisateur n'est jamais réimposé ni signalé comme dérive), assombrissement puis veille écran à 5 min ; lissage de police en niveaux de gris confirmé.
- Documentation du disque de sauvegarde XS1000 comme cible Restic externe (ext4 requis).
- **Préparation Fedora 45 / GNOME 51** : nouvel outil lecture seule `scripts/development/release-readiness.sh` (COPR noyaux, extensions GNOME, Tiling Assistant, paquets Fedora ; `--pin` produit les lignes SHA-256 prêtes à copier), rapport CI hebdomadaire, test comportemental et runbook `docs/UPGRADE_FEDORA_45.md`. Aucune bascule tant que Fedora 45 n'est pas finale et que tous les composants ne sont pas `READY`.
- Documentation : les comptes rendus d'étapes passées (`PRE1_HARDENING`, `INDUSTRIAL_READINESS`, `HARDWARE_KVM_COMPLETION`) sont rangés dans `docs/history/`, non normatifs.
- Passage du projet à **0.16.0** et préparation de la prerelease `v0.16.0-rc.1`.

## 0.15.0 — 2026-09-19

- **Fedora-Cachy coherence closure** : promotion de la couche performance en socle opérateur de première classe, sans modifier les garde-fous Fedora/GNOME/SELinux/KVM.
- Ajout d'un menu interactif **Performance Fedora-Cachy** au Workstation Control Center et d'un état performance visible dans le tableau de bord.
- Le profil performance conserve AMD P-State/EPP, TuneD/tuned-ppd, zram Fedora, GameMode dynamique, SCX fail-safe et le benchmark T705 borné ; aucun tuning global expérimental n'est activé par défaut.
- `performance-doctor --certify` exige le profil Golden normal avant une certification finale et conserve SCX en capacité optionnelle tant que le smoke test bare-metal n'a pas réussi.
- La certification Gate 3 et son contrôle live intègrent désormais explicitement le contrat performance ; un drift performance invalide l'état runtime Golden.
- Les cycles suspend/resume revalident le socle CPU/TuneD afin de détecter une dérive de politique d'alimentation après reprise.
- Le bundle Golden embarque désormais `performance-runtime.policy`, son SHA-256 et un bloc `performance_runtime` dans `golden-release.json`.
- Le tableau de bord valide également `effective_config_sha256` et `module_plan_sha256`, évitant d'afficher une ancienne certification comme valide après une modification de configuration ou de politique.
- Documentation, Control Center, contrats CI, release manifest et version projet sont réalignés sur la même surface Fedora + finition workstation + performance mesurée.
- Passage du projet à **0.15.0** et préparation de la prerelease `v0.15.0-rc.1`.
## 0.14.0 — 2026-09-03

- **Final Hardening / Release Candidate** : fermeture des écarts pré-1.0 sans ajout d'un nouveau socle fonctionnel.
- Runtime fail-closed : un environnement dont le bare-metal n'est pas positivement prouvé devient `unknown` et ne peut pas ouvrir l'APPLY.
- Orchestrateur durci : chaque module doit fournir `precheck`, `plan`, `apply` et `postcheck`; un APPLY en échec conserve son code retour et produit un rapport durable de convergence partielle.
- Correction Arc B580/VA-API : le render node est résolu par PCI `8086:e20b` au lieu de supposer `/dev/dri/renderD128` sur un HOST multi-GPU.
- Nautilus est séparé du GNOME core et complété par un manifeste dédié : GVfs archive/AFC/GOA/NFS, SMB/MTP déclaratifs, Sushi et `file-roller-nautilus`.
- Ajout de `nautilus-integration-doctor`, distinct du benchmark cold-start, intégré au postcheck, au workstation doctor et à la certification finale.
- Les flags `NAUTILUS_ENABLE_SMB`, `NAUTILUS_ENABLE_MTP` et `NAUTILUS_ENABLE_PREVIEWS` pilotent désormais réellement la convergence attendue.
- Le workaround historique `ibus-typing-booster` est déplacé hors de Nautilus et désactivé par défaut ; il reste un escape hatch explicite dans l'intégration desktop.
- Ajout de `ptyxis-doctor` afin de certifier séparément le terminal Fedora natif et la couche Bash ; Toolbx reste hors du HOST Golden par défaut.
- Ajout du workflow **Fedora 44 desktop integration pretest** pour installer et valider réellement Nautilus/GVfs/Sushi/File Roller/Ptyxis dans Fedora 44.
- Le contrôle `check-main-protection.sh` valide désormais le ruleset effectif, le ciblage de `main`, les required checks et la politique merge-only au lieu de se fier au seul booléen legacy `branch.protected`.
- DING review `74408`, Show Desktop Plus review `70326` et Resource Monitor review `70909` sont vérifiés par SHA-256 exact avant installation.
- Backup quotidien et rétention Restic exécutés depuis un bundle autonome versionné par SHA et vérifié par manifeste; timer hebdomadaire 7 daily / 4 weekly / 6 monthly sur les snapshots `full` et `daily`.
- Kickstart : serveur `sshd` HOST désactivé, `openssh-clients` conservé pour les connexions HOST → VM.
- Guard KVM étendu aux routes IPv4 non-default du HOST afin de bloquer LAN, VPN, réseaux d'entreprise et tunnels routés tout en conservant la sortie Internet via la route par défaut.
- Les Flatpaks `community-unverified` doivent être présents dans une allowlist versionnée explicite.
- Service KVM nftables renforcé avec sandbox systemd et capacités réseau bornées.
- Choix Golden confirmés : pas de LUKS imposé, pas de Secure Boot HOST, `kernel-vanilla/stable` latest-stable avec kernels Fedora conservés comme fallback.
- Ajout de `SECURITY.md`, `CODEOWNERS`, d'un template de PR et de contrats comportementaux supplémentaires pour le hardening.
- Ajout d'un schéma de configuration strict, validé avant sourcing, avec refus des clés inconnues, types invalides, doublons et syntaxe exécutable.
- Préparation de la prerelease GitHub `v0.14.0-rc.1` via manifeste et workflow idempotent; politique de dépôt cible: merge commit unique et suppression automatique des branches fusionnées.
- Documentation synchronisée avec Nautilus/Ptyxis, Resource Monitor, la supply-chain GNOME, la rétention Restic et la portée LAN/VPN du guard KVM.

## 0.13.0 — 2026-09-01

- Ajout du **Workstation Control Center** avec `control.sh` comme point d'entrée opérateur recommandé et `menu.sh` conservé comme alias de compatibilité.
- Remplacement du menu plat historique par neuf socles lisibles : Installation & convergence, Mises à jour, Sauvegarde & restauration, Diagnostics & santé, Kernel & boot, KVM / machines virtuelles, Maintenance, Certification, Logs & preuves.
- Ajout d'un tableau de bord terminal affichant version, Fedora, runtime, kernel actif, politique `kernel-vanilla/stable latest-stable`, Arc B580/driver, état Git, backup, certification, KVM et besoin de reboot.
- Ajout d'une présentation ANSI limitée aux vrais TTY avec support `NO_COLOR=1`; aucune dépendance TUI externe n'est introduite.
- Ajout d'un mode CLI scriptable (`control.sh install|update|backup|doctor|kernel|kvm|cert|logs`) conservant les codes de retour des moteurs appelés.
- La couche UI reste volontairement mince : aucune logique `apply_gate_open`, Restic, DNF, Flatpak ou nftables n'est dupliquée dans `control.sh`/`lib/control_center.sh`.
- Ajout de `scripts/maintenance/update-system.sh` pour les mises à jour quotidiennes structurées.
- La mise à jour complète sécurisée exige un runtime bare-metal, réalise un backup Restic complet et son contrôle d'intégrité avant `dnf upgrade --refresh`, met ensuite à jour les Flatpaks, consulte fwupd en lecture seule puis exécute le diagnostic global et indique le besoin de reboot.
- Le firmware n'est **jamais flashé automatiquement** par le nouvel updater ; seule `fwupdmgr get-updates` est utilisée dans le parcours automatisé.
- La politique kernel reste inchangée : `kernel-vanilla/stable` suit la dernière stable upstream, plancher actuel `7.2.2`, kernel Fedora conservé comme fallback ; aucune branche `mainline`, `-rc` ou `linux-next` n'entre dans le Golden.
- Ajout de `docs/CONTROL_CENTER.md`, mise à jour du portail documentaire et du README pour faire du cockpit l'interface opérateur principale.
- Ajout de `tests/test_workstation_control_center_contract.sh` et extension des contrats entrypoints/documentation afin d'empêcher toute régression vers un cockpit monolithique ou un contournement des moteurs protégés.

## 0.12.0 — 2026-09-01

- Ajout de **Desktop Icons NG (DING)** au profil fonctionnel Golden depuis l'artefact GNOME Extensions review `74408` / version de site `95`, UUID `ding@rastersoft.com`, déclaré compatible GNOME Shell 50.
- Fedora 44 ne fournit pas DING dans le manifest RPM du projet ; l'installateur dédié valide l'URL pinée, l'UUID, la compatibilité GNOME 50, compile le schéma GSettings et enregistre la provenance.
- Le dossier XDG Desktop est convergé vers `~/Bureau` ; son contenu devient visible sur le fond d'écran GNOME.
- La **Corbeille** est affichée sur le bureau ; Home, volumes externes et volumes réseau sont masqués par défaut afin de garder une surface de travail propre.
- Ajout de **Show Desktop Plus** depuis l'artefact GNOME Extensions review `70326` / version de site `8`, déclaré compatible GNOME Shell 50 ; l'installateur valide l'UUID et la compatibilité avant installation et enregistre la provenance.
- Show Desktop Plus est configuré en `left-end` dans la barre supérieure, clic gauche `toggle-desktop`, `Super+D` activé, badge de fenêtres désactivé et comportement par workspace conservé.
- `gnome-doctor` certifie désormais DING, `~/Bureau`, la Corbeille, la provenance des deux extensions utilisateur et les réglages du bouton/raccourci.
- Ajout de `xdg-user-dirs` et `unzip` aux dépendances gérées requises par cette ergonomie.
- Le Fedora package preflight valide les deux artefacts GNOME-reviewed DING/Show Desktop Plus ; le Fedora host pretest les installe dans un utilisateur de test, compile leurs schémas et converge les GSettings.
- Ajout du contrat CI `test_desktop_ergonomics_contract.sh` et maintien d'exceptions externes étroites limitées aux deux installateurs GNOME-reviewed pinés.
- Ajout du **LAB GNOME VirtualBox fail-closed** : `scripts/lab/apply-gnome-virtualbox.sh` exige Fedora 44, GNOME Shell 50/Wayland et une identité VirtualBox concordante (`systemd-detect-virt=oracle` + DMI), puis ne converge que les boutons de fenêtres, DING et Show Desktop Plus.
- Ajout de `diagnostics/virtualbox-gnome-lab-doctor` et `tests/test_virtualbox_gnome_lab_contract.sh`; le doctor confirme aussi que `install.sh --apply` et la baseline hardware restent interdits/invalides en VirtualBox.
- La validation graphique finale DING + Show Desktop est explicitement réalisée au GATE 2 GNOME/VirtualBox puis confirmée bare-metal ; aucune preuve graphique n'est simulée en CI.

## 0.11.0 — 2026-08-31

- Refonte de la documentation opérateur : ajout de `docs/README.md` comme portail, `docs/GLOSSARY.md`, `docs/KVM_QUICKSTART.md` et `docs/KVM_NETWORK.md`.
- Transformation de `docs/TROUBLESHOOTING.md` en vrai runbook par symptôme couvrant APPLY, DNF/repos, Flatpak, codecs, GNOME/portals, Arc B580, veille/affichage, KVM/libvirt, `/data`, `devops-nat`, Ubuntu/Windows et Restic.
- Documents normatifs rendus version-neutral et reliés à `VERSION` afin d'éviter les références actives 0.8/0.9 devenues ambiguës ; les numéros historiques restent dans les release notes/changelog.
- Correction de la documentation GNOME : Dash to Dock **et AppIndicator** sont les deux extensions fonctionnelles gérées ; Blur My Shell reste hors de l'état Golden certifié.
- Suppression des anciennes commandes `baseline-doctor record-*` de la documentation WSL2.
- Ajout de draw.io au catalogue documentaire professionnel et clarification de la révision 1.7 du cahier des charges par rapport au numéro de release.
- Nettoyage de `GITHUB_GOVERNANCE.md` : suppression des limitations propres à un connector/outillage particulier et ajout d'un contrat documentaire public.
- Réseau KVM rendu réellement **fail-closed lors d'un changement de connectivité** : le dispatcher NetworkManager installe désormais un guard d'urgence synchronement avant tout reconcile ; si la redécouverte/validation du nouvel uplink échoue, le forwarding via `virbr50` reste bloqué.
- `fedora-gnome-custom-kvm-guard.service` utilise `reconcile` au start/reload avec retry `Restart=on-failure`; suppression du reload asynchrone `--no-block` et du `|| true` qui pouvait masquer un échec.
- `runtime_certification.sh` exige le service KVM guard actif, un reconcile réussi, `guard_mode=normal`, les règles nftables bidirectionnelles et la couverture de tous les CIDR uplink détectés.
- La preuve Ubuntu→LAN est renforcée : le gateway physique doit d'abord être prouvé joignable depuis le HOST avant que son injoignabilité depuis la VM soit considérée comme une preuve de blocage.
- La portée de sécurité du guard est documentée précisément : réseaux IPv4 directement connectés/uplink par défaut ; les routes/VPN additionnels devront être ajoutés explicitement s'ils doivent entrer dans le contrat futur.
- Ajout de `scripts/kvm/verify_ubuntu_cloud_image.sh` : empreinte Canonical cloud-image épinglée, vérification GPG de `SHA256SUMS`, puis SHA-256 de l'image avant création du disque Ubuntu.
- `create_ubuntu_devops_vm.sh` exige désormais l'authentification de l'image Canonical ; `gnupg2` est ajouté au socle KVM Fedora.
- `create_windows11_vm.sh` accepte `--windows-sha256` et `--virtio-sha256` afin de vérifier les médias lorsqu'un hash obtenu depuis une source de confiance indépendante est disponible ; sans hash, le script avertit explicitement que la provenance reste une responsabilité opérateur.
- Ajout des contrats CI `test_kvm_network_fail_closed.sh`, `test_vm_image_auth_contract.sh` et `test_documentation_contract.sh` ; le workflow `Tests` les exécute sur chaque push/PR.
- Le contrat documentaire vérifie notamment les commandes obsolètes, AppIndicator, draw.io, les invariants `devops-nat`, les liens Markdown locaux et la couverture minimale du troubleshooting.

## 0.10.0 — 2026-08-30

- Consolidation **pré-1.0** : priorité au durcissement, à la reproductibilité, aux preuves et à la cohérence de release.
- Intégration officielle de draw.io (`com.jgraph.drawio.desktop`) au catalogue professionnel, corrigeant l'ajout précédent non reflété dans `VERSION`/CHANGELOG.
- Détection runtime renforcée avec `systemd-detect-virt` : VM et conteneurs ne sont plus classés bare-metal par défaut.
- Le `--dry-run` est désormais décrit explicitement comme un **preflight non-mutant / plan de convergence**, sans prétendre simuler les transactions.
- La politique Kernel Vanilla exige réellement le `kernel-core` le plus récent disponible dans les dépôts activés, respecte `KERNEL_VENDOR_CHANGE_ALLOWED`, garde le plancher 7.2.2 et les kernels Fedora fallback.
- Nettoyage des clés de configuration mortes identifiées lors de l'audit pré-1.0 ; `DISPLAY_CERT_TOLERANCE_HZ` est maintenant réellement consommé.
- Les preuves Nautilus/suspend utilisent un fingerprint runtime incluant hardware, kernel, linux-firmware, firmware Intel GPU, Mesa, Mutter et GNOME Shell.
- `final-certification` exige désormais le socle KVM host lorsque KVM est activé.
- Réseau KVM explicitement IPv4-only : `KVM_IPV6_ENABLED=false` et activation IPv6 fail-closed tant qu'une isolation dual-stack équivalente n'est pas implémentée.
- Kickstart rendu déterministe : le SHA Git courant est incorporé et le `%post` fetch/checkout exactement ce commit ; aucun `git clone ... || true` permissif.
- VM Ubuntu : SSH key-only (`ssh_pwauth: false`), mot de passe runtime conservé pour console/sudo, suppression de `NOPASSWD:ALL`.
- Supply-chain Ubuntu : Kubernetes figé sur la génération v1.37.x, kind v0.33.0, Minikube v1.38.1 ; AWS CLI v2 installé depuis ZIP + signature détachée vérifiée avec la clé AWS officielle.
- Politique Flatpak explicite : mises à jour manuelles/utilisateur, aucun updater Flatpak silencieux créé par le projet.
- Ajout de `manifests/application-provenance.tsv` pour distinguer Fedora/vendor signé/Flathub vérifié/Flathub communautaire.
- Réduction des exemptions globales ShellCheck : SC2034 et SC2153 ne sont plus masqués globalement.
- Les prétests Fedora package, Fedora host et Ubuntu VM sont programmés chaque semaine en plus des déclenchements PR/push.
- Ajout de `docs/PRE1_HARDENING.md`, `docs/SUPPLY_CHAIN.md`, `docs/GITHUB_GOVERNANCE.md` et du contrôle manuel `scripts/development/check-main-protection.sh`.

## 0.9.3 — 2026-08-30

- Ajout d'une politique **Curated GNOME Dock** déterministe après installation des applications professionnelles.
- Ordre épinglé : Nautilus → Brave → Ptyxis → VS Code → Bitwarden → Slack → LibreOffice → GNOME Software.
- Remmina reste installé mais volontairement non épinglé.
- Ajout du script idempotent `configure-dock-favorites.sh` qui écrit et relit `org.gnome.shell favorite-apps`.
- Le module `applications.dock_favorites` valide les IDs, interdit les doublons, applique l'ordre et exige que les huit lanceurs `.desktop` soient réellement exportés.
- `applications-doctor` contrôle désormais l'ordre du dock et la présence des lanceurs ; il est ajouté à la certification bare-metal finale.
- Le Fedora 44 host integration pretest exécute la configuration réelle sous un utilisateur de test dans une session D-Bus et relit le GSettings persistant.
- Ajout du contrat CI `test_dock_favorites_contract.sh` et de `docs/DOCK_FAVORITES.md`.

## 0.9.2 — 2026-08-30

- Ajout de la couche **Fedora Host Bash UX** pour que Ptyxis ouvre directement un Bash professionnel et prêt à travailler sur l'OS hôte.
- Ajout des paquets Fedora officiels `bash-completion`, `fzf`, `zoxide` et `direnv`.
- Ajout d'un profil modulaire sous `~/.config/fedora-gnome-custom/bash/` avec historique, aliases, navigation, complétions et prompt séparés.
- Le `.bashrc` utilisateur n'est jamais remplacé : sauvegarde initiale `bashrc.pre-fgc`, puis bloc géré unique et idempotent.
- Historique étendu à 50 000/100 000 entrées, `histappend`, déduplication et synchronisation multi-terminal `history -a` / `history -n`.
- Prompt Bash natif deux lignes avec utilisateur/hôte, chemin, branche Git, état tracked modifié et code retour en erreur ; aucune commande réseau et aucun framework Starship/Oh My Bash.
- Ajout d'aliases DevOps courts pour Git, Docker Compose, Kubernetes et Terraform, sans alias destructif pour `rm`, `mv`, `cp` ou `sudo`.
- Les complétions de `gh`, `glab`, `kubectl`, `helm` et `minikube` sont générées uniquement si les binaires existent puis mises en cache.
- Ajout de `shell-doctor`, intégré à `workstation-doctor` et à la certification bare-metal finale.
- Le prétest Fedora 44 crée un utilisateur réel dans le conteneur, installe le profil Bash et exécute un smoke test interactif.
- Ajout de `docs/HOST_BASH_UX.md` et passage de la Golden Workstation en version 0.9.2.

## 0.9.1 — 2026-08-30

- Passage de la VM Ubuntu Server 26.04 au profil **Ubuntu DevOps Ready** : objectif `clone → build/test → containerize → deploy` dès le premier login après bootstrap.
- Ajout de GitLab CLI `glab` en complément de Git/Git LFS et GitHub CLI.
- Ajout de Node.js 22 LTS, npm et Corepack pour les projets Angular/JavaScript.
- Ajout d'OpenJDK 21 et Maven pour les projets Java/Spring.
- Ajout de Minikube avec Docker comme driver par défaut, en complément de kind, kubectl et Helm.
- Ajout de K9s, kubectx/kubens et du binaire Go `yq` v4.
- Minikube vérifie le checksum publié de sa release ; `yq` v4.53.3 et K9s v0.51.0 sont épinglés avec SHA-256 attendu. Aucun `curl | bash` n'est introduit.
- `verify-devops.sh` certifie les nouveaux outils, les versions minimales Node/OpenJDK, le driver Minikube et conserve les contrôles Docker/QEMU Guest Agent.
- Le vrai prétest Ubuntu 26.04 compile/exécute un programme Java, exécute Node, vérifie Docker Compose, GitLab CLI et les outils Kubernetes, puis exige leur persistance après reboot.
- Ajout de `docs/UBUNTU_DEVOPS_READY.md` et passage de la Golden Workstation en version 0.9.1.

## 0.9.0 — 2026-08-30

- Ajout de la couche **Desktop & Lifecycle Completion** pour transformer la Golden Workstation en poste principal quotidien/professionnel, sans copier Ubuntu/Yaru ni multiplier les extensions cosmétiques.
- AppIndicator officiel Fedora activé et certifié en complément de Dash to Dock ; Blur My Shell reste désactivé par défaut.
- Intégration GNOME Keyring/Secret Service, CUPS/IPP-over-USB/Avahi/AirScan, VPN OpenVPN/OpenConnect, TuneD PPD, français/dictionnaires/polices, Remmina et support mobile/iPhone.
- Ajout du runtime Intel Arc Level Zero/OpenCL et d'`arc-compute-doctor`, qui exige l'énumération réelle de l'Arc B580.
- Ajout de `portal-doctor` pour certifier ScreenCast/FileChooser/OpenURI et Notification via xdg-desktop-portal/PipeWire/Wayland.
- Politique lifecycle DNF5 : téléchargement automatique autorisé, **installation automatique interdite**, **reboot automatique interdit**, avec `fstrim.timer` et refresh metadata fwupd.
- Ajout d'une sauvegarde utilisateur Restic quotidienne par timer systemd, chiffrée, sans prune silencieux et sans inclure la passphrase Restic ; absence du disque externe = skip propre, pas corruption du statut.
- Durcissement de la certification suspend/resume : un cycle physique ne peut être compté qu'une fois et le repair display doit être postérieur au hook de reprise correspondant.
- `display-doctor` vérifie désormais le `Current mode` réellement actif à 2560×1440 ~240 Hz.
- Restauration des preuves runtime KVM du garde réseau : table nft présente, gateway KVM joignable et LAN physique bloqué depuis Ubuntu lorsque la politique l'exige.
- Extension de la matrice known-good aux composants desktop/portal/power/compute et ajout du contrat CI `test_desktop_lifecycle_contract.sh`.

## 0.8.2 — 2026-08-30

- Ajout d'une politique GNOME explicite imposant les trois contrôles de fenêtre **Réduire / Agrandir / Fermer** à droite via `org.gnome.desktop.wm.preferences button-layout`.
- Le module GNOME applique `:minimize,maximize,close` de façon idempotente et refuse la validation post-APPLY si la valeur réellement enregistrée diffère.
- Ajout d'un contrat CI empêchant une régression silencieuse vers le comportement GNOME par défaut sans boutons Réduire/Agrandir.

## 0.8.1 — 2026-08-30

- Ajout explicite de `amd-ucode-firmware` pour le Ryzen 7 7700 et `intel-gpu-firmware` pour l'Arc B580, avec `firmware-doctor` et détection des échecs de chargement firmware.
- Certification de la MSI MAG B850M Mortar WiFi : Realtek 8126-VB/`r8169`/5000baseT, Wi-Fi 7 et 6 GHz détectés dynamiquement, Bluetooth, ALC4080 USB Audio/PipeWire et xHCI.
- Extension du hook suspend/resume aux contrôleurs réseau/audio/USB et ajout de `usb-resume-doctor` dans chaque preuve post-veille.
- Ajout d'une matrice known-good BIOS + kernel + linux-firmware/microcode + Mesa + Mutter + GNOME Shell + Nautilus + QEMU/libvirt, invalidée lors d'un changement de version jusqu'à recertification.
- Ajout du benchmark T705 KVM `io_uring` vs AIO natif, filesystem-safe, avec sélection persistante du meilleur backend ; `cache=none` et discard/unmap restent la base sûre.
- Ubuntu 26.04 et Windows 11 exposent désormais le channel QEMU Guest Agent, VirtIO RNG et balloon mémoire ; Windows expose aussi le channel SPICE.
- Ajout de `Configure-GuestIntegration.ps1` pour installer/certifier les drivers VirtIO et QEMU Guest Agent depuis l'ISO fourni par l'opérateur.
- `runtime_certification.sh` exige désormais la réponse `guest-ping` des deux VMs et valide les périphériques de virtualisation.
- Ajout du contrat CI `test_hardware_kvm_completion_contract.sh` et de la documentation `HARDWARE_KVM_COMPLETION.md`.

## 0.8.0 — 2026-08-30

- Ajout du profil **Golden Workstation** séparant baseline pré-APPLY et certification runtime post-APPLY.
- Ajout de Fedora Kernel Vanilla `@kernel-vanilla/stable`, plancher Linux `7.2.2`, contrôle Secure Boot fail-closed, `kernel-doctor` et rollback explicite vers les kernels Fedora.
- Conservation obligatoire des kernels Fedora déjà installés comme fallback de boot ; aucun retrait agressif de kernels.
- Remplacement des preuves RAM/NVMe déclaratives par des tests automatisés : `stress-ng --verify` à 5600/6000 et `fio` filesystem-safe avec CRC32C sur root + `/data`.
- Les preuves automatisées contiennent le SHA-256 de leurs logs ; root et `/data` doivent résoudre vers deux NVMe physiques distincts.
- Fingerprint renforcé : BIOS/UUID plateforme, CPU, GPU/driver, mémoire, serial/firmware NVMe et EDID disponible.
- La validation suspend/resume n'est plus un prérequis pré-APPLY : elle est déplacée après installation/reboot afin de ne pas bloquer l'installation des corrections qu'elle doit mesurer.
- Ajout d'un vrai benchmark **cold-start Nautilus** : processus absent au départ, mesure jusqu'à possession de `org.gnome.Nautilus`, cible 1200 ms et hard limit 2000 ms.
- Ajout d'un prewarm GNOME login limité à Portal/GIO ; Nautilus lui-même n'est jamais pré-démarré.
- Thumbnails Nautilus configurés `local-only` ; suppression optionnelle d'`ibus-typing-booster` pour réduire une dépendance de premier lancement non nécessaire à ce profil.
- Ajout du display recovery GNOME 50 via `gdctl` : 2560×1440, ~240 Hz, scale 1.0, SDR/default et Full RGB.
- Ajout d'un watcher user sur resume logind, `MonitorsChanged` de Mutter et hotplug/change DRM afin de réappliquer le display state après veille ou power-cycle écran.
- Ajout de `display-doctor`, capture `drm_info` et preuve de repair.
- Blur My Shell désactivé par défaut dans le profil Golden Workstation afin de réduire les variables du compositor à 240 Hz ; Dash to Dock reste activé.
- Ajout de `final-certification` exigeant kernel/GPU/display/GNOME sains, cold-start courant et cinq cycles suspend/resume post-APPLY avec repair récent.
- Ajout d'un générateur Kickstart Fedora 44 protégé ciblant uniquement le NVMe explicitement choisi ; aucune sélection destructive automatique de disque.
- Ajout des contrats CI Golden Workstation et mise à jour de la documentation GNOME/installation.

## 0.7.1 — 2026-08-27

- Hardening WSL2 et supply-chain : isolation runtime bare-metal/WSL2/CI, blocage APPLY/certification hors bare-metal, entrypoints contrôlés et GitHub Actions épinglées.

Voir l'historique Git antérieur pour les versions 0.1.0 à 0.7.0.

# Lifecycle de migration Fedora N+1

## Principe

Le HOST Golden ne doit jamais être exposé directement à une mise à niveau majeure improvisée. Le parcours est :

```text
Fedora 44 Golden
      ↓
check Fedora 45
      ↓
qualification N+1 sans mutation RPM
      ↓
repos + repoclosure + transaction distro-sync stockée
GNOME/extensions + paquets + extras/duplicates
      ↓
PASS uniquement si aucun blocker
      ↓
Fedora 45 finale publiée
+ Golden courant certifié
+ baseline valide
+ Git propre
+ backup Restic same-commit + restore canary
      ↓
prepare
      ↓
dnf5 system-upgrade download --releasever=45
      ↓
AUCUN REBOOT AUTOMATIQUE
      ↓
approbation opérateur explicite
      ↓
upgrade physique
      ↓
postcheck
      ↓
recertification bare-metal complète
      ↓
Fedora 45 Golden
```

## Commandes

```bash
./control.sh upgrade status 45
./control.sh upgrade check 45
./control.sh upgrade qualify 45
./control.sh upgrade prepare 45
./control.sh upgrade postcheck 45
./control.sh upgrade clean 45
```

Le moteur réel est `scripts/upgrade/upgrade-lifecycle.sh`.

## Ce que fait `check`

`check` est un inventaire non destructif :

- vérifie le chemin autorisé 44 → 45 ;
- enregistre les repositories activés vus avec `releasever=45` ;
- liste les RPM dupliqués ;
- liste les RPM extras/orphelins vis-à-vis des repositories ;
- indique si le répertoire officiel de la Fedora 45 finale est publié ;
- rapporte les pins GNOME du projet qui restent liés à GNOME Shell 50.

Le rapport est écrit sous `reports/fedora-45-qualification.txt` dans l'état runtime du projet.

## Ce que fait `qualify`

`qualify` ne lance aucune mise à niveau du HOST. Il :

1. rafraîchit les métadonnées N+1 ;
2. refuse les RPM dupliqués ;
3. exécute `dnf5 --releasever=45 repoclosure --json` ;
4. résout un `distro-sync` Fedora 45 avec `--store`, donc stocke la transaction sans l'exécuter ;
5. vérifie les blockers Golden, notamment les extensions GNOME ;
6. écrit un marker `verdict=PASS` lié au commit Git uniquement si tout est compatible.

Un blocker donne un code d'échec et **aucun marker PASS**.

## État Fedora 45 actuel

Le projet sait qualifier Fedora 45 avant sa sortie finale, mais ne doit pas la préparer pour migration réelle tant que la release finale n'est pas publiée.

La qualification actuelle doit également rester bloquée tant que les artefacts GNOME Golden sont explicitement épinglés à Shell 50. Le workflow `.github/workflows/fedora45-qualification.yml` produit un rapport périodique qui expose cet état au lieu de masquer l'incompatibilité.

Cette distinction est volontaire :

```text
workflow CI vert = le mécanisme de qualification fonctionne
verdict du rapport = READY_FOR_HOST_QUALIFICATION ou BLOCKED
```

Le workflow n'affirme donc jamais qu'une Fedora pré-release ou incompatible est Golden.

## Préconditions de `prepare`

`prepare` est bare-metal uniquement et fail-closed. Il exige :

- Fedora source = 44 et cible = 45 ;
- `diagnostics/host-security-policy-doctor` PASS : Secure Boot OFF et aucun chiffrement bloc local ;
- working tree Git propre ;
- baseline matérielle valide ;
- certification Golden courante valide pour le fingerprint runtime ;
- qualification Fedora 45 PASS, fraîche et liée au même commit ;
- backup pré-APPLY Restic frais et lié au même commit ; ce backup inclut déjà `restic check` et un restore-canary réel ;
- publication de Fedora 45 finale ;
- absence de reboot en attente ;
- Fedora 44 courante déjà totalement mise à jour ;
- plugin `dnf5 system-upgrade` disponible.

`--allowerasing` est interdit par défaut. Le projet ne résout jamais un conflit majeur en acceptant silencieusement la suppression de paquets.

## Préparation ≠ lancement

La seule opération de `prepare` est :

```text
dnf5 system-upgrade download --releasever=45
```

Le projet **n'exécute jamais automatiquement** la phase reboot/offline. Après revue volontaire de la transaction, la commande DNF native qui déclenche ce boot reste une action opérateur explicite :

```bash
sudo dnf5 system-upgrade reboot
```

Elle n'est pas exposée comme action automatique du Control Center.

## Après l'upgrade

`postcheck` exige Fedora 45, valide la politique HOST, exécute `dnf5 check`, refuse les RPM dupliqués et vérifie que l'ancien certificat Golden est devenu invalide.

Le fingerprint runtime contient maintenant explicitement `fedora_release`. Une transition 44 → 45 invalide donc les preuves sensibles même dans l'hypothèse improbable où les autres versions seraient identiques.

Il faut ensuite refaire la certification bare-metal complète avant de déclarer Fedora 45 Golden.

## Rollback et récupération

Une migration majeure ne possède pas de rollback magique fiable au niveau RPM. La stratégie Golden est donc :

- kernel Fedora et kernels Golden précédents conservés pour les incidents de boot kernel ;
- backup Restic + restore-canary obligatoire avant préparation ;
- inventaires et métadonnées libvirt sauvegardés ;
- restauration staging-first ;
- en cas d'échec majeur de l'OS, réinstallation de la dernière Fedora Golden connue puis restauration contrôlée depuis Restic.

La commande `upgrade clean` supprime seulement une transaction offline préparée avant son exécution ; elle ne tente jamais de rétrograder un HOST déjà migré.

## CI Fedora 45

`.github/workflows/fedora45-qualification.yml` exécute régulièrement un conteneur Fedora 45 pour contrôler :

- disponibilité de l'image Fedora 45 ;
- GNOME Shell 51+ ;
- DNF5/repoclosure ;
- Nautilus, Ptyxis, Restic, KVM/libvirt, Mesa et Flatpak ;
- duplicates/extras ;
- fermeture des dépendances Fedora ;
- blockers des extensions Golden ;
- disponibilité de la release finale.

Le rapport est conservé comme artifact GitHub Actions.

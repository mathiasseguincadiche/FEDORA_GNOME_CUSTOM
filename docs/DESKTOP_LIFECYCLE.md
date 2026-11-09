# Entretien du poste : mises à jour et cycle de vie

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — politiques relues contre `modules/desktop/27_lifecycle.sh`, `config/desktop.conf`, la couverture des mises à jour et les scripts de sauvegarde — matériel : non vérifié

Cette page décrit comment le poste se maintient au quotidien : mises à jour des RPM et des Flatpak, rôle de GNOME Logiciels, sauvegarde quotidienne et preuves sensibles aux mises à jour. Les commandes elles-mêmes sont dans le [centre de contrôle](CONTROL_CENTER.md).

## Capacités quotidiennes

La certification du poste couvre notamment :

- GNOME Keyring / Secret Service ;
- portails Wayland ;
- impression et numérisation sans pilote (driverless) ;
- VPN NetworkManager ;
- TuneD PPD ;
- langue française, dictionnaires et polices ;
- Remmina ;
- support mobile ;
- Intel Arc compute.

## RPM Fedora

`/etc/dnf/automatic.conf` est convergé avec :

- téléchargement automatique : **oui** ;
- installation automatique : **non** ;
- reboot automatique : **jamais**.

`dnf5-automatic.timer`, `fstrim.timer` et, lorsqu'il existe, `fwupd-refresh.timer` sont activés (`modules/desktop/27_lifecycle.sh`). Le timer fwupd rafraîchit les métadonnées ; il ne flashe jamais un firmware.

## Flatpak

Politique :

```text
LIFECYCLE_FLATPAK_UPDATE_POLICY=manual
```

**Pour mettre à jour seulement les applications Flatpak**, utiliser `./control.sh update flatpak` (ou directement `flatpak update`). Cela ne prépare pas de transaction RPM hors ligne.

**Pour mettre à jour l'ensemble du poste**, la commande est différente :

```bash
./control.sh update all
```

Le mode complet exige une sauvegarde Borg préalable et peut préparer une transaction RPM DNF5 : ce n'est **pas** une simple commande Flatpak. Il met aussi à jour Flatpak lorsque les RPM sont déjà à jour, sans demander de redémarrage dans ce cas. Si des RPM ont été préparés, vérifier `./control.sh update status`, puis suivre les étapes conditionnelles de redémarrage et de finalisation de la [procédure complète](UPDATE_COVERAGE.md#3-procédure-de-mise-à-jour-complète).

Le projet ne crée aucun timer ni service qui installerait des Flatpak en silence.

## GNOME Logiciels

GNOME Logiciels reste disponible pour parcourir le catalogue et installer de nouvelles applications, mais ne propose plus de voie parallèle de mise à jour : le module lifecycle installe une base dconf système dédiée et verrouille `org.gnome.software` `download-updates=false` et `allow-updates=false`, en conservant les entrées du profil dconf existant. Les mises à jour RPM passent par la transaction sauvegardée du projet.

Après APPLY, se déconnecter, se reconnecter, puis lancer `./diagnostics/lifecycle-doctor`. Une valeur utilisateur ou un profil dconf personnalisé qui contourne la politique fait échouer ce contrôle. Ne pas supprimer PackageKit ou DNF5 pour autant.

GNOME Disques (`gnome-disk-utility`) fait partie de la couche d'intégration ; Flatseal est livré depuis Flathub (provenance upstream, sans badge « verified »).

## Sauvegarde quotidienne

Le timer Borg sauvegarde les données utilisateur dès que le support externe, ou le dépôt distant, est accessible :

- dépôt non chiffré, par décision du propriétaire ([ADR 0014](adr/0014-borg-unencrypted-backups.md)) ;
- clés privées `.ssh` et `.gnupg`, et dossier `secrets` du projet, toujours exclus ([ADR 0021](adr/0021-no-private-keys-in-unencrypted-backups.md)) ;
- rétention automatique selon la politique versionnée, qui ne touche jamais les archives pré-APPLY ;
- support absent : run enregistré `skipped`, timer intact ;
- sauvegarde pré-APPLY indépendante, qui échoue fermée.

Sources, exclusions et restauration : [sauvegarde et restauration](BACKUP_RESTORE.md).

## Veille et affichage

Chaque preuve de veille porte un `cycle_id` unique et une empreinte d'exécution qui inclut la pile graphique. Un changement de noyau, de firmware GPU, de Mesa, de Mutter ou de GNOME Shell impose de refaire ces preuves.

## KVM

L'hôte KVM fait partie de la certification finale lorsque `ENABLE_KVM=true`. La certification des invités reste une étape distincte :

```bash
scripts/kvm/runtime_certification.sh
```

Le réseau KVM utilise un garde qui échoue fermé : un changement de connectivité passe d'abord en mode d'urgence, avant la reconstruction des règles normales ([réseau KVM](KVM_NETWORK.md)).

## Limites

La CI ne simule ni l'Arc B580 sous Wayland à 240 Hz, ni la veille, ni les deux NVMe, ni le réseau local réel : la certification finale se fait uniquement sur le PC physique.

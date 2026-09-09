# Runbook — second T705, données persistantes et Gaming

Ce runbook couvre le contrat `/data` et le socle Gaming. Il complète [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md), [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) et [`GAMING.md`](GAMING.md).

## Contrat attendu

```text
/data                  EXT4 dédié sur le second T705
├── Documents          0750 / user_home_t
├── Projets            0750 / user_home_t
├── ISO                0750 / user_home_t
├── Jeux               0750 / user_home_t
└── libvirt            contexte libvirt dédié
```

`Documents` doit aussi être le XDG Documents de l'utilisateur workstation.

Le projet ne partitionne et ne formate jamais automatiquement le second T705.

## `/data` absent

```bash
findmnt /data
lsblk -f
./control.sh doctor data
```

Ne lancer ni formatage ni création de filesystem depuis le projet. Identifier le second T705 préparé par l'opérateur puis restaurer son montage `/data`.

Une réinstallation normale doit réutiliser le même EXT4 sans effacer son contenu.

## `/data` monté avec le mauvais filesystem

```bash
findmnt -n -T /data -o SOURCE,TARGET,FSTYPE,OPTIONS
findmnt -n -T / -o SOURCE,TARGET,FSTYPE
```

Le doctor exige `FSTYPE=ext4` pour `/data` et refuse que `/data` corresponde au filesystem racine.

Ne convertir ni reformater automatiquement un volume contenant des données.

## Répertoire persistant absent

```bash
./control.sh doctor data
ls -ld /data/Documents /data/Projets /data/ISO /data/Jeux
```

Le module `desktop.persistent_data` crée idempotemment les quatre racines pendant APPLY sans supprimer leur contenu existant.

Ne créer aucun lien symbolique vers `/data/libvirt` et ne déplacer pas les données utilisateur sous le sous-arbre KVM.

## Owner ou mode incorrect

```bash
stat -c '%U:%G %a %n' /data/Documents /data/Projets /data/ISO /data/Jeux
```

Attendu pour chaque racine utilisateur : propriétaire workstation et mode `750`.

Le projet ne fait jamais de `chmod 777` et ne doit pas appliquer un `chown -R` aveugle sur les payloads existants.

## Label SELinux incorrect

```bash
ls -Zd /data/Documents /data/Projets /data/ISO /data/Jeux /data/libvirt
```

Les racines utilisateur doivent exposer `user_home_t`. `/data/libvirt` conserve sa politique `virt_image_t`.

Si les règles `semanage fcontext` du projet sont déjà installées, réappliquer les labels est préférable à désactiver SELinux :

```bash
sudo restorecon -RFv /data/Documents /data/Projets /data/ISO /data/Jeux /data/libvirt
./control.sh doctor data
```

## XDG Documents incorrect

```bash
xdg-user-dir DOCUMENTS
```

Attendu :

```text
/data/Documents
```

Le module de données persistantes configure cette valeur avec `xdg-user-dirs-update`.

## Backup refuse `/data`

```bash
./control.sh doctor data
./diagnostics/backup-doctor --certify-status
```

Les sauvegardes Documents/Projets échouent volontairement si `/data` n'est pas le montage EXT4 dédié attendu.

Par défaut :

```text
/data/Documents  → Restic
/data/Projets    → Restic
/data/ISO        → pas de backup automatique
/data/Jeux       → pas de backup automatique
```

Une donnée irremplaçable stockée directement dans `/data/ISO` ou `/data/Jeux` nécessite une politique de backup explicite.

## Gaming doctor en KO

```bash
./control.sh doctor gaming
```

Puis vérifier :

```bash
./control.sh doctor data
rpm -q steam gamemode mangohud goverlay gamescope steam-devices
vulkaninfo --summary
```

Le profil Golden attend Gaming activé. La certification finale ne doit pas PASS avec `GAMING_ENABLE=false`.

## `/data/Jeux` non inscriptible

```bash
stat -c '%U:%G %a %n' /data/Jeux
ls -Zd /data/Jeux
./control.sh doctor data
./control.sh doctor gaming
```

Corriger la cause du contrat de stockage avant Steam. Ne donner pas à Steam un accès global à `/data` et ne déplacer pas la bibliothèque sous `/data/libvirt`.

## Steam n'utilise pas encore `/data/Jeux`

C'est normal après une première installation. Le projet ne modifie pas `libraryfolders.vdf`.

Dans Steam, utiliser **Settings → Storage** et enregistrer `/data/Jeux` comme bibliothèque.

Steam est un RPM natif : aucune permission Flatpak filesystem n'est nécessaire pour ce chemin.

## Vulkan Arc B580 absent

```bash
./diagnostics/graphics-doctor
vulkaninfo --summary
lspci -Dnnk -d 8086:e20b
```

Attendu : Intel Arc B580, pilote kernel `xe`, renderer Vulkan Intel/Mesa. Ne pas ajouter de `force_probe`, Mesa git/COPR ou kernel gaming pour masquer un KO.

## Proton absent

Sur une installation Steam fraîche, l'absence de payload Proton est un avertissement : Steam télécharge les compatibility tools à la demande.

Le contrat privilégie : Valve Proton → Proton Experimental → Proton-GE seulement en exception par titre.

## Jeu instable ou incompatible

Commencer sans option de lancement. Puis tester séparément :

```text
gamemoderun %command%
mangohud %command%
mangohud gamemoderun %command%
```

Gamescope reste spécifique au titre et à l'affichage. Ne rendre aucun helper obligatoire globalement.

Les problèmes anti-cheat, DRM ou compatibilité d'un jeu particulier ne sont pas une preuve de défaillance générale de la Golden Workstation.

## Après réparation

```bash
./control.sh doctor data
./control.sh doctor gaming
./control.sh status
```

Si la réparation a modifié un composant sensible de la matrice Golden, relancer la certification physique au lieu de réutiliser une preuve devenue `STALE`.

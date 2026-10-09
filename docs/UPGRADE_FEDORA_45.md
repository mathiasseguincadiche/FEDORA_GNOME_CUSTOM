# Préparer Fedora 45 / GNOME 51

La cible future est Fedora 45 Workstation avec GNOME 51. Le profil Fedora 44 / GNOME 50 déjà testé reste actif pendant la préparation. Une Beta ou un numéro de version changé dans un ancien verrou ne constitue pas un profil de production.

## État réel du profil

`profiles/fedora45/profile.json` est **pending**. Il ne contient aucun faux SHA de média final ou d'extension. Fedora 45 est encore en préparation ; la disponibilité de GNOME 51 ne suffit pas à qualifier la combinaison Fedora, noyau, extensions, applications et matériel.

```bash
./control.sh upgrade plan
bash scripts/development/release-readiness.sh --report-only --pin
```

Le plan refuse de préparer une mutation tant que le profil final n'est pas promu. `--report-only` collecte les blocages et rend zéro pour permettre la publication du rapport ; seul son champ `OVERALL` exprime READY ou BLOCKED. Le statut vert du job de collecte n'est pas une certification.

Le workflow [Fedora 45 GNOME 51 preview readiness](../.github/workflows/release-readiness.yml) utilise un vrai conteneur Fedora 45. Il vérifie le système, GNOME 51, un aller-retour Borg, les manifestes RPM, les extensions RPM et les archives des quatre extensions épinglées. Il conserve `readiness.json` et, uniquement si les quatre archives sont compatibles, un verrou **candidat** complet. Il ne change pas le verrou GNOME 50 actuel et ne certifie pas une session Wayland, l'Arc B580 ou la veille.

## Laboratoire GNOME 51 natif de préversion

Le workflow [Fedora 45 native GNOME 51 boot and recovery preview](../.github/workflows/fedora45-gnome-preview.yml) utilise un seed Fedora Cloud 45 Beta dont le SHA256 et la clé de signature sont indépendamment épinglés. Le nom de l'image est extrait du CHECKSUM signé ; le laboratoire recontrôle signature et contenu avant démarrage.

Avant l'installation graphique, il met à jour les paquets déjà présents dans le seed Beta via les dépôts officiels : installer le groupe GNOME seul ne suffit pas à actualiser ses schémas. Il redémarre normalement cette transaction et exige le nouveau boot ainsi que le noyau Fedora mis à jour avant d'installer GNOME. Le journal de maintenance reste conservé ; aucun service en échec n'est réinitialisé pour fabriquer un PASS. Il vérifie notamment la présence de custom-accel-config, requise par Mutter 51, avant le démarrage de GDM.

Il exerce une session Wayland GNOME 51 native, la politique de mises à jour, la bureautique, le reboot, Borg et la récupération isolée. Les six extensions personnalisées sont explicitement DEFERRED, car les blocages de compatibilité ne sont pas contournés. Un PASS natif ne promeut ni les extensions ni le profil de production. Le laboratoire Fedora 44 reste celui du bureau personnalisé complet.

## Promotion à effectuer sur GitHub

Une même PR doit fournir et faire examiner :

1. `installer/fedora45-media.lock` : Workstation **final**, compose exact, nom de l'ISO et du CHECKSUM, URL officielle et SHA256 réel. L'empreinte Fedora 45 est `4F50A6114CD5C6976A7F1179655A4B02F577861E`. Vérifier cryptographiquement le CHECKSUM signé et le couple exact nom/hash avant d'accepter ce verrou.
2. `profiles/fedora45/gnome-extensions.lock` : **déjà renseigné** avec des archives compatibles GNOME 51 relevées par la CI (voir [GNOME_EXTENSIONS.md](GNOME_EXTENSIONS.md#profil-fedora-45--gnome-51-en-préparation)). DING, Show Desktop Plus et Resource Monitor n'ont pas de build GNOME 51 : ils sont remplacés par Gtk4 DING, Show Desktop Button et Vitals ; seules ces identités revues (ou celles de Fedora 44) sont acceptées. Reste à faire examiner le fichier, compiler les schémas et tester la session GNOME 51 réelle ; un simple tag API ne suffit pas.
3. `profiles/fedora45/profile.json` : `schema=1`, `release=45`, `gnome_major=51`, `status=ready`, SHA256 des deux fichiers ci-dessus et `packages_lock_sha256` pour le manifeste Nautilus 45 et `qualification_commit` réel. Les preuves CI doivent porter sur ce commit et ces fichiers, avant la promotion.
4. Un laboratoire Fedora 45 signé et épinglé, puis démarrage, redémarrage, journaux/coredumps, extensions actives et restauration isolée. Le laboratoire Fedora 44 existant reste la référence précédente, pas une preuve Fedora 45.
5. Une mise à jour des tests de promotion : le test qui exige actuellement un profil pending doit devenir un contrôle du profil réellement promu. Préserver les tests négatifs Beta, GNOME 50, clés inattendues, archive altérée et identité obsolète.

Le validateur rejette un statut pending, un média Beta, une empreinte incorrecte, des clés d'extension supplémentaires, un UUID modifié, un major 50, un hash manquant ou un verrou changé après qualification. Il vérifie la structure et l'identité du profil examiné ; il ne fabrique pas une preuve de téléchargement signé ni une qualification matérielle.

## Différence Nautilus/GVfs déjà traitée

Fedora 45 ne fournit plus `gvfs-archive`. `profiles/fedora45/packages-nautilus.txt` conserve Nautilus, GVfs et les backends pris en charge, Sushi et File Roller, puis ajoute explicitement File Roller. Le moteur et le doctor sélectionnent cette liste uniquement sur un profil 45 promu. L'ouverture et l'extraction restent disponibles ; le montage des archives par GIO n'est plus promis.

## Vérification « jour J » avant d'installer

Les extensions GNOME sont épinglées (URL, version, SHA256) : elles ne se mettent pas à jour toutes seules. Juste avant d'installer, lancer le workflow [Fedora 45 GNOME 51 preview readiness](../.github/workflows/release-readiness.yml) (onglet Actions, « Run workflow ») et lire son résumé :

- `READY` pour chaque extension : l'archive épinglée est toujours téléchargeable, de même empreinte, avec le bon UUID et le major 51.
- `LATEST … UP-TO-DATE` : l'épingle est la dernière version publiée. `LATEST … NEWER` : une version plus récente existe ; le rapport donne sa version, sa review et son SHA256, et l'artefact `latest-gnome-extensions.lock` contient le verrou mis à jour à relire avant de remplacer les épingles.
- `LATEST KERNEL` : la dernière stable publiée sur kernel.org, à comparer au plancher `KERNEL_MIN_VERSION` de `config/kernel.conf`.

Après l'installation : `./control.sh update all`, `./control.sh update reboot`, `./control.sh update finalize`, puis `./control.sh kernel status`. Le BIOS de la carte mère et le firmware (`fwupd`) se vérifient à la main : le projet liste les mises à jour de firmware mais ne les installe jamais.

## Promouvoir le profil à la sortie de l'ISO finale

Une fois l'ISO **finale** Workstation et son fichier CHECKSUM signé téléchargés (jamais une Beta), le propriétaire promeut le profil avec un seul outil, au lieu de recopier des empreintes à la main :

```bash
# Prérequis : arbre Git propre, CI verte sur le commit courant, clé Fedora 45 dans un trousseau GPG.
python3 scripts/development/promote-fedora45.py \
  --iso /chemin/Fedora-Workstation-Live-45-COMPOSE.x86_64.iso \
  --checksum /chemin/Fedora-Workstation-45-COMPOSE-x86_64-CHECKSUM \
  --keyring /chemin/fedora.gpg \
  --commit "$(git rev-parse HEAD)"
```

L'outil refuse (et restaure les fichiers) si : le nom n'est pas celui d'une image finale (Beta/RC), le CHECKSUM n'est pas signé par la clé Fedora 45 épinglée (`4F50A611…861E`) ou ne lie pas exactement ce nom à cette empreinte, l'ISO a été modifiée, l'arbre Git n'est pas propre, ou `--commit` n'est pas le HEAD courant. En cas de succès il écrit `installer/fedora45-media.lock` et `profiles/fedora45/profile.json` (`status: ready`, empreintes du média, du verrou d'extensions et de la liste de paquets), puis exécute le même validateur que tous les gardes. Il ne commit rien : relire `git diff`, committer ces deux fichiers, laisser la CI tourner, puis passer par une PR.

Le contrôle [Fedora 45 package and driver preflight](../.github/workflows/fedora45-package-preflight.yml) prouve en conteneur Fedora 45 réel que les manifestes se résolvent (RPM Fusion 45 compris), que l'espace utilisateur Intel Arc s'installe (Vulkan ANV, VA-API `iHD`), que les échanges ffmpeg/intel-media-driver fonctionnent, que le RPM Linux amont existe et se télécharge pour Fedora 45, et que les quatre archives GNOME 51 épinglées sont valides. Il est informatif : il ne promeut rien et ne certifie aucun matériel.

## Installation neuve directement en Fedora 45

Une fois le profil final promu :

```bash
bash installer/verify-fedora-media.sh --release 45 --iso /chemin/Fedora-Workstation-Live-45-COMPOSE.x86_64.iso --checksum /chemin/Fedora-Workstation-45-COMPOSE-x86_64-CHECKSUM --keyring /chemin/fedora.gpg
bash installer/generate-fedora-kickstart.sh --release 45 --disk /dev/disk/by-id/nvme-IDENTITE_REELLE
```

Les noms COMPOSE et IDENTITE_REELLE sont des placeholders à remplacer par les valeurs vérifiées. La génération conserve le contrôle du numéro de série NVMe, la confirmation destructive, le mot de passe chiffré du compte et le commit Git épinglé. Le chiffrement du mot de passe ne chiffre pas le disque. Le post-install sélectionne `HOST_RELEASE="45"` ; aucun disque `/data` n'est formaté automatiquement.

Installer une Beta manuellement ne permet pas de contourner la promotion : les préchecks du projet refuseront ce profil tant que le verrou final n'est pas prêt.

## Mise à niveau Fedora 44 vers Fedora 45

Mettre Fedora 44 complètement à jour et démarrer/finaliser ce résultat avant la migration :

```bash
./control.sh update all
./control.sh update reboot
./control.sh update finalize
./control.sh upgrade plan
./control.sh upgrade prepare
./control.sh upgrade status
```

`prepare` exige le profil final, le HOST physique, Secure Boot désactivé, un Git propre, le système source à jour et aucune mise à jour projet déjà en attente. Il résout la dernière stable Linux amont pour Fedora 45, puis effectue une sauvegarde Borg complète **avec les VM arrêtées** : disques, XML, NVRAM et état swtpm. L'espace de staging, le support externe et les preuves d'intégrité/restitution sont contrôlés. Il télécharge ensuite la transaction DNF5 system-upgrade, sans `--allowerasing`, sans saut de paquets et sans redémarrage automatique.

Relire les suppressions/conflits éventuels de la transaction. Le redémarrage est une action séparée :

```bash
./control.sh upgrade reboot
# après retour en session Fedora 45 :
./control.sh upgrade finalize
```

`finalize` exige le même commit et la même configuration, un boot différent, Fedora 45, GNOME 51, le journal DNF, une base de paquets cohérente et le noyau amont prévu réellement démarré. Il active ensuite le profil 45 dans l’override local sans supprimer les autres réglages et installe les quatre archives GNOME 51 du profil promu, avec vérification des hashes, UUID, major et schémas. Exécuter la finalisation depuis le compte GNOME, sans sudo. La phase `extensions-installed` demande une déconnexion normale puis une nouvelle connexion ; le code de retour 20 signifie qu’une action reste à effectuer. Relancer alors `./control.sh upgrade finalize` : le diagnostic doit confirmer le bureau et les extensions effectivement actifs avant le statut completed. Toute divergence bloque la finalisation ; elle n'est jamais annoncée comme réussie.

Le profil, les médias et les verrous entrent dans l'empreinte de configuration : les anciennes preuves Golden deviennent obsolètes. Refaire WSL2 → VirtualBox avec validation visuelle → matériel physique, restauration isolée et reprise VM.

## Récupération et qualification physique

Le retour au noyau N-1 ne revient **pas** de Fedora 45 à Fedora 44. Une récupération de l'OS repose sur la sauvegarde, le média connu et la reconstruction isolée décrite dans [BACKUP_RESTORE.md](BACKUP_RESTORE.md).

Mesurer sur la machine réelle : GNOME/Wayland, Arc B580 et `xe`, Vulkan/Steam/Proton, écran 1440p/~240 Hz, veille/reprise, réseau, audio et périphériques. Conserver le cas à qualifier du redémarrage direct avec session GNOME ouverte, déjà observé dans le laboratoire QEMU : aucun timeout système ni contrôle de coredump n'est neutralisé.

Références : [DNF5 system-upgrade](https://dnf5.readthedocs.io/en/latest/commands/system-upgrade.8.html), [clés Fedora](https://fedoraproject.org/security/), [calendrier GNOME](https://release.gnome.org/calendar/).

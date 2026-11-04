# Chaîne d'approvisionnement et provenance

> Mise à jour : 2026-11-04 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-04 — relu contre `installer/fedora45-media.lock`, `config/kernel.conf`, `config/gnome-extensions.lock`, `scripts/kvm/verify_rocky_cloud_image.sh`, `guest/rocky-devops/bootstrap-devops.sh` et `scripts/packages/install-rpmfusion-release.sh` — matériel : non vérifié

Cette page dit d'où vient chaque logiciel installé et comment le projet vérifie qu'il n'a pas été altéré. La liste complète des paquets est dans l'[inventaire logiciel](SOFTWARE_INVENTORY.md).

## Principes

- Préférer les dépôts officiels Fedora et Rocky Linux, puis les dépôts signés des éditeurs.
- Jamais de `curl | bash` ni de `wget | sh`.
- Épingler par version et par empreinte (SHA-256 ou signature) tout binaire téléchargé directement. Changer une version impose de changer son empreinte dans le même commit.
- Épingler les GitHub Actions par SHA de commit.
- Distinguer l'**intégrité** (le fichier correspond à l'empreinte attendue) de la **provenance** (l'empreinte vient bien de la source de confiance, par exemple par une signature).
- Rejouer chaque semaine les contrôles qui dépendent de services externes, pour voir une rupture sans attendre un commit ([CI](CI_VALIDATION.md)).

Les verrous sont des constantes vérifiées, pas des options de `config/local.conf`. La version du projet se lit dans [`VERSION`](../VERSION).

## Média d'installation Fedora 45

`installer/fedora45-media.lock` fixe le média : `Fedora-Workstation-Live-45-1.4.x86_64.iso`, son SHA-256, le fichier `CHECKSUM` qui le liste et l'empreinte de la clé Fedora 45 (`4F50 A611 4CD5 C697 6A7F 1179 655A 4B02 F577 861E`). `installer/verify-fedora-media.sh` vérifie la signature du `CHECKSUM` avec `gpgv`, puis l'empreinte de l'ISO. La procédure est dans le [guide d'installation](INSTALLATION_GUIDE.md).

## Noyau Linux amont

Le noyau vient du COPR `@kernel-vanilla/stable` (`config/kernel.conf`). Seule la version annoncée stable par kernel.org est acceptée, avec un plancher (`KERNEL_MIN_VERSION`) ; les versions RC et un COPR en retard sont refusés. Un noyau Fedora signé reste installé en secours. Le COPR est un dépôt communautaire signé par COPR. Voir [Linux amont](UPSTREAM_LINUX.md).

## Extensions GNOME

Dash to Dock et AppIndicator viennent des dépôts Fedora, aux versions exactes de `profiles/fedora45/gnome-rpms.json`. Les quatre autres sont téléchargées et verrouillées par version et SHA-256 dans `config/gnome-extensions.lock`, identique à `profiles/fedora45/gnome-extensions.lock` :

| Extension | Source | SHA-256 |
|---|---|---|
| Gtk4 DING v145 | GNOME Extensions, review 75162 | `4a884fa3976aeb814726fd96428c09cfeca2da01aec3ac8629ddd6cd22bff2c1` |
| Show Desktop Button v59 | GNOME Extensions, review 75965 | `76411e57bf5402c54bc04e5a94700c62dfb71b094ed6eac48509f609c07f6000` |
| Vitals v85 | GNOME Extensions, review 74743 | `899e5ffe27d1793cf13db069d835c11136cec816717e4e450a56f08bcf976b2f` |
| Tiling Assistant v56 | release GitHub officielle | `961da0c6b8e5960770e68a06d71205765870435dbe8fe0ccc1ec50d4cc78265a` |

Une archive dont le contenu change derrière la même URL est refusée **avant** `gnome-extensions install`. Le correctif d'arrêt de DING modifie un seul fichier, avec sa propre empreinte inscrite dans le profil ([laboratoire](FEDORA_GNOME_CI_LAB.md#correctif-darrêt-de-gtk4-ding)). Les verrous Fedora 44 ne servent qu'au [parcours historique](history/HISTORICAL_FEDORA44.md).

## Dépôts RPM Fusion

Le module `system.sources` et la CI installent `rpmfusion-free-release` et `rpmfusion-nonfree-release` par le même script, `scripts/packages/install-rpmfusion-release.sh`, depuis `mirrors.rpmfusion.org` puis `download1.rpmfusion.org`.

Le chemin normal est `dnf install` de l'URL officielle. Depuis le 3 novembre 2026, dnf5 5.4.6 refuse les paquets `45-1` : ils déclarent la dépendance `/usr/share/dnf5/libdnf.conf.d/`, avec une barre oblique finale, qu'aucun paquet ne fournit sous cette forme. Pour ce seul cas, le script installe le paquet avec `rpm -i --nodeps` après avoir vérifié :

- son nom, sa version et son architecture ;
- que ses dépendances sont exactement ce répertoire et `system-release(N)`, et que les deux sont présents ;
- sa signature, par la clé RPM Fusion épinglée du dépôt.

Les clés publiques sont versionnées dans `config/keys/`. Le script refuse un fichier dont l'empreinte diffère de celles publiées sur [rpmfusion.org/keys](https://rpmfusion.org/keys) :

| Dépôt | Empreinte |
|---|---|
| free (2020) | `E9A4 91A3 DE24 7814 E7E0 67EA E06F 8ECD D651 FF2E` |
| nonfree (2020) | `79BD B88F 9BBF 7391 0FD4 095B 6A2A F961 9484 3C65` |

Toute autre situation échoue sans rien installer. Le chemin normal ne vérifie pas la signature du paquet de configuration installé depuis une URL (dnf l'annonce : « skipped OpenPGP checks ») ; les paquets installés ensuite depuis les dépôts RPM Fusion sont, eux, vérifiés par dnf. `tests/test_rpmfusion_release_behavior.sh` exerce le chemin normal, le repli et chaque refus.

## Applications de l'hôte

`manifests/application-provenance.tsv` donne la classe de confiance de chaque application : dépôt Fedora, dépôt éditeur signé (VS Code, Brave) ou Flathub. Une application Flathub publiée par la communauté n'est jamais présentée comme officielle.

Une entrée classée `community-unverified` n'est installable que si son identifiant figure aussi dans `UNVERIFIED_FLATHUB_ALLOWLIST`. Cette liste fait de l'exception une décision versionnée et testable, et non une simple note. La résolution des identifiants Flathub est contrôlée en CI ; la provenance est revue à chaque release.

## Image Rocky Linux Cloud

La création de `rocky-devops` n'accepte pas une image locale sur son seul nom. L'image est conservée avec sa liste d'empreintes signée :

```text
Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
CHECKSUM
CHECKSUM.asc
```

`scripts/kvm/verify_rocky_cloud_image.sh` :

1. part de l'empreinte de la clé Rocky Linux épinglée dans le script ;
2. importe une clé locale fournie explicitement, ou la télécharge en HTTPS depuis dl.rockylinux.org ;
3. vérifie que l'empreinte importée est exactement celle attendue ;
4. vérifie la signature de `CHECKSUM` par la clé de production Rocky 10 (une sous-clé de signature valide est acceptée) ;
5. exige une seule ligne associant le nom versionné à un SHA-256, et compare l'image.

`scripts/kvm/create_rocky_devops_vm.sh` exige `--cloud-image /chemin/image.qcow2` et appelle ce contrôle avant de créer le moindre disque. `CHECKSUM` et `CHECKSUM.asc` doivent accompagner l'image ; `--sha256sums` et `--signature` permettent d'indiquer d'autres chemins. Cette vérification ne peut pas être désactivée. Le laboratoire Rocky de la CI utilise lui aussi une liste signée.

## Outils de la VM Rocky DevOps

- `kubectl` vient de `pkgs.k8s.io`, limité à la branche `v1.37` ; les correctifs de cette branche sont acceptés.
- kind, Minikube, Helm, yq, K9s, kubectx et kubens ont une version et un SHA-256 versionnés dans `guest/rocky-devops/bootstrap-devops.sh`. L'empreinte n'est jamais lue à côté du binaire : un serveur qui changerait à la fois le binaire et son empreinte serait refusé. EPEL 10.2 ne fournit pas de RPM kubectx, d'où l'archive officielle.
- AWS CLI v2 est téléchargé avec sa signature détachée, vérifiée par la clé AWS dont l'empreinte est versionnée.

Les versions sont dans l'[inventaire](SOFTWARE_INVENTORY.md#23-outils-hors-paquets-versions-épinglées).

## Accès distant (optionnel)

Rien n'est installé sans `REMOTE_ENABLE="true"`.

- **Tailscale** : dépôt éditeur `pkgs.tailscale.com`, défini dans `config/repos/tailscale.repo`. Les métadonnées et les paquets sont vérifiés (`repo_gpgcheck=1` et `gpgcheck=1`), comme l'exigent les contrats du projet. Avant la première installation, comparer encore cette définition à la publication officielle : la présence de clés et de directives ne prouve pas à elle seule la provenance.
- **Sunshine** : COPR `lizardbyte/stable` du projet amont, seulement avec `REMOTE_SUNSHINE_ENABLE="true"`. Même classe de confiance que le COPR du noyau ; la valeur est contrainte par `config/schema-enums.tsv`.
- Aucun port exposé à Internet.

## Mises à jour

- RPM Fedora : téléchargement automatique autorisé ; installation et redémarrage automatiques interdits.
- Flatpak : mise à jour manuelle, par GNOME Software ou `flatpak update`. Le projet ne crée aucun timer de mise à jour Flatpak.

## Ce que la CI apporte

Les prétests de paquets, d'intégration de l'hôte et de la VM Rocky sont rejoués chaque semaine. Ils détectent la disparition d'un dépôt, un changement de clé ou de signature, un identifiant Flathub disparu, une release externe incompatible et une rupture du bootstrap.

La CI complète la provenance ; elle ne remplace ni la qualification du matériel ni la responsabilité de l'opérateur sur les médias qu'il fournit lui-même.

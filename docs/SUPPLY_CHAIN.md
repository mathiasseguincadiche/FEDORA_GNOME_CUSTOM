# Supply-chain et provenance

Les archives d’extensions de la référence **Fedora 45 / GNOME 51** sont centralisées dans `config/gnome-extensions.lock`, identique à `profiles/fedora45/gnome-extensions.lock`. Ces verrous sélectionnent les artefacts revus pour la préparation ; l’APPLY exige toujours le profil promu. Les verrous Fedora 44 sont réservés au [parcours historique](HISTORICAL_FEDORA44.md).

La version actuelle du projet se lit dans [`VERSION`](../VERSION), jamais
dans une ancienne notice historique. Les verrous sont des constantes de
provenance vérifiées et non des options libres de `config/local.conf`.

## Principes

- préférer Fedora/Rocky Linux officiels et des dépôts éditeurs signés ;
- ne jamais utiliser `curl | bash` / `wget | sh` ;
- épingler par version et checksum/signature les binaires téléchargés directement ;
- épingler les GitHub Actions à un SHA immuable ;
- distinguer **intégrité** (le fichier correspond au hash attendu) et **provenance** (le hash/signature vient bien de la source de confiance) ;
- exécuter périodiquement les prétests dépendant de services externes afin de détecter une rupture sans attendre un commit.

## Image Rocky Linux Cloud

La création de `rocky-devops` n'accepte plus une image locale sur son seul nom.

L'opérateur conserve ensemble :

```text
Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
CHECKSUM
CHECKSUM.asc
```

`scripts/kvm/verify_rocky_cloud_image.sh` :

1. utilise l'empreinte Rocky Linux cloud-image attendue, épinglée dans le script ;
2. importe une clé locale fournie explicitement ou récupère cette clé par HTTPS sur dl.rockylinux.org ;
3. vérifie que l'empreinte importée est exactement celle attendue ;
4. vérifie la signature GPG de `CHECKSUM` liée à la clé de production Rocky 10 (une sous-clé de signature valide est acceptée) ;
5. exige une seule ligne associant le nom versionné au SHA-256 et compare le hash de l'image.

`create_rocky_devops_vm.sh` exige `--cloud-image /chemin/image.qcow2` et appelle ce contrôle avant toute création de disque. Par défaut, `CHECKSUM` et `CHECKSUM.asc` doivent accompagner l’image dans le même dossier ; `--sha256sums` et `--signature` permettent de préciser leurs chemins. L’authentification de l’image ne peut pas être désactivée.

Le vrai prétest Rocky Linux CI utilise lui aussi une liste SHA-256 signée Rocky Linux.

## VM Rocky DevOps — bootstrap

- Kubernetes est limité à la génération `v1.37.x` ; les patchs restent fournis par `pkgs.k8s.io` ;
- kind est épinglé à `v0.33.0` et vérifié avec le checksum publié ;
- Minikube est épinglé à `v1.38.1` et vérifié avec son SHA-256 publié ;
- yq `v4.53.3` et K9s `v0.51.0` ont des SHA-256 attendus versionnés ;
- Helm v4.3.0 utilise l'archive officielle get.helm.sh et son SHA-256 publié ;
- AWS CLI v2 est téléchargé sous forme de ZIP + signature détachée, puis la signature est vérifiée avec la clé AWS et l'empreinte attendue versionnée.

## Applications du HOST

`manifests/application-provenance.tsv` documente la classe de confiance.

Les paquets Flathub communautaires ne sont pas présentés comme des paquets officiels de l'éditeur. La résolution des IDs Flathub est contrôlée en CI ; la provenance est revue lors des releases.

## Mises à jour

- RPM Fedora : téléchargement automatique autorisé, installation et reboot automatiques interdits ;
- Flatpak : mise à jour volontairement manuelle via GNOME Software ou `flatpak update` ; aucun timer de mise à jour Flatpak n'est créé par le projet.

## CI

Les prétests package Fedora, intégration host et Rocky Linux VM sont rejoués périodiquement afin de détecter :

- disparition d'un dépôt ;
- changement de clé/signature ;
- App ID Flathub disparu ;
- release externe incompatible ;
- rupture de bootstrap.

La CI complète la provenance et la reproductibilité ; elle ne remplace pas la validation du matériel physique ni la responsabilité de l’opérateur sur les médias invités fournis manuellement.

## Accès distant (profil optionnel)

Activé seulement par `REMOTE_ENABLE="true"` ; rien n'est téléchargé sinon.

- **Tailscale** : dépôt éditeur `pkgs.tailscale.com`, fichier versionné dans `config/repos/tailscale.repo`. Les **métadonnées et les paquets RPM** sont soumis aux contrôles de signature (`repo_gpgcheck=1` et `gpgcheck=1`), exigés par les contrats du projet. Cette configuration doit encore être comparée à la publication officielle avant la première installation : la présence de clés et de directives n'est pas à elle seule une preuve de provenance.
- **Sunshine** : COPR `lizardbyte/stable` du projet amont, uniquement avec `REMOTE_SUNSHINE_ENABLE="true"`. Le COPR est un dépôt communautaire signé par COPR : même classe de confiance que le COPR noyau, et le seul tiers du profil. La valeur est contrainte par `config/schema-enums.tsv`.
- **Aucun** `curl | bash`, aucun binaire téléchargé hors dépôt, aucun port exposé à Internet.

## Extensions GNOME revues

Les extensions téléchargées directement depuis GNOME Extensions sont verrouillées par review, version **et SHA-256** :

```text
Gtk4 DING 75162 / v145          4a884fa3976aeb814726fd96428c09cfeca2da01aec3ac8629ddd6cd22bff2c1
Show Desktop Button 75965 / v59 76411e57bf5402c54bc04e5a94700c62dfb71b094ed6eac48509f609c07f6000
Vitals 74743 / v85             899e5ffe27d1793cf13db069d835c11136cec816717e4e450a56f08bcf976b2f
Tiling Assistant v56          961da0c6b8e5960770e68a06d71205765870435dbe8fe0ccc1ec50d4cc78265a
```

Un changement de contenu derrière une URL review existante est refusé **avant** `gnome-extensions install`.

## Exceptions Flathub communautaires

Les entrées classées `community-unverified` dans `manifests/application-provenance.tsv` ne sont installables que si leur App ID figure aussi dans `UNVERIFIED_FLATHUB_ALLOWLIST`. Cette allowlist transforme l'exception de confiance en décision versionnée et testable au lieu d'une simple note documentaire.

Kubectx/kubens v0.11.0 sont installés depuis les archives officielles ahmetb/kubectx avec leurs SHA-256 versionnés : aucun RPM kubectx n'est fourni par EPEL 10.2 au moment de la qualification.

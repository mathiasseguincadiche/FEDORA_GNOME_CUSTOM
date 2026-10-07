# Supply-chain et provenance

Les références exécutables des quatre extensions téléchargées sont centralisées dans
[`config/gnome-extensions.lock`](../config/gnome-extensions.lock). Les numéros cités
ci-dessous décrivent la version 0.16.0 ; le lock reste la référence à mettre à jour.
Les clés de ce fichier sont des constantes vérifiées, pas des options `local.conf`.


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

`create_rocky_devops_vm.sh` appelle ce contrôle avant toute création de disque.

Le vrai prétest Rocky Linux CI utilise lui aussi une liste SHA-256 signée Rocky Linux.

## VM Rocky DevOps — bootstrap

- Kubernetes est limité à la génération `v1.37.x` ; les patchs restent fournis par `pkgs.k8s.io` ;
- kind est épinglé à `v0.33.0` et vérifié avec le checksum publié ;
- Minikube est épinglé à `v1.38.1` et vérifié avec son SHA-256 publié ;
- yq `v4.53.3` et K9s `v0.51.0` ont des SHA-256 attendus versionnés ;
- Helm v4.3.0 utilise l'archive officielle get.helm.sh et son SHA-256 publié ;
- AWS CLI v2 est téléchargé sous forme de ZIP + signature détachée, puis la signature est vérifiée avec la clé AWS et l'empreinte attendue versionnée.

## Médias Windows / VirtIO

Le projet ne télécharge silencieusement ni Windows 11 ni `virtio-win.iso`.

Ils restent sous la responsabilité explicite de l'opérateur :

- ISO Windows depuis Microsoft ;
- VirtIO-Win depuis une source Fedora/Red Hat de confiance ;
- SHA-256 attendus obtenus indépendamment depuis des sources de confiance.

`create_windows11_vm.sh` **exige** :

```text
--windows-sha256 <hash-de-confiance>
--virtio-sha256 <hash-de-confiance>
```

Les deux valeurs sont obligatoires ensemble. Si l'une manque, la création est refusée. Les deux fichiers sont vérifiés **avant** `qemu-img create`.

Important : calculer soi-même le SHA-256 d'un fichier déjà compromis puis fournir ce même hash ne prouve rien. Le digest attendu doit provenir d'une source de confiance indépendante.

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

La CI complète la provenance et la reproductibilité ; elle ne remplace pas la validation du matériel physique ni la responsabilité de l'opérateur sur les médias Windows fournis manuellement.

## Accès distant (profil optionnel)

Activé seulement par `REMOTE_ENABLE="true"` ; rien n'est téléchargé sinon.

- **Tailscale** : dépôt éditeur `pkgs.tailscale.com`, définition dans `config/repos/tailscale.repo`. Les **métadonnées** du dépôt sont signées (`repo_gpgcheck=1`), les paquets ne le sont pas dans la définition publiée par l'éditeur (`gpgcheck=0`) : la confiance repose donc sur la signature du dépôt et sur TLS. La définition est reproduite **sans avoir pu être relue à la source** depuis l'environnement de rédaction : la comparer avec la version publiée avant la première installation.
- **Sunshine** : COPR `lizardbyte/stable` du projet amont, uniquement avec `REMOTE_SUNSHINE_ENABLE="true"`. Le COPR est un dépôt communautaire signé par COPR : même classe de confiance que le COPR noyau, et le seul tiers du profil. La valeur est contrainte par `config/schema-enums.tsv`.
- **Aucun** `curl | bash`, aucun binaire téléchargé hors dépôt, aucun port exposé à Internet.

## Extensions GNOME revues

Les extensions téléchargées directement depuis GNOME Extensions sont verrouillées par review, version **et SHA-256** :

```text
DING 74408 / v95             48175f0b5c1f8a1a724d761198c91d6994e91e28aec685605ae6a240b0a95aae
Show Desktop Plus 70326 / v8 9ceab00be63b93c4eade16cf804bf4edd587632750aa89b78e317673fd6016a9
Resource Monitor 70909 / v28  18f49cf20bd8f96f22f6048d7404e51cb414c1aea94ca16d0c2ad3634e9d8bf2
```

Un changement de contenu derrière une URL review existante est refusé **avant** `gnome-extensions install`.

## Exceptions Flathub communautaires

Les entrées classées `community-unverified` dans `manifests/application-provenance.tsv` ne sont installables que si leur App ID figure aussi dans `UNVERIFIED_FLATHUB_ALLOWLIST`. Cette allowlist transforme l'exception de confiance en décision versionnée et testable au lieu d'une simple note documentaire.

Kubectx/kubens v0.11.0 sont installés depuis les archives officielles ahmetb/kubectx avec leurs SHA-256 versionnés : aucun RPM kubectx n'est fourni par EPEL 10.2 au moment de la qualification.

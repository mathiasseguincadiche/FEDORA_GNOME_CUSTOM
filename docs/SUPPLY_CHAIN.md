# Supply-chain et provenance

## Principes

- préférer Fedora/Ubuntu officiels et des dépôts éditeurs signés ;
- ne jamais utiliser `curl | bash` / `wget | sh` ;
- épingler par version et checksum/signature les binaires téléchargés directement ;
- épingler les GitHub Actions à un SHA immuable ;
- distinguer **intégrité** (le fichier correspond au hash attendu) et **provenance** (le hash/signature vient bien de la source de confiance) ;
- exécuter périodiquement les prétests dépendant de services externes afin de détecter une rupture sans attendre un commit.

## Image Ubuntu Cloud

La création de `ubuntu-devops` n'accepte plus une image locale sur son seul nom.

L'opérateur conserve ensemble :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

`scripts/kvm/verify_ubuntu_cloud_image.sh` :

1. utilise l'empreinte Canonical cloud-image attendue, épinglée dans le script ;
2. importe une clé locale fournie explicitement ou récupère cette clé depuis le keyserver Ubuntu ;
3. vérifie que l'empreinte importée est exactement celle attendue ;
4. vérifie la signature GPG de `SHA256SUMS` ;
5. vérifie le SHA-256 de l'image.

`create_ubuntu_devops_vm.sh` appelle ce contrôle avant toute création de disque.

Le vrai prétest Ubuntu CI utilise lui aussi une liste SHA-256 signée Canonical.

## VM Ubuntu DevOps — bootstrap

- Kubernetes est limité à la génération `v1.37.x` ; les patchs restent fournis par `pkgs.k8s.io` ;
- kind est épinglé à `v0.33.0` et vérifié avec le checksum publié ;
- Minikube est épinglé à `v1.38.1` et vérifié avec son SHA-256 publié ;
- yq `v4.53.3` et K9s `v0.51.0` ont des SHA-256 attendus versionnés ;
- Helm vérifie l'empreinte de la clé du dépôt ;
- AWS CLI v2 est téléchargé sous forme de ZIP + signature détachée, puis la signature est vérifiée avec la clé AWS et l'empreinte attendue versionnée.

## Médias Windows / VirtIO

Le projet ne télécharge silencieusement ni Windows 11 ni `virtio-win.iso`.

Ils restent sous la responsabilité explicite de l'opérateur :

- ISO Windows depuis Microsoft ;
- VirtIO-Win depuis la source Fedora/Red Hat de confiance utilisée par l'opérateur.

`create_windows11_vm.sh` accepte :

```text
--windows-sha256 <hash-de-confiance>
--virtio-sha256 <hash-de-confiance>
```

Lorsque ces valeurs sont fournies, les deux fichiers sont vérifiés **avant** création du disque.

Important : calculer soi-même le SHA-256 d'un fichier compromis puis fournir ce même hash ne prouve rien. Le hash attendu doit provenir d'une source de confiance indépendante.

## Applications du HOST

`manifests/application-provenance.tsv` documente la classe de confiance.

Les paquets Flathub communautaires ne sont pas présentés comme des paquets officiels de l'éditeur. La résolution des IDs Flathub est contrôlée en CI ; la provenance est revue lors des releases.

## Mises à jour

- RPM Fedora : téléchargement automatique autorisé, installation et reboot automatiques interdits ;
- Flatpak : mise à jour volontairement manuelle via GNOME Software ou `flatpak update` ; aucun timer de mise à jour Flatpak n'est créé par le projet.

## CI

Les prétests package Fedora, intégration host et Ubuntu VM sont rejoués périodiquement afin de détecter :

- disparition d'un dépôt ;
- changement de clé/signature ;
- App ID Flathub disparu ;
- release externe incompatible ;
- rupture de bootstrap.

La CI complète la provenance et la reproductibilité ; elle ne remplace pas la validation du matériel physique ni la responsabilité de l'opérateur sur les médias Windows fournis manuellement.

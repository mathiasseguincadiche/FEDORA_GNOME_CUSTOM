# Supply-chain et provenance

## Principes

- préférer Fedora/Ubuntu officiels et des dépôts éditeurs signés ;
- ne jamais utiliser `curl | bash` / `wget | sh` ;
- épingler par version et checksum/signature les binaires téléchargés directement ;
- épingler les GitHub Actions à un SHA immuable ;
- exécuter chaque semaine les prétests dépendant de services externes afin de détecter une rupture sans attendre un commit.

## VM Ubuntu DevOps

- Kubernetes est limité à la génération `v1.37.x` ; les patchs restent fournis par le dépôt officiel `pkgs.k8s.io` ;
- kind est épinglé à `v0.33.0` et vérifié avec le checksum publié de la release ;
- Minikube est épinglé à `v1.38.1` et vérifié avec son SHA-256 publié ;
- yq `v4.53.3` et K9s `v0.51.0` ont des SHA-256 attendus versionnés ;
- Helm vérifie l'empreinte de la clé du dépôt ;
- AWS CLI v2 est téléchargé sous forme de ZIP + signature détachée, et la signature est vérifiée avec la clé publique AWS dont l'empreinte attendue est `FB5D B77F D5C1 18B8 0511 ADA8 A631 0ACC 4672 475C`.

## Applications du host

`manifests/application-provenance.tsv` documente la classe de confiance. Les paquets Flathub communautaires ne sont pas présentés comme des paquets officiels de l'éditeur. La résolution des IDs Flathub est contrôlée en CI ; la provenance est revue lors des releases.

## Mises à jour

- RPM Fedora : téléchargement automatique autorisé, installation et reboot automatiques interdits ;
- Flatpak : mise à jour volontairement manuelle via GNOME Software ou `flatpak update` ; aucun timer de mise à jour Flatpak n'est créé par le projet.

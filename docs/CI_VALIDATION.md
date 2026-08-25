# CI et validation bout-en-bout

La CI du projet ne se limite plus à ShellCheck.

## Tests de contrats

`.github/workflows/tests.yml` valide la structure, les politiques hardware/GNOME, les applications, le multimédia, KVM, le bootstrap Ubuntu, l'accès Nautilus SFTP/SMB, le backup/recovery et le contrat de maturité CI.

## Shell quality

Tous les fichiers Bash suivis par Git sont vérifiés par `bash -n` et ShellCheck.

## Fedora 44 package preflight

Le preflight historique vérifie la résolution des manifests, RPM Fusion, les dépôts VS Code/Brave, Flathub, les swaps multimédia et la compatibilité GNOME 50 des extensions.

## Fedora 44 host integration pretest

`.github/workflows/fedora-host-pretest.yml` va plus loin : dans un conteneur **Fedora 44**, il installe réellement l'ensemble des packages Fedora natifs du contrat HOST/GNOME/KVM, les outils backup, réalise les swaps multimédia et valide les dépôts/Flatpaks/extensions.

## Architecture non-regression

`.github/workflows/non-regression.yml` bloque notamment :

- ouverture accidentelle du gate machine réelle ;
- changement vers X11 comme contrat ;
- activation de Just Perfection, `force_probe`, VFIO/GPU passthrough ;
- retour de VirtioFS ;
- suppression de l'isolation réseau KVM ;
- flush global nftables/iptables ;
- commandes de formatage/partitionnement dans les modules ;
- assouplissement du contrat backup fail-closed ;
- patterns évidents de secrets versionnés.

## Ubuntu 26.04 real VM pretest

`.github/workflows/vm-pretest.yml` télécharge l'image cloud officielle Ubuntu Server 26.04, vérifie la signature Canonical des `SHA256SUMS`, vérifie le SHA-256 de l'image puis démarre une **vraie VM QEMU** (KVM si disponible, TCG sinon).

Dans cette VM, le workflow :

1. crée `mathias` par cloud-init et valide SSH ;
2. vérifie Ubuntu 26.04, DNS et Internet ;
3. copie **exactement** `guest/ubuntu-devops/bootstrap-devops.sh` du dépôt ;
4. exécute le bootstrap réel ;
5. exécute `verify-devops.sh` ;
6. lance `docker run --rm hello-world` ;
7. redémarre la VM ;
8. vérifie la persistance de Docker, Terraform, kubectl et du service Docker ;
9. publie report, console, bootstrap et verify logs comme artifacts GitHub Actions.

Cette CI complète les certifications sur la machine réelle ; elle ne remplace pas les tests Intel Arc, GNOME/Wayland, suspend/resume, `/data`, Secure Boot/TPM Windows ou l'isolation du LAN qui nécessitent le matériel final.

# Rocky DevOps Ready

La VM `rocky-devops` est un Rocky Linux 10.2 dédié aux labs/projets DevOps, créé à la demande sur `qemu:///system` et stocké sur `/data`.

La version applicable est celle de [`../VERSION`](../VERSION).

## Profil

- 6 vCPU `host-passthrough` ;
- 16 Gio RAM ;
- qcow2 160 Gio ;
- Q35 + UEFI ;
- disque/réseau VirtIO ;
- `devops-nat` ;
- QEMU Guest Agent ;
- VirtIO RNG ;
- balloon mémoire ;
- aucun GPU passthrough ;
- aucun autostart.

## Image source authentifiée

Avant toute création de disque, le workflow exige :

```text
Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
CHECKSUM
CHECKSUM.asc
```

Le script `scripts/kvm/verify_rocky_cloud_image.sh` :

1. importe/récupère la clé de signature Rocky Linux attendue ;
2. compare son empreinte à la valeur épinglée dans le script ;
3. vérifie la signature de `CHECKSUM` ;
4. extrait le checksum de l'image choisie ;
5. vérifie le SHA-256 réel de l'image.

`create_rocky_devops_vm.sh` appelle ce contrôle avant `qemu-img convert`.

Cela évite qu'une image locale soit considérée fiable uniquement parce qu'elle porte le bon nom.

## Stack prête après le premier bootstrap

- Git/Git LFS, `gh`, `glab` ;
- Docker CE, Compose v2, Buildx, containerd ;
- kubectl **v1.37.x**, Helm, kind **v0.33.0**, Minikube **v1.38.1** avec driver Docker, K9s, kubectx/kubens, yq v4 ;
- Terraform, Ansible ;
- AWS CLI v2, Azure CLI ;
- Node.js ≥ 22, npm, Corepack ;
- OpenJDK 21, Maven ;
- Python 3/pip/venv/pipx ;
- ShellCheck, jq, ripgrep, rsync, SSH, tmux et outils réseau.

Les identifiants GitHub/GitLab/AWS/Azure restent manuels : aucun token n'est embarqué.

## Authentification

Le script de création demande un mot de passe runtime afin de conserver un accès **console/sudo**.

SSH est différent :

```text
ssh_pwauth: false
root désactivé
clé publique injectée
```

`verify-devops.sh` exige `PasswordAuthentication no` dans la configuration effective de `sshd`.

## Supply-chain du bootstrap

Aucun `curl | bash`.

- RPM/DNF + paquets signés pour Rocky Linux/EPEL/Docker/GitHub/HashiCorp/Azure/Kubernetes ;
- Kubernetes limité à la génération `v1.37` ;
- kind v0.33.0 et Minikube v1.38.1 avec checksums publiés ;
- yq v4.53.3 et K9s v0.51.0 avec SHA-256 attendus versionnés ;
- Helm v4.3.0, SHA-256 amont publié ;
- AWS CLI v2 depuis ZIP + signature détachée vérifiée avec la clé AWS attendue.

Voir [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md).

## Création

Placer l'image et ses deux fichiers de vérification signés dans le même dossier, puis :

```bash
scripts/kvm/create_rocky_devops_vm.sh \
  --cloud-image /data/libvirt/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
```

Pour une clé Rocky Linux locale obtenue par un canal de confiance :

```bash
scripts/kvm/create_rocky_devops_vm.sh \
  --cloud-image /data/libvirt/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2 \
  --rocky-key-file /chemin/RPM-GPG-KEY-Rocky-10
```

Le bootstrap et le verify exacts du checkout HOST sont encodés dans cloud-init. Le premier démarrage exécute `/usr/local/sbin/devops-bootstrap.sh`.

## Validation

Dans la VM :

```bash
sudo /usr/local/sbin/devops-verify.sh
```

Depuis Fedora :

```bash
scripts/kvm/runtime_certification.sh
```

Le workflow CI `Rocky Linux 10.2 real VM pretest` authentifie lui aussi une image Rocky Linux, exécute le bootstrap exact, smoke-test Docker/Node/Java/Kubernetes/cloud/IaC, redémarre la VM et vérifie la persistance.

Il est exigé avant fusion et tourne périodiquement afin de détecter une rupture de dépôt, clé, signature ou release externe.

## Accès aux fichiers

Fedora → Rocky reste en SSH/SFTP via Nautilus/GIO. Aucun partage HOST VirtioFS n'est introduit.

Voir [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md) et [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md).

## Transition depuis une ancienne VM Ubuntu

Il n'existe pas de conversion en place entre Ubuntu et Rocky. Conserver l'ancienne VM arrêtée, son XML et son archive Borg avec les disques/NVRAM avant de créer rocky-devops. Ne pas renommer un disque Ubuntu en Rocky. Transférer les dépôts et données par SSH/SFTP, recréer les environnements Python, images/volumes et clusters avec leurs outils, puis vérifier les résultats côté Rocky. Les identifiants restent saisis manuellement.

Le nouveau nom de domaine évite d'écraser l'ancien disque. Une ancienne clé UBUNTU_SERVER_* dans config/local.conf doit être retirée ou remplacée après revue : le validateur la refuse. Les preuves de certification antérieures deviennent obsolètes avec le nouveau profil. Rafraîchir les favoris Nautilus et certifier le nouvel invité avant de retirer l'ancien.

Le test GitHub exigé par contracts démarre Rocky 10.2 en Q35/UEFI, valide le bootstrap, Docker et les outils, prouve le changement d'identifiant de démarrage, arrête la VM, archive qcow2/NVRAM/seed avec Borg sans chiffrement, supprime les sources, contrôle les SHA-256 restaurés et redémarre uniquement la copie restaurée avec réseau QEMU restrict=on (SSH localhost autorisé, sorties réseau bloquées). Il ne certifie pas les périphériques physiques ni Windows.

La certification HOST ouvre un terminal SSH pour demander le mot de passe sudo de la VM. Le compte opérateur conserve un sudo authentifié ; aucun sudo illimité sans mot de passe n'est provisionné. Le sudo sans mot de passe du compte CI reste limité à une VM jetable de laboratoire.

Le noyau de l'invité est celui maintenu par Rocky Linux pour Enterprise Linux 10. Le suivi Linux amont stable N/N-1 concerne le HOST Fedora et ne remplace pas le noyau Rocky.

Kubectx/kubens v0.11.0 sont installés depuis les archives officielles ahmetb/kubectx avec leurs SHA-256 versionnés : aucun RPM kubectx n'est fourni par EPEL 10.2 au moment de la qualification.

Rocky Linux 10 requiert un processeur x86-64-v3. Le profil host-passthrough expose les capacités du Ryzen 7 7700 ; masquer AVX2 dans un modèle CPU générique empêcherait le démarrage. Le laboratoire utilise CPU host en KVM, max en émulation.

Le transfert porte sur les données applicatives ; ne pas recopier les répertoires système Ubuntu (/etc, /usr, base de paquets) dans Rocky. Vérifier les UID/GID, les propriétaires des volumes et les empreintes SSH du nouvel invité. Si une adresse IP est réutilisée, revoir l'entrée connue correspondant à cette seule VM après comparaison de la nouvelle clé ; ne pas effacer l'ensemble des clés connues.

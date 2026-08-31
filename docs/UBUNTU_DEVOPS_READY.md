# Ubuntu DevOps Ready

La VM `ubuntu-devops` est un Ubuntu Server 26.04 dédié aux labs/projets DevOps, créé à la demande sur `qemu:///system` et stocké sur `/data`.

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
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

Le script `scripts/kvm/verify_ubuntu_cloud_image.sh` :

1. importe/récupère la clé de signature Canonical attendue ;
2. compare son empreinte à la valeur épinglée dans le script ;
3. vérifie la signature de `SHA256SUMS` ;
4. extrait le checksum de l'image choisie ;
5. vérifie le SHA-256 réel de l'image.

`create_ubuntu_devops_vm.sh` appelle ce contrôle avant `qemu-img convert`.

Cela évite qu'une image locale soit considérée fiable uniquement parce qu'elle porte le bon nom.

## Stack prête après le premier bootstrap

- Git/Git LFS, `gh`, `glab` ;
- Docker CE, Compose v2, Buildx, containerd ;
- kubectl **v1.37.x**, Helm, kind **v0.33.0**, Minikube **v1.38.1** avec driver Docker, K9s, kubectx/kubens, yq v4 ;
- Terraform, Ansible ;
- AWS CLI v2, Azure CLI ;
- Node.js 22 LTS, npm, Corepack ;
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

- APT + dépôts signés pour Ubuntu/Docker/GitHub/HashiCorp/Azure/Kubernetes/Helm ;
- Kubernetes limité à la génération `v1.37` ;
- kind v0.33.0 et Minikube v1.38.1 avec checksums publiés ;
- yq v4.53.3 et K9s v0.51.0 avec SHA-256 attendus versionnés ;
- Helm avec contrôle de l'empreinte de clé du dépôt ;
- AWS CLI v2 depuis ZIP + signature détachée vérifiée avec la clé AWS attendue.

Voir [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md).

## Création

Placer l'image et ses deux fichiers de vérification signés dans le même dossier, puis :

```bash
scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Pour une clé Canonical locale obtenue par un canal de confiance :

```bash
scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img \
  --canonical-key-file /chemin/cle-canonical.asc
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

Le workflow CI `Ubuntu 26.04 real VM pretest` authentifie lui aussi une image Canonical, exécute le bootstrap exact, smoke-test Docker/Node/Java/Kubernetes/cloud/IaC, redémarre la VM et vérifie la persistance.

Il tourne périodiquement afin de détecter une rupture de dépôt, clé, signature ou release externe.

## Accès aux fichiers

Fedora → Ubuntu reste en SSH/SFTP via Nautilus/GIO. Aucun partage HOST VirtioFS n'est introduit.

Voir [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md) et [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md).

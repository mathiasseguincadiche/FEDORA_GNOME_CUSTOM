# KVM au quotidien

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — cycle de vie de l'invité et encadré de non-retour relus contre `scripts/kvm/`, profil contre `config/vm-profiles.conf`, non rejoué — matériel : non vérifié

Créer, utiliser et dépanner la VM Rocky DevOps. L'architecture et le contenu du profil sont dans la [référence virtualisation](VIRTUALIZATION.md), l'isolation réseau dans le [réseau KVM](KVM_NETWORK.md).

**À la fin de ce guide :** créer la VM Rocky DevOps depuis une image authentifiée, s'y connecter par clé SSH, la qualifier et diagnostiquer une panne courante. Le rôle du garde réseau est expliqué dans les [notions clés](CONCEPTS.md#7-le-garde-réseau-isole-les-vm-du-réseau-local).

Rocky se crée **après** l'installation de Fedora et les premiers contrôles de l'hôte, et **avant** la certification finale (Gate 3). Le Live USB et l'installation n'exigent aucune VM ; l'APPLY n'en crée jamais.

```text
Hôte Fedora
├── connexion libvirt : qemu:///system
├── pool              : devops-data → /data/libvirt/images
├── réseau            : devops-nat  → virbr50 → 192.168.50.0/24
└── VM                : rocky-devops
```

Une règle pour tout ce qui suit : ne jamais désactiver SELinux, firewalld ou le garde nftables pour contourner un problème, ne pas retoucher le XML du domaine au hasard, ne pas copier un QCOW2 en cours d'utilisation comme un fichier ordinaire.

## 1. Vérifier le socle

```bash
./control.sh doctor data
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

**Réussite :** `virtualization-doctor` sans `KO` : `/dev/kvm`, `kvm_amd`, `qemu:///system`, pool `devops-data`, réseau `devops-nat`, SELinux Enforcing, firewalld, garde nftables, OVMF et swtpm. Le benchmark écrit sur un fichier de `/data`, jamais sur le disque brut. **Arrêt :** un `KO` se corrige avant de créer la VM ([dépannage](#dépannage)).

## 2. Créer Rocky DevOps

Placer l'image, `CHECKSUM` et `CHECKSUM.asc` de la même release dans `/data/libvirt/iso` (détails dans la [référence](VIRTUALIZATION.md#image-source-authentifiée)), puis :

```bash
./control.sh kvm create-rocky \
  --cloud-image /data/libvirt/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
```

`CHECKSUM` et `CHECKSUM.asc` sont cherchés à côté de l'image ; sinon, les passer avec `--sha256sums` et `--signature`. Une clé Rocky obtenue par un canal de confiance se passe avec `--rocky-key-file`, une autre clé SSH publique avec `--ssh-key`. Pour vérifier l'image seule avant création : `bash scripts/kvm/verify_rocky_cloud_image.sh --image … --sha256sums … --signature …`.

Le script authentifie l'image **avant** de créer le disque, demande le mot de passe console/sudo sans l'afficher, injecte la clé SSH, génère cloud-init et crée la VM sans autostart. Au premier démarrage, l'invité installe sa stack ; il peut redémarrer une fois pour passer sur le noyau Rocky complet.

**Réussite :** `virsh --connect qemu:///system list --all` montre `rocky-devops`, puis `sudo cloud-init status --long` dans l'invité finit par `status: done`. **Arrêt :** si l'image est refusée, rien n'a été créé ; corriger la cause signalée ([image refusée](#dépannage)). Le script refuse aussi de continuer si le domaine, son disque ou son dossier cloud-init existent déjà : il n'écrase jamais une VM.

## 3. Utiliser

**Pour te connecter**, vérifier que le domaine existe, le démarrer **s'il est arrêté**, puis attendre que son réseau et son agent invité soient prêts :

```bash
virsh --connect qemu:///system list --all
virsh --connect qemu:///system start rocky-devops
virsh --connect qemu:///system domifaddr rocky-devops --source agent
ssh mathias@192.168.50.x  # remplacer x par l'adresse réellement relevée
```

**Pour arrêter proprement Rocky après ton travail** (et non avant la connexion SSH) :

```bash
virsh --connect qemu:///system shutdown rocky-devops
virsh --connect qemu:///system domstate rocky-devops  # attendre « shut off »
```

L'utilisateur de l'invité est fixé par `ROCKY_SERVER_USERNAME` dans `config/vm-profiles.conf` (`mathias`) ; l'adresse vient de la commande `domifaddr`. Si l'agent ne renvoie pas encore d'adresse, patienter puis consulter les baux avec `virsh --connect qemu:///system net-dhcp-leases devops-nat` ; ne pas deviner l'IP. Si Rocky est déjà démarré, **ne pas relancer** `start` : passer à `domifaddr`. `virsh destroy` équivaut à couper l'alimentation : réservé au dépannage. SSH accepte uniquement la clé ; le mot de passe sert à la console et à `sudo`. `virt-manager --connect qemu:///system` reste disponible, mais tout se fait en ligne de commande.

### Fichiers de la VM dans Nautilus

```bash
./control.sh kvm nautilus-refresh
```

Le script découvre l'IP de Rocky (Guest Agent ou bail DHCP) et crée ou met à jour le favori `sftp://mathias@192.168.50.x/home/mathias` dans `~/.config/gtk-3.0/bookmarks`. Relancer après un changement d'IP. Autres actions de `scripts/kvm/configure_nautilus_vm_access.sh` : `show`, `remove` (retire seulement ce favori), `open-rocky`. L'accès garde les permissions réelles de `mathias` ; aucun répertoire de l'hôte n'est partagé.

### Outils avancés

| Besoin | Outil |
|---|---|
| Cycle de vie, snapshots, réseaux, pools | `virsh` |
| Démons libvirt, validation de l'hôte et des XML | `virt-admin`, `virt-host-validate`, `virt-xml-validate` |
| Créer, cloner, modifier une VM | `virt-install`, `virt-clone`, `virt-xml` |
| Images qcow2 | `qemu-img`, `qemu-io`, `qemu-nbd`, `qemu-storage-daemon` |
| Disques invités hors ligne | `guestfish`, `virt-inspector`, `virt-ls`, `virt-cat`, `virt-edit`, `virt-copy-in/out`, `virt-df`, `virt-diff`, `virt-log` |
| Préparer des modèles | `virt-customize`, `virt-sysprep`, `virt-resize`, `virt-sparsify`, `virt-builder`, `cloud-localds` |
| Surveiller, migrer, QMP | `virt-top`, `virt-v2v`, `virt-qemu-qmp-proxy` |
| Catalogue et firmware | `osinfo-query`, OVMF/UEFI, swtpm |

`libvirt-nss` permet de résoudre les noms des domaines quand le réseau le permet. `virtualization-doctor` vérifie la présence de ces outils.

## 4. Qualifier

```bash
sudo /usr/local/sbin/devops-verify.sh          # dans l'invité
./control.sh kvm certify                         # depuis Fedora
```

La certification demande le mot de passe sudo de la VM dans un terminal SSH. Elle précède la [Gate 3](QUALIFICATION.md).

## 5. Exports

Les exports de la VM sont **manuels**, au moment choisi par le propriétaire. Avant toute modification importante, arrêter Rocky et suivre la [procédure complète d'export et de reprise](KVM_EXPORT_RESTORE.md) : inventaire XML/disques/NVRAM, copie cohérente, empreintes et test isolé. Borg ne sauvegarde ni les disques ni le XML libvirt.

## Dépannage

**Socle KVM indisponible.** `ls -l /dev/kvm`, `lsmod | grep kvm_amd`. S'il manque sur le PC, activer AMD-V/SVM dans l'UEFI avant de toucher à Linux. Si libvirt ne répond pas : `systemctl status virtqemud.socket virtnetworkd.socket virtstoraged.socket`. Le projet peut retomber sur `libvirtd.socket` ; ne pas basculer à la main entre les deux modèles.

**Pool `devops-data` absent.** `virsh --connect qemu:///system pool-info devops-data` et `findmnt -no SOURCE,FSTYPE,TARGET /data` : `/data` doit être le montage EXT4 du second NVMe. Labels : `ls -Zd /data/libvirt /data/libvirt/images` et `semanage fcontext -l | grep /data/libvirt` ; jamais de `chmod 777`. Ne pas recréer le pool sur le SSD système pour contourner un second T705 absent ([données `/data`](TROUBLESHOOTING.md#données-data-et-gaming)).

**Réseau `devops-nat` absent.** `virsh --connect qemu:///system net-info devops-nat` (actif, autostart) et `ip addr show virbr50` : attendu `192.168.50.0/24`, passerelle `192.168.50.254`. `firewall-cmd --get-zone-of-interface=virbr50` doit répondre `libvirt`.

**Garde réseau en mode d'urgence.** `guard_mode=emergency` veut dire que le forwarding des VM est volontairement coupé plutôt que de garder une isolation peut-être obsolète. Causes typiques : LAN courant en conflit avec `192.168.50.0/24`, uplink sans réseau directement connecté exploitable, erreur nftables, changement de connectivité incomplet. Regarder `ip -4 route`, `sudo nft list table inet fedora_gnome_custom_kvm` et `journalctl -u fedora-gnome-custom-kvm-guard.service -b`, puis :

```bash
./control.sh kvm guard-check
./control.sh kvm guard-reconcile
./control.sh kvm guard-check      # attendu : guard_mode=normal
```

Si la reconstruction échoue, garder le mode d'urgence et diagnostiquer ; ne pas supprimer la table nftables pour retrouver Internet ([réseau KVM](KVM_NETWORK.md#fermé-par-défaut-lors-dun-changement-réseau)).

**Rocky ne démarre pas.** `virsh --connect qemu:///system dominfo rocky-devops`, `domblklist`, `dumpxml`, `journalctl -u virtqemud -b`. Vérifier `/data/libvirt/images/rocky-devops.qcow2`, le seed cloud-init et le réseau.

**Pas d'adresse IP ou pas de SSH.** `virsh --connect qemu:///system domiflist rocky-devops`, puis `net-dhcp-leases devops-nat` ; sans bail, vérifier `devops-nat` avant de toucher au réseau de Rocky. Ensuite `ssh -v`. Un refus du mot de passe en SSH est **normal** : seule la clé est acceptée, ne pas réactiver `PasswordAuthentication`. Dans l'invité (console) : `sudo systemctl status qemu-guest-agent`.

**Rocky n'a plus Internet, l'hôte oui.** Si le garde est en mode d'urgence, c'est volontaire (voir plus haut). Sinon, dans l'invité : `ip route`, `getent ahostsv4 example.com`, `curl -I https://example.com`, puis `./control.sh kvm certify` depuis Fedora.

**Bootstrap incomplet.** Dans l'invité : `sudo cloud-init status --long`, `sudo systemctl status fgc-devops-bootstrap.service`, `sudo cat /var/log/devops-bootstrap.log`, `sudo /usr/local/sbin/devops-verify.sh`. Distinguer panne réseau/DNS, dépôt éditeur indisponible, signature ou checksum externe modifié, et outil réellement absent (le laboratoire Rocky de la CI tourne aussi périodiquement pour repérer ces ruptures). Ne recréer la VM qu'après avoir sauvé les données utiles et compris l'échec.

**Image refusée.** Image, `CHECKSUM` et `CHECKSUM.asc` doivent venir de la même release Rocky 10.2. Autres causes : image corrompue, signature invalide, serveur de clés indisponible (fournir alors une clé obtenue par un canal de confiance avec `--rocky-key-file`), clé locale incorrecte. Ne jamais contourner la signature ni la comparaison SHA-256 ; ne relancer la création que si le domaine et son disque n'existent pas encore.

**Nautilus ne voit plus Rocky.** `./control.sh kvm nautilus-refresh`, puis vérifier le service SSH de l'invité.

**Reconstruire l'invité.** Opération destructive : elle efface le disque de la VM et tout ce qu'il contient. D'abord sauver les données utiles de l'invité (copie SFTP ou [export](#5-exports)), puis, depuis Fedora :

> [!CAUTION]
> Point de non-retour : `undefine --remove-all-storage` efface le domaine, sa NVRAM et son disque, sans retour arrière. Les données utiles de l'invité doivent être sauvegardées avant (copie SFTP ou [export](#5-exports)).

```bash
virsh --connect qemu:///system shutdown rocky-devops                              # arrêt propre
virsh --connect qemu:///system undefine rocky-devops --nvram --remove-all-storage  # efface le domaine, sa NVRAM et son disque
```

Vérifier avec `virsh --connect qemu:///system list --all` que `rocky-devops` a disparu, retirer le dossier `/data/libvirt/cloud-init/rocky-devops` s'il reste (le script de création refuse un dossier existant), puis relancer la création.

**Certification KVM en échec.** Corriger le premier `KO` réel de `virtualization-doctor`, puis relancer. Ne jamais modifier les preuves.

# Golden Stack Certification — drivers, KVM and applications

Ce runbook complète la certification matérielle. Le principe est identique : un composant n'est pas considéré Golden parce qu'un paquet est installé ; il doit prouver son binding, son runtime ou sa configuration effective.

## 1. Pilotes et drivers

```bash
./diagnostics/driver-doctor
```

Sur le bare metal final, le contrat exige :

- Arc B580 `8086:e20b` liée à `xe` ;
- contrôleur Ethernet 5G lié à `r8169` ;
- les deux Crucial T705 liés au pilote `nvme` ;
- xHCI lié à `xhci_hcd` ;
- audio USB via `snd_usb_audio` ;
- Nuvoton NCT6687D-R via `nct6683` ;
- le PCI ID Wi-Fi et son driver exactement identiques à l'enrôlement bare-metal ;
- les modules critiques marqués `intree` par `modinfo` ;
- aucun stack NVIDIA/akmod parasite sur ce HOST Arc.

Un débind, un remplacement par `vfio-pci`, un driver Wi-Fi différent ou un module critique externe invalide la certification.

## 2. Virtualisation KVM/libvirt

### Capabilities HOST

```bash
./diagnostics/virtualization-doctor
./diagnostics/kvm-domain-doctor
```

`kvm-domain-doctor` exige notamment :

- cgroups v2 ;
- accès direct `qemu:///system` par l'utilisateur, sans masquer une mauvaise session de groupes par un fallback sudo ;
- daemons modulaires `virtqemud`, `virtnetworkd`, `virtstoraged` lorsque la pile installée les fournit ;
- `domcapabilities` KVM x86_64 avec Q35, `host-passthrough`, EFI/OVMF et TPM CRB/emulator.

### XML des invités

Quand `ubuntu-devops` ou `windows-11` existe, son XML réel est validé. `runtime_certification.sh` utilise `--require-guests` et exige les deux invités.

Contrat commun : Q35, CPU `host-passthrough`, RAM/vCPU exacts, qcow2 VirtIO sur `/data`, `cache=none`, `discard=unmap`, profil I/O mesuré, réseau `devops-nat` en VirtIO, QEMU Guest Agent, VirtIO RNG, balloon et aucun `hostdev`.

Ubuntu reste headless. Windows exige en plus Secure Boot, clés enrôlées, TPM 2.0 CRB emulator et SPICE.

### Médias Windows

La création de Windows refuse maintenant toute opération sans :

```text
--windows-sha256 <digest de confiance>
--virtio-sha256  <digest de confiance>
```

Les deux digests sont contrôlés avant la création du qcow2. Ne pas utiliser comme « preuve » un SHA calculé uniquement après téléchargement depuis une source non authentifiée.

### État I/O

Les scripts de création ne `source` plus le fichier d'état du benchmark. Ils ne lisent que `KVM_IO_SELECTED_PROFILE` et n'acceptent que `io_uring`, `native` ou `threads`.

## 3. Applications

```bash
./diagnostics/applications-doctor
./diagnostics/application-runtime-doctor
```

Le contrat `manifests/application-runtime-contract.tsv` vérifie :

- RPM Fedora : paquet présent, exécutable réel, smoke test `--version` ;
- RPM vendor : mêmes contrôles + fichier `.repo` installé strictement identique à la source auditée du dépôt ;
- Flatpak : provenance conforme, origine exactement `flathub`, runtime renseigné, processus `/usr/bin/true` réellement exécutable dans le sandbox, export `.desktop` présent et valide ;
- Flatpak communautaires non vérifiés : présence obligatoire dans `UNVERIFIED_FLATHUB_ALLOWLIST`.

Slack, MarkText et draw.io restent volontairement classés `community-unverified`. Leur installation est une exception auditée, pas une affirmation de publication officielle.

## 4. Identité Golden

`effective_config_sha256` couvre désormais :

- la configuration et les dépôts vendor ;
- les manifestes paquets/Flatpak/provenance/runtime ;
- le plan de modules ;
- les XML de politique de virtualisation ;
- le lock média Fedora 44.

Une modification de ces politiques rend donc les anciennes preuves dry-run/APPLY obsolètes.

## 5. Gate 3 finale

`./diagnostics/final-certification certify` exécute désormais explicitement :

- `driver-doctor` ;
- `application-runtime-doctor` ;
- `virtualization-doctor` et `kvm-domain-doctor` si KVM est activé ;
- tous les doctors matériels, GPU, stockage, média, GNOME, portail, backup et lifecycle déjà présents.

Le marker final contient `driver_contract=PASS`, `application_runtime_contract=PASS` et, lorsque KVM est actif, `kvm_domain_contract=PASS`.

Cela ne remplace pas la preuve physique : ces PASS finaux n'existent réellement qu'après Gate 3 sur la machine cible.

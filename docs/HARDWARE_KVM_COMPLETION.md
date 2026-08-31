# Hardware & KVM Completion

Ce document récapitule les choix de complétion hardware/KVM intégrés au contrat courant. La version applicable est celle de [`../VERSION`](../VERSION).

## Firmware et microcode

Le HOST Fedora 44 installe explicitement `linux-firmware`, `amd-ucode-firmware` pour le Ryzen 7 7700 et `intel-gpu-firmware` pour l'Arc B580.

`firmware-doctor` vérifie les paquets, la version microcode exposée par le noyau, les déclarations firmware de `xe`, le firmware RTL8126 disponible et les échecs de chargement firmware du journal courant.

`fwupd` reste inventaire/metadata-only : aucun flash BIOS/firmware automatique.

## Carte mère et périphériques

`hardware-components-doctor` vérifie notamment :

- Realtek 8126-VB avec pilote `r8169` et capacité 5000baseT ;
- Wi-Fi détecté dynamiquement, driver attaché, PHY `iw`, EHT/802.11be et visibilité 6 GHz ;
- contrôleur Bluetooth ;
- ALC4080/USB Audio, `snd_usb_audio` et graphe PipeWire ;
- contrôleurs USB liés à `xhci_hcd`.

Le modèle Wi-Fi exact n'est pas inventé : le PCI ID réel de la machine reste l'autorité.

## Veille / USB

Le hook sleep capture réseau, audio USB, xHCI, GPU/DRM/NVMe et erreurs associées.

`usb-resume-doctor` fait partie de chaque preuve `final-certification record-suspend`; une erreur xHCI/USB récente peut invalider le cycle.

## Matrice known-good

`software-matrix-doctor certify` capture BIOS, kernel, linux-firmware, microcode, firmware GPU, Mesa, Mutter, GNOME Shell, Nautilus, QEMU et libvirt.

Si un composant significatif change, le doctor demande une nouvelle validation au lieu de considérer silencieusement la machine comme identique.

## KVM / T705

Avant de créer les VM :

```bash
./diagnostics/kvm-io-doctor benchmark
```

Le benchmark est filesystem-safe sur `/data`, exige l'absence de VM active et compare `io_uring` à AIO natif lorsque les deux sont supportés.

Les disques utilisent :

```text
cache=none
discard=unmap
```

`detect_zeroes` et IOThread ne sont ajoutés que si `virt-install --disk=?` confirme leur support.

## Réseau KVM fail-closed

`devops-nat` reste :

```text
virbr50
192.168.50.0/24
DHCP .100-.200
```

Le guard nftables bloque le forwarding entre VM et LAN uplink sans purger firewalld.

Lors d'un changement Ethernet/Wi-Fi/DHCP :

```text
NetworkManager event
      ↓
emergency guard
      ↓
redécouverte + validation
      ↓
normal guard si succès
```

Si la reconstruction échoue, le mode d'urgence reste actif et coupe le forwarding externe via `virbr50` au lieu de conserver un ancien LAN potentiellement obsolète.

Voir [`KVM_NETWORK.md`](KVM_NETWORK.md).

## Guest integration

Ubuntu 26.04 et Windows 11 reçoivent :

- channel `org.qemu.guest_agent.0` ;
- VirtIO RNG ;
- balloon mémoire VirtIO ;
- disque et réseau VirtIO.

Windows reçoit aussi le canal SPICE `com.redhat.spice.0`.

`Configure-GuestIntegration.ps1` installe les pilotes VirtIO signés depuis l'ISO fourni par l'opérateur, installe QEMU Guest Agent et refuse de valider si un périphérique VirtIO reste en erreur.

## Image Ubuntu authentifiée

La création de `ubuntu-devops` exige désormais :

```text
image Canonical
SHA256SUMS
SHA256SUMS.gpg
```

Le script `verify_ubuntu_cloud_image.sh` authentifie la liste de checksums avec l'empreinte Canonical attendue puis vérifie le SHA-256 de l'image avant création du disque.

Ce contrôle aligne le workflow bare-metal opérateur avec la politique déjà utilisée par le vrai prétest Ubuntu en CI.

## Certification runtime

```bash
./diagnostics/firmware-doctor
./diagnostics/hardware-components-doctor
./diagnostics/kvm-io-doctor benchmark
./diagnostics/software-matrix-doctor status
./scripts/kvm/runtime_certification.sh
```

`runtime_certification.sh` exige notamment :

- QEMU Guest Agent dans les deux VM ;
- VirtIO/RNG/balloon ;
- Secure Boot + TPM Windows ;
- guard KVM actif ;
- reconcile réussi ;
- `guard_mode=normal` ;
- CIDR uplink présents dans nftables ;
- DNS/HTTPS Ubuntu ;
- blocage du gateway LAN depuis Ubuntu lorsque le HOST prouve d'abord que ce gateway répond.

La certification bare-metal reste la preuve finale ; la CI protège le contrat statique mais ne simule pas le matériel physique.

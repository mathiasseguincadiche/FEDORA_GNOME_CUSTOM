# Réseau KVM `devops-nat` — architecture et sécurité

Ce document explique le réseau KVM privé de la workstation. Il complète [`VIRTUALIZATION.md`](VIRTUALIZATION.md) avec un niveau de détail suffisant pour comprendre **qui fournit l'adresse IP, qui fait le NAT, qui filtre les réseaux protégés du HOST et ce qui se passe lors d'un changement Ethernet/Wi-Fi**.

## Contrat réseau

```text
nom       devops-nat
bridge    virbr50
réseau    192.168.50.0/24
gateway   192.168.50.254
DHCP      192.168.50.100-200
DNS       9.9.9.9 + 1.1.1.1
mode      NAT IPv4
zone      firewalld libvirt
IPv6      désactivé / fail-closed
```

Flux autorisés :

```text
HOST ↔ VM           autorisé
VM ↔ VM             autorisé
VM → Internet       autorisé
```

Flux interdits :

```text
VM → LAN/VPN/route HOST protégée   bloqué
LAN/VPN/route HOST → VM             bloqué en forwarding
Internet → VM       aucun port-forward implicite
```

## Vue simple

```text
ubuntu-devops / windows-11
          │
          │ VirtIO
          ▼
     ┌─────────┐
     │ virbr50 │  192.168.50.254
     └────┬────┘
          │
          ├── libvirt/dnsmasq : DHCP + DNS
          │
          ├── libvirt NAT : sortie Internet
          │
          └── nftables guard : interdit LAN/VPN/routes HOST protégées
                         │
                         ▼
                 Ethernet / Wi-Fi
                         │
                         ▼
                      Internet
```

`virbr50` est un **bridge virtuel libvirt**. Ce n'est pas l'interface Ethernet/Wi-Fi physique du PC.

## Pourquoi le NAT libvirt ne suffit pas

Le NAT libvirt donne aux VM une connectivité sortante sans les placer directement sur le LAN. Ce comportement est souhaité pour Internet, mais le contrat Golden Workstation ajoute une exigence plus stricte : les VM de laboratoire ne doivent pas pouvoir atteindre directement les réseaux privés/routés connus du HOST (LAN, VPN, entreprise, tunnels explicites).

Le projet ajoute donc une table nftables propre :

```text
inet fedora_gnome_custom_kvm
```

Elle ne remplace pas firewalld et ne purge aucune règle globale.

## Rôle de chaque couche

### libvirt

Libvirt définit `devops-nat`, crée `virbr50`, fournit le DHCP/DNS du segment privé et configure le NAT nécessaire à la sortie des VM.

Source versionnée :

```text
virtualization/xml/networks/devops-nat.xml
```

### firewalld

Le bridge `virbr50` est associé à la zone :

```text
libvirt
```

Le projet conserve firewalld actif et ne crée pas de stratégie basée sur sa désactivation.

### nftables guard

Le helper :

```text
/usr/local/libexec/fedora-gnome-custom/kvm-network-guard
```

provient de :

```text
scripts/kvm/kvm_network_guard.sh
```

Il lit la table de routage IPv4 principale du HOST, exclut la route `default`, le loopback et `devops-nat`, puis construit le set :

```text
blocked_host_ipv4
```

Le contrat normal contient deux directions :

```text
virbr50 → réseau HOST protégé      REJECT
réseau HOST protégé → virbr50      DROP
```

Le HOST lui-même peut toujours parler aux VM parce que ce trafic n'est pas du forwarding entre une route protégée et `virbr50`.

## Portée exacte des réseaux protégés

Le contrat courant bloque toutes les **routes IPv4 explicites non-default de la table principale du HOST** : réseaux directement connectés, LAN, routes VPN/entreprise et tunnels explicitement routés. Le CIDR KVM lui-même et le loopback sont exclus.

La route IPv4 `default` reste volontairement hors du set afin de conserver **VM → Internet**. Un nouveau VPN ou une nouvelle route d'entreprise déclenche le reconcile via NetworkManager ; si la nouvelle table ne peut pas être découverte, validée ou appliquée, le guard conserve le mode `emergency` qui bloque tout forwarding via `virbr50`.

## Détection de chevauchement

Le réseau VM ne doit jamais chevaucher le LAN courant.

Exemple valide :

```text
LAN maison    192.168.1.0/24
KVM           192.168.50.0/24
```

Exemple refusé :

```text
LAN courant   192.168.50.0/24
KVM           192.168.50.0/24
```

Le guard utilise Python `ipaddress` pour refuser ce cas avant de construire les règles normales.

## Fail-closed lors d'un changement réseau

Un changement Ethernet/Wi-Fi/DHCP peut rendre les anciennes règles obsolètes. Le projet ne conserve donc plus simplement l'ancien set en espérant que le recalcul réussisse.

Le cycle est :

```text
événement NetworkManager
        ↓
MODE EMERGENCY
bloque tout forwarding via virbr50
        ↓
redécouverte des routes HOST protégées
        ↓
validation absence de chevauchement
        ↓
transaction nftables normale valide ?
        ├── oui → MODE NORMAL
        └── non → MODE EMERGENCY conservé
```

Le mode d'urgence bloque les deux directions de forwarding via `virbr50`. Il est volontairement plus restrictif : une panne de recalcul coupe la sortie réseau des VM au lieu de risquer de les exposer au nouveau LAN.

Le service systemd utilise :

```text
ExecStart  → reconcile
ExecReload → reconcile
Restart    → on-failure
```

Le dispatcher NetworkManager installe également le mode d'urgence **avant** d'appeler `reload-or-restart`.

## Vérifier le guard

État du service :

```bash
systemctl status fedora-gnome-custom-kvm-guard.service
```

État logique :

```bash
sudo /usr/local/libexec/fedora-gnome-custom/kvm-network-guard check
```

Exemple attendu avec un LAN `192.168.1.0/24` :

```text
kvm_cidr=192.168.50.0/24
default_uplink=...
protected_networks=192.168.1.0/24
guard_mode=normal
```

Afficher la table :

```bash
sudo nft list table inet fedora_gnome_custom_kvm
```

Le mode certifié doit contenir :

```text
blocked_host_ipv4
normal block VM to protected host networks
normal block protected host networks to VM
```

Un `guard_mode=emergency` n'est pas un état normal de production : il signifie que l'isolation restrictive a été conservée parce que la reconstruction normale n'a pas pu être certifiée.

## Tester après changement Ethernet/Wi-Fi

Après avoir changé volontairement de connectivité :

```bash
sudo /usr/local/libexec/fedora-gnome-custom/kvm-network-guard check
sudo nft list table inet fedora_gnome_custom_kvm
bash scripts/kvm/runtime_certification.sh
```

La certification recharge le guard via systemd, exige son retour en mode normal et vérifie que tous les CIDR HOST protégés détectés sont présents dans la table nftables.

## Preuve VM → LAN

Lorsque la passerelle physique répond au ping depuis Fedora, `runtime_certification.sh` établit d'abord qu'elle est réellement joignable depuis le HOST. Il exige ensuite que le même ping lancé depuis `ubuntu-devops` échoue.

Cela évite le faux positif suivant :

```text
ping VM → gateway échoue
```

qui serait insuffisant si le gateway refusait déjà le ping depuis toutes les machines.

## Preuve LAN → VM

La certification host vérifie la règle nftables correspondante. Une preuve réseau réellement externe nécessite cependant un **deuxième appareil du LAN**.

Sur un autre ordinateur du LAN, pendant qu'Ubuntu est démarré :

```text
1. récupérer l'IP 192.168.50.x de la VM depuis Fedora ;
2. tenter un accès direct vers cette IP depuis l'autre machine ;
3. confirmer qu'aucun forwarding LAN → VM n'est disponible ;
4. conserver le résultat dans la validation bare-metal du réseau concerné.
```

Cette preuve est à refaire si l'architecture du LAN ou le contrat KVM change de manière significative.

## Pourquoi IPv6 est désactivé

Le guard normal certifié filtre actuellement la politique LAN en IPv4. Activer IPv6 sans politique équivalente créerait un second chemin réseau pouvant contourner l'intention d'isolation.

Le projet conserve donc :

```text
KVM_IPV6_ENABLED=false
```

et refuse l'activation tant qu'un guard dual-stack équivalent n'est pas implémenté et certifié.

## Pas de port forwarding implicite

Le projet ne configure aucun port forward automatique depuis le LAN ou Internet vers les invités.

L'administration Ubuntu se fait depuis le HOST :

```bash
ssh mathias@192.168.50.x
```

Windows est administré via sa console/GUI et les accès explicitement configurés dans le segment KVM.

## Dépannage

En cas de perte réseau VM, ne supprimer ni firewalld ni la table nftables en premier réflexe. Suivre la section KVM de [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) afin de distinguer :

- réseau libvirt inactif ;
- bridge absent ;
- DHCP absent ;
- guard en mode d'urgence ;
- chevauchement de sous-réseaux ;
- guest sans pilote/agent ;
- absence de connectivité physique du HOST.

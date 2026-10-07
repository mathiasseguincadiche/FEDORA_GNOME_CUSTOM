# ADR 0017 — Accès distant : Tailscale, SSH, Wake-on-LAN, Sunshine en option

**Statut : accepté** — le profil est livré **désactivé** ; son activation dépend du Gate 3.

## Contexte

Le propriétaire veut utiliser la workstation Fedora depuis une tablette Android, sans second ordinateur de travail : le PC reste l'unique machine, la tablette un terminal. Le besoin couvre un mode léger (SSH), un mode graphique (Sunshine + Moonlight) et le **réveil** d'un PC éteint (Wake-on-LAN). Le cahier des charges est analysé dans [REMOTE_ACCESS.md](../REMOTE_ACCESS.md).

Le projet impose déjà : aucun port inutile, SELinux Enforcing, firewalld actif, installation seulement après dry-run et sauvegarde, preuves physiques au Gate 3, et un réseau KVM fail-closed (ADR 0007).

## Décision

1. **Profil optionnel `REMOTE_*`**, désactivé par défaut (`REMOTE_ENABLE="false"`), sur le modèle de `GAMING_ENABLE`. Cinq modules (`remote.preflight`, `remote.network`, `remote.ssh`, `remote.desktop`, `remote.validation`), un `remote-doctor`, une route `./control.sh remote`.
2. **Tailscale** est l'unique chemin d'entrée. Rien n'est exposé à Internet. Le paquet vient du dépôt éditeur signé, comme les autres applications éditeur.
3. **SSH par clés uniquement**, un seul utilisateur, pas de root, drop-in `00-fgc-remote.conf` validé par `sshd -t`. Le préflight **refuse** d'agir sans clé publique dans `authorized_keys`. SSH est retiré de la zone firewalld par défaut tant que `REMOTE_SSH_LAN="false"`.
4. **Wake-on-LAN** par le profil NetworkManager de l'Ethernet filaire (`magic`), avec un fichier `.link` systemd en filet de sécurité activable. Le **relais** qui émet le Magic Packet est requis et hors du PC : le projet fournit `scripts/remote/wol-send.py`, pas le matériel.
5. **Sunshine est un opt-in distinct** (`REMOTE_SUNSHINE_ENABLE`), de même que la **connexion automatique GDM** (avec verrouillage immédiat de la session) et l'**extinction sans mot de passe** (polkit). Aucun n'est activé par `REMOTE_ENABLE` seul. L'interface web de Sunshine (47990) n'est jamais ouverte.
6. **Isolation des VM** : le garde-fou KVM protège statiquement `100.64.0.0/10` (`KVM_EXTRA_PROTECTED_CIDRS`), car `tailscaled` crée ses routes en dehors des événements NetworkManager.
7. **Qualification** : le CI prouve les contrats (modules, schéma, garde-fou, scripts). Le réveil depuis un arrêt complet, le streaming et l'encodage AV1 sont des **mesures Gate 3** (cinq cycles sans intervention locale).

## Alternatives écartées ou reportées

- **GNOME Remote Desktop** comme bureau distant par défaut : intégré et sans connexion automatique, mais moins fluide ; reporté comme **repli** si Sunshine échoue au Gate 3. Non automatisé (il implique des identifiants).
- **WireGuard / Headscale auto-hébergés** : plus de contrôle, plus de maintenance.
- **Tailscale SSH** : un seul mécanisme, mais OpenSSH reste le socle d'Ansible et des clés du projet.
- **Prise connectée** pour le réveil : dernier recours (dépendance à un cloud, coupure de courant).
- **Zone firewalld stricte pour le LAN** : durcirait aussi des usages hors périmètre ; la limite (ports hauts de `FedoraWorkstation`) est documentée, pas masquée.

## Conséquences

- Aucune modification de comportement tant que `REMOTE_ENABLE` reste à `false`.
- Un nouveau fournisseur tiers apparaît quand le profil est activé (Tailscale, et LizardByte si Sunshine est choisi) ; la provenance est décrite dans [SUPPLY_CHAIN.md](../SUPPLY_CHAIN.md).
- Sans chiffrement des disques (ADR 0002), la connexion automatique transforme l'accès physique en accès au compte ; c'est pourquoi elle est opt-in et verrouillée dès l'ouverture.
- Le Wake-on-LAN depuis un arrêt complet n'est **pas** garanti par le code : il dépend du BIOS, du pilote `r8169` sur le RTL8126 et du relais. Le profil le vérifie (`ethtool`, profil NetworkManager) mais ne le promet pas.

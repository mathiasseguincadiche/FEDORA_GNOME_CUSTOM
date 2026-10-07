# Accès distant — Tailscale, SSH, Wake-on-LAN et Sunshine

> **Objectif.** Utiliser le PC Fedora depuis une tablette Android, de chez soi ou de l'extérieur, sans exposer de port sur Internet, et pouvoir le **réveiller** quand il est éteint.
> **Public.** Le propriétaire de la workstation. **Statut : code prêt, profil désactivé par défaut, qualification physique (Gate 3) à faire.**
> **Décision d'architecture :** [ADR 0017](adr/0017-remote-access.md).

Ce guide répond à trois questions : *qu'est-ce que le projet automatise*, *l'architecture demandée est-elle bonne* (avec les corrections que l'analyse a imposées), et *dans quel ordre l'activer*.

---

## 1. Verdict sur l'architecture demandée

L'idée centrale est **bonne et conservée** : le PC Fedora reste l'unique vraie workstation, la tablette n'est qu'un terminal. Cela évite deux machines à maintenir, et tout (Git, clés, VM Rocky, conteneurs) reste au même endroit.

L'analyse a toutefois trouvé **sept points** où le cahier des charges, tel qu'écrit, ne fonctionnerait pas tout seul ou serait moins sûr qu'il n'en a l'air.

| # | Point | Constat | Réponse du projet |
|---|---|---|---|
| 1 | **Le réveil à distance exige un relais** | Tailscale ne peut pas réveiller un PC éteint : son client n'y tourne plus. Un appareil toujours allumé du LAN doit envoyer le Magic Packet. Le cahier des charges le prévoit « à terme » ; sans lui, le réveil à distance **ne marche pas**. | `scripts/remote/wol-send.py` (relais) et procédure § 7. Le choix du relais reste à faire (§ 7). |
| 2 | **Sunshine sous GNOME/Wayland est la partie fragile** | La capture passe par le portail (autorisation demandée) ou par KMS (capacité `cap_sys_admin`). Une mise à jour début 2026 a fait passer le portail avant KMS. Sunshine lancé avant l'ouverture de session n'a pas d'environnement graphique. | Profil **optionnel** (`REMOTE_SUNSHINE_ENABLE`), ouverture de session automatique **opt-in**, mesures au Gate 3. Alternative intégrée à GNOME au § 6. |
| 3 | **L'AV1 de la B580 n'est pas confirmé de bout en bout** | Le pilote média Intel gère l'encodage AV1 sur Battlemage ; je n'ai trouvé aucune source qui teste **Sunshine sur B580**. Sunshine retombe silencieusement sur H.264 logiciel si l'encodeur n'est pas utilisable. | `remote-doctor` vérifie l'encodage AV1 VA-API. Le journal Sunshine doit confirmer l'encodeur choisi (Gate 3). |
| 4 | **Le pare-feu Fedora Workstation laisse déjà passer beaucoup** | La zone `FedoraWorkstation` ouvre `ssh` **et tous les ports 1025-65535** (TCP/UDP) sur le LAN. Les ports de Sunshine sont donc atteignables depuis le LAN, protégés seulement par l'appairage Sunshine. | `REMOTE_SSH_LAN=false` retire SSH de cette zone. Les ports hauts sont **un risque assumé et documenté**, pas masqué (§ 8). |
| 5 | **L'expiration de clé Tailscale peut vous enfermer dehors** | Un nœud dont la clé expire quitte le tailnet : plus d'accès distant, et le PC est peut-être éteint. | Désactiver l'expiration de clé pour le PC et le relais (§ 5). |
| 6 | **Wake-on-LAN : trois couches, pas une** | Il faut (a) le BIOS, (b) le pilote réseau, (c) le profil NetworkManager. NetworkManager **n'active pas** le Wake-on-LAN par défaut. Le comportement du Realtek 5 GbE (RTL8126, pilote `r8169`) depuis un arrêt complet n'est confirmé par aucune source que j'ai trouvée. | Profil NetworkManager `magic` + filet `.link` optionnel + **5 cycles mesurés** (§ 10). |
| 7 | **Isolation VM / tailnet** | Les VM KVM ne doivent pas atteindre le tailnet. Le garde-fou KVM protège les routes qu'il découvre, mais `tailscale0` n'émet aucun événement NetworkManager : les routes Tailscale pouvaient apparaître après la dernière reconstruction. | Le garde-fou protège maintenant **statiquement** `100.64.0.0/10` (`KVM_EXTRA_PROTECTED_CIDRS`), avec un test. |

### Ce qui reste exactement comme demandé

Tailscale comme réseau privé, SSH par clés comme mode léger, Wake-on-LAN sur l'Ethernet filaire via NetworkManager, Sunshine + Moonlight pour le mode graphique, arrêt par `systemctl poweroff`, et la séquence de connexion de la section 22 du cahier des charges.

### Alternatives examinées

| Besoin | Choix retenu | Alternative | Pourquoi pas (pour l'instant) |
|---|---|---|---|
| Réseau privé | Tailscale | WireGuard auto-hébergé, Headscale | Plus de contrôle, mais NAT, ACL et client Android sont à construire et à maintenir. À reconsidérer si dépendre d'un plan de contrôle tiers pose problème. |
| Bureau distant | Sunshine + Moonlight (latence, AV1, 120 FPS) | **GNOME Remote Desktop** (RDP), fourni avec Fedora | Intégré, signé Fedora, **ouverture de session distante sans connexion automatique**. Moins de fluidité ; l'accélération matérielle n'est pas confirmée pour GNOME 50. **Repli recommandé si Sunshine échoue au Gate 3.** |
| SSH | OpenSSH durci | Tailscale SSH | Un seul mécanisme, mais le cahier des charges et le reste du projet (Ansible, clés) reposent sur OpenSSH. |
| Réveil sans relais | — | Prise connectée + « restaurer après coupure secteur » | Fonctionne sans NIC ni relais réseau, mais dépend d'un cloud tiers et coupe le courant d'une machine éteinte proprement. Dernier recours. |

---

## 2. Ce que le projet fait, et ce qui reste manuel

Le profil `remote` s'ajoute aux profils existants (comme `GAMING`) : cinq modules, un `doctor`, un fichier de configuration. **Tout est désactivé tant que `REMOTE_ENABLE="true"` n'est pas posé dans `config/local.conf`.**

| Module | Automatisé | Reste manuel |
|---|---|---|
| `remote.preflight` | Outils, SELinux Enforcing, firewalld, ports valides, **clé SSH publique présente**, interface filaire | — |
| `remote.network` | Dépôt Tailscale, paquets, `tailscaled`, zone firewalld, Wake-on-LAN dans le profil NetworkManager, protection KVM | **Première connexion `tailscale up`**, BIOS, relais |
| `remote.ssh` | Durcissement validé par `sshd -t`, retrait de SSH de la zone LAN | Ajouter la clé de la tablette |
| `remote.desktop` | Sunshine (COPR), service utilisateur, connexion automatique + verrouillage, extinction sans mot de passe — **chacun en opt-in** | Appairage Moonlight, réglages Sunshine |
| `remote.validation` | `remote-doctor` | Cycles de fiabilité (Gate 3) |

```bash
./control.sh remote status      # contrôle complet, lecture seule
./control.sh remote info        # MAC, diffusion LAN et adresse Tailscale à reporter sur le relais
./control.sh install dry-run    # simulation de tout le catalogue, sans mutation
```

---

## 3. Architecture

```text
 Tablette Android (Moonlight · client SSH · Tailscale · Wake-on-LAN)
        │
        ▼
     Tailscale  ─────────────►  Relais toujours allumé (LAN)
        │                              │ Magic Packet (diffusion LAN)
        ▼                              ▼
   ┌────────────────────────────────────────────┐
   │ PC Fedora : NIC 5 GbE (WoL magic)          │
   │  tailscaled · sshd (clés) · Sunshine       │
   │  zone fgc-tailnet · SELinux · firewalld    │
   │  garde-fou KVM : 100.64.0.0/10 protégé     │
   └────────────────────────────────────────────┘
```

À la maison, la tablette peut **aussi passer par Tailscale** : la connexion devient directe sur le LAN, avec une latence quasi identique, et aucun port n'a besoin d'être ouvert côté LAN pour SSH.

---

## 4. Activation pas à pas

**Préconditions :** Gate 3 du poste réussi, sauvegarde Borg pré-APPLY du même commit, console physique à portée (la réactivation du profil réseau coupe brièvement la liaison : **ne pas appliquer ce module par SSH sur la même carte**).

1. **Clé SSH de la tablette.** Générer une clé sur la tablette (client SSH Android), puis ajouter sa partie publique à `~/.ssh/authorized_keys` du PC. Sans clé, le préflight **refuse** d'aller plus loin : désactiver les mots de passe sans clé vous enfermerait dehors.
2. **Activer le profil** dans `config/local.conf` :
   ```bash
   REMOTE_ENABLE="true"
   # Options explicites, une par une, quand vous y êtes prêt :
   # REMOTE_SUNSHINE_ENABLE="true"
   # REMOTE_AUTOLOGIN="true"
   # REMOTE_POWEROFF_POLKIT="true"
   ```
3. **Simuler, puis appliquer :** `./control.sh install dry-run`, puis la séquence d'APPLY habituelle du projet (sauvegarde pré-APPLY comprise).
4. **Connexion Tailscale (manuelle, une fois) :** `sudo tailscale up`, ouvrir le lien, se connecter. Voir § 5 pour l'expiration de clé et les ACL.
5. **BIOS** : § 9. **Relais** : § 7.
6. `./control.sh remote status` doit afficher **0 KO**. Un `WARN` sur « Tailnet login » avant l'étape 4 est normal.

**Résultat attendu :** `REMOTE ACCESS HEALTHY`. **Critère d'arrêt :** un KO sur SSH, SELinux ou l'isolation KVM — ne pas poursuivre vers Sunshine tant qu'il n'est pas résolu.

---

## 5. Tailscale : expiration de clé et ACL

Dans la console d'administration Tailscale :

- **Désactiver l'expiration de clé** pour le PC et pour le relais. Sinon, au bout du délai de la clé, le PC disparaît du tailnet.
- Restreindre qui peut joindre quoi. Les ACL sont **la** frontière côté tailnet : par défaut, `tailscaled` installe ses propres règles réseau et accepte le trafic entrant sur `tailscale0` ; la zone firewalld `fgc-tailnet` est un second verrou dont l'effet exact est **à vérifier au Gate 3** (`sudo nft list ruleset`). Exemple à adapter dans l'éditeur d'ACL (syntaxe à valider dans la console) :

```json
{
  "tagOwners": { "tag:desktop": ["autogroup:admin"], "tag:relay": ["autogroup:admin"] },
  "acls": [
    { "action": "accept", "src": ["autogroup:member"], "dst": ["tag:desktop:22,47984,47989,48010,47998-48000"] },
    { "action": "accept", "src": ["autogroup:member"], "dst": ["tag:relay:22"] }
  ]
}
```

Le PC et le relais portent leur étiquette ; la tablette, nœud personnel, n'en a pas besoin. L'interface web de Sunshine (port 47990) n'apparaît **nulle part** : elle reste locale.

---

## 6. Bureau distant : Sunshine, ou GNOME Remote Desktop

### Sunshine + Moonlight (choix du cahier des charges)

À activer avec `REMOTE_SUNSHINE_ENABLE="true"`. Installé depuis le COPR `lizardbyte/stable` (source amont, signée par COPR — voir [SUPPLY_CHAIN.md](SUPPLY_CHAIN.md)). Ports ouverts **uniquement** dans la zone `fgc-tailnet`, d'après les valeurs par défaut documentées par LizardByte :

| Protocole | Ports | Rôle |
|---|---|---|
| TCP | 47984, 47989, 48010 | appairage / contrôle / RTSP |
| UDP | 47998, 47999, 48000 | vidéo / contrôle / audio |
| — | **47990** | interface web : **jamais ouverte** (le préflight le refuse) |

Ces ports doivent être **reconfirmés** avec `ss -tulpn` pendant le Gate 3 : je n'ai pas pu relire la documentation LizardByte depuis l'environnement où ce profil a été écrit.

**Il faut une session graphique ouverte.** Après un réveil, le PC s'arrête sur l'écran de connexion GDM : sans session, Sunshine n'a rien à capturer. Deux options :

- `REMOTE_AUTOLOGIN="true"` : GDM ouvre la session seul, et `REMOTE_LOCK_ON_AUTOLOGIN="true"` la **verrouille aussitôt** (vous saisissez le mot de passe depuis la tablette). Compromis à connaître : les disques ne sont pas chiffrés (ADR 0002), donc l'accès physique reste un accès au compte.
- Ne pas utiliser Sunshine, et passer par GNOME Remote Desktop.

**Réglages de départ** (cahier des charges, à ajuster par mesure) :

| Profil | Résolution | Fréquence | Codec | Débit |
|---|---|---|---|---|
| LAN | 1440p | 120 FPS | AV1 | 40–80 Mb/s |
| Distant | 1080p/1200p ou 1440p | 60–90 FPS | AV1 | 15–40 Mb/s |

**Points ouverts, à trancher par mesure :**

- *Méthode de capture* : portail (autorisation à valider) ou KMS (`cap_sys_admin`, compatibilité avec SELinux et le pilote `xe` à vérifier).
- *Écran OLED* : pendant une session distante, l'écran physique reste allumé et affiche votre travail. Le pilier « soin de l'écran » du projet impose de le mesurer (extinction de l'écran physique pendant le streaming ; un projet tiers, `sunshine-screen-off`, crée un écran virtuel sous GNOME, mais il est communautaire et testé sur une autre distribution — non adopté ici).
- *Résolution de la tablette* : la tablette n'a pas la résolution de l'écran du PC ; Sunshine sous Wayland n'adapte pas toujours le mode d'affichage.

### Repli intégré : GNOME Remote Desktop (RDP)

Fourni avec Fedora, il sait ouvrir une **session distante depuis l'écran de connexion** (« Remote Login »), donc sans connexion automatique. Il se configure dans *Paramètres → Système → Bureau à distance* (ou avec `grdctl`) et demande un certificat TLS. Il n'est **pas automatisé** par ce profil car il implique des identifiants. À envisager si Sunshine échoue au Gate 3.

---

## 7. Relais Wake-on-LAN

Un appareil **toujours allumé** du LAN, avec Tailscale, envoie le Magic Packet. Au choix, selon le matériel disponible : routeur compatible, NAS, Raspberry Pi, mini-PC. Le plus simple à reproduire : un petit Raspberry Pi avec Tailscale.

```bash
# Sur le PC (une fois) : récupérer les valeurs à reporter
./control.sh remote info

# Sur le relais (Python 3 suffit, aucune dépendance) :
python3 wol-send.py aa:bb:cc:dd:ee:ff --broadcast 192.168.1.255
```

Depuis la tablette : connexion SSH au relais (via son adresse Tailscale), puis la commande ci-dessus. Une application web de réveil hébergée sur le relais (UpSnap, décrit par Tailscale) est une alternative plus confortable.

Le script envoie le paquet 3 fois (robustesse) et valide la MAC et l'adresse de diffusion. `--print-packet` affiche le paquet sans l'envoyer.

---

## 8. Sécurité : ce qui est protégé, ce qui ne l'est pas

- **Rien n'est exposé à Internet** : ni SSH, ni Sunshine, ni le Wake-on-LAN. Le seul chemin d'entrée est le tailnet.
- **SSH** : clés uniquement, pas de root, un seul utilisateur autorisé, `sshd -t` avant tout rechargement (une configuration invalide est retirée automatiquement). Le fichier s'appelle `00-fgc-remote.conf` car `sshd` applique la **première** valeur rencontrée : il doit précéder `50-redhat.conf`.
- **SELinux** reste Enforcing et firewalld actif : le préflight et le doctor les exigent.
- **Isolation des VM** : la plage Tailscale est interdite aux VM KVM (garde-fou, testé).
- **Limite assumée — LAN** : avec la zone `FedoraWorkstation` par défaut, les ports hauts (dont ceux de Sunshine) restent atteignables depuis le LAN domestique. Un appareil du LAN pourrait donc **tenter** de s'appairer ; l'appairage exige un code. Durcir cette zone modifierait d'autres usages (partages, découverte) : ce n'est pas fait automatiquement.
- **Extinction sans mot de passe** (`REMOTE_POWEROFF_POLKIT`) : autorise tout processus de l'utilisateur à éteindre ou suspendre le PC. Le risque est faible (aucun accès, seulement une disponibilité) mais c'est un opt-in.

---

## 9. BIOS (MSI MAG B850M MORTAR WIFI, version 1.A66)

Le Wake-on-LAN depuis un arrêt complet dépend du BIOS. Les intitulés varient ; chercher, dans les menus d'alimentation et de réveil :

- **Réveil par le contrôleur PCIe / réseau** (par exemple « Resume By PCI-E Device », « Wake Up Event Setup ») : **activé**.
- **ErP / EuP Ready** : **désactivé** (activé, il coupe l'alimentation du contrôleur réseau en veille profonde).
- **Restauration après coupure secteur** : à votre convenance.

Je n'ai pas pu confirmer les noms exacts de ce BIOS : à vérifier sur la machine, puis à noter dans la fiche de qualification.

---

## 10. Qualification Gate 3 — fiabilité

Rien de ce qui suit n'est prouvable par la CI : c'est une **mesure sur le PC**.

```text
5 × arrêt complet (systemctl poweroff)
5 × réveil par Magic Packet depuis le relais
5 × démarrage Fedora sans intervention locale
5 × tailscaled actif et PC joignable
5 × SSH par clé depuis la tablette
5 × Sunshine joignable puis Moonlight connecté (si activé)
```

À consigner aussi : `ethtool` (`Wake-on: g`) après **chaque** arrêt ; encodeur réellement choisi par Sunshine (journal) ; état du verrouillage de session après réveil ; température et état de l'écran OLED pendant une session distante ; nombre de cycles où une intervention locale a été nécessaire (doit être **0**).

**Si le réveil échoue après un arrêt complet** mais fonctionne après une veille : activer `REMOTE_WOL_LINK_FALLBACK="true"` (le réglage est alors posé par `systemd-udev`, indépendamment de NetworkManager), puis recommencer les cycles. Si cela échoue encore, comparer arrêt (S5) et suspension (S3) : le projet a déjà une qualification de veille/reprise, à réutiliser.

**Critère d'arrêt :** un seul cycle nécessitant une intervention locale invalide la qualification du profil.

---

## 11. Dépannage

| Symptôme | Piste |
|---|---|
| `remote-doctor` : « WoL active » KO | Profil NetworkManager : `nmcli -g 802-3-ethernet.wake-on-lan connection show "<profil>"` doit afficher `magic`. Puis `sudo ethtool <interface>` : `Wake-on: g`. |
| Réveil impossible depuis l'extérieur | Le relais est-il joignable par Tailscale ? Envoie-t-il bien sur la **diffusion du LAN** ? Le PC clignote-t-il (liaison) après l'arrêt ? |
| SSH refuse la connexion | Clé dans `authorized_keys` ? `AllowUsers` correct ? Depuis le LAN, SSH est **volontairement fermé** : se connecter par l'adresse Tailscale. |
| Moonlight « PC introuvable » | Ajouter l'hôte par son adresse Tailscale ; Sunshine tourne-t-il (session ouverte) ? |
| Flux en H.264 au lieu d'AV1 | `vainfo` doit lister `VAProfileAV1Profile0 : VAEntrypointEncSlice` sur le nœud de la B580 ; sinon Sunshine retombe sur H.264. |
| Garde-fou KVM en urgence | `sudo /usr/local/libexec/fedora-gnome-custom/kvm-network-guard check` : `guard_mode=normal` et `100.64.0.0/10` dans `protected_networks`. |

---

## 12. Sources et limites de vérification

Les affirmations de ce guide viennent de recherches faites au moment de l'écriture ; ce qui n'a pas pu être relu à la source est signalé.

- Tailscale ne réveille pas un PC éteint ; relais sur le LAN : [Wake-on-LAN avec Tailscale et UpSnap](https://tailscale.com/blog/wake-on-lan-tailscale-upsnap) ; [routeurs de sous-réseau](https://tailscale.com/kb/1019/subnet-routers/).
- Sunshine : [documentation LizardByte](https://docs.lizardbyte.dev/projects/sunshine/v2025.118.151840/md_docs_2getting__started.html) ; [Sunshine Flatpak sous Wayland](https://discussion.fedoraproject.org/t/sunshine-flatpak-not-working-under-wayland/118302) ; [écran virtuel Sunshine sous GNOME (tiers)](https://github.com/fqazzazee/sunshine-screen-off).
- Encodage AV1 sur Battlemage : [Intel Media Driver 2024Q4](https://www.phoronix.com/news/Intel-Media-Driver-2024Q4).
- GNOME Remote Desktop, connexion distante : [fusion de la connexion graphique RDP](https://phoronix.com/news/GNOME-RDP-Remote-Login) ; [dépôt gnome-remote-desktop](https://github.com/GNOME/gnome-remote-desktop).
- Pare-feu Fedora Workstation (ports 1025-65535) : [Fedora Magazine — contrôler le pare-feu](https://fedoramagazine.org/control-the-firewall-at-the-command-line/).
- Wake-on-LAN et NetworkManager : [Arch Wiki — Wake-on-LAN](https://wiki.archlinux.org/title/Wol) ; [correctif r8169 depuis S5](https://lkml.iu.edu/hypermail/linux/kernel/1811.0/01283.html).

**Non vérifié depuis l'environnement de rédaction :** le contenu actuel de la documentation LizardByte et de celle de Tailscale (accès bloqué), la définition exacte du dépôt `tailscale.repo` (comparer `config/repos/tailscale.repo` avec la version publiée avant la première installation), le comportement du Realtek RTL8126 depuis un arrêt complet, et Sunshine sur Arc B580. Ce sont les raisons pour lesquelles le profil est **désactivé par défaut** et passe par le Gate 3.

**Étape suivante :** [CERTIFICATION.md](CERTIFICATION.md) (parcours des Gates), puis [PHYSICAL_QUALIFICATION_CHECKLIST.md](PHYSICAL_QUALIFICATION_CHECKLIST.md).

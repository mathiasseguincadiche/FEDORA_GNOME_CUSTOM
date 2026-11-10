# Générateur des schémas de la documentation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — quatorze paires source/rendu contrôlées ; sept vues mobiles vérifiées à 300 px et sept vues larges rendues à 700, 900 et 1100 px avec Inkscape ; aucune Gate 3 physique impliquée — matériel : non concerné

Les schémas de `docs/assets/diagrams/` sont produits par ce générateur, pas dessinés à la main. Chaque schéma est une paire : une source `.drawio`, éditable dans diagrams.net, et une image `.svg`, affichée par GitHub. Les deux sortent du même modèle, donc leurs libellés, leurs couleurs et leur géométrie sont identiques ; le `.svg` est écrit par le générateur, il n'est pas exporté depuis diagrams.net.

**Deux vues pour chaque sujet :** la vue horizontale, détaillée, et la vue verticale `-mobile` (canevas de 360 px, textes secondaires de 17 px, soit au moins 14 px quand l'image est affichée à 300 px). Le contenu des cartes mobiles provient des mêmes nœuds que la vue horizontale ; seule la disposition change. Les guides utilisent `<picture>` : **vue mobile pour les fenêtres de moins de 1600 px**, vue large sur les écrans spacieux. Ce seuil dépend de la *largeur de la fenêtre*, pas de la largeur effective du corps de texte GitHub ; il réduit le risque de miniaturiser les libellés larges sur un écran intermédiaire, sans garantir une largeur d'affichage fixe. Les deux vues et leurs sources restent accessibles par les liens directs sous chaque schéma. Un lecteur peut ainsi ouvrir la version large séparément et zoomer s'il le souhaite.

| Fichier | Rôle |
|---|---|
| `diagramkit.py` | Bibliothèque : boîtes, groupes, flèches, palette, contrôle que chaque texte tient dans sa boîte, écriture des deux formats. |
| `build.py` | Définition des sept schémas larges, avec le titre, la description et la géométrie de chacun ; construction des quatorze paires. |
| `mobile.py` | Recomposition verticale : textes repris des schémas larges, connecteurs explicites, lisibilité à 300 px. |
| `verify.py` | Contrôle : contraste de chaque couple de couleurs utilisé, libellés identiques entre `.drawio` et `.svg`. |

## Modifier un schéma

Depuis la racine du dépôt, avec Python 3 et sans dépendance externe :

1. Modifier le schéma concerné dans `tools/diagrams/build.py`, et sa description textuelle (troisième argument de `Diagram`) si le sens change. Pour son ordre de lecture ou ses liaisons à 300 px, intervenir dans `tools/diagrams/mobile.py`.
2. Régénérer les paires dans le dossier de la documentation :

   ```bash
   python3 tools/diagrams/build.py docs/assets/diagrams
   ```

3. Contrôler les contrastes et la concordance des libellés :

   ```bash
   python3 tools/diagrams/verify.py docs/assets/diagrams
   ```

4. Mettre à jour la description textuelle qui suit l'image dans la page concernée, puis lancer `tests/test_diagram_sources.py` et `tests/test_docs_integrity.py`.
5. Effectuer une **vérification visuelle réelle** des SVG mobiles à 300 px, puis des SVG larges à 700, 900 et 1100 px. À 700 px, privilégier la version mobile dans la page, et réserver la large au lien zoomable. Par exemple, avec Inkscape installé :

   ```bash
   inkscape docs/assets/diagrams/architecture-poste-mobile.svg \
     --export-type=png --export-width=300 \
     --export-filename=/tmp/architecture-poste-300.png

   inkscape docs/assets/diagrams/architecture-poste.svg \
     --export-type=png --export-width=900 \
     --export-filename=/tmp/architecture-poste-large-900.png
   ```

   Vérifier les retours à la ligne, l'ordre des flèches, l'absence de texte masqué et la compréhension sans zoom. Le contrôle automatique ne remplace pas cette observation.

`build.py` refuse un texte de carte ou un titre de groupe qui déborde de sa boîte, ainsi qu'une flèche vers un élément inconnu. `tests/test_diagram_sources.py` contrôle notamment que les libellés principaux des versions larges restent théoriquement à 12 px ou plus pour un affichage de référence à 960 px. Le test échoue aussi si un fichier de `docs/assets/diagrams/` ne correspond pas exactement au générateur : une retouche manuelle de l'image est détectée. Ces contrôles de dimensions **ne remplacent pas** la revue des rendus réels.

## Retoucher dans diagrams.net

Une source `.drawio` s'ouvre dans [diagrams.net](https://app.diagrams.net) (*Fichier → Ouvrir depuis → Appareil*), ou en lecture par son URL publique : `https://viewer.diagrams.net/#U` suivi de l'adresse `raw.githubusercontent.com` du fichier. Une retouche faite dans l'éditeur doit être reportée dans `build.py`, sinon la prochaine génération l'écrase et le test signale l'écart.

**Ne pas remplacer un `.svg` par un export de diagrams.net.** Les libellés des sources sont en HTML (`html=1`), pour le gras et les sous-titres : diagrams.net les exporte en `<foreignObject>`, que certains lecteurs SVG n'affichent pas, alors que le générateur écrit de simples éléments `<text>`. Un tel export diffère aussi octet pour octet de la sortie du générateur, et `tests/test_diagram_sources.py` le refuse.

## Ce que ces contrôles ne prouvent pas

`verify.py` mesure les couleurs déclarées, pas l'image affichée. Le rendu réel sur GitHub (thèmes clair et sombre, écran étroit) se vérifie en ouvrant la page ; la dernière vérification est datée en tête de ce fichier.

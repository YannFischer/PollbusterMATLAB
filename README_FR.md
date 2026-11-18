# Pollbuster MATLAB — interface native, moteur V18

## Démarrage rapide

1. Décompresser l'archive.
2. Dans MATLAB, sélectionner le dossier `PollbusterMATLAB` comme dossier courant.
3. Exécuter :

```matlab
runPollbuster
```

Ne pas ouvrir les fichiers de données pour lancer l'application. Aucun serveur, téléchargement, compilateur, Node.js, Python ou code JavaScript n'est nécessaire à l'exécution. Le projet emploie des fonctions MATLAB classiques (`figure`, `uicontrol`, `uitable`, `axes`). Il ne demande pas de toolbox additionnelle. Cible de développement : MATLAB R2021b ou plus récent ; compatibilité non testée en session MATLAB dans l'environnement de livraison.

## Statut de vérification — à lire

Le code a été porté et relu, mais **MATLAB et Octave ne sont pas installés dans l'environnement ayant généré ce projet**. L'interface et les fichiers `.m` n'ont donc pas été exécutés ici. Aucune certification d'identité numérique ou de compatibilité graphique n'est revendiquée avant les tests locaux.

Des entrées et sorties numériques du V18 original sont incluses comme oracles de test, et non comme substitut au calcul. Pour vérifier le moteur chez vous :

```matlab
rapport = pb_selftest;
```

Les 17 vérifications couvrent neuf cas à entrées figées, sept cas qui reconstruisent aussi les candidats/réservoirs en MATLAB et l'API publique H11. Elles incluent des déplacements, forces manuelles, variations de notoriété, loyauté, retour présidentiel et échelles des réservoirs. Tolérances : `1e-8` point sur les scores et `1e-3` personne sur les voix. Les tests vérifient aussi la conservation des réservoirs et les sommes par origine et catégorie sociale. Tout écart déclenche une erreur explicite : ne pas interpréter les résultats si les tests échouent. Un test de calcul ne remplace pas un test manuel de l'interface.

## Ce que permet le GUI

- Activer/désactiver chacun des douze candidats prévus dans le scénario 2027.
- Charger les plateaux H11, H10 sans Attal, H10b sans Philippe ou le plateau complet avec Villepin.
- Modifier la notoriété, une force multiplicative, la zone et la position politique d'un candidat.
- Jouer avec beta, betaVac, bonus de famille, lambda, kappa, absorption vers l'abstention, sigmas, alpha et gamma.
- Activer les thèmes, modifier leurs six poids, theta et les six coefficients de chaque candidat.
- Modifier P_RET, la loyauté des revenants, le regroupement des socles et l'échelle de chaque réservoir.
- Consulter la carte à bulles, les scores, les origines des voix et les compositions sociales.
- Sauvegarder/charger un scénario MAT, exporter trois CSV et exporter la vue courante en PNG.

Les curseurs recalculent au relâchement. Les modifications valides des tables déclenchent un recalcul. Les tables sont défilables horizontalement pour accéder aux colonnes hors champ. Pour déplacer un candidat, cocher « Deplacer » puis modifier X/Y. Un changement de X/Y non coché reste sans effet, volontairement.

### Configuration initiale

H11, sans Villepin, avec Attal et Philippe ; thèmes désactivés. C'est une référence explicitement choisie, pas une reproduction garantie de l'état actuel du navigateur. Exemple de sortie numérique du moteur original, fourni seulement pour contrôle : Mélenchon 23,051727 %, Le Pen 26,360798 %. Le code MATLAB doit retrouver ces valeurs si le portage passe les tests.

## Calcul et visualisation

1. `pb_build2027` reconstruit les réservoirs à partir des bases 2022, des transitions 2024, des retours présidentiels et des origines regroupées.
2. `pb_candidates` calcule la notoriété native à partir de ses critères et applique les modifications.
3. `pb_core` calcule les probabilités d'attraction par catégorie utilisées par V18.
4. `pb_engine` ancre les profils sur les trajectoires, répartit les réservoirs par catégorie, applique famille/héritage, porosités, usure, thèmes, déplacements et absorption vers l'abstention.
5. Les scores sont normalisés sur les voix attribuées aux candidats, hors pertes vers l'abstention.
6. Les coordonnées de carte sont des barycentres des voix simulées de six catégories : agriculture/artisanat, cadres, professions intermédiaires, employés, ouvriers, retraités. Les inactifs restent inclus dans les scores, pas dans les barycentres de la carte.
7. Le croisement des axes est le barycentre de ces mêmes suffrages à six catégories. La surface des bulles est proportionnelle au score.

**Les X/Y modifiables sont les coordonnées politiques internes d'attraction. Ils ne sont pas les X/Y affichés sur la carte sociale.** Un déplacement politique peut donc produire un déplacement social différent, voire très faible.

« Origine des voix » affiche la contribution exacte de chaque réservoir dans une exécution commune avec le plateau complet, par différence avant/après allocation du réservoir. Le site évoque des calculs isolés par réservoir : cette vue n'imite pas son implémentation d'interface à l'identique et n'étiquette pas tous les apports « fidèles ». La somme affichée est additive et égale au total du candidat.

Les pertes vers l'abstention portent uniquement sur les réservoirs modélisés. Elles ne représentent pas le taux national d'abstention. Modifier l'échelle d'un réservoir ou P_RET modifie aussi la masse à répartir, pas seulement les parts de candidats.

### Thèmes

Poids par défaut : économie 30, social 29, environnement 13, identité 16, représentation 6, défense 5, total 99. Ils sont utilisés comme poids relatifs, sans les présenter comme une prévision de vote. Leur attribution à « enquête sept. 2026 » vient du code source et n'est pas vérifiée extérieurement ici. Aucun tableau comparable 2022 n'est inventé. Les profils candidats sont des coefficients d'auteur, pas des statistiques observées.

### Couleurs

Palette des familles du site : rouge gauche radicale, rose social-démocratie, vert écologie, orange/ambre centre et macronisme, bleu clair centre droit, bleu LR, bleu foncé RN, brun droite identitaire. Les zones restent celles du moteur. Les couleurs ne sont pas une certification des couleurs officielles des partis.

## Utilisation sans interface

```matlab
D = pb_load;
cfg = pb_defaults(D);
cfg.options.beta = 0.8;
cfg.themesEnabled = true;
cfg.salience.soc = 45;
r = pb_simulate(D,cfg);
figure; pb_drawmap(axes,D,r,false);
pb_export(r,D,'resultats.csv');
```

Exemple de notoriété et déplacement :

```matlab
cfg.candidateOverrides.jlm = struct('noto',0.8,'force',1,'pos',[0.15 -0.25]);
r = pb_simulate(D,cfg);
```

Pour modifier la participation par catégorie, non exposée dans le GUI :

```matlab
cfg.options.part = D.core.part;
cfg.options.part.ouv = 0.75;
```

## Backtests

```matlab
exemple_backtests
```

Ce script recalcule 2017 et 2022 avec le moteur MATLAB à partir des entrées figées correspondantes. Les scores ne sont pas simplement chargés. Le générateur de ces réservoirs historiques n'est pas porté : seules leurs entrées numériques sont fournies. Le GUI principal sert à 2027.

Le V18 2017 couvre neuf candidats (sans Asselineau et Cheminade). Les références réelles ne sont pas renormalisées. Ni les références, ni les paramètres historiques ne constituent une évaluation hors échantillon.

## Périmètre et limites

- Premier tour V18, pas second tour.
- Pas d'ajout de famille/candidat arbitraire dans cette première interface.
- Pas d'automatisation d'un navigateur, d'appel à JavaScript ou de pont Python.
- Les données JSON sont statiques, lisibles et modifiables ; ce ne sont pas des programmes.
- Le noyau porte la branche de probabilités `P` effectivement consommée par V18. Le score diagnostique `S` de l'ancien noyau, ses plafonds et les diagnostics de rivalités non utilisés pour l'allocation V18 ne sont pas reproduits.
- Le réglage « force » est un multiplicateur manuel optionnel, égal à 1 par défaut ; il ne remplace pas une donnée observée.
- Les paramètres hérités de l'auteur contiennent des informations rétrospectives et des hypothèses contestables. Les résultats sont conditionnels à ces paramètres, pas des probabilités de victoire.
- Le rendu est une visualisation MATLAB inspirée de la carte du site, pas une copie pixel pour pixel.
- Le placement des étiquettes est heuristique ; des chevauchements restent possibles après de grands déplacements.

## Fichiers principaux

- `runPollbuster.m` : lancement.
- `pb_gui.m` : interface.
- `pb_defaults.m`, `pb_build2027.m`, `pb_candidates.m` : scénario natif.
- `pb_core.m`, `pb_engine.m`, `pb_simulate.m` : calcul.
- `pb_drawmap.m`, `pb_export.m` : visualisation et export.
- `pb_selftest.m` : comparaisons de référence.
- `exemple_sans_GUI.m`, `exemple_backtests.m` : exemples.
- `data/model.json` : constantes et données du modèle fourni.
- `data/references.json` : entrées et sorties de contrôle du moteur original.

Origine : fichiers du simulateur fournis dans la conversation, moteur V18 et scénario 2027. Ce projet ne revendique aucune affiliation à Pollbuster et ne change pas les droits de leurs auteurs sur les données et le modèle d'origine.

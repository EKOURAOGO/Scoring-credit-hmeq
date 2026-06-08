# Scoring de crédit immobilier — HMEQ

Projet de modélisation du risque de défaut de crédit immobilier sur la base de données HMEQ.
Approche multi-langages : SAS, R et Python.

## Structure du projet

| Fichier | Langage | Contenu |
|---------|---------|---------|
| CodeSas.sas | SAS | Imputation multiple PMM + construction du score |
| CodeR.R | R | Validation croisée + tests de robustesse |
| CodePython.ipynb | Python | Benchmark 4 algorithmes ML |
| Rapport scoring.pdf | — | Rapport complet |

## Méthodologie

### 1. Analyse SAS
- Imputation multiple par PMM (Predictive Mean Matching)
- Construction du score de défaut
- Analyse explicative des drivers du défaut

### 2. Validation R
- Validation croisée
- Tests de robustesse
- Vérification indépendante des résultats SAS

### 3. Modélisation Python — Benchmark comparatif
| Modèle | Description |
|--------|-------------|
| Régression logistique | Modèle de référence |
| Arbre de décision | Interprétabilité |
| Random Forest | Robustesse |
| XGBoost | Performance |

## Installation Python

```bash
pip install pandas numpy scikit-learn xgboost matplotlib seaborn jupyter
jupyter notebook CodePython.ipynb
```

## Auteurs
Emmanuel KOURAOGO

/* ===================================================================
  PROJET Projet HMEQ - VERSION ESSENTIELLE ANALYSTE RISQUE
   Objectif : Analyse explicative et drivers du défaut
   Approche : Imputation multiple par PMM (Predictive Mean Matching)
              Variables catégorielles : "Unknown" pour les modalités manquantes
   =================================================================== */

options nodate nonumber linesize=120;
ods graphics on;

libname projet "C:\Users\arouna.kone\Downloads\Projet";

/* ================================================================
   SORTIE HTML PRINCIPALE
   ================================================================ */

ods html path="C:\Users\arouna.kone\Downloads\Projet\Resultats"
         body="rapport_Projet.html"
         style=journal;

/* ================================================================
   BLOC 1 - IMPORTATION & SÉLECTION DES DONNÉES BRUTES
   ================================================================ */

title "IMPORTATION DES DONNÉES";

proc import datafile="C:\Users\arouna.kone\Downloads\Projet\hmeq.csv"
    out=Projet.hmeq_raw
    dbms=csv replace;
    getnames=yes;
run;
proc contents data=Projet.hmeq_raw;
run;

/* -----------------------------------------------------------------
   ÉTAPE 1 : Sélection des colonnes brutes et traitement
             des variables catégorielles
   ----------------------------------------------------------------- */
data hmeq_brut;
    set Projet.hmeq_raw;
    keep BAD LOAN MORTDUE VALUE REASON JOB YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC;
   
    /* Traitement REASON - les vides deviennent "Unknown" */
    if missing(REASON) or REASON = "" then REASON = "Unknown";
   
    /* Traitement JOB - les vides deviennent "Unknown" */
    if missing(JOB) or JOB = "" then JOB = "Unknown";
   
    /* Création des flags missing informatifs AVANT imputation */
    miss_DEBTINC = missing(DEBTINC);
    miss_YOJ = missing(YOJ);
    miss_DEROG = missing(DEROG);
    miss_DELINQ = missing(DELINQ);
    miss_CLAGE = missing(CLAGE);
    miss_NINQ = missing(NINQ);
    miss_MORTDUE = missing(MORTDUE);
    miss_VALUE = missing(VALUE);
   
    label
        miss_DEBTINC = "DEBTINC manquant"
        miss_YOJ = "YOJ manquant"
        miss_DEROG = "DEROG manquant"
        miss_DELINQ = "DELINQ manquant"
        miss_CLAGE = "CLAGE manquant"
        miss_NINQ = "NINQ manquant"
        miss_MORTDUE = "MORTDUE manquant"
        miss_VALUE = "VALUE manquant";
run;

/* Vérification des valeurs manquantes avant imputation */
title "VALEURS MANQUANTES AVANT IMPUTATION";

ods output summary=resume;

proc means data=hmeq_brut n nmiss mean std min max stackodsoutput;
    var LOAN MORTDUE VALUE YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC;
run;

data resume;
    set resume;
    pct_missing = (NMiss / N) * 100;
run;

proc print data=resume noobs;
run;


proc freq data=hmeq_brut;
    tables REASON JOB;
    title "DISTRIBUTION APRÈS RECODAGE UNKNOWN";
run;

/* ================================================================
   BLOC 2 - IMPUTATION MULTIPLE AVEC PROC MI (MÉTHODE PMM)
   ================================================================ */

title "IMPUTATION MULTIPLE - MÉTHODE PMM (Predictive Mean Matching)";

/* -----------------------------------------------------------------
   ÉTAPE 2 : Imputation Multiple avec PROC MI
   Équivalent SAS du MICE avec PMM (Predictive Mean Matching)
   ----------------------------------------------------------------- */
proc mi data=hmeq_brut seed=123 nimpute=5 out=Projet.hmeq_imputed_all;
    /* Variables catégorielles (déjà traitées, servent de prédicteurs) */
    class REASON JOB;
   
    /* PMM pour les variables continues - préserve la distribution originale */
    fcs regpmm(LOAN MORTDUE VALUE YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC);
   
    /* Variables à imputer */
    var REASON JOB LOAN MORTDUE VALUE YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC;
   
    /* Affichage des détails */
    ods select MissPattern ModelInfo IterHistory ParameterEstimates;
run;
proc means data=Projet.hmeq_imputed_all n nmiss;
    var LOAN MORTDUE VALUE YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC;
run;


/* -----------------------------------------------------------------
   ÉTAPE 3 : Extraction du premier jeu de données imputé
   Équivalent de complete(imputed_data, 1) dans R
   ----------------------------------------------------------------- */
data Projet.hmeq_imp;
    set Projet.hmeq_imputed_all;
    where _Imputation_ = 1;
    drop _Imputation_;
run;


/* Vérification : plus aucune valeur manquante */
title "CONTRÔLE - AUCUNE VALEUR MANQUANTE APRÈS IMPUTATION";
proc means data=Projet.hmeq_imp n nmiss;
    var LOAN MORTDUE VALUE YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC;
run;

/* ================================================================
   BLOC 3 - CRÉATION DES VARIABLES MÉTIER APRÈS IMPUTATION
   ================================================================ */

data Projet.hmeq;
    set Projet.hmeq_imp;
   
    /* Ratio Loan to Value */
    if VALUE > 0 then LTV = LOAN / VALUE;
    else LTV = .; /* Normalement VALUE est imputé, donc ce cas ne devrait pas arriver */
   
    /* Catégories LTV pour analyse */
    if LTV < 60 then LTV_CAT = "1: <60%";
    else if LTV < 80 then LTV_CAT = "2: 60-80%";
    else if LTV < 95 then LTV_CAT = "3: 80-95%";
    else if LTV >= 95 then LTV_CAT = "4: >=95%";
    else LTV_CAT = "5: Manquant";
   
    /* Transformations pour normalité */
    LOG_CLAGE = log(CLAGE + 1);
    LOG_LOAN = log(LOAN);
    LOG_MORTDUE = log(MORTDUE + 1);
    LOG_VALUE = log(VALUE + 1);
    SQRT_DELINQ = sqrt(DELINQ);
    SQRT_DEROG = sqrt(DEROG);
    SQRT_NINQ = sqrt(NINQ);
   
    label
        LTV = "Loan To Value"
        LTV_CAT = "Catégorie LTV"
        LOG_CLAGE = "Log(CLAGE+1)"
        LOG_LOAN = "Log(LOAN)"
        LOG_MORTDUE = "Log(MORTDUE+1)"
        LOG_VALUE = "Log(VALUE+1)"
        SQRT_DELINQ = "Racine(DELINQ)"
        SQRT_DEROG = "Racine(DEROG)"
        SQRT_NINQ = "Racine(NINQ)";
run;

/* ================================================================
   BLOC 4 - PROFIL DU RISQUE
   ================================================================ */

title "TAUX DE DÉFAUT GLOBAL";

proc freq data=Projet.hmeq;
    tables BAD / binomial(level='1');
run;
 
/* Test Chi2 : relation entre missing (avant imputation) et défaut */
data hmeq_brut;
    set Projet.hmeq_raw;

    if missing(REASON) or REASON = "" then REASON = "Unknown";
    if missing(JOB) or JOB = "" then JOB = "Unknown";

    miss_DEBTINC = missing(DEBTINC);
    miss_YOJ = missing(YOJ);
    miss_DEROG = missing(DEROG);
    miss_DELINQ = missing(DELINQ);
    miss_CLAGE = missing(CLAGE);
    miss_NINQ = missing(NINQ);
    miss_MORTDUE = missing(MORTDUE);
    miss_VALUE = missing(VALUE);
run;


title "TEST CHI² MISSING VS BAD";
proc freq data=hmeq_brut;
    tables (miss_DEBTINC miss_YOJ miss_DEROG miss_DELINQ
            miss_CLAGE miss_NINQ miss_MORTDUE miss_VALUE JOB REASON)*BAD / chisq;
run;
proc contents data=hmeq_brut varnum;
run;


/* ================================================================
   BLOC 5 - GRAPHIQUES PROFIL DE RISQUE
   Graphiques 1 et 2 - Taux de défaut par REASON et JOB
   ================================================================ */

title "Graphique 1 - Taux de défaut par motif de prêt";

ods graphics / reset width=800 height=600 imagename="graph_bar_reason" imagefmt=png;

proc sgplot data=Projet.hmeq;
    vbar REASON / response=BAD
                  stat=mean
                  datalabel
                  fillattrs=(color=cx3498db)
                  barwidth=0.6;
    yaxis grid label="Taux de défaut (%)"
          values=(0 to 0.25 by 0.05)
          valueformat=percent8.1;
    xaxis label="Motif du prêt"
          valueattrs=(size=10);
    format BAD percent8.1;
    label BAD = "Taux de défaut";
    title "Taux de défaut selon le motif du prêt";
    footnote "Note : La modalité 'Unknown' correspond aux motifs non renseignés";
run;


title "Graphique 2 - Taux de défaut par catégorie d'emploi";

ods graphics / reset width=800 height=1000 imagename="graph_bar_job" imagefmt=png;

proc sgplot data=Projet.hmeq;
    vbar JOB / response=BAD
               stat=mean
               datalabel
               fillattrs=(color=cx2ecc71)
               barwidth=0.7
               categoryorder=respdesc;
    yaxis grid
      label="Taux de défaut (%)"
      valueformat=percent8.1;;
    xaxis label="Catégorie d'emploi"
          valueattrs=(size=10);
    format BAD percent8.1;
    label BAD = "Taux de défaut";
    title "Taux de défaut selon la catégorie d'emploi";
    footnote "Note : La modalité 'Unknown' correspond aux emplois non renseignés";
run;


/* ================================================================
   BLOC 6 - ANALYSE UNIVARIÉE
   ================================================================ */

/* ---------- VARIABLES CONTINUES ---------- */
%macro test_cont(var);

title "TEST UNIVARIÉ &var";

/* Test Student */
proc ttest data=Projet.hmeq;
    class BAD;
    var &var;
run;

/* Test robuste Mann Whitney */
proc npar1way data=Projet.hmeq wilcoxon;
    class BAD;
    var &var;
run;

/* Visualisation avec couleurs */
ods graphics / attrpriority=none;

proc sgplot data=Projet.hmeq;
    styleattrs datacolors=(steelblue darkorange);
    vbox &var / category=BAD group=BAD;
    title "Distribution de &var selon BAD (après imputation PMM)";
run;

%mend;

%test_cont(DEBTINC);
%test_cont(LOAN);
%test_cont(CLAGE);
%test_cont(YOJ);
%test_cont(LTV);
%test_cont(DELINQ);
%test_cont(DEROG);
%test_cont(NINQ);
%test_cont(MORTDUE);
%test_cont(VALUE);

/* ---------- VARIABLES CATÉGORIELLES ---------- */
title "TEST CHI² VARIABLES CATÉGORIELLES";

proc freq data=Projet.hmeq;
    tables REASON*BAD JOB*BAD LTV_CAT*BAD / chisq;
    title "Test Chi2 avec modalités Unknown incluses";
run;

/* ---------- VARIABLES CATÉGORIELLES ---------- */

title "TEST CHI² VARIABLES CATÉGORIELLES";

proc freq data=Projet.hmeq;
    tables REASON*BAD JOB*BAD / chisq;
run;


/* ================================================================
   BLOC 7 - TEST ANOVA
   Vérifie différences entre groupes métiers
   ================================================================ */

title "ANOVA - DEBTINC SELON TYPE EMPLOI";

proc glm data=Projet.hmeq;
    class JOB;
    model DEBTINC = JOB;
    means JOB / tukey hovtest;
    title "ANOVA avec modalité Unknown";
run;
quit;

/* ANOVA INTERACTION BAD × JOB */
title "ANOVA INTERACTION BAD * JOB";

proc glm data=Projet.hmeq;
    class BAD JOB;
    model DEBTINC = BAD JOB BAD*JOB;
    lsmeans BAD JOB / adjust=tukey;
run;
quit;

/* ================================================================
   BLOC 8 - INFORMATION VALUE SIMPLIFIÉ
   ================================================================ */

%macro calculate_iv(var);
  proc rank data=Projet.hmeq groups=10 out=temp_bin_&var;
      var &var;
      ranks bin;
      where &var is not null;
  run;

  proc sql;
  create table IV_&var as
  select
      "&var" as Variable length=20,
      sum((bons/tot_bons - mauvais/tot_mauvais) *
          log((bons/tot_bons)/(mauvais/tot_mauvais))) as IV
  from (
      select
          bin,
          sum(BAD=0) as bons,
          sum(BAD=1) as mauvais,
          (select sum(BAD=0) from temp_bin_&var) as tot_bons,
          (select sum(BAD=1) from temp_bin_&var) as tot_mauvais
      from temp_bin_&var
      group by bin
  );
  quit;
%mend;

/* Exécution des macros */
%calculate_iv(DEBTINC);
%calculate_iv(CLAGE);
%calculate_iv(YOJ);
%calculate_iv(LOAN);
%calculate_iv(LTV);
%calculate_iv(DELINQ);
%calculate_iv(DEROG);
%calculate_iv(NINQ);
%calculate_iv(MORTDUE);
%calculate_iv(VALUE);

/* Supprimer la table qui a causé le problème */
proc datasets lib=work nolist;
    delete IV_summary;
quit;

/* Maintenant ça fonctionne */
data IV_summary;
    length Pouvoir_Predictif $20;
    set IV_:;
    
    if IV < 0.02 then Pouvoir_Predictif = "Faible";
    else if IV < 0.1 then Pouvoir_Predictif = "Moyen";
    else if IV < 0.3 then Pouvoir_Predictif = "Fort";
    else Pouvoir_Predictif = "Très fort";
run;
proc print data=IV_summary;
title "INFORMATION VALUE - POUVOIR PRÉDICTIF DES VARIABLES";
format IV 6.4;
run;

/* ================================================================
   BLOC 9 - MULTICOLINÉARITÉ
   ================================================================ */

title "MATRICE CORRÉLATION";

proc corr data=Projet.hmeq plots=matrix(histogram);
    var LOAN MORTDUE VALUE DEBTINC CLAGE YOJ LTV DELINQ DEROG NINQ;
run;

title "VIF - FACTEUR D'INFLATION DE VARIANCE";

proc reg data=Projet.hmeq;
    model BAD = LOAN MORTDUE VALUE DEBTINC CLAGE YOJ LTV DELINQ DEROG NINQ / vif tol;
run;
quit;

/* ================================================================
   BLOC 10 - MODÈLE LOGISTIQUE EXPLICATIF (SANS IMPUTATION MÉDIANE)
   ================================================================ */

title "MODÈLE LOGISTIQUE EXPLICATIF - DONNÉES IMPUTÉES PAR PMM";

proc logistic data=Projet.hmeq descending plots(only)=(roc oddsratio);
    class REASON JOB / param=ref ref=first;
   
    model BAD(event='1') =
        DEBTINC
        YOJ
        CLAGE
        DELINQ
        DEROG
        NINQ
        LTV
        LOAN
        MORTDUE
        VALUE
        REASON
        JOB
        / selection=stepwise slentry=0.1 slstay=0.1 details lackfit;

    oddsratio DEBTINC / cl=pl;
    oddsratio DELINQ / cl=pl;
    oddsratio LTV / cl=pl;
    oddsratio CLAGE / cl=pl;
   
    output out=Projet.pred
           p=prob
           xbeta=logit
           reschi=residual
           h=leverage;
   
    title "Modèle logistique après imputation multiple (PMM)";
run;

/* ================================================================
   EXPORT DES COEFFICIENTS DU MODÈLE LOGISTIQUE FINAL (PMM)
   ================================================================ */

/* Sécurité ODS : on s'assure que tout s'affiche */
ods select all;
ods exclude none;

/* ------------------------------------------------
   1. Estimation du modèle + capture des coefficients
   ------------------------------------------------ */

ods output ParameterEstimates=Coef_full;

proc logistic data=Projet.hmeq descending;
    class REASON JOB / param=ref ref=first;
   
    model BAD(event='1') =
        DEBTINC
        YOJ
        CLAGE
        DELINQ
        DEROG
        NINQ
        LTV
        LOAN
        MORTDUE
        VALUE
        REASON
        JOB
        / selection=stepwise
          slentry=0.1
          slstay=0.1
          details
          lackfit;

    title "MODÈLE LOGISTIQUE EXPLICATIF - DONNÉES IMPUTÉES PAR PMM";
run;

/* ------------------------------------------------
   2. Identification de la dernière étape (modèle final)
   ------------------------------------------------ */

proc sql noprint;
    select max(Step) into :maxstep
    from Coef_full;
quit;

/* ------------------------------------------------
   3. Coefficients du modèle FINAL uniquement
   ------------------------------------------------ */

data Coef_final;
    set Coef_full;
    where Step = &maxstep;

    /* Odds Ratio calculé à partir du coefficient */
    Odds_Ratio = exp(Estimate);
run;

/* ------------------------------------------------
   4. Export WORD (RTF)
   ------------------------------------------------ */

ods rtf file="C:\Users\arouna.kone\Downloads\Projet\Resultats\Coefficients_Modele_Logistique_Final_PMM.rtf"
        style=journal
        bodytitle;

title "Coefficients du modèle logistique final (PMM)";

/* Tableau propre pour Word / mémoire */
proc print data=Coef_final noobs label;
    var Variable ClassVal0 Estimate StdErr WaldChiSq ProbChiSq Odds_Ratio;
    label
        Variable   = "Variable"
        ClassVal0  = "Modalité (si catégorielle)"
        Estimate   = "Coefficient (ß)"
        StdErr     = "Erreur standard"
        WaldChiSq  = "Chi² de Wald"
        ProbChiSq  = "p-value"
        Odds_Ratio = "Odds Ratio exp(ß)";
    format Estimate 8.4 StdErr 8.4 Odds_Ratio 8.3 ProbChiSq pvalue6.4;
run;

ods rtf close;


/* ================================================================
   BLOC 11 - TRANSFORMATION EN SCORE
   ================================================================ */

data Projet.score;
    set Projet.pred;
   
    odds = prob/(1-prob);
    score = 600 - (20/log(2))*log(odds);
   
    /* Arrondi et clipping */
    score_round = round(score);
    if score_round < 300 then score_round = 300;
    if score_round > 900 then score_round = 900;
   
    /* Catégorie de risque */
    if score_round >= 680 then risque = "1: Bon";
    else if score_round >= 580 then risque = "2: Moyen";
    else if score_round >= 480 then risque = "3: Risqué";
    else risque = "4: Très risqué";
   
    label
        score = "Score de crédit"
        risque = "Catégorie de risque";
run;

/* ================================================================
   BLOC 12 - GRAPHIQUES DE PERFORMANCE SCORE
   Graphiques 3, 4 et complémentaires
   ================================================================ */

title "Graphique 3 - Distribution du score de crédit (après imputation PMM)";

ods graphics / reset width=800 height=600 imagename="graph_distribution_score" imagefmt=png;

proc sgplot data=Projet.score;
    histogram score / nbins=30
                     fillattrs=(color=steelblue transparency=0.4)
                     outline;
    density score / type=normal
                    lineattrs=(color=red thickness=2 pattern=solid)
                    legendlabel="Distribution normale";
    density score / type=kernel
                    lineattrs=(color=darkgreen thickness=2 pattern=dash)
                    legendlabel="Estimation kernel";
    keylegend / position=topright location=inside;
    xaxis grid label="Score de crédit"
          values=(200 to 1000 by 100);
    yaxis grid label="Fréquence";
run;
title;

title "Graphique 4 - Distribution du score par statut de défaut";

ods graphics / reset width=800 height=600 imagename="graph_score_par_BAD" imagefmt=png;

proc sgplot data=Projet.score;
    vbox score / category=BAD
                 fillattrs=(color=cx3498db transparency=0.3)
                 meanattrs=(color=red symbol=diamondFilled size=10)
                 medianattrs=(color=blue thickness=2)
                 whiskerattrs=(color=gray thickness=1);
    xaxis label="Statut de défaut (0 = Bon, 1 = Défaut)"
          valueattrs=(size=11);
    yaxis grid label="Score de crédit"
          values=(200 to 1000 by 100);
    title "Distribution du score selon le statut de défaut";
   
    /* Calcul des moyennes */
    proc means data=Projet.score noprint;
        class BAD;
        var score;
        output out=moyennes_score mean=Score_Moyen;
    run;
run;
title;

/* Courbe de performance par décile */
title "Graphique complémentaire - Taux de défaut par décile de score";

proc rank data=Projet.score groups=10 out=score_deciles;
    var score;
    ranks decile;
run;

proc sql;
create table taux_defaut_decile as
select
    decile + 1 as Decile,
    count(*) as N,
    sum(BAD) as N_Defauts,
    mean(BAD) as Taux_Defaut,
    min(score) as Score_Min,
    max(score) as Score_Max,
    mean(score) as Score_Moyen,
    (calculated N_Defauts / calculated N) as Taux_Defaut_Calc
from score_deciles
group by decile
order by decile;
quit;

ods graphics / reset width=800 height=600 imagename="graph_taux_defaut_decile" imagefmt=png;

proc sgplot data=taux_defaut_decile;
    series x=Decile y=Taux_Defaut /
           markers
           markerattrs=(symbol=circleFilled size=10)
           lineattrs=(color=red thickness=3);
    xaxis grid label="Décile de score (1 = score le plus faible, 10 = score le plus élevé)"
          integer values=(1 to 10);
    yaxis grid label="Taux de défaut"
          /*values=(0 to 0.5 by 0.05)*/
          valueformat=percent8.1;
    format Taux_Defaut percent8.1;
    title "Taux de défaut par décile de score (imputation PMM)";
    footnote "Relation décroissante : plus le score est élevé, plus le risque est faible";
run;
title;

/* ================================================================
   BLOC 13 - SYNTHÈSE COMPARATIVE DES MÉTHODES D'IMPUTATION
   ================================================================ */

title "COMPARAISON STATISTIQUES AVANT/APRÈS IMPUTATION PMM";

/* Statistiques avant imputation */
proc means data=hmeq_brut n nmiss mean std p25 p50 p75;
    var DEBTINC YOJ CLAGE DELINQ DEROG NINQ LOAN MORTDUE VALUE;
    output out=stats_avant mean= median=p50;
    title "Statistiques avant imputation (données brutes)";
run;

/* Statistiques après imputation */
proc means data=Projet.hmeq n mean std p25 p50 p75;
    var DEBTINC YOJ CLAGE DELINQ DEROG NINQ LOAN MORTDUE VALUE;
    output out=stats_apres mean= median=p50;
    title "Statistiques après imputation PMM";
run;

/* ================================================================
   BLOC 14 - EXPORT WORD + HTML
   ================================================================ */

ods html close;

ods rtf file="C:\Users\arouna.kone\Downloads\Projet\Resultats\rapport_Projet_PMM.rtf"
        style=journal
        bodytitle;

title "SYNTHÈSE PROJET HMEQ - IMPUTATION MULTIPLE PMM";

/* Section 1: Traitement des missings */
ods proclabel "1. Gestion des valeurs manquantes";
proc freq data=hmeq_brut;
    tables REASON JOB;
    title "Modalités Unknown après recodage";
run;

proc means data=hmeq_brut n nmiss;
    var DEBTINC YOJ CLAGE DELINQ DEROG NINQ LOAN MORTDUE VALUE;
    title "Missings avant imputation";
run;

proc means data=Projet.hmeq n nmiss;
    var DEBTINC YOJ CLAGE DELINQ DEROG NINQ LOAN MORTDUE VALUE;
    title "Zéro missing après imputation PMM";
run;

/* Section 2: Profil risque */
ods proclabel "2. Profil de risque";
proc freq data=Projet.hmeq;
    tables BAD / binomial;
run;

/* Section 3: Graphiques */
ods proclabel "3. Analyse graphique";
proc sgplot data=Projet.hmeq;
    vbar REASON / response=BAD stat=mean;
    title "Taux défaut par motif (Unknown inclus)";
run;

proc sgplot data=Projet.hmeq;
    vbar JOB / response=BAD stat=mean categoryorder=respdesc;
    title "Taux défaut par emploi (Unknown inclus)";
run;

/*khi2*/
proc freq data=hmeq_brut;
    tables (miss_DEBTINC miss_YOJ miss_DEROG miss_DELINQ
            miss_CLAGE miss_NINQ miss_MORTDUE miss_VALUE JOB REASON)*BAD / chisq;
run;

/* Section 4: Information Value */
ods proclabel "4. Information Value";
proc print data=IV_summary noobs;
    var Variable IV Pouvoir_Predictif;
    format IV 6.4;
    title "Pouvoir prédictif des variables";
run;

/* Section 5: Modèle */
ods proclabel "5. Modèle logistique";
proc logistic data=Projet.hmeq descending;
    class REASON JOB / param=ref;
    model BAD = DEBTINC YOJ CLAGE DELINQ DEROG NINQ LTV REASON JOB
              / selection=stepwise;
    title "Modèle final sur données imputées PMM";
run;

ods rtf close;

/* ================================================================
   EXPORT CSV DES RÉSULTATS
   ================================================================ */

proc export data=Projet.score
    outfile="C:\Users\arouna.kone\Downloads\Projet\Resultats\scores_PMM.csv"
    dbms=csv replace;
run;

proc export data=IV_summary
    outfile="C:\Users\arouna.kone\Downloads\Projet\Resultats\information_value_PMM.csv"
    dbms=csv replace;
run;

proc export data=Projet.hmeq
    outfile="C:\Users\arouna.kone\Downloads\Projet\Resultats\donnees_imputees_PMM.csv"
    dbms=csv replace;
run;

/* ================================================================
   MESSAGE DE FIN
   ================================================================ */

%put ==============================================================;
%put ANALYSE PROJET HMEQ TERMINÉE - IMPUTATION MULTIPLE PMM;
%put ==============================================================;
%put Méthode employée :;
%put - Variables catégorielles : recodage des missings en "Unknown";
%put - Variables continues : imputation multiple PMM (Predictive Mean Matching);
%put - Aucune imputation par médiane réalisée;
%put ==============================================================;
%put Fichiers créés dans Resultats :;
%put - donnees_imputees_PMM.csv;
%put - scores_PMM.csv;
%put - information_value_PMM.csv;
%put - rapport_Projet_PMM.rtf;
%put - Graphiques PNG (barres, distribution, score);
%put ==============================================================;

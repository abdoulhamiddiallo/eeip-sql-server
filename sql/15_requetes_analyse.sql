/* =====================================================================
   EEIP · Script 15 : requêtes d'analyse de gourou
   ---------------------------------------------------------------------
   Chaque bloc répond à une question d'énergéticien. Exécutez-les un par un.
   ===================================================================== */
USE EEIP;
GO

/* 1. La « courbe en canard » : consommation et solaire français, heure locale moyenne, par saison */
WITH H AS (
    SELECT s.FiliereId, i.Code AS Indicateur,
           DATEPART(HOUR, DATEADD(MINUTE, d.DecalageMinutes, m.InstantUtc)) AS HeureLocale,
           c.Saison, CAST(m.Valeur AS float) AS V
    FROM core.Mesure AS m
    JOIN core.Serie AS s ON s.SerieId = m.SerieId
    JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
    JOIN core.Zone AS z ON z.ZoneId = s.ZoneId AND z.Code = 'FR'
    JOIN core.Source AS so ON so.SourceId = s.SourceId AND so.Code = 'ODRE'
    JOIN core.FuseauDecalage AS d ON d.Fuseau = z.Fuseau AND m.InstantUtc >= d.DebutUtc AND m.InstantUtc < d.FinUtc
    JOIN core.Calendrier AS c ON c.DateJour = CAST(DATEADD(MINUTE, d.DecalageMinutes, m.InstantUtc) AS date)
    LEFT JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId
    WHERE m.InstantUtc >= DATEADD(YEAR, -1, SYSUTCDATETIME())
      AND (i.Code = 'CONSO_ELEC' OR (i.Code = 'PROD_ELEC' AND f.Code = 'SOLAIRE'))
)
SELECT Saison, HeureLocale,
       CAST(AVG(CASE WHEN Indicateur = 'CONSO_ELEC' THEN V END) AS int) AS ConsommationMW,
       CAST(AVG(CASE WHEN Indicateur = 'PROD_ELEC'  THEN V END) AS int) AS SolaireMW,
       CAST(AVG(CASE WHEN Indicateur = 'CONSO_ELEC' THEN V END)
          - AVG(CASE WHEN Indicateur = 'PROD_ELEC'  THEN V END) AS int) AS DemandeResiduelleMW
FROM H
GROUP BY Saison, HeureLocale
ORDER BY CASE Saison WHEN N'hiver' THEN 1 WHEN N'printemps' THEN 2 WHEN N'été' THEN 3 ELSE 4 END, HeureLocale;
GO

/* 2. Le jour de pointe de chaque année en France (puissance maximale atteinte) */
WITH J AS (
    SELECT Annee, JourLocal, Maximum, Source,
           ROW_NUMBER() OVER (PARTITION BY Annee ORDER BY Maximum DESC) AS Rang
    FROM mart.vw_MesureJour
    WHERE Indicateur = 'CONSO_ELEC' AND Zone = 'FR' AND Source = 'ODRE'
)
SELECT Annee, JourLocal AS JourDePointe, CAST(Maximum AS int) AS PointeMW
FROM J WHERE Rang = 1 ORDER BY Annee;
GO

/* 3. Les heures de prix négatifs, par zone et par mois (le prix de l'abondance solaire) */
SELECT Zone, AnneeMois, SUM(HeuresPrixNegatifs) AS HeuresNegatives,
       CAST(MIN(PrixMin) AS decimal(9,2)) AS PrixLePlusBas
FROM mart.vw_PrixJour
WHERE JourLocal >= DATEADD(MONTH, -12, CAST(GETDATE() AS date))
GROUP BY Zone, AnneeMois
HAVING SUM(HeuresPrixNegatifs) > 0
ORDER BY AnneeMois DESC, HeuresNegatives DESC;
GO

/* 4. L'écart de prix France-Allemagne et ce qui l'explique : corrélation avec l'éolien allemand */
WITH P AS (
    SELECT f.JourLocal, f.PrixMoyen AS PrixFR, d.PrixMoyen AS PrixDE, f.PrixMoyen - d.PrixMoyen AS Ecart
    FROM mart.vw_PrixJour AS f
    JOIN mart.vw_PrixJour AS d ON d.JourLocal = f.JourLocal AND d.Zone = 'DE_LU'
    WHERE f.Zone = 'FR'
),
E AS (
    SELECT JourLocal, SUM(Part) AS PartEolienDE
    FROM mart.vw_MixJour WHERE Zone = 'DE_LU' AND Famille = 'EOLIEN' GROUP BY JourLocal
),
X AS (SELECT CAST(p.Ecart AS float) AS x, CAST(e.PartEolienDE AS float) AS y
      FROM P AS p JOIN E AS e ON e.JourLocal = p.JourLocal)
SELECT COUNT(*) AS Jours,
       CAST(AVG(x) AS decimal(9,2)) AS EcartMoyenFR_DE,
       -- coefficient de corrélation de Pearson, calculé à la main
       CAST((COUNT(*) * SUM(x * y) - SUM(x) * SUM(y))
          / NULLIF(SQRT(COUNT(*) * SUM(x * x) - SQUARE(SUM(x))) * SQRT(COUNT(*) * SUM(y * y) - SQUARE(SUM(y))), 0)
            AS decimal(5,3)) AS CorrelationEcartEolienDE
FROM X;
GO

/* 5. Le classement carbone des zones sur les 30 derniers jours (estimé par le mix) */
SELECT Zone,
       CAST(SUM(ProductionMWh) / 1e6 AS decimal(9,2)) AS ProductionTWh,
       CAST(SUM(ProductionMWh * IntensiteEstimee_gkWh) / NULLIF(SUM(ProductionMWh), 0) AS decimal(9,1)) AS IntensiteEstimee_gkWh,
       CAST(AVG(IntensiteMesuree_gkWh) AS decimal(9,1)) AS IntensiteMesuree_gkWh,
       RANK() OVER (ORDER BY SUM(ProductionMWh * IntensiteEstimee_gkWh) / NULLIF(SUM(ProductionMWh), 0)) AS Rang
FROM mart.vw_IntensiteCarboneJour
WHERE JourLocal >= DATEADD(DAY, -30, CAST(GETDATE() AS date))
GROUP BY Zone
ORDER BY Rang;
GO

/* 6. La France, exportatrice : solde par voisin sur 12 mois glissants */
SELECT Voisin,
       CAST(SUM(ImportMWh) / 1e6 AS decimal(9,2)) AS ImportsTWh,
       CAST(SUM(ExportMWh) / 1e6 AS decimal(9,2)) AS ExportsTWh,
       CAST(SUM(ExportMWh - ImportMWh) / 1e6 AS decimal(9,2)) AS SoldeExportateurTWh
FROM mart.vw_EchangesJour
WHERE Zone = 'FR' AND JourLocal >= DATEADD(MONTH, -12, CAST(GETDATE() AS date))
GROUP BY Voisin
ORDER BY SoldeExportateurTWh DESC;
GO

/* 7. Facteur de charge du nucléaire par pays : énergie produite / (capacité x heures) */
WITH Prod AS (
    SELECT Pays, Annee, SUM(EnergieMWh) AS EnergieMWh, SUM(DureeJourHeures) AS Heures
    FROM mart.vw_MesureJour
    WHERE Indicateur = 'PROD_ELEC' AND Source = 'ENTSOE' AND Famille = 'NUCLEAIRE'
    GROUP BY Pays, Annee
),
Cap AS (
    SELECT COALESCE(z.ParentCode, z.Code) AS Pays, YEAR(m.InstantUtc) AS Annee, SUM(m.Valeur) AS CapaciteMW
    FROM core.Mesure AS m
    JOIN core.Serie AS s ON s.SerieId = m.SerieId
    JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId AND i.Code = 'CAPACITE_INSTALLEE'
    JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId AND f.Famille = 'NUCLEAIRE'
    JOIN core.Zone AS z ON z.ZoneId = s.ZoneId
    GROUP BY COALESCE(z.ParentCode, z.Code), YEAR(m.InstantUtc)
)
SELECT p.Pays, p.Annee, CAST(c.CapaciteMW AS int) AS CapaciteMW,
       CAST(p.EnergieMWh / 1e6 AS decimal(9,1)) AS ProductionTWh,
       CAST(p.EnergieMWh / NULLIF(c.CapaciteMW * p.Heures, 0) AS decimal(5,3)) AS FacteurDeCharge
FROM Prod AS p JOIN Cap AS c ON c.Pays = p.Pays AND c.Annee = p.Annee
ORDER BY p.Pays, p.Annee;
GO

/* 8. Prix de l'électricité des ménages : la France face à l'Union, sur 10 ans (LAG, évolution) */
SELECT Pays, Annee, PrixMenages_kWh,
       CAST(PrixMenages_kWh - LAG(PrixMenages_kWh) OVER (PARTITION BY Pays ORDER BY Annee) AS decimal(9,4)) AS VariationSurUnAn,
       CAST(PrixMenages_kWh / NULLIF(FIRST_VALUE(PrixMenages_kWh) OVER (PARTITION BY Pays ORDER BY Annee), 0) - 1
            AS decimal(7,3)) AS VariationDepuisLeDebut
FROM mart.PanelPaysAnnee
WHERE Pays IN ('FR', 'DE', 'ES', 'IT', 'EU27') AND Annee >= YEAR(GETDATE()) - 10 AND PrixMenages_kWh IS NOT NULL
ORDER BY Pays, Annee;
GO

/* 9. Le mix énergétique primaire de la France et de l'Allemagne : 1990 face à la dernière année connue */
WITH E AS (
    SELECT z.Code AS Pays, YEAR(m.InstantUtc) AS Annee, f.Libelle AS Produit, m.Valeur
    FROM core.Mesure AS m
    JOIN core.Serie AS s ON s.SerieId = m.SerieId
    JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId AND i.Code = 'ENERGIE_BRUTE'
    JOIN core.Zone AS z ON z.ZoneId = s.ZoneId AND z.Code IN ('FR', 'DE')
    JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId
),
Bornes AS (SELECT Pays, MAX(Annee) AS Derniere FROM E GROUP BY Pays)
SELECT e.Pays, e.Annee, e.Produit, CAST(e.Valeur AS int) AS ktep,
       CAST(e.Valeur / SUM(e.Valeur) OVER (PARTITION BY e.Pays, e.Annee) AS decimal(5,3)) AS Part
FROM E AS e JOIN Bornes AS b ON b.Pays = e.Pays
WHERE e.Annee IN (1990, b.Derniere)
ORDER BY e.Pays, e.Annee, ktep DESC;
GO

/* 10. Trois sources, une même consommation française : l'écart quotidien entre RTE, éCO2mix et ENTSO-E */
SELECT JourLocal,
       CAST(MAX(CASE WHEN Source = 'RTE'    THEN Moyenne END) AS int) AS RTE_MW,
       CAST(MAX(CASE WHEN Source = 'ODRE'   THEN Moyenne END) AS int) AS ECO2MIX_MW,
       CAST(MAX(CASE WHEN Source = 'ENTSOE' THEN Moyenne END) AS int) AS ENTSOE_MW,
       CAST(MAX(CASE WHEN Source = 'ENTSOE' THEN Moyenne END) / NULLIF(MAX(CASE WHEN Source = 'ODRE' THEN Moyenne END), 0) - 1
            AS decimal(6,4)) AS EcartENTSOE_ECO2MIX
FROM mart.vw_MesureJour
WHERE Indicateur = 'CONSO_ELEC' AND Zone = 'FR' AND JourLocal >= DATEADD(DAY, -30, CAST(GETDATE() AS date))
GROUP BY JourLocal
ORDER BY JourLocal DESC;
GO

/* 11. Contrôle du signe des échanges éCO2mix : la France est exportatrice nette depuis 2023,
       le solde annuel doit donc être NÉGATIF (convention positif = importation) */
SELECT YEAR(JourLocal) AS Annee, CAST(SUM(EnergieMWh) / 1e6 AS decimal(9,1)) AS SoldeImportateurTWh
FROM mart.vw_MesureJour
WHERE Indicateur = 'SOLDE_ECHANGES' AND Zone = 'FR'
GROUP BY YEAR(JourLocal)
ORDER BY Annee;
GO

/* 12. Le gaz et l'électricité : la saisonnalité comparée (moyenne journalière par mois) */
SELECT Mois, Indicateur, CAST(AVG(Moyenne) AS int) AS PuissanceMoyenneMW,
       CAST(AVG(Moyenne) / AVG(AVG(Moyenne)) OVER (PARTITION BY Indicateur) AS decimal(5,2)) AS IndiceSaisonnier
FROM mart.vw_MesureJour
WHERE Zone = 'FR' AND Indicateur IN ('CONSO_GAZ', 'CONSO_ELEC') AND Source = 'ODRE'
GROUP BY Mois, Indicateur
ORDER BY Indicateur, Mois;
GO

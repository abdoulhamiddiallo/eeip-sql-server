/* =====================================================================
   EEIP · Script 16 : la couche Power BI (schéma bi)
   ---------------------------------------------------------------------
   Des objets en français, prêts pour le modèle sémantique :
     dimensions   : bi.vw_Zone, bi.vw_Famille, bi.vw_Source, bi.vw_Jour
     faits légers : bi.vw_Panel (Eurostat, 1990 à aujourd'hui), bi.vw_Revision
     faits lourds : bi.MixJour, bi.ConsoJour, bi.PrixJour, bi.EchangeJour,
                    bi.CarboneJour, bi.ProfilHoraire
                    (matérialisés par bi.usp_Rafraichir, étape 2 du travail horaire)
     plateforme   : bi.vw_Lot, bi.vw_Volume, bi.vw_Qualite, bi.vw_Partition
   Power BI ne lit que ce schéma : le modèle ne dépend jamais des tables internes.
   Le rafraîchissement est INCRÉMENTAL : seuls les jours recalculés dans
   mart.MesureJour depuis le passage précédent sont repris (une révision
   consolidée d'ODRÉ sur un jour ancien est donc bien propagée).
   Rejouable sans risque. Le premier remplissage prend quelques minutes.
   ===================================================================== */
USE EEIP;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'bi') IS NULL EXEC (N'CREATE SCHEMA bi AUTHORIZATION dbo;');
GO

/* ---------- Zones : pays, zones de prix, régions, avec un nom court pour les visuels ---------- */
CREATE OR ALTER VIEW bi.vw_Zone
AS
SELECT  z.Code AS Zone,
        z.Nom  AS ZoneNom,
        CASE z.Code WHEN 'DE_LU' THEN N'Allemagne' WHEN 'IT_NORD' THEN N'Italie du Nord'
                    WHEN 'DK1' THEN N'Danemark Ouest' WHEN 'DK2' THEN N'Danemark Est'
                    WHEN 'NO2' THEN N'Norvège Sud' WHEN 'SE3' THEN N'Suède Centre'
                    WHEN 'EU27' THEN N'Union européenne' WHEN 'EA20' THEN N'Zone euro'
                    WHEN 'DE_BE' THEN N'Allemagne et Belgique'
                    ELSE z.Nom END AS NomCourt,
        z.TypeZone,
        CASE z.TypeZone WHEN 'PAYS' THEN N'Pays' WHEN 'ZONE_PRIX' THEN N'Zone de prix'
                        WHEN 'REGION' THEN N'Région française' ELSE N'Agrégat' END AS Type,
        COALESCE(z.ParentCode, z.Code) AS Pays,
        CAST(z.Latitude AS float)  AS Latitude,
        CAST(z.Longitude AS float) AS Longitude,
        CAST(z.EstUE AS int)       AS EstUE,
        -- les 11 systèmes électriques suivis heure par heure (production, consommation, carbone)
        CAST(CASE WHEN z.Code IN ('AT','BE','CH','CZ','DE_LU','ES','FR','IT','NL','PL','PT') THEN 1 ELSE 0 END AS int) AS Marche,
        -- les 11 zones de prix du marché journalier
        CAST(CASE WHEN z.Code IN ('AT','BE','CH','CZ','DE_LU','ES','FR','IT_NORD','NL','PL','PT') THEN 1 ELSE 0 END AS int) AS Prix,
        -- les pays dont les frontières électriques sont chargées
        CAST(CASE WHEN z.Code IN ('AT','BE','CH','CZ','DE','ES','FR','IT','NL','PL','PT') THEN 1 ELSE 0 END AS int) AS Echanges,
        -- la zone de prix et le pays d'un système : l'Italie se lit au Nord, l'Allemagne avec le Luxembourg
        CASE z.Code WHEN 'IT' THEN 'IT_NORD' WHEN 'DE' THEN 'DE_LU' ELSE z.Code END AS ZonePrix
FROM core.Zone AS z
WHERE z.Origine = 'REFERENCE';
GO

/* ---------- Voisins : les pays de l'autre côté d'une frontière électrique ---------- */
CREATE OR ALTER VIEW bi.vw_Voisin
AS
SELECT z.Code AS Voisin, z.Nom AS VoisinNom,
       CAST(z.Latitude AS float) AS VoisinLatitude, CAST(z.Longitude AS float) AS VoisinLongitude
FROM core.Zone AS z
WHERE z.Origine = 'REFERENCE' AND z.TypeZone = 'PAYS';
GO

/* ---------- Familles de production : libellé, couleur fixe, ordre d'empilement ---------- */
CREATE OR ALTER VIEW bi.vw_Famille
AS
SELECT  f.Famille,
        CASE f.Famille WHEN 'NUCLEAIRE' THEN N'Nucléaire' WHEN 'CHARBON' THEN N'Charbon' WHEN 'GAZ' THEN N'Gaz'
                       WHEN 'PETROLE' THEN N'Fioul' WHEN 'THERMIQUE' THEN N'Thermique fossile'
                       WHEN 'HYDRAULIQUE' THEN N'Hydraulique' WHEN 'EOLIEN' THEN N'Éolien' WHEN 'SOLAIRE' THEN N'Solaire'
                       WHEN 'BIOENERGIES' THEN N'Bioénergies' WHEN 'AUTRES' THEN N'Autres'
                       WHEN 'RENOUVELABLES' THEN N'Renouvelables' WHEN 'STOCKAGE' THEN N'Stockage'
                       ELSE N'Vecteurs' END AS FamilleLibelle,
        CASE f.Famille WHEN 'NUCLEAIRE' THEN '#F7C948' WHEN 'HYDRAULIQUE' THEN '#3D9BE9' WHEN 'EOLIEN' THEN '#4FE0C8'
                       WHEN 'SOLAIRE' THEN '#FF9F43' WHEN 'BIOENERGIES' THEN '#7CC47F' WHEN 'GAZ' THEN '#F2545B'
                       WHEN 'CHARBON' THEN '#8C7B6B' WHEN 'PETROLE' THEN '#B57EDC' WHEN 'THERMIQUE' THEN '#E8577A'
                       WHEN 'AUTRES' THEN '#7F93AA' WHEN 'STOCKAGE' THEN '#56708F' ELSE '#C9A66B' END AS Couleur,
        CASE f.Famille WHEN 'NUCLEAIRE' THEN 1 WHEN 'HYDRAULIQUE' THEN 2 WHEN 'EOLIEN' THEN 3 WHEN 'SOLAIRE' THEN 4
                       WHEN 'BIOENERGIES' THEN 5 WHEN 'GAZ' THEN 6 WHEN 'CHARBON' THEN 7 WHEN 'PETROLE' THEN 8
                       WHEN 'THERMIQUE' THEN 9 WHEN 'AUTRES' THEN 10 WHEN 'STOCKAGE' THEN 11 ELSE 12 END AS Ordre,
        MAX(CAST(f.EstBasCarbone AS int))   AS BasCarbone,
        MAX(CAST(f.EstRenouvelable AS int)) AS Renouvelable,
        MAX(CAST(f.EstFossile AS int))      AS Fossile,
        CAST(AVG(f.FacteurCO2) AS float)    AS FacteurCO2
FROM core.Filiere AS f
GROUP BY f.Famille;
GO

/* ---------- Sources et licences ---------- */
CREATE OR ALTER VIEW bi.vw_Source
AS
SELECT so.Code AS Source, so.Nom AS SourceNom, so.Licence, so.Priorite,
       CASE so.Code WHEN 'RTE' THEN '#19D3C5' WHEN 'ODRE' THEN '#F7C948' WHEN 'ENTSOE' THEN '#7AA7FF'
                    ELSE '#B794F6' END AS Couleur
FROM core.Source AS so;
GO

/* ---------- Calendrier en heure locale, du premier jour chargé à demain ---------- */
CREATE OR ALTER VIEW bi.vw_Jour
AS
SELECT  c.DateJour AS Jour, c.Annee, c.Trimestre, c.Mois, c.NomMois, c.AnneeMois,
        DATEFROMPARTS(c.Annee, c.Mois, 1) AS DebutMois,
        -- le lundi de la semaine, quel que soit le réglage DATEFIRST de la session
        DATEADD(DAY, -((DATEPART(WEEKDAY, c.DateJour) + @@DATEFIRST - 2) % 7), c.DateJour) AS DebutSemaine,
        c.JourSemaine, c.NomJour, CAST(c.EstOuvre AS int) AS EstOuvre, c.Saison
FROM core.Calendrier AS c
WHERE c.DateJour >= '2023-01-01' AND c.DateJour <= DATEADD(DAY, 1, CAST(GETDATE() AS date));
GO

/* ---------- Panel annuel Eurostat : un pays, une année, vingt indicateurs ---------- */
CREATE OR ALTER VIEW bi.vw_Panel
AS
SELECT  p.Pays AS Zone, p.Annee,
        CAST(p.ProductionTWh AS float)          AS ProductionTWh,
        CAST(p.PartNucleaire AS float)          AS PartNucleaire,
        CAST(p.PartFossile AS float)            AS PartFossile,
        CAST(p.PartRenouvelableMix AS float)    AS PartRenouvelableMix,
        CAST(p.PartRenouvElecOfficiel AS float) AS PartRenouvelableOfficielle,
        CAST(p.ConsoFinaleTWh AS float)         AS ConsoFinaleTWh,
        CAST(p.ImportsTWh AS float)             AS ImportsTWh,
        CAST(p.ExportsTWh AS float)             AS ExportsTWh,
        CAST(p.SoldeExportateurTWh AS float)    AS SoldeExportateurTWh,
        CAST(p.PrixMenages_kWh AS float)        AS PrixMenages,
        CAST(p.PrixEntreprises_kWh AS float)    AS PrixEntreprises,
        CAST(p.IntensiteCO2Estimee AS float)    AS IntensiteCO2,
        CAST(p.GES_Electricite_Mt AS float)     AS GesElectriciteMt,
        CAST(p.GES_Total_Mt AS float)           AS GesTotalMt,
        CAST(p.DependanceEnergetique AS float)  AS Dependance
FROM mart.PanelPaysAnnee AS p;
GO

/* =====================================================================
   Les agrégats lourds sont MATÉRIALISÉS dans des tables bi.* :
   Power BI lit quelques centaines de milliers de lignes au lieu de
   recalculer le golden record sur des millions de points à chaque fois.
   ===================================================================== */
IF OBJECT_ID(N'bi.MixJour') IS NULL
CREATE TABLE bi.MixJour (
    Zone        varchar(20)   NOT NULL,
    Jour        date          NOT NULL,
    Famille     varchar(20)   NOT NULL,
    Source      varchar(20)   NOT NULL,
    EnergieMWh  decimal(14,1) NULL,
    Completude  decimal(5,4)  NULL,
    CONSTRAINT PK_bi_MixJour PRIMARY KEY (Zone, Jour, Famille)
);

IF OBJECT_ID(N'bi.ConsoJour') IS NULL
CREATE TABLE bi.ConsoJour (
    Zone          varchar(20)   NOT NULL,
    Jour          date          NOT NULL,
    Source        varchar(20)   NOT NULL,
    ConsoMWh      decimal(14,1) NULL,
    PointeMW      decimal(12,1) NULL,
    CreuxMW       decimal(12,1) NULL,
    PrevisionMWh  decimal(14,1) NULL,     -- prévision de la veille (France, éCO2mix)
    GazMWh        decimal(14,1) NULL,     -- consommation de gaz (France, ODRÉ)
    Completude    decimal(5,4)  NULL,
    CONSTRAINT PK_bi_ConsoJour PRIMARY KEY (Zone, Jour)
);

IF OBJECT_ID(N'bi.PrixJour') IS NULL
CREATE TABLE bi.PrixJour (
    Zone             varchar(20)   NOT NULL,
    Jour             date          NOT NULL,
    PrixMoyen        decimal(10,2) NULL,
    PrixMin          decimal(10,2) NULL,
    PrixMax          decimal(10,2) NULL,
    HeuresNegatives  decimal(6,2)  NULL,
    Granularite      varchar(10)   NULL,
    CONSTRAINT PK_bi_PrixJour PRIMARY KEY (Zone, Jour)
);

IF OBJECT_ID(N'bi.EchangeJour') IS NULL
CREATE TABLE bi.EchangeJour (
    Pays       varchar(20)   NOT NULL,
    Voisin     varchar(20)   NOT NULL,
    Jour       date          NOT NULL,
    ImportMWh  decimal(14,1) NOT NULL,
    ExportMWh  decimal(14,1) NOT NULL,
    Source     varchar(20)   NOT NULL,
    CONSTRAINT PK_bi_EchangeJour PRIMARY KEY (Pays, Voisin, Jour)
);

IF OBJECT_ID(N'bi.CarboneJour') IS NULL
CREATE TABLE bi.CarboneJour (
    Zone               varchar(20)   NOT NULL,
    Jour               date          NOT NULL,
    ProductionMWh      decimal(14,1) NULL,
    EmissionsT         decimal(14,1) NULL,    -- tonnes de CO2 estimées par le mix
    IntensiteEstimee   decimal(9,1)  NULL,    -- g/kWh
    IntensiteMesuree   decimal(9,1)  NULL,    -- g/kWh publié par éCO2mix (France)
    CONSTRAINT PK_bi_CarboneJour PRIMARY KEY (Zone, Jour)
);

IF OBJECT_ID(N'bi.ProfilHoraire') IS NULL
CREATE TABLE bi.ProfilHoraire (
    Zone       varchar(20)   NOT NULL,
    Annee      smallint      NOT NULL,
    Mois       tinyint       NOT NULL,
    Heure      tinyint       NOT NULL,     -- heure locale, 0 à 23
    Grandeur   varchar(20)   NOT NULL,     -- CONSO, PRIX, CO2 ou une famille de production
    Valeur     decimal(12,2) NULL,         -- MW moyens, €/MWh ou g/kWh
    NbJours    smallint      NOT NULL,
    CONSTRAINT PK_bi_ProfilHoraire PRIMARY KEY (Zone, Annee, Mois, Heure, Grandeur)
);
GO

IF NOT EXISTS (SELECT 1 FROM ops.Parametre WHERE Cle = 'BI_DERNIER_CALCUL')
    INSERT ops.Parametre (Cle, Valeur, Description, ModifieLe)
    VALUES ('BI_DERNIER_CALCUL', '1900-01-01T00:00:00',
            N'Instant du dernier rafraîchissement de la couche Power BI (filigrane de bi.usp_Rafraichir)', SYSUTCDATETIME());
GO

CREATE OR ALTER PROCEDURE bi.usp_Rafraichir
    @Complet bit = 0          -- 1 = tout recalculer
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    DECLARE @t datetime2(3), @n int, @debut datetime2(0) = SYSUTCDATETIME(),
            @w datetime2(0) = TRY_CAST((SELECT Valeur FROM ops.Parametre WHERE Cle = 'BI_DERNIER_CALCUL') AS datetime2(0)),
            @d0 date, @m0 date, @msg nvarchar(400);
    DECLARE @bilan TABLE (Ordre int IDENTITY, Tableau nvarchar(40), Lignes int, Secondes decimal(9,1));

    IF @Complet = 1 OR @w IS NULL OR NOT EXISTS (SELECT 1 FROM bi.MixJour) SET @w = '1900-01-01';

    /* 0. Le plus ancien jour recalculé dans mart depuis le passage précédent */
    SELECT @d0 = MIN(JourLocal) FROM mart.MesureJour WHERE CalculeLeUtc >= @w;
    IF @d0 IS NULL
    BEGIN
        SELECT N'rien à rafraîchir' AS Bilan;
        RETURN;
    END
    IF @w = '1900-01-01' SET @d0 = '1900-01-01';
    SET @m0 = DATEFROMPARTS(YEAR(@d0), MONTH(@d0), 1);

    /* Le quotidien utile, une fois, en clair */
    SET @t = SYSDATETIME();
    SELECT j.SerieId, j.JourLocal, so.Code AS Source, so.Priorite, i.Code AS Indicateur,
           z.Code AS Zone, z.Nom AS ZoneNom, z.ParentCode, cp.Code AS Contrepartie, cp.Nom AS ContrepartieNom,
           cp.ParentCode AS ContrepartieParent, f.Famille, s.Granularite,
           CAST(j.Moyenne AS float) AS Moyenne, CAST(j.Minimum AS float) AS Minimum, CAST(j.Maximum AS float) AS Maximum,
           CAST(j.EnergieMWh AS float) AS EnergieMWh, j.DureeNegativeMinutes, CAST(j.Completude AS float) AS Completude
    INTO #j
    FROM mart.MesureJour AS j
    JOIN core.Serie      AS s  ON s.SerieId = j.SerieId
    JOIN core.Source     AS so ON so.SourceId = s.SourceId
    JOIN core.Indicateur AS i  ON i.IndicateurId = s.IndicateurId
    JOIN core.Zone       AS z  ON z.ZoneId = s.ZoneId
    LEFT JOIN core.Zone    AS cp ON cp.ZoneId = s.ContrepartieId
    LEFT JOIN core.Filiere AS f  ON f.FiliereId = s.FiliereId
    WHERE j.JourLocal >= @d0
      AND i.Code IN ('PROD_ELEC', 'CONSO_ELEC', 'PREV_CONSO_J1', 'CONSO_GAZ', 'PRIX_SPOT_J1', 'FLUX_PHYSIQUE', 'INTENSITE_CO2');
    INSERT @bilan VALUES (N'lecture de mart', @@ROWCOUNT, DATEDIFF(MILLISECOND, @t, SYSDATETIME()) / 1000.0);

    /* 1. Mix : par zone et par jour, la meilleure source gagne (golden record) */
    SET @t = SYSDATETIME();
    WITH ParSource AS (
        SELECT Zone, JourLocal, Source, Priorite, Famille, SUM(EnergieMWh) AS E, MIN(Completude) AS C
        FROM #j WHERE Indicateur = 'PROD_ELEC' AND Famille IS NOT NULL
        GROUP BY Zone, JourLocal, Source, Priorite, Famille
    ), Choix AS (
        SELECT *, DENSE_RANK() OVER (PARTITION BY Zone, JourLocal ORDER BY Priorite, Source) AS Rang FROM ParSource
    )
    SELECT Zone, JourLocal, Famille, Source, E, C INTO #mix FROM Choix WHERE Rang = 1;
    BEGIN TRAN;
        DELETE bi.MixJour WHERE Jour >= @d0;
        INSERT bi.MixJour (Zone, Jour, Famille, Source, EnergieMWh, Completude)
        SELECT Zone, JourLocal, Famille, Source, CAST(E AS decimal(14,1)), CAST(C AS decimal(5,4)) FROM #mix;
        SET @n = @@ROWCOUNT;
    COMMIT;
    INSERT @bilan VALUES (N'bi.MixJour', @n, DATEDIFF(MILLISECOND, @t, SYSDATETIME()) / 1000.0);

    /* 2. Consommation : meilleure source, pointe et creux du jour, prévision de la veille, gaz */
    SET @t = SYSDATETIME();
    WITH Conso AS (
        SELECT Zone, JourLocal, Source, SUM(EnergieMWh) AS E, MAX(Maximum) AS Pointe, MIN(Minimum) AS Creux,
               MIN(Completude) AS C,
               DENSE_RANK() OVER (PARTITION BY Zone, JourLocal ORDER BY MIN(Priorite), Source) AS Rang
        FROM #j WHERE Indicateur = 'CONSO_ELEC'
        GROUP BY Zone, JourLocal, Source
    ), Prev AS (
        SELECT Zone, JourLocal, SUM(EnergieMWh) AS E FROM #j WHERE Indicateur = 'PREV_CONSO_J1' GROUP BY Zone, JourLocal
    ), Gaz AS (
        SELECT Zone, JourLocal, SUM(EnergieMWh) AS E FROM #j WHERE Indicateur = 'CONSO_GAZ' GROUP BY Zone, JourLocal
    )
    SELECT c.Zone, c.JourLocal, c.Source, c.E, c.Pointe, c.Creux, p.E AS Prev, g.E AS Gaz, c.C
    INTO #conso
    FROM Conso AS c
    LEFT JOIN Prev AS p ON p.Zone = c.Zone AND p.JourLocal = c.JourLocal
    LEFT JOIN Gaz  AS g ON g.Zone = c.Zone AND g.JourLocal = c.JourLocal
    WHERE c.Rang = 1;
    BEGIN TRAN;
        DELETE bi.ConsoJour WHERE Jour >= @d0;
        INSERT bi.ConsoJour (Zone, Jour, Source, ConsoMWh, PointeMW, CreuxMW, PrevisionMWh, GazMWh, Completude)
        SELECT Zone, JourLocal, Source, CAST(E AS decimal(14,1)), CAST(Pointe AS decimal(12,1)), CAST(Creux AS decimal(12,1)),
               CAST(Prev AS decimal(14,1)), CAST(Gaz AS decimal(14,1)), CAST(C AS decimal(5,4))
        FROM #conso;
        SET @n = @@ROWCOUNT;
    COMMIT;
    INSERT @bilan VALUES (N'bi.ConsoJour', @n, DATEDIFF(MILLISECOND, @t, SYSDATETIME()) / 1000.0);

    /* 3. Prix spot : une ligne par zone et par jour.
          Quand le pas horaire et le pas au quart d'heure coexistent, le plus complet gagne, puis l'horaire. */
    SET @t = SYSDATETIME();
    WITH P AS (
        SELECT Zone, JourLocal, Moyenne, Minimum, Maximum, DureeNegativeMinutes, Granularite,
               ROW_NUMBER() OVER (PARTITION BY Zone, JourLocal ORDER BY Completude DESC, Granularite DESC) AS Rang
        FROM #j WHERE Indicateur = 'PRIX_SPOT_J1' AND Completude >= 0.5
    )
    SELECT * INTO #prix FROM P WHERE Rang = 1;
    BEGIN TRAN;
        DELETE bi.PrixJour WHERE Jour >= @d0;
        INSERT bi.PrixJour (Zone, Jour, PrixMoyen, PrixMin, PrixMax, HeuresNegatives, Granularite)
        SELECT Zone, JourLocal, CAST(Moyenne AS decimal(10,2)), CAST(Minimum AS decimal(10,2)), CAST(Maximum AS decimal(10,2)),
               CAST(DureeNegativeMinutes / 60.0 AS decimal(6,2)), Granularite
        FROM #prix;
        SET @n = @@ROWCOUNT;
    COMMIT;
    INSERT @bilan VALUES (N'bi.PrixJour', @n, DATEDIFF(MILLISECOND, @t, SYSDATETIME()) / 1000.0);

    /* 4. Échanges entre pays : les zones de prix et les codes EIC des interconnexions
          sont rattachés à leur pays, puis la meilleure source gagne pour chaque frontière et chaque sens */
    SET @t = SYSDATETIME();
    WITH Flux AS (
        SELECT CASE WHEN ZoneNom = '10YCB-GERMANY--8' THEN 'DE'
                    WHEN ZoneNom IN ('10Y1001C--00098F', '17Y0000009369493') THEN 'GB'
                    ELSE COALESCE(ParentCode, Zone) END AS Destination,
               CASE WHEN ContrepartieNom = '10YCB-GERMANY--8' THEN 'DE'
                    WHEN ContrepartieNom IN ('10Y1001C--00098F', '17Y0000009369493') THEN 'GB'
                    ELSE COALESCE(ContrepartieParent, Contrepartie) END AS Origine,
               JourLocal, Source, Priorite, EnergieMWh
        FROM #j WHERE Indicateur = 'FLUX_PHYSIQUE' AND Contrepartie IS NOT NULL
    ), ParSource AS (
        SELECT Destination, Origine, JourLocal, Source, MIN(Priorite) AS Priorite, SUM(EnergieMWh) AS E
        FROM Flux WHERE Destination <> Origine
        GROUP BY Destination, Origine, JourLocal, Source
    ), Meilleure AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY Destination, Origine, JourLocal ORDER BY Priorite, Source) AS Rang
        FROM ParSource
    ), Sens AS (
        SELECT Destination AS Pays, Origine AS Voisin, JourLocal, E AS Imp, 0.0 AS Exp, Source FROM Meilleure WHERE Rang = 1
        UNION ALL
        SELECT Origine, Destination, JourLocal, 0.0, E, Source FROM Meilleure WHERE Rang = 1
    )
    SELECT Pays, Voisin, JourLocal, SUM(Imp) AS Imp, SUM(Exp) AS Exp, MIN(Source) AS Source
    INTO #ech
    FROM Sens GROUP BY Pays, Voisin, JourLocal;
    BEGIN TRAN;
        DELETE bi.EchangeJour WHERE Jour >= @d0;
        INSERT bi.EchangeJour (Pays, Voisin, Jour, ImportMWh, ExportMWh, Source)
        SELECT Pays, Voisin, JourLocal, CAST(Imp AS decimal(14,1)), CAST(Exp AS decimal(14,1)), Source FROM #ech;
        SET @n = @@ROWCOUNT;
    COMMIT;
    INSERT @bilan VALUES (N'bi.EchangeJour', @n, DATEDIFF(MILLISECOND, @t, SYSDATETIME()) / 1000.0);

    /* 5. Carbone : intensité estimée par le mix et les facteurs d'émission, face à la mesure éCO2mix */
    SET @t = SYSDATETIME();
    WITH Facteur AS (SELECT Famille, AVG(FacteurCO2) AS F FROM core.Filiere GROUP BY Famille),
    Mix AS (
        SELECT m.Zone, m.JourLocal, SUM(m.E) AS Prod, SUM(m.E * f.F) / 1000.0 AS Tonnes
        FROM #mix AS m JOIN Facteur AS f ON f.Famille = m.Famille
        WHERE m.Famille NOT IN ('STOCKAGE', 'VECTEURS') AND m.E > 0
        GROUP BY m.Zone, m.JourLocal
    ), Mesuree AS (
        SELECT Zone, JourLocal, AVG(Moyenne) AS I FROM #j WHERE Indicateur = 'INTENSITE_CO2' GROUP BY Zone, JourLocal
    )
    SELECT x.Zone, x.JourLocal, x.Prod, x.Tonnes, me.I INTO #co2
    FROM Mix AS x LEFT JOIN Mesuree AS me ON me.Zone = x.Zone AND me.JourLocal = x.JourLocal;
    BEGIN TRAN;
        DELETE bi.CarboneJour WHERE Jour >= @d0;
        INSERT bi.CarboneJour (Zone, Jour, ProductionMWh, EmissionsT, IntensiteEstimee, IntensiteMesuree)
        SELECT Zone, JourLocal, CAST(Prod AS decimal(14,1)), CAST(Tonnes AS decimal(14,1)),
               CAST(Tonnes * 1000.0 / NULLIF(Prod, 0) AS decimal(9,1)), CAST(I AS decimal(9,1))
        FROM #co2;
        SET @n = @@ROWCOUNT;
    COMMIT;
    INSERT @bilan VALUES (N'bi.CarboneJour', @n, DATEDIFF(MILLISECOND, @t, SYSDATETIME()) / 1000.0);

    /* 6. Profil horaire : la journée type de chaque mois, heure locale par heure locale.
          Une source par zone et par indicateur : celle qui remonte le plus loin.
          Grandeurs additives (production, consommation) : énergie de l'heure divisée par le nombre de jours,
          donc juste même quand une série passe du pas horaire au quart d'heure en cours de mois.
          Grandeurs moyennes (prix, CO2) : moyenne pondérée par la durée des points. */
    SET @t = SYSDATETIME();
    WITH Cand AS (
        SELECT s.SerieId, z.Code AS Zone, i.Code AS Indicateur, so.Code AS Source, so.Priorite, s.PasMinutes,
               z.Fuseau, f.Famille, s.PremierInstant
        FROM core.Serie AS s
        JOIN core.Source     AS so ON so.SourceId = s.SourceId
        JOIN core.Indicateur AS i  ON i.IndicateurId = s.IndicateurId
        JOIN core.Zone       AS z  ON z.ZoneId = s.ZoneId
        LEFT JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId
        WHERE i.Code IN ('PROD_ELEC', 'CONSO_ELEC', 'PRIX_SPOT_J1', 'INTENSITE_CO2')
          AND z.TypeZone IN ('PAYS', 'ZONE_PRIX') AND z.Origine = 'REFERENCE'
          AND s.PasMinutes BETWEEN 1 AND 60 AND s.NbPoints > 0
    ), Rang AS (
        SELECT Zone, Indicateur, Source,
               ROW_NUMBER() OVER (PARTITION BY Zone, Indicateur ORDER BY MIN(PremierInstant), MIN(Priorite), Source) AS R
        FROM Cand GROUP BY Zone, Indicateur, Source
    )
    SELECT c.SerieId, c.Zone, c.PasMinutes, c.Fuseau,
           CASE c.Indicateur WHEN 'CONSO_ELEC' THEN 'CONSO' WHEN 'PRIX_SPOT_J1' THEN 'PRIX'
                             WHEN 'INTENSITE_CO2' THEN 'CO2' ELSE c.Famille END AS Grandeur,
           CAST(CASE WHEN c.Indicateur IN ('PRIX_SPOT_J1', 'INTENSITE_CO2') THEN 0 ELSE 1 END AS bit) AS Additive
    INTO #ps
    FROM Cand AS c JOIN Rang AS r ON r.Zone = c.Zone AND r.Indicateur = c.Indicateur AND r.Source = c.Source AND r.R = 1
    WHERE c.Indicateur <> 'PROD_ELEC' OR c.Famille NOT IN ('VECTEURS');

    CREATE TABLE #fz (Fuseau varchar(40) COLLATE DATABASE_DEFAULT NOT NULL, Annee int NOT NULL,
                      DebutUtc datetime2(0) NOT NULL, FinUtc datetime2(0) NOT NULL, DecalageMinutes smallint NOT NULL,
                      PRIMARY KEY (Fuseau, Annee, DebutUtc));
    INSERT #fz
    SELECT d.Fuseau, a.value, d.DebutUtc, d.FinUtc, d.DecalageMinutes
    FROM core.FuseauDecalage AS d
    JOIN (SELECT DISTINCT Fuseau FROM #ps) AS f ON f.Fuseau = d.Fuseau
    CROSS APPLY GENERATE_SERIES(GREATEST(YEAR(d.DebutUtc), 2020), LEAST(YEAR(DATEADD(SECOND, -1, d.FinUtc)), 2100)) AS a
    WHERE d.FinUtc >= '2020-01-01';

    -- 1er niveau : chaque série, chaque jour, chaque heure locale (robuste aux points manquants)
    SELECT s.Zone, s.Grandeur, s.Additive, s.SerieId, CAST(l.Locale AS date) AS JourLocal,
           CAST(DATEPART(HOUR, l.Locale) AS tinyint) AS Heure, AVG(CAST(m.Valeur AS float)) AS V
    INTO #h1
    FROM core.Mesure AS m
    JOIN #ps AS s ON s.SerieId = m.SerieId
    JOIN #fz AS d ON d.Fuseau = s.Fuseau AND d.Annee = YEAR(m.InstantUtc)
                 AND m.InstantUtc >= d.DebutUtc AND m.InstantUtc < d.FinUtc
    CROSS APPLY (SELECT DATEADD(MINUTE, d.DecalageMinutes, m.InstantUtc) AS Locale) AS l
    WHERE m.InstantUtc >= DATEADD(DAY, -1, CAST(@m0 AS datetime2(0))) AND m.Valeur IS NOT NULL
    GROUP BY s.Zone, s.Grandeur, s.Additive, s.SerieId, CAST(l.Locale AS date), DATEPART(HOUR, l.Locale);

    -- 2e niveau : les séries d'une même grandeur s'additionnent (production, consommation) ou se moyennent (prix, CO2)
    -- 3e niveau : la moyenne des jours du mois donne la journée type
    SELECT Zone, Grandeur, YEAR(JourLocal) AS Annee, MONTH(JourLocal) AS Mois, Heure,
           AVG(V) AS V, COUNT(*) AS NbJours
    INTO #ph
    FROM (SELECT Zone, Grandeur, JourLocal, Heure,
                 CASE WHEN MAX(CAST(Additive AS int)) = 1 THEN SUM(V) ELSE AVG(V) END AS V
          FROM #h1 WHERE JourLocal >= @m0
          GROUP BY Zone, Grandeur, JourLocal, Heure) AS x
    GROUP BY Zone, Grandeur, YEAR(JourLocal), MONTH(JourLocal), Heure;

    BEGIN TRAN;
        DELETE bi.ProfilHoraire WHERE DATEFROMPARTS(Annee, Mois, 1) >= @m0;
        INSERT bi.ProfilHoraire (Zone, Annee, Mois, Heure, Grandeur, Valeur, NbJours)
        SELECT Zone, Annee, Mois, Heure, Grandeur, CAST(V AS decimal(12,2)), NbJours
        FROM #ph WHERE NbJours >= 5;
        SET @n = @@ROWCOUNT;
    COMMIT;
    INSERT @bilan VALUES (N'bi.ProfilHoraire', @n, DATEDIFF(MILLISECOND, @t, SYSDATETIME()) / 1000.0);

    /* Le filigrane avance : le prochain passage ne reprendra que ce qui aura changé */
    UPDATE ops.Parametre SET Valeur = CONVERT(varchar(19), @debut, 126), ModifieLe = SYSUTCDATETIME()
    WHERE Cle = 'BI_DERNIER_CALCUL';
    SET @msg = CONCAT(N'Couche Power BI rafraîchie depuis le ', CONVERT(char(10), @d0, 23));
    EXEC ops.usp_Journal_Ecrire NULL, 'INFO', N'bi.usp_Rafraichir', @msg;

    SELECT Tableau, Lignes, Secondes FROM @bilan ORDER BY Ordre;
END
GO

/* ---------- Révisions : les valeurs remplacées par une version plus fiable (tables temporelles) ---------- */
CREATE OR ALTER VIEW bi.vw_Revision
AS
SELECT  so.Code AS Source, i.Libelle AS Indicateur,
        DATEFROMPARTS(YEAR(h.ValidTo), MONTH(h.ValidTo), 1) AS MoisRevision,
        COUNT_BIG(*) AS Versions
FROM core.MesureHistorique AS h
JOIN core.Serie AS s ON s.SerieId = h.SerieId
JOIN core.Source AS so ON so.SourceId = s.SourceId
JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
GROUP BY so.Code, i.Libelle, DATEFROMPARTS(YEAR(h.ValidTo), MONTH(h.ValidTo), 1);
GO

/* ---------- Plateforme : lots, volumes, qualité, partitions ---------- */
CREATE OR ALTER VIEW bi.vw_Lot
AS
SELECT  l.LotId, l.Declencheur, l.Sources, l.Statut,
        CAST(l.Debut AS datetime2(0)) AS Debut, CAST(l.Fin AS datetime2(0)) AS Fin,
        CAST(l.Debut AS date) AS JourLot,
        CAST(ISNULL(l.DureeSecondes, 0) / 60.0 AS decimal(10,1)) AS DureeMinutes,
        l.NbAppels, l.NbReponsesIdentiques, l.NbLignesLues, l.NbInserees, l.NbRevisees, l.NbInchangees, l.NbRejetees,
        (SELECT COUNT(*) FROM dq.Anomalie AS a WHERE a.LotId = l.LotId) AS NbAnomalies
FROM ops.Lot AS l;
GO

CREATE OR ALTER VIEW bi.vw_Volume
AS
SELECT  so.Code AS Source, i.Libelle AS Indicateur, t.Libelle AS Theme,
        COUNT(DISTINCT s.ZoneId) AS Zones,
        COUNT(*) AS Series,
        SUM(CAST(ISNULL(s.NbPoints, 0) AS bigint)) AS Valeurs,
        MIN(s.PremierInstant) AS Premier,
        MAX(s.DernierInstant) AS Dernier,
        MIN(s.PasMinutes) AS PasMinutes
FROM core.Serie AS s
JOIN core.Source AS so ON so.SourceId = s.SourceId
JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
JOIN core.Theme AS t ON t.ThemeId = i.ThemeId
GROUP BY so.Code, i.Libelle, t.Libelle;
GO

CREATE OR ALTER VIEW bi.vw_Qualite
AS
SELECT  a.TypeAnomalie, CAST(a.DetecteLe AS date) AS Jour, COUNT(*) AS Nombre
FROM dq.Anomalie AS a
GROUP BY a.TypeAnomalie, CAST(a.DetecteLe AS date);
GO

CREATE OR ALTER VIEW bi.vw_Partition
AS
SELECT  ps.partition_number AS NumeroPartition,
        fg.name AS GroupeDeFichiers,
        CAST(prv.value AS date) AS DebutMois,
        YEAR(CAST(prv.value AS date)) AS Annee,
        p.data_compression_desc AS Compression,
        ps.row_count AS Lignes,
        CAST(ps.used_page_count * 8 / 1024.0 AS decimal(12,1)) AS Mo
FROM sys.dm_db_partition_stats AS ps
JOIN sys.partitions AS p ON p.partition_id = ps.partition_id
JOIN sys.indexes AS i ON i.object_id = ps.object_id AND i.index_id = ps.index_id
JOIN sys.partition_schemes AS sch ON sch.data_space_id = i.data_space_id
JOIN sys.destination_data_spaces AS dds ON dds.partition_scheme_id = sch.data_space_id AND dds.destination_id = ps.partition_number
JOIN sys.filegroups AS fg ON fg.data_space_id = dds.data_space_id
JOIN sys.partition_range_values AS prv ON prv.function_id = sch.function_id AND prv.boundary_id = ps.partition_number - 1
WHERE ps.object_id = OBJECT_ID(N'core.Mesure') AND ps.index_id = 1 AND ps.row_count > 0;
GO

/* ---------- Droits : le rôle de lecture voit le schéma bi ---------- */
GRANT SELECT ON SCHEMA::bi TO eeip_lecteur;
GO

/* ---------- L'Agent : la couche Power BI devient l'étape 2 du travail horaire ---------- */
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'EEIP · Temps réel')
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps AS st JOIN msdb.dbo.sysjobs AS j ON j.job_id = st.job_id
               WHERE j.name = N'EEIP · Temps réel' AND st.step_id = 2)
        EXEC msdb.dbo.sp_delete_jobstep @job_name = N'EEIP · Temps réel', @step_id = 2;
    EXEC msdb.dbo.sp_update_jobstep @job_name = N'EEIP · Temps réel', @step_id = 1,
         @on_success_action = 3, @on_fail_action = 2;
    EXEC msdb.dbo.sp_add_jobstep @job_name = N'EEIP · Temps réel', @step_id = 2,
         @step_name = N'2. Couche Power BI', @subsystem = N'TSQL', @database_name = N'EEIP',
         @command = N'SET QUOTED_IDENTIFIER ON; EXEC bi.usp_Rafraichir;',
         @on_success_action = 1, @on_fail_action = 2;
END
GO

/* ---------- Premier remplissage (quelques minutes) ---------- */
USE EEIP;
GO
SET QUOTED_IDENTIFIER ON;
EXEC bi.usp_Rafraichir @Complet = 1;
GO

/* Contrôle */
SELECT N'bi.' + o.name AS Objet, o.type_desc AS Genre,
       (SELECT SUM(p.rows) FROM sys.partitions AS p WHERE p.object_id = o.object_id AND p.index_id IN (0, 1)) AS Lignes
FROM sys.objects AS o
WHERE o.schema_id = SCHEMA_ID(N'bi') AND o.type IN ('U', 'V', 'P')
ORDER BY o.type, o.name;
GO

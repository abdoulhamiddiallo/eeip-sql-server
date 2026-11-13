/* =====================================================================
   EEIP · Script 10 : la couche analytique (mart)
   ---------------------------------------------------------------------
   mart.MesureJour              : chaque série infra-horaire résumée par JOUR
                                  LOCAL (moyenne, pointe, creux, énergie,
                                  durée négative, complétude), rafraîchie de
                                  façon INCRÉMENTALE (seuls les jours touchés)
   mart.vw_MesureJour           : la même chose, en clair
   mart.vw_MixJour              : le mix de production par famille et par jour,
                                  meilleure source choisie (golden record)
   mart.vw_PrixJour             : prix spot quotidiens et heures de prix négatifs
   mart.vw_EchangesJour         : importations, exportations, solde par zone
   mart.vw_IntensiteCarboneJour : CO2 estimé par le mix, face au CO2 mesuré
   mart.PanelPaysAnnee          : un pays, une année, 20 indicateurs en colonnes,
                                  reconstruit à côté puis basculé par SWITCH
   ===================================================================== */
USE EEIP;
GO

/* ---------- Agrégat quotidien ---------- */
IF OBJECT_ID(N'mart.MesureJour', N'U') IS NULL
BEGIN
    CREATE TABLE mart.MesureJour
    (
        SerieId               int            NOT NULL,
        JourLocal             date           NOT NULL,
        NbPoints              smallint       NOT NULL,
        Moyenne               decimal(19,4)  NULL,
        Minimum               decimal(19,4)  NULL,
        Maximum               decimal(19,4)  NULL,
        EnergieMWh            decimal(19,3)  NULL,   -- puissance moyenne x durée du jour (MW -> MWh)
        DureeNegativeMinutes  smallint       NOT NULL,
        DureeJourHeures       tinyint        NOT NULL,   -- 23, 24 ou 25 les jours de changement d'heure
        Completude            decimal(5,4)   NOT NULL,
        LotMax                int            NOT NULL,
        CalculeLeUtc          datetime2(0)   NOT NULL
    ) ON ps_MoisDate (JourLocal);
    CREATE CLUSTERED COLUMNSTORE INDEX CCI_MesureJour ON mart.MesureJour ORDER (SerieId, JourLocal) ON ps_MoisDate (JourLocal);
END
GO

CREATE OR ALTER PROCEDURE mart.usp_MesureJour_Rafraichir
    @Complet    bit = 0,      -- 1 = tout recalculer
    @LotCourant int = NULL    -- le lot qui appelle : ses écritures sont terminées, il est donc inclus
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    DECLARE @w int = TRY_CAST((SELECT Valeur FROM ops.Parametre WHERE Cle = 'MART_DERNIER_LOT') AS int),
            -- le filigrane n'avance jamais au-delà d'un AUTRE lot encore en cours (il peut écrire encore)
            @lotMax int = ISNULL((SELECT MIN(LotId) - 1 FROM ops.Lot
                                  WHERE Statut = 'EN_COURS' AND LotId <> ISNULL(@LotCourant, -1)),
                                 (SELECT MAX(LotId) FROM ops.Lot)),
            @series int, @jours bigint = 0, @n int, @dMin date, @dMax date, @msg nvarchar(400);
    IF @Complet = 1 SET @w = 0;

    /* 1. Les séries infra-horaires touchées depuis le dernier passage, avec leur plage de jours.
          Le travail est ensuite découpé en paquets de 50 séries : chaque paquet tient en mémoire,
          même sur un poste modeste, au lieu d'un seul calcul géant sur des dizaines de millions de points. */
    CREATE TABLE #plage
    (
        SerieId     int          NOT NULL PRIMARY KEY,
        PasMinutes  int          NOT NULL,
        Fuseau      varchar(40)  COLLATE DATABASE_DEFAULT NOT NULL,
        EstPuissance bit         NOT NULL,
        JourMin     date         NOT NULL,
        JourMax     date         NOT NULL,
        Traite      bit          NOT NULL DEFAULT (0)
    );
    INSERT #plage (SerieId, PasMinutes, Fuseau, EstPuissance, JourMin, JourMax)
    SELECT t.SerieId, s.PasMinutes, z.Fuseau, CASE WHEN i.Nature = 'PUISSANCE' THEN 1 ELSE 0 END,
           DATEADD(DAY, -1, CAST(t.Debut AS date)), DATEADD(DAY, 1, CAST(t.Fin AS date))
    FROM (SELECT m.SerieId, MIN(m.InstantUtc) AS Debut, MAX(m.InstantUtc) AS Fin
          FROM core.Mesure AS m
          WHERE m.LotId > @w AND m.LotId <= @lotMax
          GROUP BY m.SerieId) AS t
    JOIN core.Serie AS s ON s.SerieId = t.SerieId
    JOIN core.Zone AS z ON z.ZoneId = s.ZoneId
    JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
    WHERE s.PasMinutes <= 60;

    SET @series = @@ROWCOUNT;
    IF @series = 0
    BEGIN
        UPDATE ops.Parametre SET Valeur = CAST(@lotMax AS nvarchar(20)), ModifieLe = SYSUTCDATETIME()
        WHERE Cle = 'MART_DERNIER_LOT';
        SELECT 0 AS SeriesRecalculees, 0 AS JoursRecalcules;
        RETURN;
    END

    /* 2. Durée de chaque jour local (23 h, 24 h ou 25 h) : AT TIME ZONE sur très peu de lignes */
    SELECT @dMin = MIN(JourMin), @dMax = MAX(JourMax) FROM #plage;
    CREATE TABLE #duree (Fuseau varchar(40) COLLATE DATABASE_DEFAULT NOT NULL, JourLocal date NOT NULL,
                         Heures tinyint NOT NULL, PRIMARY KEY (Fuseau, JourLocal));
    INSERT #duree (Fuseau, JourLocal, Heures)
    SELECT f.Fuseau, c.DateJour,
           DATEDIFF(MINUTE, CAST(c.DateJour AS datetime2(0)) AT TIME ZONE f.Fuseau,
                            CAST(DATEADD(DAY, 1, c.DateJour) AS datetime2(0)) AT TIME ZONE f.Fuseau) / 60
    FROM (SELECT DISTINCT Fuseau FROM #plage) AS f
    CROSS JOIN core.Calendrier AS c
    WHERE c.DateJour BETWEEN @dMin AND @dMax;

    /* 3. Périodes de fuseau découpées par année : la jointure devient une égalité (fuseau, année) */
    CREATE TABLE #fuseau (Fuseau varchar(40) COLLATE DATABASE_DEFAULT NOT NULL, Annee int NOT NULL,
                          DebutUtc datetime2(0) NOT NULL, FinUtc datetime2(0) NOT NULL, DecalageMinutes smallint NOT NULL,
                          PRIMARY KEY (Fuseau, Annee, DebutUtc));
    INSERT #fuseau (Fuseau, Annee, DebutUtc, FinUtc, DecalageMinutes)
    SELECT d.Fuseau, a.value, d.DebutUtc, d.FinUtc, d.DecalageMinutes
    FROM core.FuseauDecalage AS d
    JOIN (SELECT DISTINCT Fuseau FROM #plage) AS f ON f.Fuseau = d.Fuseau
    CROSS APPLY GENERATE_SERIES(GREATEST(YEAR(d.DebutUtc), 1990), LEAST(YEAR(DATEADD(SECOND, -1, d.FinUtc)), 2100)) AS a;

    /* 4. Recalcul paquet par paquet, chaque paquet dans sa propre transaction courte */
    CREATE TABLE #paquet (SerieId int PRIMARY KEY, PasMinutes int NOT NULL, Fuseau varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
                          EstPuissance bit NOT NULL, JourMin date NOT NULL, JourMax date NOT NULL);

    WHILE EXISTS (SELECT 1 FROM #plage WHERE Traite = 0)
    BEGIN
        TRUNCATE TABLE #paquet;
        INSERT #paquet SELECT TOP (50) SerieId, PasMinutes, Fuseau, EstPuissance, JourMin, JourMax
                       FROM #plage WHERE Traite = 0 ORDER BY SerieId;

        BEGIN TRANSACTION;
            DELETE j
            FROM mart.MesureJour AS j
            JOIN #paquet AS p ON p.SerieId = j.SerieId AND j.JourLocal BETWEEN p.JourMin AND p.JourMax;

            INSERT mart.MesureJour
                (SerieId, JourLocal, NbPoints, Moyenne, Minimum, Maximum, EnergieMWh, DureeNegativeMinutes,
                 DureeJourHeures, Completude, LotMax, CalculeLeUtc)
            SELECT x.SerieId, x.JourLocal, COUNT(*),
                   CAST(AVG(x.V) AS decimal(19,4)), CAST(MIN(x.V) AS decimal(19,4)), CAST(MAX(x.V) AS decimal(19,4)),
                   CASE WHEN MAX(CAST(x.EstPuissance AS int)) = 1
                        THEN CAST(AVG(x.V) * ISNULL(MAX(du.Heures), 24) AS decimal(19,3)) END,
                   SUM(CASE WHEN x.V < 0 THEN x.PasMinutes ELSE 0 END),
                   ISNULL(MAX(du.Heures), 24),
                   CAST(LEAST(1.0, COUNT(*) * MAX(x.PasMinutes) / (ISNULL(MAX(du.Heures), 24) * 60.0)) AS decimal(5,4)),
                   MAX(x.LotId), SYSUTCDATETIME()
            FROM (
                SELECT m.SerieId, CAST(DATEADD(MINUTE, d.DecalageMinutes, m.InstantUtc) AS date) AS JourLocal,
                       CAST(m.Valeur AS float) AS V, p.PasMinutes, p.EstPuissance, p.Fuseau, m.LotId
                FROM core.Mesure AS m
                JOIN #paquet AS p ON p.SerieId = m.SerieId
                JOIN #fuseau AS d
                  ON d.Fuseau = p.Fuseau AND d.Annee = YEAR(m.InstantUtc)
                 AND m.InstantUtc >= d.DebutUtc AND m.InstantUtc < d.FinUtc
                WHERE m.InstantUtc >= DATEADD(DAY, -1, CAST(p.JourMin AS datetime2(0)))
                  AND m.InstantUtc <  DATEADD(DAY,  2, CAST(p.JourMax AS datetime2(0)))
                  AND m.Valeur IS NOT NULL
            ) AS x
            JOIN #paquet AS p ON p.SerieId = x.SerieId AND x.JourLocal BETWEEN p.JourMin AND p.JourMax
            LEFT JOIN #duree AS du ON du.Fuseau = x.Fuseau AND du.JourLocal = x.JourLocal
            GROUP BY x.SerieId, x.JourLocal;
            SET @n = @@ROWCOUNT;
            SET @jours += @n;

            UPDATE pl SET Traite = 1 FROM #plage AS pl JOIN #paquet AS p ON p.SerieId = pl.SerieId;
        COMMIT TRANSACTION;
    END

    UPDATE ops.Parametre SET Valeur = CAST(@lotMax AS nvarchar(20)), ModifieLe = SYSUTCDATETIME()
    WHERE Cle = 'MART_DERNIER_LOT';

    SET @msg = CONCAT(@series, N' séries, ', @jours, N' jours-séries recalculés, du ',
                      CONVERT(char(10), @dMin, 23), N' au ', CONVERT(char(10), @dMax, 23));
    EXEC ops.usp_Journal_Ecrire @lotMax, 'INFO', N'mart.usp_MesureJour_Rafraichir', @msg;
    SELECT @series AS SeriesRecalculees, @jours AS JoursRecalcules, @dMin AS Du, @dMax AS Au;
END
GO

/* ---------- Vues en clair ---------- */
CREATE OR ALTER VIEW mart.vw_MesureJour
AS
SELECT  j.SerieId, so.Code AS Source, so.Priorite, i.Code AS Indicateur, i.Libelle AS IndicateurLibelle,
        t.Libelle AS Theme, i.Unite, z.Code AS Zone, z.Nom AS ZoneNom, z.TypeZone,
        COALESCE(z.ParentCode, z.Code) AS Pays,
        f.Code AS Filiere, f.Libelle AS FiliereLibelle, f.Famille, f.EstRenouvelable, f.EstFossile, f.EstBasCarbone,
        f.FacteurCO2, f.Couleur, cp.Code AS Contrepartie, s.Granularite,
        j.JourLocal, c.Annee, c.Mois, c.AnneeMois, c.JourSemaine, c.EstOuvre, c.Saison,
        j.Moyenne, j.Minimum, j.Maximum, j.EnergieMWh, j.DureeNegativeMinutes, j.DureeJourHeures, j.Completude
FROM mart.MesureJour AS j
JOIN core.Serie      AS s  ON s.SerieId = j.SerieId
JOIN core.Source     AS so ON so.SourceId = s.SourceId
JOIN core.Indicateur AS i  ON i.IndicateurId = s.IndicateurId
JOIN core.Theme      AS t  ON t.ThemeId = i.ThemeId
JOIN core.Zone       AS z  ON z.ZoneId = s.ZoneId
JOIN core.Calendrier AS c  ON c.DateJour = j.JourLocal
LEFT JOIN core.Filiere AS f  ON f.FiliereId = s.FiliereId
LEFT JOIN core.Zone    AS cp ON cp.ZoneId = s.ContrepartieId;
GO

/* Mix quotidien : pour chaque zone et chaque jour, la source de meilleure priorité gagne */
CREATE OR ALTER VIEW mart.vw_MixJour
AS
WITH ParSource AS (
    SELECT Zone, ZoneNom, TypeZone, JourLocal, Source, Priorite, Famille,
           SUM(EnergieMWh) AS EnergieMWh, MIN(Completude) AS Completude
    FROM mart.vw_MesureJour
    WHERE Indicateur = 'PROD_ELEC'
    GROUP BY Zone, ZoneNom, TypeZone, JourLocal, Source, Priorite, Famille
),
Choix AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY Zone, JourLocal ORDER BY Priorite, Source) AS RangSource
    FROM ParSource
)
SELECT Zone, ZoneNom, TypeZone, JourLocal, Source, Famille, EnergieMWh, Completude,
       CAST(EnergieMWh / NULLIF(SUM(CASE WHEN Famille <> 'STOCKAGE' THEN EnergieMWh END)
                                OVER (PARTITION BY Zone, JourLocal), 0) AS decimal(9,6)) AS Part
FROM Choix
WHERE RangSource = 1;
GO

CREATE OR ALTER VIEW mart.vw_PrixJour
AS
SELECT Zone, ZoneNom, Pays, JourLocal, Annee, AnneeMois, JourSemaine,
       Moyenne AS PrixMoyen, Minimum AS PrixMin, Maximum AS PrixMax,
       Maximum - Minimum AS Amplitude,
       CAST(DureeNegativeMinutes / 60.0 AS decimal(6,2)) AS HeuresPrixNegatifs,
       Granularite, Completude
FROM mart.vw_MesureJour
WHERE Indicateur = 'PRIX_SPOT_J1';
GO

/* Échanges : un flux entrant dans B depuis A est une exportation de A */
CREATE OR ALTER VIEW mart.vw_EchangesJour
AS
WITH Flux AS (
    SELECT Zone AS Destination, Contrepartie AS Origine, JourLocal, Source, Priorite, EnergieMWh
    FROM mart.vw_MesureJour
    WHERE Indicateur = 'FLUX_PHYSIQUE' AND Contrepartie IS NOT NULL
),
Meilleure AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY Destination, Origine, JourLocal ORDER BY Priorite, Source) AS Rang
    FROM Flux
),
ParZone AS (
    SELECT Destination AS Zone, JourLocal, Origine AS Voisin, EnergieMWh AS ImportMWh, 0 AS ExportMWh FROM Meilleure WHERE Rang = 1
    UNION ALL
    SELECT Origine, JourLocal, Destination, 0, EnergieMWh FROM Meilleure WHERE Rang = 1
)
SELECT Zone, JourLocal, Voisin,
       SUM(ImportMWh) AS ImportMWh, SUM(ExportMWh) AS ExportMWh,
       SUM(ImportMWh) - SUM(ExportMWh) AS SoldeImportateurMWh
FROM ParZone
GROUP BY Zone, JourLocal, Voisin;
GO

/* Intensité carbone : estimée par le mix et les facteurs CO2, face à la mesure éCO2mix */
CREATE OR ALTER VIEW mart.vw_IntensiteCarboneJour
AS
WITH Mix AS (
    SELECT m.Zone, m.JourLocal,
           SUM(m.EnergieMWh * f.FacteurCO2) / NULLIF(SUM(m.EnergieMWh), 0) AS IntensiteEstimee,
           SUM(m.EnergieMWh) AS ProductionMWh
    FROM mart.vw_MixJour AS m
    JOIN (SELECT Famille, AVG(FacteurCO2) AS FacteurCO2 FROM core.Filiere GROUP BY Famille) AS f
      ON f.Famille = m.Famille
    WHERE m.Famille NOT IN ('STOCKAGE', 'VECTEURS') AND m.EnergieMWh > 0
    GROUP BY m.Zone, m.JourLocal
),
Mesuree AS (
    SELECT Zone, JourLocal, Moyenne AS IntensiteMesuree
    FROM mart.vw_MesureJour WHERE Indicateur = 'INTENSITE_CO2'
)
SELECT x.Zone, x.JourLocal, x.ProductionMWh,
       CAST(x.IntensiteEstimee AS decimal(9,1)) AS IntensiteEstimee_gkWh,
       CAST(me.IntensiteMesuree AS decimal(9,1)) AS IntensiteMesuree_gkWh
FROM Mix AS x
LEFT JOIN Mesuree AS me ON me.Zone = x.Zone AND me.JourLocal = x.JourLocal;
GO

/* ---------- Panel annuel par pays : deux tables jumelles et une bascule SWITCH ---------- */
DECLARE @t sysname;
DECLARE @tables TABLE (Nom sysname);
INSERT @tables VALUES (N'PanelPaysAnnee'), (N'PanelPaysAnnee_Chargement');
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Nom FROM @tables;
OPEN c;
FETCH NEXT FROM c INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID(N'mart.' + @t, N'U') IS NULL
    BEGIN
        DECLARE @sql nvarchar(max) = N'
        CREATE TABLE mart.' + QUOTENAME(@t) + N'
        (
            ZoneId                 smallint       NOT NULL,
            Pays                   varchar(12)    NOT NULL,
            PaysNom                nvarchar(100)  NOT NULL,
            EstUE                  bit            NOT NULL,
            Annee                  smallint       NOT NULL,
            ProductionTWh          decimal(12,3)  NULL,
            PartNucleaire          decimal(7,4)   NULL,
            PartFossile            decimal(7,4)   NULL,
            PartRenouvelableMix    decimal(7,4)   NULL,
            PartRenouvElecOfficiel decimal(7,2)   NULL,
            ConsoFinaleTWh         decimal(12,3)  NULL,
            ImportsTWh             decimal(12,3)  NULL,
            ExportsTWh             decimal(12,3)  NULL,
            SoldeExportateurTWh    decimal(12,3)  NULL,
            PrixMenages_kWh        decimal(9,4)   NULL,
            PrixEntreprises_kWh    decimal(9,4)   NULL,
            PrixSpotMoyen_MWh      decimal(9,2)   NULL,
            HeuresPrixNegatifs     decimal(9,1)   NULL,
            IntensiteCO2Estimee    decimal(9,1)   NULL,
            GES_Electricite_Mt     decimal(12,3)  NULL,
            GES_Total_Mt           decimal(12,3)  NULL,
            DependanceEnergetique  decimal(7,2)   NULL,
            CalculeLeUtc           datetime2(0)   NOT NULL
        ) ON FG_MART;
        CREATE CLUSTERED COLUMNSTORE INDEX ' + QUOTENAME(N'CCI_' + @t) + N' ON mart.' + QUOTENAME(@t) + N' ON FG_MART;';
        EXEC sys.sp_executesql @sql;
    END
    FETCH NEXT FROM c INTO @t;
END
CLOSE c;
DEALLOCATE c;
GO

CREATE OR ALTER PROCEDURE mart.usp_Panel_Rafraichir
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    DECLARE @lignes int, @msg nvarchar(400);

    TRUNCATE TABLE mart.PanelPaysAnnee_Chargement;

    WITH Pays AS (
        SELECT ZoneId, Code, Nom, EstUE FROM core.Zone WHERE TypeZone IN ('PAYS', 'AGREGAT') AND Origine = 'REFERENCE'
    ),
    /* Valeurs annuelles des indicateurs Eurostat (les semestres et les mois sont moyennés ou sommés) */
    Annuel AS (
        SELECT s.ZoneId, i.Code AS Indicateur, f.Famille, f.EstRenouvelable, f.EstFossile,
               YEAR(m.InstantUtc) AS Annee,
               SUM(CAST(m.Valeur AS float)) AS Somme, AVG(CAST(m.Valeur AS float)) AS Moyenne
        FROM core.Mesure AS m
        JOIN core.Serie AS s ON s.SerieId = m.SerieId
        JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
        JOIN core.Source AS so ON so.SourceId = s.SourceId
        LEFT JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId
        WHERE so.Code = 'EUROSTAT'
        GROUP BY s.ZoneId, i.Code, f.Famille, f.EstRenouvelable, f.EstFossile, YEAR(m.InstantUtc)
    ),
    Prod AS (
        SELECT ZoneId, Annee,
               SUM(Somme) AS Totale,
               SUM(CASE WHEN Famille = 'NUCLEAIRE' THEN Somme END) AS Nucleaire,
               SUM(CASE WHEN EstFossile = 1 THEN Somme END) AS Fossile,
               SUM(CASE WHEN EstRenouvelable = 1 THEN Somme END) AS Renouvelable,
               COUNT(DISTINCT Famille) AS NbFamilles
        FROM Annuel WHERE Indicateur = 'PROD_ELEC_MENSUELLE'
        GROUP BY ZoneId, Annee
    ),
    Co2 AS (
        SELECT a.ZoneId, a.Annee,
               SUM(a.Somme * fc.FacteurCO2) / NULLIF(SUM(a.Somme), 0) AS Intensite
        FROM Annuel AS a
        JOIN (SELECT Famille, AVG(FacteurCO2) AS FacteurCO2 FROM core.Filiere GROUP BY Famille) AS fc ON fc.Famille = a.Famille
        WHERE a.Indicateur = 'PROD_ELEC_MENSUELLE'
        GROUP BY a.ZoneId, a.Annee
    ),
    Spot AS (
        -- les zones de prix (DE_LU, IT_NORD...) sont rattachées à leur pays
        SELECT pz.ZoneId, YEAR(j.JourLocal) AS Annee,
               AVG(CAST(j.Moyenne AS float)) AS PrixMoyen, SUM(j.DureeNegativeMinutes) / 60.0 AS HeuresNeg
        FROM mart.MesureJour AS j
        JOIN core.Serie AS s ON s.SerieId = j.SerieId
        JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId AND i.Code = 'PRIX_SPOT_J1'
        JOIN core.Zone AS z ON z.ZoneId = s.ZoneId
        JOIN core.Zone AS pz ON pz.Code = COALESCE(z.ParentCode, z.Code)
        GROUP BY pz.ZoneId, YEAR(j.JourLocal)
    ),
    Cles AS (
        SELECT DISTINCT ZoneId, Annee FROM Annuel
        UNION SELECT ZoneId, Annee FROM Spot
    )
    INSERT mart.PanelPaysAnnee_Chargement WITH (TABLOCK)
    SELECT  p.ZoneId, p.Code, p.Nom, p.EstUE, k.Annee,
            CAST(pr.Totale / 1000 AS decimal(12,3)),
            CAST(pr.Nucleaire / NULLIF(pr.Totale, 0) AS decimal(7,4)),
            CAST(pr.Fossile / NULLIF(pr.Totale, 0) AS decimal(7,4)),
            CAST(pr.Renouvelable / NULLIF(pr.Totale, 0) AS decimal(7,4)),
            CAST(MAX(CASE WHEN a.Indicateur = 'PART_RENOUV_ELEC'   THEN a.Moyenne END) AS decimal(7,2)),
            CAST(MAX(CASE WHEN a.Indicateur = 'CONSO_FINALE_ELEC'  THEN a.Somme END) / 1000 AS decimal(12,3)),
            CAST(MAX(CASE WHEN a.Indicateur = 'IMPORT_ELEC'        THEN a.Somme END) / 1000 AS decimal(12,3)),
            CAST(MAX(CASE WHEN a.Indicateur = 'EXPORT_ELEC'        THEN a.Somme END) / 1000 AS decimal(12,3)),
            CAST((MAX(CASE WHEN a.Indicateur = 'EXPORT_ELEC' THEN a.Somme END)
                - MAX(CASE WHEN a.Indicateur = 'IMPORT_ELEC' THEN a.Somme END)) / 1000 AS decimal(12,3)),
            CAST(MAX(CASE WHEN a.Indicateur = 'PRIX_MENAGES'       THEN a.Moyenne END) AS decimal(9,4)),
            CAST(MAX(CASE WHEN a.Indicateur = 'PRIX_ENTREPRISES'   THEN a.Moyenne END) AS decimal(9,4)),
            CAST(MAX(sp.PrixMoyen) AS decimal(9,2)),
            CAST(MAX(sp.HeuresNeg) AS decimal(9,1)),
            CAST(MAX(co.Intensite) AS decimal(9,1)),
            CAST(MAX(CASE WHEN a.Indicateur = 'GES_ELECTRICITE'    THEN a.Moyenne END) AS decimal(12,3)),
            CAST(MAX(CASE WHEN a.Indicateur = 'GES_TOTAL'          THEN a.Moyenne END) AS decimal(12,3)),
            CAST(MAX(CASE WHEN a.Indicateur = 'DEPENDANCE_ENERGIE' THEN a.Moyenne END) AS decimal(7,2)),
            SYSUTCDATETIME()
    FROM Cles AS k
    JOIN Pays AS p ON p.ZoneId = k.ZoneId
    LEFT JOIN Annuel AS a ON a.ZoneId = k.ZoneId AND a.Annee = k.Annee AND a.Indicateur <> 'PROD_ELEC_MENSUELLE'
    LEFT JOIN Prod AS pr ON pr.ZoneId = k.ZoneId AND pr.Annee = k.Annee
    LEFT JOIN Co2  AS co ON co.ZoneId = k.ZoneId AND co.Annee = k.Annee
    LEFT JOIN Spot AS sp ON sp.ZoneId = k.ZoneId AND sp.Annee = k.Annee
    GROUP BY p.ZoneId, p.Code, p.Nom, p.EstUE, k.Annee, pr.Totale, pr.Nucleaire, pr.Fossile, pr.Renouvelable;
    SET @lignes = @@ROWCOUNT;

    /* Bascule : l'ancienne version sort, la nouvelle entre, en une opération de métadonnées */
    BEGIN TRANSACTION;
        TRUNCATE TABLE mart.PanelPaysAnnee;
        ALTER TABLE mart.PanelPaysAnnee_Chargement SWITCH TO mart.PanelPaysAnnee;
    COMMIT TRANSACTION;

    SET @msg = CONCAT(@lignes, N' lignes pays-année publiées par SWITCH');
    EXEC ops.usp_Journal_Ecrire NULL, 'INFO', N'mart.usp_Panel_Rafraichir', @msg;
    SELECT @lignes AS LignesPubliees;
END
GO

/* Contrôle */
SELECT SCHEMA_NAME(o.schema_id) + N'.' + o.name AS ObjetCree, o.type_desc AS Type_
FROM sys.objects AS o
WHERE SCHEMA_NAME(o.schema_id) = N'mart' AND o.type IN ('U', 'V', 'P')
ORDER BY o.type_desc, o.name;
GO

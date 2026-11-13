/* =====================================================================
   EEIP · Script 11 : l'API de lecture et le voyage dans le temps
   ---------------------------------------------------------------------
   api.usp_Serie_Obtenir    : une mesure, à la maille voulue (15 min, heure,
                              jour, mois) EN HEURE LOCALE, telle qu'elle est
                              aujourd'hui ou telle qu'elle ÉTAIT (@VuAuUtc)
   api.usp_Mix_Obtenir      : le mix de production d'une zone, jour, mois ou année
   api.usp_Prix_Comparer    : prix spot de plusieurs zones et écart à la première
   api.usp_Revisions_Lister : toutes les versions successives d'un point
   api.usp_Catalogue        : les séries disponibles, en JSON
   Nouveautés SQL Server 2022 utilisées : DATE_BUCKET, clause WINDOW,
   STRING_SPLIT ordonné, GREATEST, JSON_OBJECT.
   ===================================================================== */
USE EEIP;
GO

CREATE OR ALTER PROCEDURE api.usp_Serie_Obtenir
    @Indicateur    varchar(40),
    @Zone          varchar(12),
    @Filiere       varchar(20)  = NULL,       -- NULL = toutes les filières
    @Contrepartie  varchar(12)  = NULL,
    @Source        varchar(10)  = NULL,       -- NULL = la meilleure source disponible
    @Debut         datetime2(0) = NULL,       -- heure LOCALE de la zone
    @Fin           datetime2(0) = NULL,       -- heure LOCALE, exclue
    @Pas           varchar(5)   = 'PT60M',    -- PT15M (brut), PT60M, P1D, P1M
    @VuAuUtc       datetime2(3) = NULL,       -- NULL = valeurs en vigueur
    @EnJson        bit          = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @fuseau varchar(40), @debutUtc datetime2(0), @finUtc datetime2(0);

    SELECT @fuseau = Fuseau FROM core.Zone WHERE Code = @Zone;
    IF @fuseau IS NULL THROW 50010, N'Zone inconnue.', 1;

    SET @Fin   = ISNULL(@Fin, DATEADD(DAY, 1, CAST(CAST(GETDATE() AS date) AS datetime2(0))));
    SET @Debut = ISNULL(@Debut, DATEADD(DAY, -7, @Fin));
    -- bornes locales -> UTC, une seule fois
    SET @debutUtc = CAST(SWITCHOFFSET(@Debut AT TIME ZONE @fuseau, '+00:00') AS datetime2(0));
    SET @finUtc   = CAST(SWITCHOFFSET(@Fin   AT TIME ZONE @fuseau, '+00:00') AS datetime2(0));

    CREATE TABLE #series (SerieId int PRIMARY KEY, Source varchar(10) COLLATE DATABASE_DEFAULT,
                          Filiere varchar(20) COLLATE DATABASE_DEFAULT, Contrepartie varchar(12) COLLATE DATABASE_DEFAULT);
    INSERT #series
    SELECT s.SerieId, so.Code, f.Code, cp.Code
    FROM core.Serie AS s
    JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId AND i.Code = @Indicateur
    JOIN core.Zone AS z ON z.ZoneId = s.ZoneId AND z.Code = @Zone
    JOIN core.Source AS so ON so.SourceId = s.SourceId
    LEFT JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId
    LEFT JOIN core.Zone AS cp ON cp.ZoneId = s.ContrepartieId
    WHERE (@Filiere IS NULL OR f.Code = @Filiere)
      AND (@Contrepartie IS NULL OR cp.Code = @Contrepartie)
      AND (@Source IS NULL OR so.Code = @Source)
      -- sans source imposée : la source de meilleure priorité qui a des données
      AND (@Source IS NOT NULL OR so.Priorite = (
              SELECT MIN(so2.Priorite) FROM core.Serie AS s2
              JOIN core.Source AS so2 ON so2.SourceId = s2.SourceId
              WHERE s2.IndicateurId = s.IndicateurId AND s2.ZoneId = s.ZoneId
                AND s2.DernierInstant >= @debutUtc AND s2.PremierInstant < @finUtc));

    CREATE TABLE #pts (SerieId int, InstantUtc datetime2(0), Valeur decimal(19,6));
    IF @VuAuUtc IS NULL
        INSERT #pts SELECT m.SerieId, m.InstantUtc, m.Valeur
        FROM core.Mesure AS m JOIN #series AS s ON s.SerieId = m.SerieId
        WHERE m.InstantUtc >= @debutUtc AND m.InstantUtc < @finUtc;
    ELSE
        INSERT #pts SELECT m.SerieId, m.InstantUtc, m.Valeur
        FROM core.Mesure FOR SYSTEM_TIME AS OF @VuAuUtc AS m JOIN #series AS s ON s.SerieId = m.SerieId
        WHERE m.InstantUtc >= @debutUtc AND m.InstantUtc < @finUtc;

    WITH Local_ AS (
        SELECT p.SerieId, DATEADD(MINUTE, d.DecalageMinutes, p.InstantUtc) AS HeureLocale, p.Valeur
        FROM #pts AS p
        JOIN core.FuseauDecalage AS d ON d.Fuseau = @fuseau AND p.InstantUtc >= d.DebutUtc AND p.InstantUtc < d.FinUtc
    ),
    Seau AS (
        SELECT SerieId, Valeur,
               CASE @Pas WHEN 'PT15M' THEN HeureLocale
                         WHEN 'PT60M' THEN DATE_BUCKET(HOUR, 1, HeureLocale)
                         WHEN 'P1D'   THEN DATE_BUCKET(DAY, 1, HeureLocale)
                         ELSE              DATE_BUCKET(MONTH, 1, HeureLocale) END AS Periode
        FROM Local_
    )
    SELECT s.Source, s.Filiere, s.Contrepartie, b.Periode AS PeriodeLocale,
           CAST(AVG(b.Valeur) AS decimal(19,3)) AS Moyenne,
           MIN(b.Valeur) AS Minimum, MAX(b.Valeur) AS Maximum, COUNT(*) AS NbPoints
    INTO #res
    FROM Seau AS b JOIN #series AS s ON s.SerieId = b.SerieId
    GROUP BY s.Source, s.Filiere, s.Contrepartie, b.Periode;

    IF @EnJson = 1
        SELECT JSON_OBJECT('indicateur': @Indicateur, 'zone': @Zone, 'pas': @Pas,
                           'vu_au_utc': CONVERT(varchar(23), @VuAuUtc, 126)) AS Entete,
               (SELECT * FROM #res ORDER BY Filiere, PeriodeLocale FOR JSON PATH) AS Donnees;
    ELSE
        SELECT * FROM #res ORDER BY Filiere, Contrepartie, PeriodeLocale;
END
GO

CREATE OR ALTER PROCEDURE api.usp_Mix_Obtenir
    @Zone   varchar(12),
    @Debut  date,
    @Fin    date,                 -- exclue
    @Pas    varchar(3) = 'P1M'    -- P1D, P1M, P1Y
AS
BEGIN
    SET NOCOUNT ON;
    WITH Base AS (
        SELECT CASE @Pas WHEN 'P1D' THEN JourLocal
                         WHEN 'P1Y' THEN DATE_BUCKET(YEAR, 1, JourLocal)
                         ELSE DATE_BUCKET(MONTH, 1, JourLocal) END AS Periode,
               Famille, EnergieMWh
        FROM mart.vw_MixJour
        WHERE Zone = @Zone AND JourLocal >= @Debut AND JourLocal < @Fin
    )
    SELECT Periode, Famille,
           CAST(SUM(EnergieMWh) / 1000 AS decimal(14,3)) AS EnergieGWh,
           CAST(SUM(EnergieMWh) / NULLIF(SUM(SUM(CASE WHEN Famille <> 'STOCKAGE' THEN EnergieMWh END)) OVER w, 0)
                AS decimal(7,4)) AS Part
    FROM Base
    GROUP BY Periode, Famille
    WINDOW w AS (PARTITION BY Periode)
    ORDER BY Periode, EnergieGWh DESC;
END
GO

CREATE OR ALTER PROCEDURE api.usp_Prix_Comparer
    @Zones  varchar(200) = 'FR,DE_LU,ES,IT_NORD',   -- la première sert de référence
    @Debut  date,
    @Fin    date
AS
BEGIN
    SET NOCOUNT ON;
    WITH Liste AS (
        SELECT TRIM(value) AS Zone, ordinal AS Rang FROM STRING_SPLIT(@Zones, ',', 1)
    ),
    Prix AS (
        SELECT l.Rang, p.Zone, p.JourLocal, p.PrixMoyen, p.HeuresPrixNegatifs
        FROM mart.vw_PrixJour AS p
        JOIN Liste AS l ON l.Zone = p.Zone
        WHERE p.JourLocal >= @Debut AND p.JourLocal < @Fin
    )
    SELECT Zone, JourLocal, PrixMoyen, HeuresPrixNegatifs,
           CAST(PrixMoyen - FIRST_VALUE(PrixMoyen) OVER w AS decimal(9,2)) AS EcartAReference,
           CAST(AVG(PrixMoyen) OVER (PARTITION BY Zone ORDER BY JourLocal ROWS 6 PRECEDING) AS decimal(9,2)) AS Moyenne7Jours
    FROM Prix
    WINDOW w AS (PARTITION BY JourLocal ORDER BY Rang)
    ORDER BY JourLocal, Rang;
END
GO

CREATE OR ALTER PROCEDURE api.usp_Revisions_Lister
    @Indicateur  varchar(40),
    @Zone        varchar(12),
    @Filiere     varchar(20) = NULL,
    @InstantUtc  datetime2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT so.Code AS Source, s.CodeSource, f.Code AS Filiere, m.InstantUtc, m.Valeur, m.Qualite,
           m.LotId, m.ValidFrom AS ConnuDepuisUtc,
           CASE WHEN m.ValidTo = '9999-12-31 23:59:59.999' THEN NULL ELSE m.ValidTo END AS RemplaceLeUtc
    FROM core.Mesure FOR SYSTEM_TIME ALL AS m
    JOIN core.Serie AS s ON s.SerieId = m.SerieId
    JOIN core.Source AS so ON so.SourceId = s.SourceId
    JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
    JOIN core.Zone AS z ON z.ZoneId = s.ZoneId
    LEFT JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId
    WHERE i.Code = @Indicateur AND z.Code = @Zone
      AND (@Filiere IS NULL OR f.Code = @Filiere)
      AND m.InstantUtc = @InstantUtc
    ORDER BY so.Code, f.Code, m.ValidFrom;
END
GO

CREATE OR ALTER PROCEDURE api.usp_Catalogue
AS
BEGIN
    SET NOCOUNT ON;
    SELECT (
        SELECT i.Code AS indicateur, i.Libelle AS libelle, i.Unite AS unite,
               (SELECT DISTINCT z.Code AS zone, so.Code AS source, s.Granularite AS granularite
                FROM core.Serie AS s
                JOIN core.Zone AS z ON z.ZoneId = s.ZoneId
                JOIN core.Source AS so ON so.SourceId = s.SourceId
                WHERE s.IndicateurId = i.IndicateurId
                FOR JSON PATH) AS series
        FROM core.Indicateur AS i
        ORDER BY i.Code
        FOR JSON PATH, ROOT('catalogue')
    ) AS CatalogueJson;
END
GO

SELECT s.name + N'.' + p.name AS ProcedureCreee
FROM sys.procedures AS p JOIN sys.schemas AS s ON s.schema_id = p.schema_id
WHERE s.name = N'api' ORDER BY ProcedureCreee;
GO

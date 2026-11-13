/* =====================================================================
   EEIP · Script 04 : le référentiel (dimensions) et la configuration
   ---------------------------------------------------------------------
   core.Source          : RTE, ODRÉ, ENTSO-E, Eurostat
   core.Theme           : consommation, production, prix, échanges...
   core.Indicateur      : indicateurs CANONIQUES, communs à toutes les sources
   core.Zone            : pays, zones de prix, régions : table TEMPORELLE
   core.ZoneAlias       : codes propres à une source (EIC, EL, code INSEE...)
   core.Filiere         : nucléaire, gaz, éolien... famille, facteur CO2, couleur
   core.FiliereAlias    : B14 d'ENTSO-E, N9000 d'Eurostat, NUCLEAR de RTE...
   core.Frontiere       : les interconnexions entre deux zones
   cfg.RequeteACharger  : le catalogue piloté par les données (JSON)
   core.Serie           : source + code + indicateur + zone + filière + contrepartie
   core.Calendrier      : dimension date (GENERATE_SERIES)
   core.FuseauDecalage  : périodes d'heure d'été / d'hiver par fuseau
   ===================================================================== */
USE EEIP;
GO

/* ---------- Sources ---------- */
IF OBJECT_ID(N'core.Source', N'U') IS NULL
CREATE TABLE core.Source
(
    SourceId      tinyint        NOT NULL CONSTRAINT PK_Source PRIMARY KEY,
    Code          varchar(10)    NOT NULL CONSTRAINT UQ_Source_Code UNIQUE,
    Nom           nvarchar(120)  NOT NULL,
    UrlBase       varchar(300)   NOT NULL,
    Licence       nvarchar(120)  NULL,
    NecessiteCle  bit            NOT NULL CONSTRAINT DF_Source_Cle DEFAULT (0),
    Priorite      tinyint        NOT NULL   -- 1 = préférée quand plusieurs sources donnent la même mesure
) ON FG_REFERENTIEL;
GO

/* ---------- Thèmes ---------- */
IF OBJECT_ID(N'core.Theme', N'U') IS NULL
CREATE TABLE core.Theme
(
    ThemeId  tinyint       NOT NULL CONSTRAINT PK_Theme PRIMARY KEY,
    Code     varchar(20)   NOT NULL CONSTRAINT UQ_Theme_Code UNIQUE,
    Libelle  nvarchar(60)  NOT NULL
) ON FG_REFERENTIEL;
GO

/* ---------- Indicateurs canoniques ---------- */
IF OBJECT_ID(N'core.Indicateur', N'U') IS NULL
CREATE TABLE core.Indicateur
(
    IndicateurId  smallint       IDENTITY(1,1) NOT NULL CONSTRAINT PK_Indicateur PRIMARY KEY,
    Code          varchar(40)    NOT NULL CONSTRAINT UQ_Indicateur_Code UNIQUE,
    Libelle       nvarchar(200)  NOT NULL,
    ThemeId       tinyint        NOT NULL CONSTRAINT FK_Indicateur_Theme REFERENCES core.Theme (ThemeId),
    Unite         nvarchar(30)   NOT NULL,
    -- PUISSANCE (MW à un instant), ENERGIE (MWh, GWh), PRIX, INTENSITE, RATIO, MASSE
    Nature        varchar(12)    NOT NULL CONSTRAINT CK_Indicateur_Nature
                  CHECK (Nature IN ('PUISSANCE', 'ENERGIE', 'PRIX', 'INTENSITE', 'RATIO', 'MASSE')),
    Description   nvarchar(400)  NULL
) ON FG_REFERENTIEL;
GO

/* ---------- Zones : table temporelle versionnée par le système ---------- */
IF OBJECT_ID(N'core.Zone', N'U') IS NULL
CREATE TABLE core.Zone
(
    ZoneId        smallint       IDENTITY(1,1) NOT NULL CONSTRAINT PK_Zone PRIMARY KEY CLUSTERED,
    Code          varchar(12)    NOT NULL,   -- FR, DE_LU, IT_NORD, FR-IDF, EU27...
    Nom           nvarchar(100)  NOT NULL,
    TypeZone      varchar(10)    NOT NULL CONSTRAINT CK_Zone_Type
                  CHECK (TypeZone IN ('PAYS', 'ZONE_PRIX', 'REGION', 'AGREGAT')),
    CodeIso2      char(2)        NULL,
    CodeEic       varchar(16)    NULL,       -- code européen ENTSO-E (10YFR-RTE------C)
    CodeEurostat  varchar(10)    NULL,       -- EL pour la Grèce, EU27_2020...
    ParentCode    varchar(12)    NULL,       -- FR-IDF -> FR ; IT_NORD -> IT
    Fuseau        varchar(40)    NOT NULL CONSTRAINT DF_Zone_Fuseau DEFAULT ('Romance Standard Time'),
    Latitude      decimal(9,6)   NULL,
    Longitude     decimal(9,6)   NULL,
    EstUE         bit            NOT NULL CONSTRAINT DF_Zone_EstUE DEFAULT (0),
    Origine       varchar(10)    NOT NULL CONSTRAINT DF_Zone_Origine DEFAULT ('REFERENCE')
                  CONSTRAINT CK_Zone_Origine CHECK (Origine IN ('REFERENCE', 'DEDUITE')),
    ValidFrom     datetime2(3)   GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo       datetime2(3)   GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
) ON FG_REFERENTIEL
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = core.ZoneHistorique));
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Zone_Code')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Zone_Code ON core.Zone (Code) ON FG_REFERENTIEL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Zone_Eic')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Zone_Eic ON core.Zone (CodeEic) WHERE CodeEic IS NOT NULL ON FG_REFERENTIEL;
GO

/* ---------- Alias de zones propres à une source ---------- */
IF OBJECT_ID(N'core.ZoneAlias', N'U') IS NULL
CREATE TABLE core.ZoneAlias
(
    SourceCode     varchar(10)  NOT NULL CONSTRAINT FK_ZoneAlias_Source REFERENCES core.Source (Code),
    CodeExterne    varchar(60)  NOT NULL,
    CodeZoneCible  varchar(12)  NOT NULL,
    CONSTRAINT PK_ZoneAlias PRIMARY KEY (SourceCode, CodeExterne)
) ON FG_REFERENTIEL;
GO

/* ---------- Filières de production ---------- */
IF OBJECT_ID(N'core.Filiere', N'U') IS NULL
CREATE TABLE core.Filiere
(
    FiliereId        smallint       IDENTITY(1,1) NOT NULL CONSTRAINT PK_Filiere PRIMARY KEY,
    Code             varchar(20)    NOT NULL CONSTRAINT UQ_Filiere_Code UNIQUE,
    Libelle          nvarchar(80)   NOT NULL,
    -- famille commune à toutes les sources : c'est elle qui sert aux comparaisons entre pays
    Famille          varchar(20)    NOT NULL CONSTRAINT CK_Filiere_Famille
                     CHECK (Famille IN ('NUCLEAIRE', 'CHARBON', 'GAZ', 'PETROLE', 'THERMIQUE', 'HYDRAULIQUE',
                                        'EOLIEN', 'SOLAIRE', 'BIOENERGIES', 'RENOUVELABLES', 'AUTRES',
                                        'STOCKAGE', 'VECTEURS')),
    EstRenouvelable  bit            NOT NULL,
    EstFossile       bit            NOT NULL,
    EstBasCarbone    bit            NOT NULL,
    -- émissions directes indicatives, en g CO2 par kWh produit : modifiables
    FacteurCO2       decimal(7,1)   NOT NULL CONSTRAINT DF_Filiere_CO2 DEFAULT (0),
    Couleur          char(7)        NOT NULL,   -- #RRGGBB, réutilisée dans Power BI
    Ordre            tinyint        NOT NULL
) ON FG_REFERENTIEL;
GO

IF OBJECT_ID(N'core.FiliereAlias', N'U') IS NULL
CREATE TABLE core.FiliereAlias
(
    SourceCode   varchar(10)  NOT NULL CONSTRAINT FK_FiliereAlias_Source REFERENCES core.Source (Code),
    CodeExterne  varchar(60)  NOT NULL,
    CodeFiliere  varchar(20)  NOT NULL CONSTRAINT FK_FiliereAlias_Filiere REFERENCES core.Filiere (Code),
    CONSTRAINT PK_FiliereAlias PRIMARY KEY (SourceCode, CodeExterne)
) ON FG_REFERENTIEL;
GO

/* ---------- Frontières (interconnexions) ---------- */
IF OBJECT_ID(N'core.Frontiere', N'U') IS NULL
CREATE TABLE core.Frontiere
(
    ZoneA       varchar(12)  NOT NULL,
    ZoneB       varchar(12)  NOT NULL,
    ChargerFlux bit          NOT NULL CONSTRAINT DF_Frontiere_Charger DEFAULT (1),
    CONSTRAINT PK_Frontiere PRIMARY KEY (ZoneA, ZoneB),
    CONSTRAINT CK_Frontiere_Ordre CHECK (ZoneA < ZoneB)   -- une seule ligne par paire
) ON FG_REFERENTIEL;
GO

/* ---------- Catalogue piloté par les données ---------- */
IF OBJECT_ID(N'cfg.RequeteACharger', N'U') IS NULL
CREATE TABLE cfg.RequeteACharger
(
    CfgId               int             IDENTITY(1,1) NOT NULL CONSTRAINT PK_RequeteACharger PRIMARY KEY,
    SourceCode          varchar(10)     NOT NULL CONSTRAINT FK_Cfg_Source REFERENCES core.Source (Code),
    -- ODRE : jeu de données ; ENTSOE : documentType ; RTE : chemin d'API ; EUROSTAT : code du jeu
    Jeu                 varchar(120)    NOT NULL,
    -- tout le reste, en JSON : champs, filtres, paramètres de l'API (ISJSON de SQL Server 2022)
    Parametres          nvarchar(4000)  NOT NULL CONSTRAINT DF_Cfg_Param DEFAULT (N'{}')
                        CONSTRAINT CK_Cfg_Parametres CHECK (ISJSON(Parametres, OBJECT) = 1),
    IndicateurCode      varchar(40)     NOT NULL CONSTRAINT FK_Cfg_Indicateur REFERENCES core.Indicateur (Code),
    ZoneCode            varchar(12)     NULL,
    ContrepartieCode    varchar(12)     NULL,
    FacteurEchelle      float           NOT NULL CONSTRAINT DF_Cfg_Facteur DEFAULT (1),
    DebutHistorique     date            NOT NULL,
    FenetreJours        smallint        NOT NULL CONSTRAINT DF_Cfg_Fenetre DEFAULT (31),    -- taille d'un appel
    RecouvrementJours   smallint        NOT NULL CONSTRAINT DF_Cfg_Recouv  DEFAULT (3),     -- relecture pour les révisions
    Actif               bit             NOT NULL CONSTRAINT DF_Cfg_Actif   DEFAULT (1),
    DernierInstant      datetime2(0)    NULL,      -- filigrane : dernier instant intégré (UTC)
    DerniereExtraction  datetime2(0)    NULL,
    DernierStatut       varchar(12)     NULL,
    DerniereEmpreinte   binary(32)      NULL,      -- SHA-256 de la dernière réponse intégrée
    Commentaire         nvarchar(200)   NULL,
    CONSTRAINT UQ_RequeteACharger UNIQUE (SourceCode, Jeu, IndicateurCode, ZoneCode, ContrepartieCode)
) ON FG_REFERENTIEL;
GO

/* ---------- Séries ---------- */
IF OBJECT_ID(N'core.Serie', N'U') IS NULL
CREATE TABLE core.Serie
(
    SerieId          int            IDENTITY(1,1) NOT NULL CONSTRAINT PK_Serie PRIMARY KEY CLUSTERED,
    SourceId         tinyint        NOT NULL CONSTRAINT FK_Serie_Source       REFERENCES core.Source (SourceId),
    CodeSource       varchar(200)   NOT NULL,  -- identifiant stable chez le producteur
    IndicateurId     smallint       NOT NULL CONSTRAINT FK_Serie_Indicateur   REFERENCES core.Indicateur (IndicateurId),
    ZoneId           smallint       NOT NULL CONSTRAINT FK_Serie_Zone         REFERENCES core.Zone (ZoneId),
    FiliereId        smallint       NULL     CONSTRAINT FK_Serie_Filiere      REFERENCES core.Filiere (FiliereId),
    ContrepartieId   smallint       NULL     CONSTRAINT FK_Serie_Contrepartie REFERENCES core.Zone (ZoneId),
    Granularite      varchar(5)     NOT NULL CONSTRAINT CK_Serie_Granularite
                     CHECK (Granularite IN ('PT15M', 'PT30M', 'PT60M', 'P1D', 'P1M', 'P6M', 'P1Y')),
    PasMinutes       AS (CASE Granularite WHEN 'PT15M' THEN 15 WHEN 'PT30M' THEN 30 WHEN 'PT60M' THEN 60
                                          WHEN 'P1D' THEN 1440 END) PERSISTED,
    CfgId            int            NULL     CONSTRAINT FK_Serie_Cfg REFERENCES cfg.RequeteACharger (CfgId),
    PremierInstant   datetime2(0)   NULL,
    DernierInstant   datetime2(0)   NULL,
    NbPoints         int            NULL,
    DerniereMaj      datetime2(3)   NULL,
    CreeLe           datetime2(3)   NOT NULL CONSTRAINT DF_Serie_CreeLe DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Serie UNIQUE (SourceId, CodeSource)
) ON FG_REFERENTIEL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Serie_Indicateur_Zone')
    CREATE NONCLUSTERED INDEX IX_Serie_Indicateur_Zone
    ON core.Serie (IndicateurId, ZoneId)
    INCLUDE (SourceId, FiliereId, ContrepartieId, Granularite)
    ON FG_REFERENTIEL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Serie_Cfg')
    CREATE NONCLUSTERED INDEX IX_Serie_Cfg ON core.Serie (CfgId) INCLUDE (DernierInstant) ON FG_REFERENTIEL;
GO

/* ---------- Calendrier (1990 à 2040) ---------- */
IF OBJECT_ID(N'core.Calendrier', N'U') IS NULL
CREATE TABLE core.Calendrier
(
    DateJour     date          NOT NULL CONSTRAINT PK_Calendrier PRIMARY KEY,
    Annee        smallint      NOT NULL,
    Trimestre    tinyint       NOT NULL,
    Mois         tinyint       NOT NULL,
    NomMois      nvarchar(12)  NOT NULL,
    AnneeMois    char(7)       NOT NULL,   -- 2026-11
    JourSemaine  tinyint       NOT NULL,   -- 1 = lundi
    NomJour      nvarchar(10)  NOT NULL,
    EstOuvre     bit           NOT NULL,
    Saison       nvarchar(10)  NOT NULL    -- hiver, printemps, été, automne
) ON FG_REFERENTIEL;
GO

IF NOT EXISTS (SELECT 1 FROM core.Calendrier)
    INSERT core.Calendrier (DateJour, Annee, Trimestre, Mois, NomMois, AnneeMois, JourSemaine, NomJour, EstOuvre, Saison)
    SELECT  j.D, YEAR(j.D), DATEPART(QUARTER, j.D), MONTH(j.D),
            FORMAT(j.D, 'MMMM', 'fr-FR'),
            CONVERT(char(7), j.D, 126),
            (DATEDIFF(DAY, '19000101', j.D) % 7) + 1,            -- indépendant de SET DATEFIRST
            FORMAT(j.D, 'dddd', 'fr-FR'),
            CASE WHEN (DATEDIFF(DAY, '19000101', j.D) % 7) < 5 THEN 1 ELSE 0 END,
            CASE WHEN MONTH(j.D) IN (12, 1, 2) THEN N'hiver' WHEN MONTH(j.D) IN (3, 4, 5) THEN N'printemps'
                 WHEN MONTH(j.D) IN (6, 7, 8) THEN N'été' ELSE N'automne' END
    FROM (SELECT DATEADD(DAY, s.value, CAST('1990-01-01' AS date)) AS D
          FROM GENERATE_SERIES(0, DATEDIFF(DAY, '1990-01-01', '2040-12-31')) AS s) AS j;
GO

/* ---------- Décalages horaires : une ligne par période d'heure d'été ou d'hiver ----------
   Convertir des millions d'instants UTC avec AT TIME ZONE est lent (mode ligne).
   On calcule UNE fois les périodes de chaque fuseau, puis une simple jointure par
   intervalle donne l'heure locale, en mode batch. */
IF OBJECT_ID(N'core.FuseauDecalage', N'U') IS NULL
CREATE TABLE core.FuseauDecalage
(
    Fuseau           varchar(40)   NOT NULL,
    DebutUtc         datetime2(0)  NOT NULL,
    FinUtc           datetime2(0)  NOT NULL,
    DecalageMinutes  smallint      NOT NULL,
    CONSTRAINT PK_FuseauDecalage PRIMARY KEY (Fuseau, DebutUtc)
) ON FG_REFERENTIEL;
GO

CREATE OR ALTER PROCEDURE core.usp_Fuseau_Generer
AS
BEGIN
    SET NOCOUNT ON;
    DELETE core.FuseauDecalage;

    /* 1. Le décalage de chaque fuseau, heure par heure, de 2010 à 2041
       2. « Îles » : on regroupe les heures consécutives de même décalage */
    WITH Heures AS (
        SELECT f.Fuseau, h.HeureUtc,
               DATEPART(TZOFFSET, CAST(h.HeureUtc AS datetimeoffset(0)) AT TIME ZONE f.Fuseau) AS Decalage
        FROM (SELECT DISTINCT Fuseau FROM core.Zone) AS f
        CROSS JOIN (SELECT DATEADD(HOUR, s.value, CAST('2010-01-01' AS datetime2(0))) AS HeureUtc
                    FROM GENERATE_SERIES(0, DATEDIFF(HOUR, '2010-01-01', '2041-01-01')) AS s) AS h
    ),
    Ruptures AS (
        SELECT *, CASE WHEN LAG(Decalage) OVER (PARTITION BY Fuseau ORDER BY HeureUtc) = Decalage
                       THEN 0 ELSE 1 END AS Nouveau
        FROM Heures
    ),
    Iles AS (
        SELECT *, SUM(Nouveau) OVER (PARTITION BY Fuseau ORDER BY HeureUtc ROWS UNBOUNDED PRECEDING) AS Ile
        FROM Ruptures
    )
    INSERT core.FuseauDecalage (Fuseau, DebutUtc, FinUtc, DecalageMinutes)
    SELECT Fuseau,
           CASE WHEN MIN(HeureUtc) = '2010-01-01' THEN '1900-01-01' ELSE MIN(HeureUtc) END,
           DATEADD(HOUR, 1, MAX(HeureUtc)),
           MIN(Decalage)
    FROM Iles
    GROUP BY Fuseau, Ile;

    -- la dernière période de chaque fuseau couvre tout le futur
    UPDATE d SET FinUtc = '9999-12-31'
    FROM core.FuseauDecalage AS d
    WHERE d.FinUtc = (SELECT MAX(d2.FinUtc) FROM core.FuseauDecalage AS d2 WHERE d2.Fuseau = d.Fuseau);

    SELECT Fuseau, COUNT(*) AS Periodes, MIN(DecalageMinutes) AS HiverMinutes, MAX(DecalageMinutes) AS EteMinutes
    FROM core.FuseauDecalage GROUP BY Fuseau ORDER BY Fuseau;
END
GO

/* ---------- Résolution d'un code de zone, quelle que soit la source ----------
   Ordre : 1) alias de la source  2) code exact  3) code EIC  4) code Eurostat  5) ISO2 */
CREATE OR ALTER FUNCTION core.fn_ZoneResoudre (@SourceCode varchar(10), @Code varchar(60))
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (1) r.ZoneId
    FROM (
        SELECT z.ZoneId, 1 AS Rang
        FROM core.ZoneAlias AS a JOIN core.Zone AS z ON z.Code = a.CodeZoneCible
        WHERE a.SourceCode = @SourceCode AND a.CodeExterne = @Code
        UNION ALL SELECT z.ZoneId, 2 FROM core.Zone AS z WHERE z.Code = @Code
        UNION ALL SELECT z.ZoneId, 3 FROM core.Zone AS z WHERE z.CodeEic = @Code
        UNION ALL SELECT z.ZoneId, 4 FROM core.Zone AS z WHERE z.CodeEurostat = @Code
        UNION ALL SELECT z.ZoneId, 5 FROM core.Zone AS z WHERE LEN(@Code) = 2 AND z.CodeIso2 = @Code AND z.TypeZone = 'PAYS'
    ) AS r
    ORDER BY r.Rang, r.ZoneId
);
GO

CREATE OR ALTER FUNCTION core.fn_FiliereResoudre (@SourceCode varchar(10), @Code varchar(60))
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (1) r.FiliereId
    FROM (
        SELECT f.FiliereId, 1 AS Rang
        FROM core.FiliereAlias AS a JOIN core.Filiere AS f ON f.Code = a.CodeFiliere
        WHERE a.SourceCode = @SourceCode AND a.CodeExterne = @Code
        UNION ALL SELECT f.FiliereId, 2 FROM core.Filiere AS f WHERE f.Code = @Code
    ) AS r
    ORDER BY r.Rang
);
GO

/* Contrôle */
SELECT s.name + N'.' + t.name AS TableCree, t.temporal_type_desc AS Temporel
FROM sys.tables AS t JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name IN (N'core', N'cfg') ORDER BY TableCree;
SELECT COUNT(*) AS JoursCalendrier, MIN(DateJour) AS Premier, MAX(DateJour) AS Dernier FROM core.Calendrier;
GO

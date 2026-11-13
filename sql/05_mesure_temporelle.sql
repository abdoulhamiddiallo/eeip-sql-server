/* =====================================================================
   EEIP · Script 05 : la table des mesures, partitionnée et historisée
   ---------------------------------------------------------------------
   core.Mesure           : la valeur EN VIGUEUR de chaque point (série, instant UTC)
   core.MesureHistorique : chaque valeur remplacée (temps réel -> consolidé
                           -> définitif, révisions), datée par SQL Server
   Architecture d'une table de séries temporelles à fort volume :
   - index COLUMNSTORE CLUSTER ORDONNÉ (SerieId, InstantUtc), nouveauté
     SQL Server 2022 : compression 10 fois, lecture en mode batch, et les
     segments triés permettent de sauter tout ce qui n'est pas demandé ;
   - clé primaire NON CLUSTER (SerieId, InstantUtc), alignée sur les
     partitions : unicité garantie et recherches ponctuelles en quelques
     lectures (indispensable aux révisions) ;
   - partitionnement MENSUEL sur InstantUtc.
   ===================================================================== */
USE EEIP;
GO

/* 1. L'historique d'abord : mêmes colonnes, même ordre, mêmes types, sans clé */
IF OBJECT_ID(N'core.MesureHistorique', N'U') IS NULL
BEGIN
    CREATE TABLE core.MesureHistorique
    (
        SerieId     int            NOT NULL,
        InstantUtc  datetime2(0)   NOT NULL,
        Valeur      decimal(19,6)  NULL,
        Qualite     char(1)        NOT NULL,
        LotId       int            NOT NULL,
        ValidFrom   datetime2(3)   NOT NULL,
        ValidTo     datetime2(3)   NOT NULL
    ) ON ps_MoisUtc (InstantUtc);

    CREATE CLUSTERED COLUMNSTORE INDEX CCI_MesureHistorique
        ON core.MesureHistorique
        ON ps_MoisUtc (InstantUtc);
END
GO

/* 2. La table courante, versionnée par le système */
IF OBJECT_ID(N'core.Mesure', N'U') IS NULL
CREATE TABLE core.Mesure
(
    SerieId     int            NOT NULL,
    InstantUtc  datetime2(0)   NOT NULL,   -- début de l'intervalle, toujours en UTC
    Valeur      decimal(19,6)  NULL,
    -- T = temps réel, C = consolidé, D = définitif, P = provisoire, E = estimé
    Qualite     char(1)        NOT NULL CONSTRAINT DF_Mesure_Qualite DEFAULT ('T')
                CONSTRAINT CK_Mesure_Qualite CHECK (Qualite IN ('T', 'C', 'D', 'P', 'E')),
    LotId       int            NOT NULL,   -- le lot qui a écrit cette version
    ValidFrom   datetime2(3)   GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo     datetime2(3)   GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo),
    CONSTRAINT PK_Mesure PRIMARY KEY NONCLUSTERED (SerieId, InstantUtc)
        WITH (DATA_COMPRESSION = PAGE)
        ON ps_MoisUtc (InstantUtc),
    CONSTRAINT FK_Mesure_Serie FOREIGN KEY (SerieId) REFERENCES core.Serie (SerieId)
)
ON ps_MoisUtc (InstantUtc)
WITH (SYSTEM_VERSIONING = ON (
        HISTORY_TABLE = core.MesureHistorique,
        DATA_CONSISTENCY_CHECK = ON,
        HISTORY_RETENTION_PERIOD = INFINITE));
GO

/* 3. Le columnstore cluster ORDONNÉ (SQL Server 2022) : la table devient columnstore */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'core.Mesure') AND name = N'CCI_Mesure')
    CREATE CLUSTERED COLUMNSTORE INDEX CCI_Mesure
        ON core.Mesure
        ORDER (SerieId, InstantUtc)
        ON ps_MoisUtc (InstantUtc);
GO

/* Contrôle : les deux tables, leur lien temporel, leurs index et leurs partitions */
SELECT t.name AS TableCree, t.temporal_type_desc AS Role_,
       OBJECT_NAME(t.history_table_id) AS TableHistorique
FROM sys.tables AS t
WHERE t.object_id IN (OBJECT_ID(N'core.Mesure'), OBJECT_ID(N'core.MesureHistorique'));

SELECT OBJECT_NAME(i.object_id) AS TableCree, i.name AS Index_, i.type_desc AS Type_,
       ds.name AS Stockage, ds.type_desc AS TypeStockage,
       (SELECT COUNT(*) FROM sys.partitions AS p WHERE p.object_id = i.object_id AND p.index_id = i.index_id) AS Partitions
FROM sys.indexes AS i
JOIN sys.data_spaces AS ds ON ds.data_space_id = i.data_space_id
WHERE i.object_id IN (OBJECT_ID(N'core.Mesure'), OBJECT_ID(N'core.MesureHistorique'));

-- colonnes de tri du columnstore ordonné
SELECT c.name AS Colonne, ic.column_store_order_ordinal AS RangTri
FROM sys.index_columns AS ic
JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE ic.object_id = OBJECT_ID(N'core.Mesure') AND ic.column_store_order_ordinal > 0
ORDER BY ic.column_store_order_ordinal;
GO

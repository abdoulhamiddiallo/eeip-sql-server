/* =====================================================================
   EEIP · Script 02 : schémas (les couches de l'entrepôt) et sécurité
   ---------------------------------------------------------------------
   cfg  : configuration pilotée par les données (quoi charger, comment)
   raw  : réponses API brutes, compressées, rejouables
   stg  : zone de transit typée, vidée après chaque intégration
   core : modèle de référence historisé (dimensions + mesures temporelles)
   dq   : règles, contrôles et anomalies de qualité
   mart : couche analytique (agrégats quotidiens, mix, panel annuel)
   api  : procédures de lecture exposées aux consommateurs
   ops  : lots, journal, paramètres, maintenance
   ===================================================================== */
USE EEIP;
GO

DECLARE @schemas TABLE (Nom sysname);
INSERT @schemas VALUES (N'cfg'), (N'raw'), (N'stg'), (N'core'), (N'dq'), (N'mart'), (N'api'), (N'ops');

DECLARE @nom sysname, @sql nvarchar(400);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Nom FROM @schemas;
OPEN c;
FETCH NEXT FROM c INTO @nom;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF SCHEMA_ID(@nom) IS NULL
    BEGIN
        SET @sql = N'CREATE SCHEMA ' + QUOTENAME(@nom) + N' AUTHORIZATION dbo;';
        EXEC sys.sp_executesql @sql;
    END
    FETCH NEXT FROM c INTO @nom;
END
CLOSE c;
DEALLOCATE c;
GO

/* Rôles applicatifs : moindre privilège */
IF DATABASE_PRINCIPAL_ID(N'eeip_chargeur') IS NULL CREATE ROLE eeip_chargeur AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'eeip_lecteur')  IS NULL CREATE ROLE eeip_lecteur  AUTHORIZATION dbo;
GO

-- Le chargeur (programme Python, Agent SQL) exécute des procédures et écrit en transit, rien de plus.
GRANT EXECUTE ON SCHEMA::ops  TO eeip_chargeur;
GRANT EXECUTE ON SCHEMA::raw  TO eeip_chargeur;
GRANT EXECUTE ON SCHEMA::core TO eeip_chargeur;
GRANT EXECUTE ON SCHEMA::cfg  TO eeip_chargeur;
GRANT EXECUTE ON SCHEMA::dq   TO eeip_chargeur;
GRANT EXECUTE ON SCHEMA::mart TO eeip_chargeur;
GRANT SELECT  ON SCHEMA::cfg  TO eeip_chargeur;
GRANT SELECT  ON SCHEMA::core TO eeip_chargeur;
GRANT INSERT, SELECT, DELETE ON SCHEMA::stg TO eeip_chargeur;

-- Le lecteur (Power BI, analystes) : la couche analytique et l'API, rien d'autre.
GRANT SELECT  ON SCHEMA::mart TO eeip_lecteur;
GRANT EXECUTE ON SCHEMA::api  TO eeip_lecteur;
GO

/* Le compte de service de l'Agent SQL Server devient chargeur */
DECLARE @agent sysname = (SELECT TOP (1) CAST(service_account AS sysname) FROM sys.dm_server_services
                          WHERE servicename LIKE N'SQL Server Agent%'), @s nvarchar(600);
IF @agent IS NOT NULL AND SUSER_ID(@agent) IS NOT NULL AND DATABASE_PRINCIPAL_ID(@agent) IS NULL
BEGIN
    SET @s = N'CREATE USER ' + QUOTENAME(@agent) + N' FOR LOGIN ' + QUOTENAME(@agent) + N';';
    EXEC sys.sp_executesql @s;
END
IF @agent IS NOT NULL AND DATABASE_PRINCIPAL_ID(@agent) IS NOT NULL
   AND IS_ROLEMEMBER(N'eeip_chargeur', @agent) = 0
BEGIN
    SET @s = N'ALTER ROLE eeip_chargeur ADD MEMBER ' + QUOTENAME(@agent) + N';';
    EXEC sys.sp_executesql @s;
END
GO

/* Contrôle */
SELECT name AS SchemaCree FROM sys.schemas
WHERE name IN (N'cfg', N'raw', N'stg', N'core', N'dq', N'mart', N'api', N'ops') ORDER BY name;
SELECT r.name AS Role_, m.name AS Membre
FROM sys.database_principals AS r
LEFT JOIN sys.database_role_members AS rm ON rm.role_principal_id = r.principal_id
LEFT JOIN sys.database_principals AS m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE N'eeip%';
GO

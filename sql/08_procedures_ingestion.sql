/* =====================================================================
   EEIP · Script 08 : procédures stockées d'ingestion
   ---------------------------------------------------------------------
   ops.usp_Journal_Ecrire     : écrit une ligne de journal
   ops.usp_Lot_Ouvrir         : ouvre un lot, renvoie son numéro
   ops.usp_Lot_Fermer         : ferme un lot avec son statut et ses compteurs
   cfg.usp_Cfg_Marquer        : note le résultat d'une requête du catalogue
   raw.usp_Payload_Inserer    : range une réponse API compressée
   stg.usp_Transit_Purger     : vide le transit d'une requête (en cas d'échec)
   core.usp_Mesure_Integrer   : le cœur : zones, filières, séries, révisions,
                                insertions, filigrane, compteurs
   Toutes : SET XACT_ABORT ON, TRY/CATCH, transaction courte, journal.
   ===================================================================== */
USE EEIP;
GO

CREATE OR ALTER PROCEDURE ops.usp_Journal_Ecrire
    @LotId    int,
    @Niveau   varchar(6),
    @Etape    nvarchar(100),
    @Message  nvarchar(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT ops.Journal (LotId, Niveau, Etape, Message) VALUES (@LotId, @Niveau, @Etape, @Message);
END
GO

CREATE OR ALTER PROCEDURE ops.usp_Lot_Ouvrir
    @Declencheur  nvarchar(60),
    @Sources      varchar(60),
    @LotId        int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- un lot EN_COURS sans aucune activité depuis 3 heures appartient à un processus interrompu
    -- (chaque paquet intégré écrit dans le journal : un long chargement qui avance n'est jamais touché)
    UPDATE l
    SET Statut = 'ECHEC', Fin = SYSUTCDATETIME(), Message = N'Lot abandonné : processus interrompu'
    FROM ops.Lot AS l
    WHERE l.Statut = 'EN_COURS'
      AND l.Debut < DATEADD(HOUR, -3, SYSUTCDATETIME())
      AND NOT EXISTS (SELECT 1 FROM ops.Journal AS j
                      WHERE j.LotId = l.LotId AND j.Horodatage >= DATEADD(HOUR, -3, SYSUTCDATETIME()));

    INSERT ops.Lot (Declencheur, Sources) VALUES (@Declencheur, @Sources);
    SET @LotId = CAST(SCOPE_IDENTITY() AS int);
    EXEC ops.usp_Journal_Ecrire @LotId, 'INFO', N'Ouverture du lot', @Sources;
END
GO

CREATE OR ALTER PROCEDURE ops.usp_Lot_Fermer
    @LotId                 int,
    @Statut                varchar(12),
    @NbAppels              int = 0,
    @NbReponsesIdentiques  int = 0,
    @Message               nvarchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ops.Lot
    SET Fin = SYSUTCDATETIME(), Statut = @Statut, NbAppels = @NbAppels,
        NbReponsesIdentiques = @NbReponsesIdentiques, Message = @Message
    WHERE LotId = @LotId;
    EXEC ops.usp_Journal_Ecrire @LotId, 'INFO', N'Fermeture du lot', @Statut;
END
GO

CREATE OR ALTER PROCEDURE cfg.usp_Cfg_Marquer
    @CfgId      int,
    @Statut     varchar(12),          -- SUCCES, VIDE, ECHEC, INCHANGE, SANS_CLE
    @Empreinte  binary(32) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE cfg.RequeteACharger
    SET DernierStatut      = @Statut,
        DerniereExtraction = CASE WHEN @Statut IN ('SUCCES', 'INCHANGE', 'VIDE') THEN SYSUTCDATETIME() ELSE DerniereExtraction END,
        DerniereEmpreinte  = CASE WHEN @Statut = 'SUCCES' AND @Empreinte IS NOT NULL THEN @Empreinte ELSE DerniereEmpreinte END
    WHERE CfgId = @CfgId;
END
GO

CREATE OR ALTER PROCEDURE raw.usp_Payload_Inserer
    @LotId         int,
    @CfgId         int,
    @SourceCode    varchar(10),
    @Url           varchar(1000),
    @HttpStatut    smallint,
    @TailleOctets  int,
    @Empreinte     binary(32),
    @ContenuGzip   varbinary(max),
    @PayloadId     bigint OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT raw.Payload (LotId, CfgId, SourceCode, Url, HttpStatut, TailleOctets, Empreinte, ContenuGzip)
    VALUES (@LotId, @CfgId, @SourceCode, LEFT(@Url, 1000), @HttpStatut, @TailleOctets, @Empreinte, @ContenuGzip);
    SET @PayloadId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE stg.usp_Transit_Purger
    @LotId  int,
    @CfgId  int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DELETE stg.Mesure WHERE LotId = @LotId AND (@CfgId IS NULL OR CfgId = @CfgId);
END
GO

/* ---------------------------------------------------------------------
   Intégration des mesures d'UNE requête du catalogue (@CfgId)
   1. codes de zones, filières et contreparties résolus UNE fois par code
      distinct ; zone inconnue -> membre déduit, filière inconnue -> AUTRES
      (jamais de perte de donnée, toujours une anomalie à traiter)
   2. séries inconnues -> créées
   3. typage, mise à l'échelle, dédoublonnage ; un instant au-delà de la
      dernière borne de partition est refusé (la dernière partition doit
      rester vide pour que la fenêtre glissante fonctionne)
   4. révisions : UPDATE des seules valeurs changées, et jamais une
      qualité inférieure sur une supérieure (le temps réel n'écrase pas
      le définitif) ; SQL Server range l'ancienne version dans l'historique
   5. nouveautés : INSERT
   6. statistiques des séries, filigrane du catalogue, compteurs du lot
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE core.usp_Mesure_Integrer
    @LotId  int,
    @CfgId  int
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @SourceId tinyint, @SourceCode varchar(10), @IndicateurId smallint, @Facteur float,
            @lues int = 0, @valides int = 0, @ins int = 0, @rev int = 0, @inch int = 0, @rej int = 0,
            @futur int = 0, @maxInstant datetime2(0), @borneMax datetime2(0), @msg nvarchar(2000);

    SELECT @SourceId     = so.SourceId,
           @SourceCode   = so.Code,
           @IndicateurId = i.IndicateurId,
           @Facteur      = c.FacteurEchelle
    FROM cfg.RequeteACharger AS c
    JOIN core.Source     AS so ON so.Code = c.SourceCode
    JOIN core.Indicateur AS i  ON i.Code  = c.IndicateurCode
    WHERE c.CfgId = @CfgId;

    IF @IndicateurId IS NULL
        THROW 50001, N'CfgId inconnu : vérifie cfg.RequeteACharger.', 1;

    -- dernière borne de la fonction de partition : rien ne doit tomber au-delà
    SELECT @borneMax = MAX(CAST(prv.value AS datetime2(0)))
    FROM sys.partition_range_values AS prv
    JOIN sys.partition_functions AS pf ON pf.function_id = prv.function_id
    WHERE pf.name = N'pf_MoisUtc';

    SELECT @lues = COUNT(*) FROM stg.Mesure WHERE LotId = @LotId AND CfgId = @CfgId;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Une seule intégration à la fois dans toute la base : deux chargements lancés en parallèle
           (ENTSO-E et ODRÉ, par exemple) s'attendent ici au lieu de se bloquer mutuellement. */
        DECLARE @verrou int;
        EXEC @verrou = sys.sp_getapplock @Resource = N'EEIP_Integration', @LockMode = N'Exclusive',
                                         @LockOwner = N'Transaction', @LockTimeout = 1800000;
        IF @verrou < 0 THROW 50010, N'Intégration : attente du verrou EEIP_Integration trop longue (30 minutes).', 1;

        /* 1. Codes distincts du transit, résolus une seule fois */
        CREATE TABLE #code
        (
            Role       char(1)     NOT NULL,     -- Z = zone, F = filière, C = contrepartie
            Code       varchar(60) COLLATE DATABASE_DEFAULT NOT NULL,
            CodeDeduit varchar(12) COLLATE DATABASE_DEFAULT NULL,   -- code court si la zone doit être déduite
            Id         smallint    NULL,
            PRIMARY KEY (Role, Code)
        );
        INSERT #code (Role, Code)
        SELECT DISTINCT 'Z', ZoneCode FROM stg.Mesure WHERE LotId = @LotId AND CfgId = @CfgId
        UNION
        SELECT DISTINCT 'F', FiliereCode FROM stg.Mesure WHERE LotId = @LotId AND CfgId = @CfgId AND FiliereCode IS NOT NULL
        UNION
        SELECT DISTINCT 'C', ContrepartieCode FROM stg.Mesure WHERE LotId = @LotId AND CfgId = @CfgId AND ContrepartieCode IS NOT NULL;

        UPDATE k SET k.Id = r.ZoneId
        FROM #code AS k CROSS APPLY core.fn_ZoneResoudre(@SourceCode, k.Code) AS r
        WHERE k.Role IN ('Z', 'C');

        -- zones et contreparties inconnues : membre déduit (code long -> empreinte courte et stable)
        UPDATE #code
        SET CodeDeduit = CASE WHEN LEN(Code) <= 12 THEN Code
                              ELSE 'X' + LEFT(CONVERT(varchar(64), HASHBYTES('SHA2_256', Code), 2), 11) END
        WHERE Role IN ('Z', 'C') AND Id IS NULL;

        INSERT core.Zone (Code, Nom, TypeZone, Origine)
        SELECT DISTINCT k.CodeDeduit, LEFT(k.Code, 100), 'PAYS', 'DEDUITE'
        FROM #code AS k
        WHERE k.CodeDeduit IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM core.Zone AS z WHERE z.Code = k.CodeDeduit);

        UPDATE k SET k.Id = z.ZoneId
        FROM #code AS k JOIN core.Zone AS z ON z.Code = k.CodeDeduit
        WHERE k.Id IS NULL AND k.CodeDeduit IS NOT NULL;

        UPDATE k SET k.Id = r.FiliereId
        FROM #code AS k CROSS APPLY core.fn_FiliereResoudre(@SourceCode, k.Code) AS r
        WHERE k.Role = 'F';

        INSERT dq.Anomalie (LotId, TypeAnomalie, Detail)
        SELECT @LotId, 'CODE_INCONNU', CONCAT(@SourceCode, N' : filière « ', k.Code, N' » sans alias, rangée dans AUTRES')
        FROM #code AS k WHERE k.Role = 'F' AND k.Id IS NULL;

        UPDATE #code SET Id = (SELECT FiliereId FROM core.Filiere WHERE Code = 'AUTRES')
        WHERE Role = 'F' AND Id IS NULL;

        /* 2. Séries inconnues */
        INSERT core.Serie (SourceId, CodeSource, IndicateurId, ZoneId, FiliereId, ContrepartieId, Granularite, CfgId)
        SELECT @SourceId, k.CodeSource, @IndicateurId, k.ZoneId, k.FiliereId, k.ContrepartieId, k.Granularite, @CfgId
        FROM (
            SELECT st.CodeSource,
                   MAX(kz.Id) AS ZoneId, MAX(kf.Id) AS FiliereId, MAX(kc.Id) AS ContrepartieId,
                   MAX(st.Granularite) AS Granularite
            FROM stg.Mesure AS st
            JOIN #code AS kz ON kz.Role = 'Z' AND kz.Code = st.ZoneCode
            LEFT JOIN #code AS kf ON kf.Role = 'F' AND kf.Code = st.FiliereCode
            LEFT JOIN #code AS kc ON kc.Role = 'C' AND kc.Code = st.ContrepartieCode
            WHERE st.LotId = @LotId AND st.CfgId = @CfgId
            GROUP BY st.CodeSource
        ) AS k
        WHERE NOT EXISTS (SELECT 1 FROM core.Serie AS s WHERE s.SourceId = @SourceId AND s.CodeSource = k.CodeSource);

        /* 3. Typage, mise à l'échelle, dédoublonnage, garde-fou de partition */
        CREATE TABLE #src
        (
            SerieId     int            NOT NULL,
            InstantUtc  datetime2(0)   NOT NULL,
            Valeur      decimal(19,6)  NULL,
            Qualite     char(1)        COLLATE DATABASE_DEFAULT NOT NULL,
            PRIMARY KEY (SerieId, InstantUtc)
        );

        INSERT #src (SerieId, InstantUtc, Valeur, Qualite)
        SELECT d.SerieId, d.InstantUtc, d.Valeur, d.Qualite
        FROM (
            SELECT s.SerieId, st.InstantUtc,
                   CAST(ROUND(st.Valeur * @Facteur, 6) AS decimal(19,6)) AS Valeur,
                   st.Qualite,
                   ROW_NUMBER() OVER (PARTITION BY s.SerieId, st.InstantUtc
                                      ORDER BY CASE st.Qualite WHEN 'D' THEN 1 WHEN 'C' THEN 2 ELSE 3 END) AS Rang
            FROM stg.Mesure AS st
            JOIN core.Serie AS s ON s.SourceId = @SourceId AND s.CodeSource = st.CodeSource
            WHERE st.LotId = @LotId AND st.CfgId = @CfgId
              AND st.InstantUtc < @borneMax
              AND (st.Valeur IS NULL OR ABS(st.Valeur * @Facteur) < 1e12)
        ) AS d
        WHERE d.Rang = 1;

        SET @valides = @@ROWCOUNT;
        SET @rej = @lues - @valides;
        SELECT @futur = COUNT(*) FROM stg.Mesure
        WHERE LotId = @LotId AND CfgId = @CfgId AND InstantUtc >= @borneMax;
        IF @futur > 0
        BEGIN
            SET @msg = CONCAT(N'CfgId ', @CfgId, N' : ', @futur, N' points au-delà de la dernière partition (',
                              CONVERT(char(10), @borneMax, 23), N') refusés : lancer ops.usp_Partition_Etendre');
            EXEC ops.usp_Journal_Ecrire @LotId, 'AVERT', N'core.usp_Mesure_Integrer', @msg;
        END

        /* 4. Révisions : valeur changée ET qualité au moins égale */
        UPDATE m
        SET m.Valeur  = s.Valeur,
            m.Qualite = s.Qualite,
            m.LotId   = @LotId
        FROM core.Mesure AS m
        JOIN #src AS s ON s.SerieId = m.SerieId AND s.InstantUtc = m.InstantUtc
        WHERE (m.Valeur IS DISTINCT FROM s.Valeur OR m.Qualite <> s.Qualite)
          AND CASE s.Qualite WHEN 'D' THEN 3 WHEN 'C' THEN 2 ELSE 1 END
           >= CASE m.Qualite WHEN 'D' THEN 3 WHEN 'C' THEN 2 ELSE 1 END;
        SET @rev = @@ROWCOUNT;

        /* 5. Nouveautés */
        INSERT core.Mesure (SerieId, InstantUtc, Valeur, Qualite, LotId)
        SELECT s.SerieId, s.InstantUtc, s.Valeur, s.Qualite, @LotId
        FROM #src AS s
        WHERE NOT EXISTS (SELECT 1 FROM core.Mesure AS m
                          WHERE m.SerieId = s.SerieId AND m.InstantUtc = s.InstantUtc);
        SET @ins = @@ROWCOUNT;
        SET @inch = @valides - @ins - @rev;

        /* 6. Statistiques des séries touchées (lecture limitée à ces séries : segments sautés) */
        UPDATE se
        SET se.PremierInstant = a.Premier,
            se.DernierInstant = a.Dernier,
            se.NbPoints       = a.Nb,
            se.DerniereMaj    = SYSUTCDATETIME()
        FROM core.Serie AS se
        JOIN (
            SELECT m.SerieId, MIN(m.InstantUtc) AS Premier, MAX(m.InstantUtc) AS Dernier, COUNT_BIG(*) AS Nb
            FROM core.Mesure AS m
            WHERE m.SerieId IN (SELECT DISTINCT SerieId FROM #src)
            GROUP BY m.SerieId
        ) AS a ON a.SerieId = se.SerieId;

        -- filigrane : le programme reprendra à partir d'ici la prochaine fois
        SELECT @maxInstant = MAX(InstantUtc) FROM #src;
        UPDATE cfg.RequeteACharger
        SET DernierInstant = CASE WHEN DernierInstant IS NULL OR @maxInstant > DernierInstant
                                  THEN @maxInstant ELSE DernierInstant END
        WHERE CfgId = @CfgId AND @maxInstant IS NOT NULL;

        UPDATE ops.Lot
        SET NbLignesLues += @lues, NbInserees += @ins, NbRevisees += @rev,
            NbInchangees += @inch, NbRejetees += @rej
        WHERE LotId = @LotId;

        DELETE stg.Mesure WHERE LotId = @LotId AND CfgId = @CfgId;

        COMMIT TRANSACTION;

        SET @msg = CONCAT(N'CfgId ', @CfgId, N' : ', @lues, N' lues, ', @ins, N' insérées, ',
                          @rev, N' révisées, ', @inch, N' inchangées, ', @rej, N' rejetées.');
        EXEC ops.usp_Journal_Ecrire @LotId, 'INFO', N'core.usp_Mesure_Integrer', @msg;

        SELECT @lues AS Lues, @ins AS Inserees, @rev AS Revisees, @inch AS Inchangees, @rej AS Rejetees;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @msg = CONCAT(N'CfgId ', @CfgId, N' : ', ERROR_MESSAGE());
        EXEC ops.usp_Journal_Ecrire @LotId, 'ERREUR', N'core.usp_Mesure_Integrer', @msg;
        THROW;
    END CATCH
END
GO

SELECT s.name + N'.' + p.name AS ProcedureCreee, p.modify_date AS ModifieeLe
FROM sys.procedures AS p JOIN sys.schemas AS s ON s.schema_id = p.schema_id
ORDER BY ProcedureCreee;
GO

# Le modèle sémantique EEIP

Document généré à partir des fichiers TMDL de `powerbi/EEIP.SemanticModel` : **23 tables**, **20 relations**, **261 mesures DAX**. 
Mode Import, culture fr-FR, deux paramètres de connexion (`Serveur`, `Base`). Le modèle ne lit que le schéma `bi` de la base.

![Le modèle sémantique en matrice en bus](diagrammes/png/modele_semantique.png)

## Sommaire

- [Les tables](#les-tables)
- [Les relations](#les-relations)
- [Les mesures, dossier par dossier](#les-mesures-dossier-par-dossier)

## Les tables

| Table | Rôle | Source | Colonnes |
|---|---|---|---:|
| `D_Annee` | Les années du panel Eurostat. | `DAX` | 1  |
| `D_Famille` | Familles de production, avec leur couleur fixe et leur facteur d'émission (g CO2 par kWh). | `bi.vw_Famille` | 8  |
| `D_Heure` | Les 24 heures de la journée, en heure locale. | `DAX` | 2  |
| `D_Jour` | Calendrier en heure locale, depuis le 1er janvier 2023. | `bi.vw_Jour` | 12  |
| `D_Mois` | Les douze mois, avec un libellé court pour les axes. | `DAX` | 4  |
| `D_Source` | Les quatre producteurs de données et leur rang dans le golden record. | `bi.vw_Source` | 5  |
| `D_Voisin` | Le pays de l'autre côté de la frontière électrique. | `bi.vw_Voisin` | 4  |
| `D_Zone` | Pays, zones de prix, régions françaises et agrégats européens. | `bi.vw_Zone` | 13  |
| `F_Carbone` | CO2 estimé par le mix et les facteurs d'émission, face à la mesure publiée par RTE. | `bi.CarboneJour` | 6  |
| `F_Conso` | Consommation quotidienne, pointe et creux, prévision de la veille. | `bi.ConsoJour` | 9  |
| `F_Echange` | Flux physiques par frontière et par sens, rattachés aux pays. | `bi.EchangeJour` | 6  |
| `F_Lot` | Le journal des chargements. | `bi.vw_Lot` | 16  |
| `F_Mix` | Production quotidienne par famille, la meilleure source retenue (golden record). | `bi.MixJour` | 6  |
| `F_Panel` | Eurostat : un pays, une année, depuis 1990. | `bi.vw_Panel` | 17  |
| `F_Partition` | Les partitions mensuelles non vides de core.Mesure. | `bi.vw_Partition` | 7  |
| `F_Prix` | Prix spot du marché à un jour, en €/MWh, par zone de prix et par jour. | `bi.PrixJour` | 7  |
| `F_Profil` | La journée type de chaque mois, heure locale par heure locale. | `bi.ProfilHoraire` | 7  |
| `F_Qualite` | Anomalies écartées par les contrôles qualité. | `bi.vw_Qualite` | 3  |
| `F_Revision` | Valeurs remplacées par une version plus fiable, conservées par les tables temporelles. | `bi.vw_Revision` | 4  |
| `F_Volume` | Séries et valeurs stockées, par source et par indicateur. | `bi.vw_Volume` | 9  |
| `Choix Année` | Table déconnectée : le segment d'année pilote les KPI sans filtrer les courbes. | `DAX` | 1  |
| `Choix Année Europe` | Table déconnectée pour la page Europe (Eurostat, depuis 1990). | `DAX` | 1  |
| `Metrics` | Table des mesures, sans données | `·` | 261 mesures |

<details><summary><b>Toutes les colonnes, table par table</b></summary>

#### D_Annee

| Colonne | Type | Visible |
|---|---|---|
| `Annee` | int64 | oui |

#### D_Famille

| Colonne | Type | Visible |
|---|---|---|
| `Famille` | string | oui |
| `FamilleLibelle` | string | oui |
| `Couleur` | string | non |
| `Ordre` | int64 | non |
| `BasCarbone` | int64 | oui |
| `Renouvelable` | int64 | oui |
| `Fossile` | int64 | oui |
| `FacteurCO2` | double | oui |

#### D_Heure

| Colonne | Type | Visible |
|---|---|---|
| `Heure` | int64 | oui |
| `HeureLibelle` | string | oui |

#### D_Jour

| Colonne | Type | Visible |
|---|---|---|
| `Jour` | dateTime | oui |
| `Annee` | int64 | oui |
| `Trimestre` | int64 | oui |
| `Mois` | int64 | oui |
| `NomMois` | string | oui |
| `AnneeMois` | string | oui |
| `DebutMois` | dateTime | oui |
| `DebutSemaine` | dateTime | oui |
| `JourSemaine` | int64 | non |
| `NomJour` | string | oui |
| `EstOuvre` | int64 | oui |
| `Saison` | string | oui |

#### D_Mois

| Colonne | Type | Visible |
|---|---|---|
| `Mois` | int64 | oui |
| `NomMois` | string | oui |
| `Abrege` | string | oui |
| `Court` | string | oui |

#### D_Source

| Colonne | Type | Visible |
|---|---|---|
| `Source` | string | oui |
| `SourceNom` | string | oui |
| `Licence` | string | oui |
| `Priorite` | int64 | oui |
| `Couleur` | string | non |

#### D_Voisin

| Colonne | Type | Visible |
|---|---|---|
| `Voisin` | string | oui |
| `VoisinNom` | string | oui |
| `VoisinLatitude` | double | oui |
| `VoisinLongitude` | double | oui |

#### D_Zone

| Colonne | Type | Visible |
|---|---|---|
| `Zone` | string | oui |
| `ZoneNom` | string | oui |
| `NomCourt` | string | oui |
| `TypeZone` | string | non |
| `Type` | string | oui |
| `Pays` | string | oui |
| `Latitude` | double | oui |
| `Longitude` | double | oui |
| `EstUE` | int64 | non |
| `Marche` | int64 | non |
| `Prix` | int64 | non |
| `Echanges` | int64 | non |
| `ZonePrix` | string | non |

#### F_Carbone

| Colonne | Type | Visible |
|---|---|---|
| `Zone` | string | non |
| `Jour` | dateTime | non |
| `ProductionMWh` | double | oui |
| `EmissionsT` | double | oui |
| `IntensiteEstimee` | double | oui |
| `IntensiteMesuree` | double | oui |

#### F_Conso

| Colonne | Type | Visible |
|---|---|---|
| `Zone` | string | non |
| `Jour` | dateTime | non |
| `Source` | string | oui |
| `ConsoMWh` | double | oui |
| `PointeMW` | double | oui |
| `CreuxMW` | double | oui |
| `PrevisionMWh` | double | oui |
| `GazMWh` | double | oui |
| `Completude` | double | oui |

#### F_Echange

| Colonne | Type | Visible |
|---|---|---|
| `Pays` | string | non |
| `Voisin` | string | non |
| `Jour` | dateTime | non |
| `ImportMWh` | double | oui |
| `ExportMWh` | double | oui |
| `Source` | string | oui |

#### F_Lot

| Colonne | Type | Visible |
|---|---|---|
| `LotId` | int64 | oui |
| `Declencheur` | string | oui |
| `Sources` | string | oui |
| `Statut` | string | oui |
| `Debut` | dateTime | oui |
| `Fin` | dateTime | oui |
| `JourLot` | dateTime | oui |
| `DureeMinutes` | double | oui |
| `NbAppels` | int64 | oui |
| `NbReponsesIdentiques` | int64 | oui |
| `NbLignesLues` | int64 | oui |
| `NbInserees` | int64 | oui |
| `NbRevisees` | int64 | oui |
| `NbInchangees` | int64 | oui |
| `NbRejetees` | int64 | oui |
| `NbAnomalies` | int64 | oui |

#### F_Mix

| Colonne | Type | Visible |
|---|---|---|
| `Zone` | string | non |
| `Jour` | dateTime | non |
| `Famille` | string | non |
| `Source` | string | non |
| `EnergieMWh` | double | oui |
| `Completude` | double | oui |

#### F_Panel

| Colonne | Type | Visible |
|---|---|---|
| `Zone` | string | non |
| `Annee` | int64 | non |
| `ProductionTWh` | double | oui |
| `PartNucleaire` | double | oui |
| `PartFossile` | double | oui |
| `PartRenouvelableMix` | double | oui |
| `PartRenouvelableOfficielle` | double | oui |
| `ConsoFinaleTWh` | double | oui |
| `ImportsTWh` | double | oui |
| `ExportsTWh` | double | oui |
| `SoldeExportateurTWh` | double | oui |
| `PrixMenages` | double | oui |
| `PrixEntreprises` | double | oui |
| `IntensiteCO2` | double | oui |
| `GesElectriciteMt` | double | oui |
| `GesTotalMt` | double | oui |
| `Dependance` | double | oui |

#### F_Partition

| Colonne | Type | Visible |
|---|---|---|
| `NumeroPartition` | int64 | oui |
| `GroupeDeFichiers` | string | oui |
| `DebutMois` | dateTime | oui |
| `Annee` | int64 | oui |
| `Compression` | string | oui |
| `Lignes` | int64 | oui |
| `Mo` | double | oui |

#### F_Prix

| Colonne | Type | Visible |
|---|---|---|
| `Zone` | string | non |
| `Jour` | dateTime | non |
| `PrixMoyen` | double | oui |
| `PrixMin` | double | oui |
| `PrixMax` | double | oui |
| `HeuresNegatives` | double | oui |
| `Granularite` | string | oui |

#### F_Profil

| Colonne | Type | Visible |
|---|---|---|
| `Zone` | string | non |
| `Annee` | int64 | oui |
| `Mois` | int64 | non |
| `Heure` | int64 | non |
| `Grandeur` | string | oui |
| `Valeur` | double | oui |
| `NbJours` | int64 | oui |

#### F_Qualite

| Colonne | Type | Visible |
|---|---|---|
| `TypeAnomalie` | string | oui |
| `Jour` | dateTime | oui |
| `Nombre` | int64 | oui |

#### F_Revision

| Colonne | Type | Visible |
|---|---|---|
| `Source` | string | non |
| `Indicateur` | string | oui |
| `MoisRevision` | dateTime | oui |
| `Versions` | int64 | oui |

#### F_Volume

| Colonne | Type | Visible |
|---|---|---|
| `Source` | string | non |
| `Indicateur` | string | oui |
| `Theme` | string | oui |
| `Zones` | int64 | oui |
| `Series` | int64 | oui |
| `Valeurs` | int64 | oui |
| `Premier` | dateTime | oui |
| `Dernier` | dateTime | oui |
| `PasMinutes` | int64 | oui |

#### Choix Année

| Colonne | Type | Visible |
|---|---|---|
| `Année` | int64 | oui |

#### Choix Année Europe

| Colonne | Type | Visible |
|---|---|---|
| `Année` | int64 | oui |

</details>

## Les relations

Toutes de plusieurs à un, filtre simple, de la dimension vers le fait.

| De (fait) | Vers (dimension) |
|---|---|
| `F_Mix.Zone` | `D_Zone.Zone` |
| `F_Mix.Jour` | `D_Jour.Jour` |
| `F_Mix.Famille` | `D_Famille.Famille` |
| `F_Mix.Source` | `D_Source.Source` |
| `F_Conso.Zone` | `D_Zone.Zone` |
| `F_Conso.Jour` | `D_Jour.Jour` |
| `F_Prix.Zone` | `D_Zone.Zone` |
| `F_Prix.Jour` | `D_Jour.Jour` |
| `F_Echange.Pays` | `D_Zone.Zone` |
| `F_Echange.Voisin` | `D_Voisin.Voisin` |
| `F_Echange.Jour` | `D_Jour.Jour` |
| `F_Carbone.Zone` | `D_Zone.Zone` |
| `F_Carbone.Jour` | `D_Jour.Jour` |
| `F_Profil.Zone` | `D_Zone.Zone` |
| `F_Profil.Heure` | `D_Heure.Heure` |
| `F_Profil.Mois` | `D_Mois.Mois` |
| `F_Panel.Zone` | `D_Zone.Zone` |
| `F_Panel.Annee` | `D_Annee.Annee` |
| `F_Revision.Source` | `D_Source.Source` |
| `F_Volume.Source` | `D_Source.Source` |

## Les mesures, dossier par dossier

| Dossier | Mesures |
|---|---:|
| [00 Contexte](#00-contexte) | 54 |
| [01 Système électrique](#01-système-électrique) | 32 |
| [02 Journée type](#02-journée-type) | 21 |
| [03 Prix](#03-prix) | 26 |
| [04 Échanges](#04-échanges) | 23 |
| [05 Carbone](#05-carbone) | 36 |
| [06 Régions](#06-régions) | 18 |
| [07 Europe](#07-europe) | 37 |
| [08 Plateforme](#08-plateforme) | 14 |

### 00 Contexte

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Année choisie** | `0` | Année retenue par le segment, sinon la dernière année complète. |
| **Dernier jour** | `dd/MM/yyyy` | Le dernier jour complet : l'année en cours s'arrête là. |
| **Période** | | Un libellé dynamique pour un titre ou une carte. |
| **Zone choisie** | | `SELECTEDVALUE ( D_Zone[NomCourt], "France" )` |
| **Couleur famille** | | Couleur fixe de chaque famille, la même sur toutes les pages. |
| **Consommation (année) · N-1** | `#,0.0" TWh"` | Le même calcul sur la même période de l'année précédente. |
| **Consommation (année) Δ** | `0.0%` | L'écart avec la même période de l'année précédente. |
| **Consommation · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Consommation · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Production (année) · N-1** | `#,0.0" TWh"` | Le même calcul sur la même période de l'année précédente. |
| **Production (année) Δ** | `0.0%` | L'écart avec la même période de l'année précédente. |
| **Part bas carbone (année) · N-1** | `0.0%` | Le même calcul sur la même période de l'année précédente. |
| **Part bas carbone (année) Δ** | `0.0%` | L'écart avec la même période de l'année précédente. |
| **Part renouvelable (année) · N-1** | `0.0%` | Le même calcul sur la même période de l'année précédente. |
| **Part renouvelable (année) Δ** | `0.0%` | L'écart avec la même période de l'année précédente. |
| **Part bas carbone · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Intensité (année) · N-1** | `#,0" g/kWh"` | Le même calcul sur la même période de l'année précédente. |
| **Intensité (année) Δ** | `#,0" g/kWh"` | L'écart avec la même période de l'année précédente. |
| **Intensité · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Solde · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Prix (année) · N-1** | `#,0.0" €"` | Le même calcul sur la même période de l'année précédente. |
| **Prix (année) Δ** | `0.0%` | L'écart avec la même période de l'année précédente. |
| **Prix · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Prix · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Couleur bande carbone** | | De la semaine la plus sobre (vert) à la plus carbonée (rouge) de la période affichée. |
| **Couleur solde voisin** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **h · AUTRES** | `#,0.0" GW"` | Puissance moyenne de autres pour chaque heure locale de la journée type, en GW. |
| **h · PETROLE** | `#,0.0" GW"` | Puissance moyenne de petrole pour chaque heure locale de la journée type, en GW. |
| **h · THERMIQUE** | `#,0.0" GW"` | Puissance moyenne de thermique pour chaque heure locale de la journée type, en GW. |
| **Prix · heure brut** | `#,0.0" €/MWh"` | Prix spot moyen de chaque heure locale sur l'année choisie, avant mise en forme. |
| **Couleur prix horaire** | | De l'heure la moins chère (sarcelle) à la plus chère (corail) du tableau. |
| **Heures négatives (année) · N-1** | `#,0" h"` | Le même calcul sur la même période de l'année précédente. |
| **Heures négatives (année) Δ** | `#,0" h"` | L'écart avec la même période de l'année précédente. |
| **Prix France · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Couleur prix** | | Six classes de prix, de moins de 50 à plus de 110 €/MWh. |
| **Exportations (année) · N-1** | `#,0.0" TWh"` | Le même calcul sur la même période de l'année précédente. |
| **Exportations (année) Δ** | `0.0%` | L'écart avec la même période de l'année précédente. |
| **Importations (année) · N-1** | `#,0.0" TWh"` | Le même calcul sur la même période de l'année précédente. |
| **Importations (année) Δ** | `0.0%` | L'écart avec la même période de l'année précédente. |
| **Exportations · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Exportations · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Importations · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Importations · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Solde exportateur · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Couleur solde** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Couleur voisin** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Intensité France · contexte · couleur** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Couleur intensité** | | Cinq classes : moins de 50, 150, 250, 400 g/kWh, et au-delà. |
| **Couleur couverture** | | Moins de 50 %, 90 %, 110 %, 200 %, et au-delà. |
| **Année Europe** | `0` | `SELECTEDVALUE ( 'Choix Année Europe'[Année], 2024 )` |
| **Couleur prix ménages** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |
| **Fraîcheur** | | Fin du dernier chargement réussi : la plateforme se met à jour toutes les heures. |
| **Couleur source** | | Couleur fixe de chaque source. |
| **Couleur statut lot** | | Une couleur calculée, appliquée par mise en forme conditionnelle. |

<details><summary>Le code DAX des 54 mesures</summary>

```dax
// Année retenue par le segment, sinon la dernière année complète.
'Année choisie' =
    SELECTEDVALUE ( 'Choix Année'[Année], YEAR ( TODAY () ) - 1 )

// Le dernier jour complet : l'année en cours s'arrête là.
'Dernier jour' =
    VAR d = CALCULATE ( MAX ( F_Mix[Jour] ), REMOVEFILTERS () )
    RETURN MIN ( d, TODAY () - 1 )

'Période' =
    VAR a = [Année choisie]
    RETURN IF ( a >= YEAR ( TODAY () ), "du 1er janvier au " & FORMAT ( [Dernier jour], "d mmmm yyyy" ), "année " & FORMAT ( a, "0" ) )

'Zone choisie' =
    SELECTEDVALUE ( D_Zone[NomCourt], "France" )

// Couleur fixe de chaque famille, la même sur toutes les pages.
'Couleur famille' =
    SELECTEDVALUE ( D_Famille[Couleur], "#7F93AA" )

'Consommation (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Consommation], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Consommation (année) Δ' =
    VAR v = [Consommation (année)]
    VAR p = [Consommation (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v / p - 1 )

'Consommation · contexte' =
    VAR d = [Consommation (année) Δ]
    VAR a = [Année choisie]
    VAR ref = IF ( a >= YEAR ( TODAY () ), "même période " & FORMAT ( a - 1, "0" ), FORMAT ( a - 1, "0" ) )
    RETURN "" & IF ( ISBLANK ( d ), "année " & FORMAT ( a, "0" ),
        IF ( d > 0, "▲ ", IF ( d < 0, "▼ ", "■ " ) ) & FORMAT ( d * 100, "+0.0;-0.0;0.0" ) & " %" & " vs " & ref )

'Consommation · contexte · couleur' =
    VAR d = [Consommation (année) Δ] * 1
    RETURN IF ( ISBLANK ( d ) || d = 0, "#CFE3E1", IF ( d > 0, "#4ADE80", "#FF6B5B" ) )

'Production (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Production], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Production (année) Δ' =
    VAR v = [Production (année)]
    VAR p = [Production (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v / p - 1 )

'Part bas carbone (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Part bas carbone], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Part bas carbone (année) Δ' =
    VAR v = [Part bas carbone (année)]
    VAR p = [Part bas carbone (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v - p )

'Part renouvelable (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Part renouvelable], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Part renouvelable (année) Δ' =
    VAR v = [Part renouvelable (année)]
    VAR p = [Part renouvelable (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v - p )

'Part bas carbone · contexte · couleur' =
    VAR d = [Part bas carbone (année) Δ]
    RETURN IF ( ISBLANK ( d ) || d = 0, "#CFE3E1", IF ( d > 0, "#4ADE80", "#FF6B5B" ) )

'Intensité (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Intensité], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Intensité (année) Δ' =
    VAR v = [Intensité (année)]
    VAR p = [Intensité (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v - p )

'Intensité · contexte · couleur' =
    VAR d = [Intensité (année) Δ]
    RETURN IF ( ISBLANK ( d ) || d = 0, "#CFE3E1", IF ( d < 0, "#4ADE80", "#FF6B5B" ) )

'Solde · contexte · couleur' =
    VAR s = [Solde (année)]
    RETURN IF ( ISBLANK ( s ), "#CFE3E1", IF ( s > 0, "#19D3C5", "#FF6B5B" ) )

'Prix (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Prix · zone], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Prix (année) Δ' =
    VAR v = [Prix (année)]
    VAR p = [Prix (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v / p - 1 )

'Prix · contexte' =
    VAR d = [Prix (année) Δ]
    VAR a = [Année choisie]
    VAR ref = IF ( a >= YEAR ( TODAY () ), "même période " & FORMAT ( a - 1, "0" ), FORMAT ( a - 1, "0" ) )
    RETURN "" & IF ( ISBLANK ( d ), "année " & FORMAT ( a, "0" ),
        IF ( d > 0, "▲ ", IF ( d < 0, "▼ ", "■ " ) ) & FORMAT ( d * 100, "+0.0;-0.0;0.0" ) & " %" & " vs " & ref )

'Prix · contexte · couleur' =
    VAR d = [Prix (année) Δ] * -1
    RETURN IF ( ISBLANK ( d ) || d = 0, "#CFE3E1", IF ( d > 0, "#4ADE80", "#FF6B5B" ) )

// De la semaine la plus sobre (vert) à la plus carbonée (rouge) de la période affichée.
'Couleur bande carbone' =
    VAR v = [Intensité]
    VAR t = ALLSELECTED ( D_Jour[DebutSemaine] )
    VAR lo = MINX ( t, [Intensité] )
    VAR hi = MAXX ( t, [Intensité] )
    VAR i = IF ( hi > lo, INT ( 12 * 0.9999 * ( v - lo ) / ( hi - lo ) ), 0 )
    RETURN IF ( ISBLANK ( v ), BLANK (), SWITCH ( i, 0, "#1A9850", 1, "#3DAA5C", 2, "#66BD63", 3, "#8FCB6A", 4, "#A6D96A", 5, "#C7E57E", 6, "#E6F08F", 7, "#FEE08B", 8, "#FDC165", 9, "#FDAE61", 10, "#F46D43", "#D73027" ) )

'Couleur solde voisin' =
    VAR s = [Solde voisin (année)]
    RETURN IF ( ISBLANK ( s ), BLANK (), IF ( s >= 0, "#19D3C5", "#FF6B5B" ) )

'h · AUTRES' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "AUTRES", F_Profil[Annee] = a ), 1000 )

'h · PETROLE' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "PETROLE", F_Profil[Annee] = a ), 1000 )

'h · THERMIQUE' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "THERMIQUE", F_Profil[Annee] = a ), 1000 )

'Prix · heure brut' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "PRIX", F_Profil[Annee] = a ), 1 )

// De l'heure la moins chère (sarcelle) à la plus chère (corail) du tableau.
'Couleur prix horaire' =
    VAR v = [Prix · heure]
    VAR t = CROSSJOIN ( ALL ( D_Heure ), ALL ( D_Mois ) )
    VAR lo = MINX ( t, [Prix · heure] )
    VAR hi = MAXX ( t, [Prix · heure] )
    VAR i = IF ( hi > lo, INT ( 12 * 0.9999 * ( v - lo ) / ( hi - lo ) ), 0 )
    RETURN IF ( ISBLANK ( v ), BLANK (), SWITCH ( i, 0, "#0E6E73", 1, "#11898C", 2, "#19A7A0", 3, "#3FC1A9", 4, "#8ED1A0", 5, "#D9DB8A", 6, "#F7C948", 7, "#F9A44A", 8, "#FB8053", 9, "#FF6B5B", 10, "#E8455A", "#C02D53" ) )

'Heures négatives (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Heures négatives · zone], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Heures négatives (année) Δ' =
    VAR v = [Heures négatives (année)]
    VAR p = [Heures négatives (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v - p )

'Prix France · contexte · couleur' =
    CALCULATE ( [Prix · contexte · couleur], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

// Six classes de prix, de moins de 50 à plus de 110 €/MWh.
'Couleur prix' =
    VAR v = [Prix moyen (année)]
    RETURN IF ( ISBLANK ( v ), BLANK (), SWITCH ( TRUE (), v < 50, "#19D3C5", v < 65, "#7FDBB6", v < 80, "#F7C948", v < 95, "#F9A44A", v < 110, "#FF6B5B", "#D63A55" ) )

'Exportations (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Exportations], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Exportations (année) Δ' =
    VAR v = [Exportations (année)]
    VAR p = [Exportations (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v / p - 1 )

'Importations (année) · N-1' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Importations], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a - 1, 1, 1 ), D_Jour[Jour] <= EDATE ( f, -12 ) )

'Importations (année) Δ' =
    VAR v = [Importations (année)]
    VAR p = [Importations (année) · N-1]
    RETURN IF ( NOT ISBLANK ( v ) && NOT ISBLANK ( p ) && p <> 0, v / p - 1 )

'Exportations · contexte' =
    VAR d = [Exportations (année) Δ]
    VAR a = [Année choisie]
    VAR ref = IF ( a >= YEAR ( TODAY () ), "même période " & FORMAT ( a - 1, "0" ), FORMAT ( a - 1, "0" ) )
    RETURN "" & IF ( ISBLANK ( d ), "année " & FORMAT ( a, "0" ),
        IF ( d > 0, "▲ ", IF ( d < 0, "▼ ", "■ " ) ) & FORMAT ( d * 100, "+0.0;-0.0;0.0" ) & " %" & " vs " & ref )

'Exportations · contexte · couleur' =
    VAR d = [Exportations (année) Δ] * 1
    RETURN IF ( ISBLANK ( d ) || d = 0, "#CFE3E1", IF ( d > 0, "#4ADE80", "#FF6B5B" ) )

'Importations · contexte' =
    VAR d = [Importations (année) Δ]
    VAR a = [Année choisie]
    VAR ref = IF ( a >= YEAR ( TODAY () ), "même période " & FORMAT ( a - 1, "0" ), FORMAT ( a - 1, "0" ) )
    RETURN "" & IF ( ISBLANK ( d ), "année " & FORMAT ( a, "0" ),
        IF ( d > 0, "▲ ", IF ( d < 0, "▼ ", "■ " ) ) & FORMAT ( d * 100, "+0.0;-0.0;0.0" ) & " %" & " vs " & ref )

'Importations · contexte · couleur' =
    VAR d = [Importations (année) Δ] * -1
    RETURN IF ( ISBLANK ( d ) || d = 0, "#CFE3E1", IF ( d > 0, "#4ADE80", "#FF6B5B" ) )

'Solde exportateur · contexte · couleur' =
    VAR s = [Solde exportateur (année)]
    RETURN IF ( ISBLANK ( s ), "#CFE3E1", IF ( s > 0, "#19D3C5", "#FF6B5B" ) )

'Couleur solde' =
    VAR s = [Solde exportateur]
    RETURN IF ( ISBLANK ( s ), BLANK (), IF ( s >= 0, "#19D3C5", "#FF6B5B" ) )

'Couleur voisin' =
    VAR s = [Solde exportateur (année)]
    RETURN IF ( ISBLANK ( s ), BLANK (), IF ( s >= 0, "#19D3C5", "#FF6B5B" ) )

'Intensité France · contexte · couleur' =
    CALCULATE ( [Intensité · contexte · couleur], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

// Cinq classes : moins de 50, 150, 250, 400 g/kWh, et au-delà.
'Couleur intensité' =
    VAR v = [Intensité estimée (année)]
    RETURN IF ( ISBLANK ( v ), BLANK (), SWITCH ( TRUE (), v < 50, "#4ADE80", v < 150, "#C7E57E", v < 250, "#F7C948", v < 400, "#F9A44A", "#FF6B5B" ) )

// Moins de 50 %, 90 %, 110 %, 200 %, et au-delà.
'Couleur couverture' =
    VAR v = [Couverture (année)]
    RETURN IF ( ISBLANK ( v ), BLANK (), SWITCH ( TRUE (), v < 0.5, "#FF6B5B", v < 0.9, "#F7C948", v < 1.1, "#CFE3E1", v < 2, "#19D3C5", "#4ADE80" ) )

'Année Europe' =
    SELECTEDVALUE ( 'Choix Année Europe'[Année], 2024 )

'Couleur prix ménages' =
    VAR z = SELECTEDVALUE ( D_Zone[Zone] )
    RETURN IF ( z = "FR", "#F7C948", "#2E7F86" )

// Fin du dernier chargement réussi : la plateforme se met à jour toutes les heures.
'Fraîcheur' =
    VAR d = CALCULATE ( MAX ( F_Lot[Fin] ), REMOVEFILTERS (), F_Lot[Statut] IN { "SUCCES", "PARTIEL" } )
    RETURN "●  Données à jour : " & FORMAT ( d, "dd/mm/yyyy" ) & " à " & FORMAT ( d, "HH" ) & " h " & FORMAT ( d, "nn" )

// Couleur fixe de chaque source.
'Couleur source' =
    SELECTEDVALUE ( D_Source[Couleur], "#9DB8B6" )

'Couleur statut lot' =
    SWITCH ( SELECTEDVALUE ( F_Lot[Statut] ), "SUCCES", "#4ADE80", "TERMINE", "#4ADE80", "PARTIEL", "#F7C948", "EN_COURS", "#5AA9FF",
        "ECHEC", "#FF8A8A", "#FFFFFF" )

```

</details>

### 01 Système électrique

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Production** | `#,0.0" TWh"` | Production nette, en TWh, hors stockage (le pompage est une consommation). |
| **Consommation** | `#,0.0" TWh"` | Consommation intérieure, en TWh. |
| **Production bas carbone** | `#,0.0" TWh"` | `CALCULATE ( [Production], KEEPFILTERS ( D_Famille[BasCarbone] = 1 ) )` |
| **Production renouvelable** | `#,0.0" TWh"` | `CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Renouvelable] = 1 ) )` |
| **Part bas carbone** | `0.0%` | `DIVIDE ( [Production bas carbone], [Production] )` |
| **Part renouvelable** | `0.0%` | `DIVIDE ( [Production renouvelable], [Production] )` |
| **Nucléaire** | `#,0.0` | Production de la famille nucléaire, en TWh, masquée après le dernier jour complet : une série du graphique de mix. |
| **Hydraulique** | `#,0.0` | Production de la famille hydraulique, en TWh, masquée après le dernier jour complet : une série du graphique de mix. |
| **Éolien** | `#,0.0` | Production de la famille éolien, en TWh, masquée après le dernier jour complet : une série du graphique de mix. |
| **Solaire** | `#,0.0` | Production de la famille solaire, en TWh, masquée après le dernier jour complet : une série du graphique de mix. |
| **Bioénergies** | `#,0.0` | Production de la famille bioénergies, en TWh, masquée après le dernier jour complet : une série du graphique de mix. |
| **Gaz** | `#,0.0` | Production de la famille gaz, en TWh, masquée après le dernier jour complet : une série du graphique de mix. |
| **Charbon** | `#,0.0` | Production de la famille charbon, en TWh, masquée après le dernier jour complet : une série du graphique de mix. |
| **Fioul et autres** | `#,0.0` | Production de la famille fioul et autres, en TWh, masquée après le dernier jour complet : une série du graphique de mix. |
| **Thermique fossile** | `#,0.0` | `CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] IN { "GAZ", "CHARBON", "PETROLE", "THERMIQUE" } ) )` |
| **Consommation (année)** | `#,0.0" TWh"` | Consommation sur l'année choisie, jusqu'au dernier jour complet. |
| **Production (année)** | `#,0.0" TWh"` | Production sur l'année choisie, jusqu'au dernier jour complet. |
| **Production · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Part bas carbone (année)** | `0.0%` | Part bas carbone sur l'année choisie, jusqu'au dernier jour complet. |
| **Part renouvelable (année)** | `0.0%` | Part renouvelable sur l'année choisie, jusqu'au dernier jour complet. |
| **Part bas carbone · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Nucléaire (année)** | `#,0.0` | Nucléaire sur l'année choisie, jusqu'au dernier jour complet. |
| **Hydraulique (année)** | `#,0.0` | Hydraulique sur l'année choisie, jusqu'au dernier jour complet. |
| **Éolien (année)** | `#,0.0` | Éolien sur l'année choisie, jusqu'au dernier jour complet. |
| **Solaire (année)** | `#,0.0` | Solaire sur l'année choisie, jusqu'au dernier jour complet. |
| **Bioénergies (année)** | `#,0.0` | Bioénergies sur l'année choisie, jusqu'au dernier jour complet. |
| **Gaz (année)** | `#,0.0` | Gaz sur l'année choisie, jusqu'au dernier jour complet. |
| **Charbon (année)** | `#,0.0` | Charbon sur l'année choisie, jusqu'au dernier jour complet. |
| **Fioul et autres (année)** | `#,0.0` | Fioul et autres sur l'année choisie, jusqu'au dernier jour complet. |
| **Mix (année)** | `#,0.0" TWh"` | Mix sur l'année choisie, jusqu'au dernier jour complet. |
| **Bande carbone** | `0` | `IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), IF ( NOT ISBLANK ( [Intensité] ), 1 ) )` |
| **Consommation · courbe** | `#,0.0` | Consommation, masquée après le dernier jour complet pour que la courbe ne plonge pas. |

<details><summary>Le code DAX des 32 mesures</summary>

```dax
// Production nette, en TWh, hors stockage (le pompage est une consommation).
Production =
    DIVIDE ( CALCULATE ( SUM ( F_Mix[EnergieMWh] ), KEEPFILTERS ( NOT D_Famille[Famille] IN { "STOCKAGE", "VECTEURS" } ) ), 1000000 )

// Consommation intérieure, en TWh.
Consommation =
    DIVIDE ( SUM ( F_Conso[ConsoMWh] ), 1000000 )

'Production bas carbone' =
    CALCULATE ( [Production], KEEPFILTERS ( D_Famille[BasCarbone] = 1 ) )

'Production renouvelable' =
    CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Renouvelable] = 1 ) )

'Part bas carbone' =
    DIVIDE ( [Production bas carbone], [Production] )

'Part renouvelable' =
    DIVIDE ( [Production renouvelable], [Production] )

'Nucléaire' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] = "NUCLEAIRE" ) ) )

Hydraulique =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] = "HYDRAULIQUE" ) ) )

'Éolien' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] = "EOLIEN" ) ) )

Solaire =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] = "SOLAIRE" ) ) )

'Bioénergies' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] = "BIOENERGIES" ) ) )

Gaz =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] = "GAZ" ) ) )

Charbon =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] = "CHARBON" ) ) )

'Fioul et autres' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] IN { "AUTRES", "PETROLE", "THERMIQUE" } ) ) )

'Thermique fossile' =
    CALCULATE ( [Production], KEEPFILTERS ( D_Famille[Famille] IN { "GAZ", "CHARBON", "PETROLE", "THERMIQUE" } ) )

'Consommation (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Consommation], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Production (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Production], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Production · contexte' =
    VAR r = [Part renouvelable (année)]
    RETURN IF ( ISBLANK ( r ), " ", "dont " & FORMAT ( r, "0 %" ) & " renouvelable" )

'Part bas carbone (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Part bas carbone], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Part renouvelable (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Part renouvelable], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Part bas carbone · contexte' =
    VAR d = [Part bas carbone (année) Δ] * 100
    VAR a = [Année choisie]
    RETURN IF ( ISBLANK ( d ), "nucléaire et renouvelables",
        IF ( d > 0, "▲ ", IF ( d < 0, "▼ ", "■ " ) ) & FORMAT ( d, "+0.0;-0.0;0.0" ) & " pt vs " & FORMAT ( a - 1, "0" ) )

'Nucléaire (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "NUCLEAIRE" ) )

'Hydraulique (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "HYDRAULIQUE" ) )

'Éolien (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "EOLIEN" ) )

'Solaire (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "SOLAIRE" ) )

'Bioénergies (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "BIOENERGIES" ) )

'Gaz (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "GAZ" ) )

'Charbon (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "CHARBON" ) )

'Fioul et autres (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] IN { "AUTRES", "PETROLE", "THERMIQUE" } ) )

'Mix (année)' =
    [Production (année)]

'Bande carbone' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), IF ( NOT ISBLANK ( [Intensité] ), 1 ) )

'Consommation · courbe' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), [Consommation] )

```

</details>

### 02 Journée type

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Nucléaire · heure** | `#,0.0" GW"` | Nucléaire, heure locale par heure locale, pour la journée type. |
| **Hydraulique · heure** | `#,0.0" GW"` | Hydraulique, heure locale par heure locale, pour la journée type. |
| **Éolien · heure** | `#,0.0" GW"` | Éolien, heure locale par heure locale, pour la journée type. |
| **Solaire · heure** | `#,0.0" GW"` | Solaire, heure locale par heure locale, pour la journée type. |
| **Bioénergies · heure** | `#,0.0" GW"` | Bioénergies, heure locale par heure locale, pour la journée type. |
| **Gaz · heure** | `#,0.0" GW"` | Gaz, heure locale par heure locale, pour la journée type. |
| **Charbon · heure** | `#,0.0" GW"` | Charbon, heure locale par heure locale, pour la journée type. |
| **Fioul et autres · heure** | `#,0.0" GW"` | Fioul et autres, heure locale par heure locale, pour la journée type. |
| **Consommation · heure** | `#,0.0" GW"` | Puissance moyenne appelée à cette heure, mois choisis de l'année choisie. |
| **Prix · heure** | `#,0.0" €/MWh"` | Prix spot moyen à cette heure, zone de marché du système choisi. |
| **CO2 · heure** | `#,0" g/kWh"` | CO2, heure locale par heure locale, pour la journée type. |
| **Pointe (année)** | `#,0.0" GW"` | Le quart d'heure le plus chargé de l'année. |
| **Pointe · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Creux (année)** | `#,0.0" GW"` | Le quart d'heure le moins chargé de l'année. |
| **Creux · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Heure la moins chère** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Heure la moins chère · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Heure la plus chère** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Heure la plus chère · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Précision prévision** | | Écart moyen, jour par jour, entre la prévision de la veille et la consommation réalisée (France). |
| **Précision prévision · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |

<details><summary>Le code DAX des 21 mesures</summary>

```dax
'Nucléaire · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "NUCLEAIRE", F_Profil[Annee] = a ), 1000 )

'Hydraulique · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "HYDRAULIQUE", F_Profil[Annee] = a ), 1000 )

'Éolien · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "EOLIEN", F_Profil[Annee] = a ), 1000 )

'Solaire · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "SOLAIRE", F_Profil[Annee] = a ), 1000 )

'Bioénergies · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "BIOENERGIES", F_Profil[Annee] = a ), 1000 )

'Gaz · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "GAZ", F_Profil[Annee] = a ), 1000 )

'Charbon · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "CHARBON", F_Profil[Annee] = a ), 1000 )

'Fioul et autres · heure' =
    [h · AUTRES] + [h · PETROLE] + [h · THERMIQUE]

// Puissance moyenne appelée à cette heure, mois choisis de l'année choisie.
'Consommation · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "CONSO", F_Profil[Annee] = a ), 1000 )

// Prix spot moyen à cette heure, zone de marché du système choisi.
'Prix · heure' =
    CALCULATE ( [Prix · heure brut], REMOVEFILTERS ( D_Zone ), TREATAS ( VALUES ( D_Zone[ZonePrix] ), D_Zone[Zone] ) )

'CO2 · heure' =
    VAR a = [Année choisie]
    RETURN DIVIDE ( CALCULATE ( AVERAGE ( F_Profil[Valeur] ), F_Profil[Grandeur] = "CO2", F_Profil[Annee] = a ), 1 )

// Le quart d'heure le plus chargé de l'année.
'Pointe (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN DIVIDE ( CALCULATE ( MAX ( F_Conso[PointeMW] ), REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f ), 1000 )

'Pointe · contexte' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    VAR t = CALCULATETABLE ( F_Conso, REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )
    VAR r = TOPN ( 1, t, F_Conso[PointeMW], DESC )
    VAR d = MAXX ( r, F_Conso[Jour] )
    RETURN IF ( ISBLANK ( d ), " ", "le " & FORMAT ( d, "dddd d mmmm" ) )

// Le quart d'heure le moins chargé de l'année.
'Creux (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN DIVIDE ( CALCULATE ( MIN ( F_Conso[CreuxMW] ), REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f,
        F_Conso[Completude] >= 0.95, F_Conso[CreuxMW] > 0 ), 1000 )

'Creux · contexte' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    VAR t = CALCULATETABLE ( FILTER ( F_Conso, F_Conso[Completude] >= 0.95 && F_Conso[CreuxMW] > 0 ),
        REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )
    VAR r = TOPN ( 1, t, F_Conso[CreuxMW], ASC )
    VAR d = MAXX ( r, F_Conso[Jour] )
    RETURN IF ( ISBLANK ( d ), " ", "le " & FORMAT ( d, "dddd d mmmm" ) )

'Heure la moins chère' =
    VAR t = ADDCOLUMNS ( ALL ( D_Heure[Heure] ), "p", [Prix · heure] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [p] ) ), [p], ASC )
    VAR h = MAXX ( r, D_Heure[Heure] )
    RETURN IF ( ISBLANK ( h ), "-", FORMAT ( h, "0" ) & " h - " & FORMAT ( h + 1, "0" ) & " h" )

'Heure la moins chère · contexte' =
    VAR t = ADDCOLUMNS ( ALL ( D_Heure[Heure] ), "p", [Prix · heure] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [p] ) ), [p], ASC )
    VAR p = MAXX ( r, [p] )
    RETURN IF ( ISBLANK ( p ), " ", FORMAT ( p, "0" ) & " €/MWh" )

'Heure la plus chère' =
    VAR t = ADDCOLUMNS ( ALL ( D_Heure[Heure] ), "p", [Prix · heure] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [p] ) ), [p], DESC )
    VAR h = MAXX ( r, D_Heure[Heure] )
    RETURN IF ( ISBLANK ( h ), "-", FORMAT ( h, "0" ) & " h - " & FORMAT ( h + 1, "0" ) & " h" )

'Heure la plus chère · contexte' =
    VAR t = ADDCOLUMNS ( ALL ( D_Heure[Heure] ), "p", [Prix · heure] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [p] ) ), [p], DESC )
    VAR p = MAXX ( r, [p] )
    RETURN IF ( ISBLANK ( p ), " ", FORMAT ( p, "0" ) & " €/MWh" )

// Écart moyen, jour par jour, entre la prévision de la veille et la consommation réalisée (France).
'Précision prévision' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    VAR t = CALCULATETABLE ( FILTER ( F_Conso, NOT ISBLANK ( F_Conso[PrevisionMWh] ) && F_Conso[Completude] >= 0.95 ),
        REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )
    VAR e = DIVIDE ( SUMX ( t, ABS ( F_Conso[PrevisionMWh] - F_Conso[ConsoMWh] ) ), SUMX ( t, F_Conso[ConsoMWh] ) )
    RETURN IF ( ISBLANK ( e ), "-", FORMAT ( e, "0.0 %" ) )

'Précision prévision · contexte' =
    IF ( [Précision prévision] = "-", "France seulement", "écart quotidien moyen" )

```

</details>

### 03 Prix

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Prix moyen** | `#,0.0" €/MWh"` | Prix spot moyen du marché à un jour (base), en €/MWh. |
| **Heures négatives** | `#,0" h"` | Heures où le prix spot est passé sous zéro. |
| **Prix · zone** | `#,0.0" €/MWh"` | Le prix de la zone de marché du système choisi. |
| **Heures négatives · zone** | `#,0" h"` | Heures négatives, lu dans la zone de marché du système choisi (TREATAS). |
| **Prix (année)** | `#,0.0" €"` | Prix sur l'année choisie, jusqu'au dernier jour complet. |
| **Heures négatives (année)** | `#,0" h"` | Heures négatives sur l'année choisie, jusqu'au dernier jour complet. |
| **Heures négatives · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Prix moyen (année)** | `#,0.0" €/MWh"` | Prix moyen sur l'année choisie, jusqu'au dernier jour complet. |
| **Prix France (année)** | `#,0.0" €"` | Prix France sur l'année choisie, jusqu'au dernier jour complet. |
| **Prix France · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Zone la moins chère** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Zone la moins chère · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Zone la plus chère** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Zone la plus chère · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Écart France-Allemagne** | `+#,0.0" €";-#,0.0" €";0" €"` | Prix moyen de la France moins celui de l'Allemagne (zone DE-LU), sur l'année choisie. |
| **Écart France-Allemagne · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Heures négatives France (année)** | `#,0" h"` | Heures négatives France sur l'année choisie, jusqu'au dernier jour complet. |
| **Heures négatives France · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Pic horaire France (année)** | `#,0" €"` | Pic horaire France sur l'année choisie, jusqu'au dernier jour complet. |
| **Pic horaire France · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Heures négatives zone (année)** | `#,0` | Heures négatives zone sur l'année choisie, jusqu'au dernier jour complet. |
| **Prix · France** | `#,0.0" €/MWh"` | Prix pour : France, une courbe de comparaison. |
| **Prix · Allemagne** | `#,0.0" €/MWh"` | Prix pour : Allemagne, une courbe de comparaison. |
| **Prix · Espagne** | `#,0.0" €/MWh"` | Prix pour : Espagne, une courbe de comparaison. |
| **Prix · Italie du Nord** | `#,0.0" €/MWh"` | Prix pour : Italie du Nord, une courbe de comparaison. |
| **Prix · Pologne** | `#,0.0" €/MWh"` | Prix pour : Pologne, une courbe de comparaison. |

<details><summary>Le code DAX des 26 mesures</summary>

```dax
// Prix spot moyen du marché à un jour (base), en €/MWh.
'Prix moyen' =
    AVERAGE ( F_Prix[PrixMoyen] )

// Heures où le prix spot est passé sous zéro.
'Heures négatives' =
    SUM ( F_Prix[HeuresNegatives] )

// Le prix de la zone de marché du système choisi.
'Prix · zone' =
    CALCULATE ( [Prix moyen], REMOVEFILTERS ( D_Zone ), TREATAS ( VALUES ( D_Zone[ZonePrix] ), D_Zone[Zone] ) )

'Heures négatives · zone' =
    CALCULATE ( [Heures négatives], REMOVEFILTERS ( D_Zone ), TREATAS ( VALUES ( D_Zone[ZonePrix] ), D_Zone[Zone] ) )

'Prix (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Prix · zone], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Heures négatives (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Heures négatives · zone], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Heures négatives · contexte' =
    VAR d = [Heures négatives (année) Δ]
    VAR a = [Année choisie]
    RETURN IF ( ISBLANK ( d ), "prix spot sous zéro",
        IF ( d > 0, "▲ +", IF ( d < 0, "▼ ", "■ " ) ) & FORMAT ( d, "#,0;-#,0;0" ) & " h vs " & FORMAT ( a - 1, "0" ) )

'Prix moyen (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Prix moyen], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Prix France (année)' =
    CALCULATE ( [Prix (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'Prix France · contexte' =
    CALCULATE ( [Prix · contexte], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'Zone la moins chère' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[Prix] = 1 ), "v", [Prix moyen (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], ASC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Zone la moins chère · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[Prix] = 1 ), "v", [Prix moyen (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], ASC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0.0" ) & " €/MWh" )

'Zone la plus chère' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[Prix] = 1 ), "v", [Prix moyen (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Zone la plus chère · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[Prix] = 1 ), "v", [Prix moyen (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0.0" ) & " €/MWh" )

'Écart France-Allemagne' =
    VAR fr = CALCULATE ( [Prix moyen (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )
    VAR de = CALCULATE ( [Prix moyen (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "DE_LU" )
    RETURN IF ( NOT ISBLANK ( fr ) && NOT ISBLANK ( de ), fr - de )

'Écart France-Allemagne · contexte' =
    VAR d = [Écart France-Allemagne]
    RETURN IF ( ISBLANK ( d ), " ", IF ( d < 0, "France moins chère", "France plus chère" ) )

'Heures négatives France (année)' =
    CALCULATE ( [Heures négatives (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'Heures négatives France · contexte' =
    CALCULATE ( [Heures négatives · contexte], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'Pic horaire France (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( MAX ( F_Prix[PrixMax] ), REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f,
        REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'Pic horaire France · contexte' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    VAR t = CALCULATETABLE ( F_Prix, REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f,
        REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )
    VAR d = MAXX ( TOPN ( 1, t, F_Prix[PrixMax], DESC ), F_Prix[Jour] )
    RETURN IF ( ISBLANK ( d ), " ", "le " & FORMAT ( d, "d mmmm" ) )

'Heures négatives zone (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Heures négatives], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Prix · France' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Prix moyen], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" ) )

'Prix · Allemagne' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Prix moyen], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "DE_LU" ) )

'Prix · Espagne' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Prix moyen], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "ES" ) )

'Prix · Italie du Nord' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Prix moyen], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "IT_NORD" ) )

'Prix · Pologne' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Prix moyen], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "PL" ) )

```

</details>

### 04 Échanges

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Exportations** | `#,0.0" TWh"` | `DIVIDE ( SUM ( F_Echange[ExportMWh] ), 1000000 )` |
| **Importations** | `#,0.0" TWh"` | `DIVIDE ( SUM ( F_Echange[ImportMWh] ), 1000000 )` |
| **Solde exportateur** | `+#,0.0" TWh";-#,0.0" TWh";0" TWh"` | Positif : le pays vend plus d'électricité à ses voisins qu'il ne leur en achète. |
| **Volume échangé** | `#,0.0" TWh"` | `[Exportations] + [Importations]` |
| **Solde · zone** | `+#,0.0" TWh";-#,0.0" TWh";0" TWh"` | Solde, lu dans la zone de marché du système choisi (TREATAS). |
| **Exportations · zone** | `#,0.0" TWh"` | Exportations, lu dans la zone de marché du système choisi (TREATAS). |
| **Importations · zone** | `#,0.0" TWh"` | Importations, lu dans la zone de marché du système choisi (TREATAS). |
| **Solde (année)** | `+#,0.0" TWh";-#,0.0" TWh";0" TWh"` | Solde sur l'année choisie, jusqu'au dernier jour complet. |
| **Solde · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Solde voisin (année)** | `+#,0.0;-#,0.0;0` | Solde voisin sur l'année choisie, jusqu'au dernier jour complet. |
| **Exportations (année)** | `#,0.0" TWh"` | Exportations sur l'année choisie, jusqu'au dernier jour complet. |
| **Importations (année)** | `#,0.0" TWh"` | Importations sur l'année choisie, jusqu'au dernier jour complet. |
| **Solde exportateur (année)** | `+#,0.0" TWh";-#,0.0" TWh";0" TWh"` | Solde exportateur sur l'année choisie, jusqu'au dernier jour complet. |
| **Volume échangé (année)** | `#,0.0" TWh"` | Volume échangé sur l'année choisie, jusqu'au dernier jour complet. |
| **Solde exportateur · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Consommation pays (année)** | `#,0.0" TWh"` | Consommation pays sur l'année choisie, jusqu'au dernier jour complet. |
| **Premier client** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Premier client · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Premier fournisseur** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Premier fournisseur · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Jours exportateurs** | `0%` | Part des jours où le pays a exporté plus qu'il n'a importé. |
| **Jours exportateurs · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Solde mensuel** | `+#,0.0;-#,0.0;0` | Solde exportateur des mois complets. |

<details><summary>Le code DAX des 23 mesures</summary>

```dax
Exportations =
    DIVIDE ( SUM ( F_Echange[ExportMWh] ), 1000000 )

Importations =
    DIVIDE ( SUM ( F_Echange[ImportMWh] ), 1000000 )

// Positif : le pays vend plus d'électricité à ses voisins qu'il ne leur en achète.
'Solde exportateur' =
    VAR e = [Exportations]
    VAR i = [Importations]
    RETURN IF ( ISBLANK ( e ) && ISBLANK ( i ), BLANK (), e - i )

'Volume échangé' =
    [Exportations] + [Importations]

'Solde · zone' =
    CALCULATE ( [Solde exportateur], REMOVEFILTERS ( D_Zone ), TREATAS ( VALUES ( D_Zone[Pays] ), D_Zone[Zone] ) )

'Exportations · zone' =
    CALCULATE ( [Exportations], REMOVEFILTERS ( D_Zone ), TREATAS ( VALUES ( D_Zone[Pays] ), D_Zone[Zone] ) )

'Importations · zone' =
    CALCULATE ( [Importations], REMOVEFILTERS ( D_Zone ), TREATAS ( VALUES ( D_Zone[Pays] ), D_Zone[Zone] ) )

'Solde (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Solde · zone], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Solde · contexte' =
    VAR s = [Solde (année)]
    RETURN IF ( ISBLANK ( s ), "pas de frontière chargée", IF ( s > 0, "exportateur net", "importateur net" ) )

'Solde voisin (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Solde · zone], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Exportations (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Exportations], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Importations (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Importations], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Solde exportateur (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Solde exportateur], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Volume échangé (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Volume échangé], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Solde exportateur · contexte' =
    VAR s = [Solde exportateur (année)]
    VAR c = [Consommation pays (année)]
    RETURN IF ( ISBLANK ( s ), " ", IF ( s > 0, "exportateur net", "importateur net" )
        & IF ( ISBLANK ( c ), "", " · " & FORMAT ( ABS ( s ) / c, "0 %" ) ) )

'Consommation pays (année)' =
    VAR z = SELECTCOLUMNS ( VALUES ( D_Zone[Zone] ), "z", IF ( D_Zone[Zone] = "DE", "DE_LU", D_Zone[Zone] ) )
    RETURN CALCULATE ( [Consommation (année)], REMOVEFILTERS ( D_Zone ), TREATAS ( z, D_Zone[Zone] ) )

'Premier client' =
    VAR t = ADDCOLUMNS ( ALL ( D_Voisin[VoisinNom] ), "v", [Exportations (année)] )
    VAR r = TOPN ( 1, FILTER ( t, [v] > 0 ), [v], DESC )
    RETURN COALESCE ( MAXX ( r, D_Voisin[VoisinNom] ), "-" )

'Premier client · contexte' =
    VAR t = ADDCOLUMNS ( ALL ( D_Voisin[VoisinNom] ), "v", [Exportations (année)] )
    VAR r = TOPN ( 1, FILTER ( t, [v] > 0 ), [v], DESC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0.0" ) & " TWh exportés" )

'Premier fournisseur' =
    VAR t = ADDCOLUMNS ( ALL ( D_Voisin[VoisinNom] ), "v", [Importations (année)] )
    VAR r = TOPN ( 1, FILTER ( t, [v] > 0 ), [v], DESC )
    RETURN COALESCE ( MAXX ( r, D_Voisin[VoisinNom] ), "-" )

'Premier fournisseur · contexte' =
    VAR t = ADDCOLUMNS ( ALL ( D_Voisin[VoisinNom] ), "v", [Importations (année)] )
    VAR r = TOPN ( 1, FILTER ( t, [v] > 0 ), [v], DESC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0.0" ) & " TWh importés" )

// Part des jours où le pays a exporté plus qu'il n'a importé.
'Jours exportateurs' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    VAR j = CALCULATETABLE ( VALUES ( D_Jour[Jour] ), REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )
    VAR t = FILTER ( ADDCOLUMNS ( j, "s", CALCULATE ( [Solde exportateur] ) ), NOT ISBLANK ( [s] ) )
    RETURN DIVIDE ( COUNTROWS ( FILTER ( t, [s] > 0 ) ), COUNTROWS ( t ) )

'Jours exportateurs · contexte' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    VAR j = CALCULATETABLE ( VALUES ( D_Jour[Jour] ), REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )
    VAR t = FILTER ( ADDCOLUMNS ( j, "s", CALCULATE ( [Solde exportateur] ) ), NOT ISBLANK ( [s] ) )
    VAR n = COUNTROWS ( FILTER ( t, [s] > 0 ) )
    RETURN IF ( ISBLANK ( n ), " ", FORMAT ( n, "0" ) & " jours sur " & FORMAT ( COUNTROWS ( t ), "0" ) )

// Solde exportateur des mois complets.
'Solde mensuel' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), [Solde exportateur] )

```

</details>

### 05 Carbone

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Intensité estimée** | `#,0" g/kWh"` | Grammes de CO2 par kWh produit, calculés par le mix du jour et le facteur d'émission de chaque famille. |
| **Intensité mesurée** | `#,0" g/kWh"` | Publiée par RTE (éCO2mix), France seulement. |
| **Intensité** | `#,0" g/kWh"` | La mesure de RTE quand elle existe, sinon l'estimation. |
| **Émissions** | `#,0.0" Mt"` | Millions de tonnes de CO2. |
| **Intensité (année)** | `#,0" g/kWh"` | Intensité sur l'année choisie, jusqu'au dernier jour complet. |
| **Intensité estimée (année)** | `#,0" g/kWh"` | Intensité estimée sur l'année choisie, jusqu'au dernier jour complet. |
| **Intensité mesurée (année)** | `#,0" g/kWh"` | Intensité mesurée sur l'année choisie, jusqu'au dernier jour complet. |
| **Intensité · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Intensité France (année)** | `#,0" g/kWh"` | Intensité France sur l'année choisie, jusqu'au dernier jour complet. |
| **Intensité France · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Intensité Europe (année)** | `#,0" g/kWh"` | Les 11 systèmes ensemble : émissions totales divisées par la production totale. |
| **Intensité Europe · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Plus carboné** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Plus carboné · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Moins carboné** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Moins carboné · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Émissions (année)** | `#,0" Mt"` | Émissions sur l'année choisie, jusqu'au dernier jour complet. |
| **Émissions Europe (année)** | `#,0" Mt"` | Émissions Europe sur l'année choisie, jusqu'au dernier jour complet. |
| **Émissions Europe · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Écart estimé-mesuré** | `+#,0.0" g";-#,0.0" g";0" g"` | Le modèle EEIP (mix x facteurs) face à la mesure officielle de RTE, sur la France. |
| **Écart estimé-mesuré · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Nucléaire · part (année)** | `0%` | Nucléaire · part sur l'année choisie, jusqu'au dernier jour complet. |
| **Hydraulique · part (année)** | `0%` | Hydraulique · part sur l'année choisie, jusqu'au dernier jour complet. |
| **Éolien · part (année)** | `0%` | Éolien · part sur l'année choisie, jusqu'au dernier jour complet. |
| **Solaire · part (année)** | `0%` | Solaire · part sur l'année choisie, jusqu'au dernier jour complet. |
| **Bioénergies · part (année)** | `0%` | Bioénergies · part sur l'année choisie, jusqu'au dernier jour complet. |
| **Gaz · part (année)** | `0%` | Gaz · part sur l'année choisie, jusqu'au dernier jour complet. |
| **Charbon · part (année)** | `0%` | Charbon · part sur l'année choisie, jusqu'au dernier jour complet. |
| **Fioul et autres · part (année)** | `0%` | Fioul et autres · part sur l'année choisie, jusqu'au dernier jour complet. |
| **CO2 · France** | `#,0" g/kWh"` | CO2 pour : France, une courbe de comparaison. |
| **CO2 · Allemagne** | `#,0" g/kWh"` | CO2 pour : Allemagne, une courbe de comparaison. |
| **CO2 · Pologne** | `#,0" g/kWh"` | CO2 pour : Pologne, une courbe de comparaison. |
| **CO2 · Italie** | `#,0" g/kWh"` | Intensité carbone estimée de l'Italie, une courbe de comparaison. |
| **CO2 · Espagne** | `#,0" g/kWh"` | CO2 pour : Espagne, une courbe de comparaison. |
| **France · estimée** | `#,0" g/kWh"` | Intensité carbone de la France estimée par EEIP (mix × facteurs d'émission). |
| **France · mesurée** | `#,0" g/kWh"` | Intensité carbone de la France publiée par RTE dans éCO2mix, pour contrôler l'estimation. |

<details><summary>Le code DAX des 36 mesures</summary>

```dax
// Grammes de CO2 par kWh produit, calculés par le mix du jour et le facteur d'émission de chaque famille.
'Intensité estimée' =
    DIVIDE ( SUM ( F_Carbone[EmissionsT] ) * 1000, SUM ( F_Carbone[ProductionMWh] ) )

// Publiée par RTE (éCO2mix), France seulement.
'Intensité mesurée' =
    AVERAGE ( F_Carbone[IntensiteMesuree] )

// La mesure de RTE quand elle existe, sinon l'estimation.
'Intensité' =
    VAR me = [Intensité mesurée]
    RETURN IF ( NOT ISBLANK ( me ), me, [Intensité estimée] )

// Millions de tonnes de CO2.
'Émissions' =
    DIVIDE ( SUM ( F_Carbone[EmissionsT] ), 1000000 )

'Intensité (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Intensité], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Intensité estimée (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Intensité estimée], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Intensité mesurée (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Intensité mesurée], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Intensité · contexte' =
    VAR d = [Intensité (année) Δ]
    VAR src = IF ( NOT ISBLANK ( [Intensité mesurée (année)] ), "RTE", "estimée" )
    RETURN IF ( ISBLANK ( d ), src, IF ( d > 0, "▲ ", IF ( d < 0, "▼ ", "■ " ) ) & FORMAT ( d, "+0;-0;0" ) & " g · " & src )

'Intensité France (année)' =
    CALCULATE ( [Intensité (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'Intensité France · contexte' =
    CALCULATE ( [Intensité · contexte], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

// Les 11 systèmes ensemble : émissions totales divisées par la production totale.
'Intensité Europe (année)' =
    CALCULATE ( [Intensité estimée (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Marche] = 1 )

'Intensité Europe · contexte' =
    VAR fr = [Intensité France (année)]
    VAR eu = [Intensité Europe (année)]
    RETURN IF ( ISBLANK ( eu ) || ISBLANK ( fr ) || fr = 0, "11 systèmes électriques", FORMAT ( eu / fr, "0" ) & " × la France" )

'Plus carboné' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[Marche] = 1 ), "v", [Intensité estimée (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Plus carboné · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[Marche] = 1 ), "v", [Intensité estimée (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0" ) & " g/kWh" )

'Moins carboné' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[Marche] = 1 ), "v", [Intensité estimée (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], ASC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Moins carboné · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[Marche] = 1 ), "v", [Intensité estimée (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], ASC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0" ) & " g/kWh" )

'Émissions (année)' =
    VAR a = [Année choisie]
    VAR f = IF ( a >= YEAR ( TODAY () ), [Dernier jour], DATE ( a, 12, 31 ) )
    RETURN CALCULATE ( [Émissions], REMOVEFILTERS ( D_Jour ), D_Jour[Jour] >= DATE ( a, 1, 1 ), D_Jour[Jour] <= f )

'Émissions Europe (année)' =
    CALCULATE ( [Émissions (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Marche] = 1 )

'Émissions Europe · contexte' =
    VAR fr = CALCULATE ( [Émissions (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )
    VAR eu = [Émissions Europe (année)]
    RETURN IF ( ISBLANK ( eu ), " ", "dont " & FORMAT ( DIVIDE ( fr, eu ), "0 %" ) & " France" )

// Le modèle EEIP (mix x facteurs) face à la mesure officielle de RTE, sur la France.
'Écart estimé-mesuré' =
    VAR e = CALCULATE ( [Intensité estimée (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )
    VAR me = CALCULATE ( [Intensité mesurée (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )
    RETURN IF ( NOT ISBLANK ( e ) && NOT ISBLANK ( me ), e - me )

'Écart estimé-mesuré · contexte' =
    "EEIP moins RTE"

'Nucléaire · part (année)' =
    DIVIDE ( [Nucléaire (année)], [Production (année)] )

'Hydraulique · part (année)' =
    DIVIDE ( [Hydraulique (année)], [Production (année)] )

'Éolien · part (année)' =
    DIVIDE ( [Éolien (année)], [Production (année)] )

'Solaire · part (année)' =
    DIVIDE ( [Solaire (année)], [Production (année)] )

'Bioénergies · part (année)' =
    DIVIDE ( [Bioénergies (année)], [Production (année)] )

'Gaz · part (année)' =
    DIVIDE ( [Gaz (année)], [Production (année)] )

'Charbon · part (année)' =
    DIVIDE ( [Charbon (année)], [Production (année)] )

'Fioul et autres · part (année)' =
    DIVIDE ( [Fioul et autres (année)], [Production (année)] )

'CO2 · France' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Intensité estimée], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" ) )

'CO2 · Allemagne' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Intensité estimée], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "DE_LU" ) )

'CO2 · Pologne' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Intensité estimée], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "PL" ) )

'CO2 · Italie' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Intensité estimée], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "IT" ) )

'CO2 · Espagne' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Intensité estimée], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "ES" ) )

'France · estimée' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Intensité estimée], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" ) )

'France · mesurée' =
    IF ( MAX ( D_Jour[Jour] ) > [Dernier jour], BLANK (), CALCULATE ( [Intensité mesurée], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" ) )

```

</details>

### 06 Régions

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Production régions (année)** | `#,0.0" TWh"` | Production régions sur l'année choisie, jusqu'au dernier jour complet. |
| **Consommation régions (année)** | `#,0.0" TWh"` | Consommation régions sur l'année choisie, jusqu'au dernier jour complet. |
| **Production régions · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Consommation régions · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Couverture (année)** | `0%` | Production de la région divisée par sa consommation : au-delà de 100 %, la région exporte vers ses voisines. |
| **Région la plus exportatrice** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Région la plus exportatrice · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Région la plus dépendante** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Région la plus dépendante · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Premier producteur** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Premier producteur · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Solaire · régions** | `#,0.0` | `CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "SOLAIRE" ) )` |
| **Premier solaire** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Premier solaire · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Thermique fossile (année)** | `#,0.0` | Thermique fossile sur l'année choisie, jusqu'au dernier jour complet. |
| **Part nucléaire (année)** | `0%` | Part nucléaire sur l'année choisie, jusqu'au dernier jour complet. |
| **Production (année) · TWh** | `#,0.0` | Production · TWh sur l'année choisie, jusqu'au dernier jour complet. |
| **Consommation (année) · TWh** | `#,0.0` | Consommation · TWh sur l'année choisie, jusqu'au dernier jour complet. |

<details><summary>Le code DAX des 18 mesures</summary>

```dax
'Production régions (année)' =
    CALCULATE ( [Production (année)], REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" )

'Consommation régions (année)' =
    CALCULATE ( [Consommation (année)], REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" )

'Production régions · contexte' =
    VAR p = [Production régions (année)]
    VAR c = [Consommation régions (année)]
    RETURN IF ( ISBLANK ( p ) || ISBLANK ( c ), "ODRÉ, depuis 2025", FORMAT ( p / c, "0 %" ) & " de la conso" )

'Consommation régions · contexte' =
    "12 régions métropolitaines"

// Production de la région divisée par sa consommation : au-delà de 100 %, la région exporte vers ses voisines.
'Couverture (année)' =
    DIVIDE ( [Production (année)], [Consommation (année)] )

'Région la plus exportatrice' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" ), "v", [Couverture (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Région la plus exportatrice · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" ), "v", [Couverture (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0 %" ) & " de sa consommation" )

'Région la plus dépendante' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" ), "v", [Couverture (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], ASC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Région la plus dépendante · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" ), "v", [Couverture (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], ASC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0 %" ) & " de sa consommation" )

'Premier producteur' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" ), "v", [Production (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Premier producteur · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" ), "v", [Production (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0.0" ) & " TWh produits" )

'Solaire · régions' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] = "SOLAIRE" ) )

'Premier solaire' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" ), "v", [Solaire · régions] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Premier solaire · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "REGION" ), "v", [Solaire · régions] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0.0" ) & " TWh de solaire" )

'Thermique fossile (année)' =
    CALCULATE ( [Production (année)], KEEPFILTERS ( D_Famille[Famille] IN { "GAZ", "CHARBON", "PETROLE", "THERMIQUE" } ) )

'Part nucléaire (année)' =
    DIVIDE ( [Nucléaire (année)], [Production (année)] )

'Production (année) · TWh' =
    [Production (année)]

'Consommation (année) · TWh' =
    [Consommation (année)]

```

</details>

### 07 Europe

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Renouvelables officielles** | `0.0" %"` | Part des renouvelables dans la consommation d'électricité, méthode de la directive. |
| **Renouvelables officielles (année)** | `0.0" %"` | Renouvelables officielles sur l'année choisie, jusqu'au dernier jour complet. |
| **Prix ménages** | `0.000" €"` | Prix du kWh pour les ménages, toutes taxes comprises. |
| **Prix ménages (année)** | `0.000" €"` | Prix ménages sur l'année choisie, jusqu'au dernier jour complet. |
| **Prix entreprises** | `0.000" €"` | Prix du kWh pour les entreprises, hors TVA. |
| **Prix entreprises (année)** | `0.000" €"` | Prix entreprises sur l'année choisie, jusqu'au dernier jour complet. |
| **GES électricité** | `#,0" Mt"` | Émissions de la production publique d'électricité et de chaleur. |
| **GES électricité (année)** | `#,0" Mt"` | GES électricité sur l'année choisie, jusqu'au dernier jour complet. |
| **Dépendance** | `0.0" %"` | Part de l'énergie importée. |
| **Dépendance (année)** | `0.0" %"` | Dépendance sur l'année choisie, jusqu'au dernier jour complet. |
| **Intensité Eurostat** | `#,0" g/kWh"` | Estimée par EEIP à partir du mix mensuel Eurostat. |
| **Intensité Eurostat (année)** | `#,0" g/kWh"` | Intensité Eurostat sur l'année choisie, jusqu'au dernier jour complet. |
| **Part nucléaire Eurostat** | `0%` | `AVERAGE ( F_Panel[PartNucleaire] )` |
| **Part nucléaire Eurostat (année)** | `0%` | Part nucléaire Eurostat sur l'année choisie, jusqu'au dernier jour complet. |
| **Renouvelables UE** | `0.0" %"` | `CALCULATE ( [Renouvelables officielles (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )` |
| **Renouvelables UE · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **GES électricité UE** | `#,0" Mt"` | `CALCULATE ( [GES électricité (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )` |
| **GES électricité UE · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Dépendance UE** | `0.0" %"` | `CALCULATE ( [Dépendance (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )` |
| **Dépendance UE · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Prix ménages France** | `0.000" €"` | `CALCULATE ( [Prix ménages (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )` |
| **Prix ménages France · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Prix ménages le plus élevé** | | Un classement calculé dans la mesure, sans filtre de visuel. |
| **Prix ménages le plus élevé · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Intensité Eurostat France** | `#,0" g/kWh"` | `CALCULATE ( [Intensité Eurostat (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )` |
| **Intensité Eurostat France · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Renouvelables · Union européenne** | `0.0" %"` | Renouvelables pour : Union européenne, une courbe de comparaison. |
| **GES indice · Union européenne** | `0` | GES indice pour : Union européenne, une courbe de comparaison. |
| **Renouvelables · France** | `0.0" %"` | Renouvelables pour : France, une courbe de comparaison. |
| **GES indice · France** | `0` | GES indice pour : France, une courbe de comparaison. |
| **Renouvelables · Allemagne** | `0.0" %"` | Renouvelables pour : Allemagne, une courbe de comparaison. |
| **GES indice · Allemagne** | `0` | GES indice pour : Allemagne, une courbe de comparaison. |
| **Renouvelables · Espagne** | `0.0" %"` | Renouvelables pour : Espagne, une courbe de comparaison. |
| **GES indice · Espagne** | `0` | GES indice pour : Espagne, une courbe de comparaison. |
| **Renouvelables · Pologne** | `0.0" %"` | Renouvelables pour : Pologne, une courbe de comparaison. |
| **GES indice · Pologne** | `0` | GES indice pour : Pologne, une courbe de comparaison. |
| **Prix ménages classement** | `0.000` | `IF ( SELECTEDVALUE ( D_Zone[TypeZone] ) = "PAYS", [Prix ménages (année)] )` |

<details><summary>Le code DAX des 37 mesures</summary>

```dax
// Part des renouvelables dans la consommation d'électricité, méthode de la directive.
'Renouvelables officielles' =
    AVERAGE ( F_Panel[PartRenouvelableOfficielle] )

'Renouvelables officielles (année)' =
    VAR a = [Année Europe]
    RETURN CALCULATE ( [Renouvelables officielles], REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = a )

// Prix du kWh pour les ménages, toutes taxes comprises.
'Prix ménages' =
    AVERAGE ( F_Panel[PrixMenages] )

'Prix ménages (année)' =
    VAR a = [Année Europe]
    RETURN CALCULATE ( [Prix ménages], REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = a )

// Prix du kWh pour les entreprises, hors TVA.
'Prix entreprises' =
    AVERAGE ( F_Panel[PrixEntreprises] )

'Prix entreprises (année)' =
    VAR a = [Année Europe]
    RETURN CALCULATE ( [Prix entreprises], REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = a )

// Émissions de la production publique d'électricité et de chaleur.
'GES électricité' =
    AVERAGE ( F_Panel[GesElectriciteMt] )

'GES électricité (année)' =
    VAR a = [Année Europe]
    RETURN CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = a )

// Part de l'énergie importée.
'Dépendance' =
    AVERAGE ( F_Panel[Dependance] )

'Dépendance (année)' =
    VAR a = [Année Europe]
    RETURN CALCULATE ( [Dépendance], REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = a )

// Estimée par EEIP à partir du mix mensuel Eurostat.
'Intensité Eurostat' =
    AVERAGE ( F_Panel[IntensiteCO2] )

'Intensité Eurostat (année)' =
    VAR a = [Année Europe]
    RETURN CALCULATE ( [Intensité Eurostat], REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = a )

'Part nucléaire Eurostat' =
    AVERAGE ( F_Panel[PartNucleaire] )

'Part nucléaire Eurostat (année)' =
    VAR a = [Année Europe]
    RETURN CALCULATE ( [Part nucléaire Eurostat], REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = a )

'Renouvelables UE' =
    CALCULATE ( [Renouvelables officielles (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )

'Renouvelables UE · contexte' =
    VAR a = [Année Europe]
    VAR v = [Renouvelables UE]
    VAR p = CALCULATE ( [Renouvelables officielles], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27", REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = 2004 )
    RETURN IF ( ISBLANK ( v ) || ISBLANK ( p ), "de l'électricité consommée", FORMAT ( p, "0" ) & " % en 2004" )

'GES électricité UE' =
    CALCULATE ( [GES électricité (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )

'GES électricité UE · contexte' =
    VAR v = [GES électricité UE]
    VAR p = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27", REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = 1990 )
    RETURN IF ( ISBLANK ( v ) || ISBLANK ( p ), "pas encore publié", FORMAT ( v / p - 1, "+0 %;-0 %" ) & " depuis 1990" )

'Dépendance UE' =
    CALCULATE ( [Dépendance (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )

'Dépendance UE · contexte' =
    VAR fr = CALCULATE ( [Dépendance (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )
    RETURN IF ( ISBLANK ( fr ), "énergie importée", "France : " & FORMAT ( fr, "0" ) & " %" )

'Prix ménages France' =
    CALCULATE ( [Prix ménages (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'Prix ménages France · contexte' =
    VAR u = CALCULATE ( [Prix ménages (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )
    RETURN IF ( ISBLANK ( u ), "par kWh, TTC", "par kWh, UE : " & FORMAT ( u, "0.000" ) & " €" )

'Prix ménages le plus élevé' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "PAYS" ), "v", [Prix ménages (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    RETURN COALESCE ( MAXX ( r, D_Zone[NomCourt] ), "-" )

'Prix ménages le plus élevé · contexte' =
    VAR t = ADDCOLUMNS ( CALCULATETABLE ( VALUES ( D_Zone[NomCourt] ), REMOVEFILTERS ( D_Zone ), D_Zone[TypeZone] = "PAYS" ), "v", [Prix ménages (année)] )
    VAR r = TOPN ( 1, FILTER ( t, NOT ISBLANK ( [v] ) ), [v], DESC )
    VAR v = MAXX ( r, [v] )
    RETURN IF ( ISBLANK ( v ), " ", FORMAT ( v, "0.000" ) & " € par kWh" )

'Intensité Eurostat France' =
    CALCULATE ( [Intensité Eurostat (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'Intensité Eurostat France · contexte' =
    VAR u = CALCULATE ( [Intensité Eurostat (année)], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )
    RETURN IF ( ISBLANK ( u ), "mix Eurostat", "UE : " & FORMAT ( u, "0" ) & " g/kWh" )

'Renouvelables · Union européenne' =
    CALCULATE ( [Renouvelables officielles], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )

'GES indice · Union européenne' =
    VAR v = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27" )
    VAR b = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "EU27", REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = 1990 )
    RETURN DIVIDE ( v, b ) * 100

'Renouvelables · France' =
    CALCULATE ( [Renouvelables officielles], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )

'GES indice · France' =
    VAR v = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR" )
    VAR b = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "FR", REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = 1990 )
    RETURN DIVIDE ( v, b ) * 100

'Renouvelables · Allemagne' =
    CALCULATE ( [Renouvelables officielles], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "DE" )

'GES indice · Allemagne' =
    VAR v = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "DE" )
    VAR b = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "DE", REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = 1990 )
    RETURN DIVIDE ( v, b ) * 100

'Renouvelables · Espagne' =
    CALCULATE ( [Renouvelables officielles], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "ES" )

'GES indice · Espagne' =
    VAR v = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "ES" )
    VAR b = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "ES", REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = 1990 )
    RETURN DIVIDE ( v, b ) * 100

'Renouvelables · Pologne' =
    CALCULATE ( [Renouvelables officielles], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "PL" )

'GES indice · Pologne' =
    VAR v = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "PL" )
    VAR b = CALCULATE ( [GES électricité], REMOVEFILTERS ( D_Zone ), D_Zone[Zone] = "PL", REMOVEFILTERS ( D_Annee ), D_Annee[Annee] = 1990 )
    RETURN DIVIDE ( v, b ) * 100

'Prix ménages classement' =
    IF ( SELECTEDVALUE ( D_Zone[TypeZone] ) = "PAYS", [Prix ménages (année)] )

```

</details>

### 08 Plateforme

| Mesure | Format | Ce qu'elle calcule |
|---|---|---|
| **Valeurs** | `#,0` | `SUM ( F_Volume[Valeurs] )` |
| **Valeurs · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Séries** | `#,0` | `SUM ( F_Volume[Series] )` |
| **Sources · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Profondeur** | `0` | `YEAR ( MIN ( F_Volume[Premier] ) )` |
| **Profondeur · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Lots** | `#,0` | `COUNTROWS ( F_Lot )` |
| **Lots · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Révisions** | `#,0` | Valeurs remplacées par une version plus fiable (temps réel, puis consolidé, puis définitif), gardées par les tables temporelles. |
| **Révisions · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Partitions** | `#,0` | `COUNTROWS ( F_Partition )` |
| **Partitions · contexte** | | Le texte sous la carte : l'évolution face à l'année précédente, ou une précision. |
| **Lignes stockées** | `#,0` | `SUM ( F_Partition[Lignes] )` |
| **Anomalies qualité** | `#,0` | `SUM ( F_Qualite[Nombre] ) + 0` |

<details><summary>Le code DAX des 14 mesures</summary>

```dax
Valeurs =
    SUM ( F_Volume[Valeurs] )

'Valeurs · contexte' =
    VAR n = SUM ( F_Volume[Series] )
    RETURN "dans " & FORMAT ( n, "#,0" ) & " séries"

'Séries' =
    SUM ( F_Volume[Series] )

'Sources · contexte' =
    FORMAT ( DISTINCTCOUNT ( F_Volume[Source] ), "0" ) & " producteurs"

Profondeur =
    YEAR ( MIN ( F_Volume[Premier] ) )

'Profondeur · contexte' =
    "jusqu'au " & FORMAT ( MAX ( F_Volume[Dernier] ), "dd/mm/yyyy" )

Lots =
    COUNTROWS ( F_Lot )

'Lots · contexte' =
    VAR ok = CALCULATE ( COUNTROWS ( F_Lot ), F_Lot[Statut] IN { "SUCCES", "TERMINE" } )
    RETURN FORMAT ( ok + 0, "#,0" ) & " réussis"

// Valeurs remplacées par une version plus fiable (temps réel, puis consolidé, puis définitif), gardées par les tables temporelles.
'Révisions' =
    SUM ( F_Revision[Versions] ) + 0

'Révisions · contexte' =
    "versions historisées"

Partitions =
    COUNTROWS ( F_Partition )

'Partitions · contexte' =
    VAR g = SUM ( F_Partition[Mo] )
    RETURN FORMAT ( g, "#,0" ) & " Mo compressés"

'Lignes stockées' =
    SUM ( F_Partition[Lignes] )

'Anomalies qualité' =
    SUM ( F_Qualite[Nombre] ) + 0

```

</details>

"""
EEIP · European Energy Intelligence Platform
Programme d'ingestion : interroge Open Data Réseaux Énergies (éCO2mix, gaz),
ENTSO-E, RTE et Eurostat, range chaque réponse brute compressée dans
SQL Server, normalise les mesures en UTC, puis laisse les procédures
stockées les intégrer, les historiser et les contrôler.

Utilisation (depuis C:\\EEIP, environnement virtuel activé) :
    python ingestion\\eeip_ingestion.py --tester ODRE          (diagnostic, n'écrit rien)
    python ingestion\\eeip_ingestion.py --sources ODRE
    python ingestion\\eeip_ingestion.py --sources ENTSOE --limite-fenetres 2
    python ingestion\\eeip_ingestion.py                       (les 4 sources)
    python ingestion\\eeip_ingestion.py --forcer              (même si rien n'a changé)
Codes de sortie : 0 succès ou succès partiel, 1 échec.
"""
from __future__ import annotations

import argparse
import base64
import configparser
import datetime as dt
import gzip
import hashlib
import json
import logging
import re
import sys
import time
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from zoneinfo import ZoneInfo

import pyodbc
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

RACINE = Path(__file__).resolve().parent.parent          # C:\EEIP
FICHIER_CONFIG = RACINE / "config" / "eeip.ini"
DOSSIER_LOGS = RACINE / "logs"

URL_ODRE = "https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets"
URL_ENTSOE = "https://web-api.tp.entsoe.eu/api"
URL_RTE = "https://digital.iservices.rte-france.com/open_api"
URL_RTE_JETON = "https://digital.iservices.rte-france.com/token/oauth/"
URL_EUROSTAT = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"

SOURCES = ("ODRE", "ENTSOE", "RTE", "EUROSTAT")
TAILLE_PAQUET = 20_000
PARIS = ZoneInfo("Europe/Paris")

log = logging.getLogger("eeip")


# ---------------------------------------------------------------------------
# Structures
# ---------------------------------------------------------------------------
@dataclass
class Requete:
    """Une ligne du catalogue cfg.RequeteACharger, enrichie des codes EIC."""
    cfg_id: int
    source: str
    jeu: str
    params: dict
    indicateur: str
    zone: str | None
    zone_eic: str | None
    contrepartie: str | None
    contrepartie_eic: str | None
    debut: dt.date
    fenetre: int
    recouvrement: int
    dernier_instant: dt.datetime | None
    derniere_empreinte: bytes | None

    @property
    def nom(self) -> str:
        return f"{self.source} {self.jeu} {self.indicateur} {self.zone or ''} {self.contrepartie or ''}".strip()


@dataclass
class Reponse:
    url: str            # URL sans aucun secret
    statut: int
    texte: str


class AucuneDonnee(Exception):
    """La source a répondu, mais sans aucune mesure."""


class SansCle(Exception):
    """La source exige une clé absente de config\\eeip.ini."""


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------
def configurer_journal() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")   # accents lisibles, même sous l'Agent SQL
    DOSSIER_LOGS.mkdir(parents=True, exist_ok=True)
    fichier = DOSSIER_LOGS / f"eeip_{dt.date.today():%Y%m%d}.log"
    format_ = logging.Formatter("%(asctime)s | %(levelname)-7s | %(message)s", "%Y-%m-%d %H:%M:%S")
    log.setLevel(logging.INFO)
    for gestionnaire in (logging.StreamHandler(sys.stdout), logging.FileHandler(fichier, encoding="utf-8")):
        gestionnaire.setFormatter(format_)
        log.addHandler(gestionnaire)


def lire_config() -> configparser.ConfigParser:
    if not FICHIER_CONFIG.exists():
        raise SystemExit(f"Fichier de configuration introuvable : {FICHIER_CONFIG}")
    config = configparser.ConfigParser(interpolation=None)
    config.read(FICHIER_CONFIG, encoding="utf-8")
    return config


def secret(config, section: str, cle: str) -> str | None:
    valeur = config.get(section, cle, fallback="").strip()
    return None if not valeur or valeur.startswith("COLLE") else valeur


def ouvrir_connexion(config) -> pyodbc.Connection:
    sql = config["sqlserver"]
    chaine = (
        f"DRIVER={{{sql.get('pilote', 'ODBC Driver 18 for SQL Server')}}};"
        f"SERVER={sql['serveur']};DATABASE={sql.get('base', 'EEIP')};"
        "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;APP=EEIP-Ingestion"
    )
    return pyodbc.connect(chaine, autocommit=True)


def ouvrir_session_http(config) -> requests.Session:
    session = requests.Session()
    reessais = Retry(total=4, backoff_factor=2, status_forcelist=(429, 500, 502, 503, 504, 599),
                     allowed_methods=("GET", "POST"), respect_retry_after_header=True)
    session.mount("https://", HTTPAdapter(max_retries=reessais))
    session.headers["User-Agent"] = config.get("http", "user_agent", fallback="EEIP-Ingestion/1.0")
    return session


def masquer(url: str) -> str:
    """Jamais de secret dans le journal ni dans raw.Payload."""
    return re.sub(r"(securityToken=)[^&]+", r"\1***", url)


def appeler(session, url: str, params=None, entetes=None, delai: int = 120) -> requests.Response:
    reponse = session.get(url, params=params, headers=entetes, timeout=delai)
    log.info("    GET %s -> %s (%s octets)", masquer(reponse.url)[:170], reponse.status_code, len(reponse.content))
    return reponse


def nombre(valeur) -> float | None:
    if valeur is None or isinstance(valeur, bool):
        return None
    if isinstance(valeur, (int, float)):
        return float(valeur)
    texte = str(valeur).strip().replace(",", ".")
    if texte in ("", "NaN", "nan", "NA", "ND", "-", ":"):
        return None
    try:
        return float(texte)
    except ValueError:
        return None


def en_utc(texte: str) -> dt.datetime | None:
    """ISO 8601 avec décalage (2026-11-07T10:15:00+01:00, ...Z) -> datetime UTC naïf, à la seconde."""
    if not texte:
        return None
    t = str(texte).strip().replace("Z", "+00:00")
    try:
        d = dt.datetime.fromisoformat(t)
    except ValueError:
        return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=dt.timezone.utc)
    return d.astimezone(dt.timezone.utc).replace(tzinfo=None, microsecond=0)


def granularite(minutes: float) -> str | None:
    return {15: "PT15M", 30: "PT30M", 60: "PT60M", 1440: "P1D"}.get(int(round(minutes)))


def debut_de_jour(instant: dt.datetime) -> dt.datetime:
    """Les données journalières à annuelles commencent à minuit LOCAL (23:00 UTC la veille) : on ramène au jour."""
    return (instant + dt.timedelta(hours=12)).replace(hour=0, minute=0, second=0)


def maintenant_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc).replace(tzinfo=None, microsecond=0)


def empreinte(textes: list[str]) -> bytes:
    h = hashlib.sha256()
    for t in textes:
        h.update(t.encode("utf-8"))
    return h.digest()


# ---------------------------------------------------------------------------
# Fenêtres de temps : toutes les requêtes d'un même jeu de données qui en
# sont au même point partagent les mêmes appels (cache).
# ---------------------------------------------------------------------------
def fenetres(req: Requete, fin: dt.datetime) -> list[tuple[dt.datetime, dt.datetime]]:
    """Premier chargement : grille fixe depuis DebutHistorique. Ensuite : depuis le filigrane moins le
    recouvrement, ramené à minuit, pour relire les révisions récentes et partager les appels."""
    origine = dt.datetime.combine(req.debut, dt.time())
    if req.source == "EUROSTAT":
        return [(origine, fin)]
    a = origine
    if req.dernier_instant is not None:
        a = max(origine, (req.dernier_instant - dt.timedelta(days=req.recouvrement))
                .replace(hour=0, minute=0, second=0, microsecond=0))
    jours = req.fenetre
    if req.source == "ENTSOE":
        jours = min(jours, 365)                    # ENTSO-E refuse toute période de plus d'un an
    pas = dt.timedelta(days=jours)
    liste = []
    while a < fin:
        liste.append((a, min(a + pas, fin)))
        a += pas
    return liste


# ---------------------------------------------------------------------------
# Extraction : une fonction par producteur, qui renvoie la réponse brute.
# ---------------------------------------------------------------------------
class Extracteur:
    def __init__(self, session, config, zones_eurostat: set[str]):
        self.session = session
        self.config = config
        self.zones_eurostat = zones_eurostat
        self.cache: dict[str, Reponse] = {}
        self.jeton_rte: tuple[str, float] | None = None

    def _depuis_cache(self, cle: str) -> Reponse | None:
        return self.cache.get(cle)

    def _memoriser(self, cle: str, rep: Reponse) -> Reponse:
        if len(self.cache) >= 4:                       # on garde peu de réponses : la mémoire reste maîtrisée
            self.cache.pop(next(iter(self.cache)))
        self.cache[cle] = rep
        return rep

    # ----- Open Data Réseaux Énergies (Opendatasoft, export JSON sans limite de lignes) -----
    def odre(self, req: Requete, a: dt.datetime, b: dt.datetime) -> Reponse:
        champ = req.params.get("champ_date", "date_heure")
        params = {"where": f"{champ} >= date'{a:%Y-%m-%d}' AND {champ} < date'{b:%Y-%m-%d}'", "timezone": "UTC"}
        url = f"{URL_ODRE}/{req.jeu}/exports/json"
        cle = url + json.dumps(params, sort_keys=True)
        if (rep := self._depuis_cache(cle)) is not None:
            return rep
        r = appeler(self.session, url, params)
        if r.status_code != 200:
            raise RuntimeError(f"ODRÉ HTTP {r.status_code} : {r.text[:300]}")
        return self._memoriser(cle, Reponse(r.url, r.status_code, r.text))

    # ----- ENTSO-E Transparency Platform (XML) -----
    def entsoe(self, req: Requete, a: dt.datetime, b: dt.datetime) -> Reponse:
        jeton = secret(self.config, "entsoe", "jeton")
        if not jeton:
            raise SansCle("jeton ENTSO-E absent de config\\eeip.ini")
        p = dict(req.params)
        domaine = p.pop("domaine", "in_Domain")
        params = {"securityToken": jeton, "periodStart": f"{a:%Y%m%d%H%M}", "periodEnd": f"{b:%Y%m%d%H%M}"}
        params.update({k: v for k, v in p.items()})
        if domaine == "in_out":
            params["in_Domain"] = req.zone_eic
            params["out_Domain"] = req.contrepartie_eic or req.zone_eic
        else:
            params[domaine] = req.zone_eic
        r = appeler(self.session, URL_ENTSOE, params)
        if r.status_code == 401:
            raise RuntimeError("ENTSO-E : jeton refusé (HTTP 401)")
        if r.status_code not in (200, 400):
            raise RuntimeError(f"ENTSO-E HTTP {r.status_code} : {r.text[:300]}")
        return Reponse(masquer(r.url), r.status_code, r.text)

    # ----- RTE (OAuth 2, jeton valable environ deux heures) -----
    def _jeton_rte(self) -> str:
        if self.jeton_rte and time.time() < self.jeton_rte[1]:
            return self.jeton_rte[0]
        ident = secret(self.config, "rte", "id_client")
        sec = secret(self.config, "rte", "secret_client")
        if not ident or not sec:
            raise SansCle("identifiants RTE absents de config\\eeip.ini")
        base = base64.b64encode(f"{ident}:{sec}".encode()).decode()
        r = self.session.post(URL_RTE_JETON, headers={"Authorization": f"Basic {base}",
                                                      "Content-Type": "application/x-www-form-urlencoded"}, timeout=60)
        if r.status_code != 200:
            raise RuntimeError(f"RTE : jeton refusé (HTTP {r.status_code}) : {r.text[:200]}")
        d = r.json()
        self.jeton_rte = (d["access_token"], time.time() + int(d.get("expires_in", 3600)) - 120)
        return self.jeton_rte[0]

    def rte(self, req: Requete, a: dt.datetime, b: dt.datetime) -> Reponse:
        jeton = self._jeton_rte()
        # RTE n'accepte que des journées entières en heure de Paris, et refuse une période
        # trop courte (erreur F05) : bornes calées sur minuit à Paris, au moins deux jours.
        debut = a.replace(tzinfo=dt.timezone.utc).astimezone(PARIS)
        fin = b.replace(tzinfo=dt.timezone.utc).astimezone(PARIS)
        debut = dt.datetime.combine(debut.date(), dt.time(), tzinfo=PARIS)
        jour_fin = fin.date() if fin.time() == dt.time() else fin.date() + dt.timedelta(days=1)
        fin = dt.datetime.combine(jour_fin, dt.time(), tzinfo=PARIS)
        # RTE refuse une date de fin au-delà de demain minuit (erreur F04) : la dernière fenêtre est rognée
        demain = dt.datetime.combine(dt.datetime.now(PARIS).date() + dt.timedelta(days=1), dt.time(), tzinfo=PARIS)
        fin = min(fin, demain)
        if (fin.date() - debut.date()).days < 2:
            debut = dt.datetime.combine(fin.date() - dt.timedelta(days=2), dt.time(), tzinfo=PARIS)
        params = {"start_date": debut.isoformat(timespec="seconds"), "end_date": fin.isoformat(timespec="seconds")}
        if "type" in req.params:
            params["type"] = req.params["type"]
        r = appeler(self.session, f"{URL_RTE}/{req.jeu}", params, {"Authorization": f"Bearer {jeton}"})
        if r.status_code in (204, 404):
            return Reponse(r.url, r.status_code, "{}")
        if r.status_code != 200:
            raise RuntimeError(f"RTE HTTP {r.status_code} : {r.text[:300]}")
        return Reponse(r.url, r.status_code, r.text)

    # ----- Eurostat (JSON-stat 2.0) -----
    def eurostat(self, req: Requete, a: dt.datetime, b: dt.datetime) -> Reponse:
        params: list[tuple[str, str]] = [("format", "JSON"), ("lang", "FR")]
        for dim, valeurs in (req.params.get("serveur") or {}).items():
            for v in (valeurs if isinstance(valeurs, list) else [valeurs]):
                params.append((dim, v))
        url = f"{URL_EUROSTAT}/{req.jeu}"
        cle = url + json.dumps(params)
        if (rep := self._depuis_cache(cle)) is not None:
            return rep
        r = appeler(self.session, url, params, delai=300)
        if r.status_code != 200:
            raise RuntimeError(f"Eurostat HTTP {r.status_code} : {r.text[:300]}")
        return self._memoriser(cle, Reponse(r.url, r.status_code, r.text))

    def extraire(self, req: Requete, a: dt.datetime, b: dt.datetime) -> Reponse:
        return {"ODRE": self.odre, "ENTSOE": self.entsoe, "RTE": self.rte, "EUROSTAT": self.eurostat}[req.source](req, a, b)


# ---------------------------------------------------------------------------
# Analyse : réponse brute -> lignes pour stg.Mesure
# (CodeSource, ZoneCode, FiliereCode, ContrepartieCode, Granularite, InstantUtc, Valeur, Qualite)
# ---------------------------------------------------------------------------
def qualite_odre(texte) -> str:
    t = str(texte or "").lower()
    if "finitive" in t:
        return "D"
    if "consolid" in t:
        return "C"
    return "T"


def analyser_odre(rep: Reponse, req: Requete) -> list[tuple]:
    donnees = json.loads(rep.texte)
    enregistrements = donnees if isinstance(donnees, list) else donnees.get("results", [])
    if not enregistrements:
        return []
    p = req.params
    champs = p.get("champs", [])
    role = p.get("role", "valeur")
    champ_date = p.get("champ_date", "date_heure")
    champ_zone = p.get("champ_zone")
    champ_qualite = p.get("champ_qualite", "nature")
    qualite_fixe = p.get("qualite_fixe")
    base = re.sub(r"-(tr|cons-def)$", "", req.jeu)       # temps réel et consolidé = MÊME série

    presents = set(enregistrements[0].keys())
    absents = [c for c in champs if c not in presents]
    if len(absents) == len(champs):
        raise AucuneDonnee(f"aucun des champs {champs} n'existe ; champs disponibles : {sorted(presents)}")
    if absents:
        log.warning("    champs absents de %s : %s", req.jeu, absents)

    brutes, instants = [], defaultdict(set)
    for enr in enregistrements:
        instant = en_utc(enr.get(champ_date))
        if instant is None:
            continue
        zone = str(enr.get(champ_zone)) if champ_zone else (p.get("zone") or req.zone)
        if not zone or zone == "None":
            continue
        q = qualite_fixe or qualite_odre(enr.get(champ_qualite)) if champ_qualite or qualite_fixe else "T"
        for champ in champs:
            v = nombre(enr.get(champ))
            if v is None:
                continue
            code = f"{base}/{zone}/{champ}"
            brutes.append((code, zone, champ if role == "filiere" else None,
                           champ if role == "contrepartie" else None, instant, v, q))
            instants[code].add(instant)

    # le pas de chaque série : le plus petit écart entre deux instants consécutifs
    pas = {}
    for code, ens in instants.items():
        tri = sorted(ens)
        ecarts = [(y - x).total_seconds() / 60 for x, y in zip(tri, tri[1:]) if y > x]
        pas[code] = granularite(min(ecarts)) if ecarts else "PT15M"
    return [(c, z, f, k, pas[c] or "PT15M", i, v, q) for (c, z, f, k, i, v, q) in brutes]


def _minutes_iso(resolution: str) -> int | None:
    m = re.fullmatch(r"PT(\d+)M", resolution or "")
    if m:
        return int(m[1])
    return {"PT1H": 60, "P1D": 1440}.get(resolution)


def analyser_entsoe(rep: Reponse, req: Requete) -> list[tuple]:
    racine = ET.fromstring(rep.texte)
    if racine.tag.endswith("Acknowledgement_MarketDocument"):
        raison = " ".join(t.text or "" for t in racine.iterfind(".//{*}text"))
        if "No matching data" in raison or "no matching data" in raison.lower():
            return []
        raise RuntimeError(f"ENTSO-E : {raison.strip()[:300]}")
    doc = req.params.get("documentType")
    qualite = "D" if doc in ("A44", "A68") else "T"
    lignes = []
    for serie in racine.iterfind(".//{*}TimeSeries"):
        psr = serie.findtext("{*}MktPSRType/{*}psrType")
        entree = serie.findtext("{*}inBiddingZone_Domain.mRID") or serie.findtext("{*}in_Domain.mRID")
        sortie = serie.findtext("{*}outBiddingZone_Domain.mRID") or serie.findtext("{*}out_Domain.mRID")
        signe = 1.0
        if doc == "A75" and psr and sortie and not entree:      # la part consommée (pompage, charge)
            if psr not in ("B10", "B25"):
                continue                # consommation propre des centrales : hors du périmètre production
            psr, signe = f"{psr}_CONSO", -1.0
        courbe = serie.findtext("{*}curveType") or "A01"
        for periode in serie.iterfind("{*}Period"):
            debut = en_utc(periode.findtext("{*}timeInterval/{*}start"))
            fin = en_utc(periode.findtext("{*}timeInterval/{*}end"))
            resolution = periode.findtext("{*}resolution") or ""
            if debut is None or fin is None:
                continue
            if resolution in ("P1Y", "P1M"):
                gran, pas_min, nb = resolution, None, 1
            else:
                pas_min = _minutes_iso(resolution)
                gran = granularite(pas_min) if pas_min else None
                if gran is None:
                    continue
                nb = int((fin - debut).total_seconds() // 60 // pas_min)
            points = {}
            for pt in periode.iterfind("{*}Point"):
                pos = int(pt.findtext("{*}position"))
                points[pos] = nombre(pt.findtext("{*}quantity") or pt.findtext("{*}price.amount"))
            code = f"{doc}/{req.zone}/{req.contrepartie or '-'}/{psr or '-'}/{gran}"
            precedent = None
            for pos in range(1, nb + 1):
                v = points.get(pos)
                if v is None and courbe == "A03":
                    v = precedent                               # bloc de taille variable : la valeur se prolonge
                if v is None:
                    continue
                precedent = v
                instant = debut if pas_min is None else debut + dt.timedelta(minutes=pas_min * (pos - 1))
                if gran in ("P1D", "P1M", "P1Y"):
                    instant = debut_de_jour(instant)
                lignes.append((code, req.zone, psr, req.contrepartie, gran, instant, v * signe, qualite))
    return lignes


def analyser_rte(rep: Reponse, req: Requete) -> list[tuple]:
    donnees = json.loads(rep.texte or "{}")
    blocs = donnees.get(req.params.get("cle", ""), [])
    lignes = []
    for bloc in blocs:
        filiere = contre = None
        zone = req.zone or "FR"
        if "production_type" in bloc:
            filiere = bloc["production_type"]
            if filiere in ("TOTAL", "EXCHANGE"):
                continue
        if "sender_country_eic_code" in bloc or "sender_country_name" in bloc:
            zone = bloc.get("receiver_country_eic_code") or bloc.get("receiver_country_name")
            contre = bloc.get("sender_country_eic_code") or bloc.get("sender_country_name")
        cle_type = bloc.get("type", "")
        code = f"{req.jeu.split('/')[0]}/{zone}/{contre or '-'}/{filiere or cle_type or '-'}"
        for val in bloc.get("values", []):
            a, b = en_utc(val.get("start_date")), en_utc(val.get("end_date"))
            v = nombre(val.get("value"))
            if a is None or v is None:
                continue
            gran = granularite((b - a).total_seconds() / 60) if b else "PT15M"
            if gran is None:
                continue
            lignes.append((code, zone, filiere, contre, gran, a, v, "T"))
    return lignes


_RE_MOIS = re.compile(r"^(\d{4})-?M?(\d{2})$")
_RE_SEM = re.compile(r"^(\d{4})-?S([12])$")


def periode_eurostat(texte: str) -> tuple[dt.datetime, str] | None:
    if re.fullmatch(r"\d{4}", texte):
        return dt.datetime(int(texte), 1, 1), "P1Y"
    if m := _RE_SEM.match(texte):
        return dt.datetime(int(m[1]), 1 if m[2] == "1" else 7, 1), "P6M"
    if m := _RE_MOIS.match(texte):
        return dt.datetime(int(m[1]), int(m[2]), 1), "P1M"
    return None


def correspond(valeur, attendu) -> bool:
    return valeur in attendu if isinstance(attendu, list) else valeur == attendu


def analyser_eurostat(rep: Reponse, req: Requete, zones: set[str]) -> list[tuple]:
    d = json.loads(rep.texte)
    if "error" in d:
        raise RuntimeError(f"Eurostat : {d['error']}")
    if "value" not in d:
        raise RuntimeError("Eurostat : réponse sans valeurs (requête trop large, réponse différée ?)")
    ids, tailles, dims = d["id"], d["size"], d["dimension"]
    codes = {}
    for dim in ids:
        index = dims[dim]["category"]["index"]
        if isinstance(index, list):
            codes[dim] = index
        else:
            codes[dim] = [c for c, _ in sorted(index.items(), key=lambda kv: kv[1])]
    pas = [1] * len(ids)                                   # rangement ligne par ligne (row-major)
    for k in range(len(ids) - 2, -1, -1):
        pas[k] = pas[k + 1] * tailles[k + 1]

    local = req.params.get("local") or {}
    garder = req.params.get("garder") or {}
    dim_filiere = req.params.get("dim_filiere")
    statuts = d.get("status") or {}
    valeurs = d["value"]
    items = valeurs.items() if isinstance(valeurs, dict) else enumerate(valeurs)
    lignes = []
    for brut, v in items:
        v = nombre(v)
        if v is None:
            continue
        rang = int(brut)
        coord = {dim: codes[dim][(rang // pas[k]) % tailles[k]] for k, dim in enumerate(ids)}
        if not all(correspond(coord.get(dim), attendu) for dim, attendu in local.items()):
            continue
        if any(coord.get(dim) not in liste for dim, liste in garder.items()):
            continue
        geo = coord.get("geo")
        if geo not in zones:
            continue
        p = periode_eurostat(coord.get("time", ""))
        if p is None or p[0].date() < req.debut:
            continue
        instant, gran = p
        cle = ".".join(coord[dim] for dim in ids if dim not in ("geo", "time"))
        drapeau = str(statuts.get(str(brut), "") if isinstance(statuts, dict) else "")
        qualite = "P" if "p" in drapeau else ("E" if "e" in drapeau else "D")
        lignes.append((f"{req.jeu}/{cle}/{geo}", geo, coord.get(dim_filiere) if dim_filiere else None,
                       None, gran, instant, v, qualite))
    return lignes


# ---------------------------------------------------------------------------
# Écritures SQL Server
# ---------------------------------------------------------------------------
def ouvrir_lot(cnx, declencheur: str, sources: str) -> int:
    cur = cnx.cursor()
    cur.execute("SET NOCOUNT ON; DECLARE @id int; "
                "EXEC ops.usp_Lot_Ouvrir @Declencheur = ?, @Sources = ?, @LotId = @id OUTPUT; SELECT @id;",
                declencheur, sources)
    return int(cur.fetchone()[0])


def fermer_lot(cnx, lot_id: int, statut: str, appels: int, identiques: int, message: str) -> None:
    cnx.cursor().execute("EXEC ops.usp_Lot_Fermer ?, ?, ?, ?, ?", lot_id, statut, appels, identiques, message[:2000])


def journal(cnx, lot_id, niveau: str, etape: str, message: str) -> None:
    try:
        cnx.cursor().execute("EXEC ops.usp_Journal_Ecrire ?, ?, ?, ?", lot_id, niveau, etape[:100], message[:4000])
    except pyodbc.Error:
        log.warning("Journal SQL indisponible : %s", message)


def ranger_brut(cnx, lot_id: int, req: Requete, rep: Reponse) -> None:
    octets = rep.texte.encode("utf-8")
    compresse = gzip.compress(rep.texte.encode("utf-16-le"), mtime=0)   # relu par DECOMPRESS côté SQL
    cur = cnx.cursor()
    cur.execute("SET NOCOUNT ON; DECLARE @id bigint; "
                "EXEC raw.usp_Payload_Inserer ?, ?, ?, ?, ?, ?, ?, ?, @id OUTPUT; SELECT @id;",
                lot_id, req.cfg_id, req.source, masquer(rep.url)[:1000], rep.statut, len(octets),
                hashlib.sha256(octets).digest(), compresse)
    cur.fetchone()


def charger_transit(cnx, lot_id: int, req: Requete, lignes: list[tuple]) -> None:
    sql = ("INSERT INTO stg.Mesure (LotId, CfgId, SourceCode, CodeSource, ZoneCode, FiliereCode, ContrepartieCode, "
           "Granularite, InstantUtc, Valeur, Qualite) VALUES (?,?,?,?,?,?,?,?,?,?,?)")
    cur = cnx.cursor()
    cur.fast_executemany = True                    # un seul aller-retour par paquet de 20 000 lignes
    for debut in range(0, len(lignes), TAILLE_PAQUET):
        paquet = [(lot_id, req.cfg_id, req.source, c[:200], z[:60], f and f[:60], k and k[:60], g, i, v, q)
                  for (c, z, f, k, g, i, v, q) in lignes[debut:debut + TAILLE_PAQUET]]
        cur.executemany(sql, paquet)


def integrer(cnx, lot_id: int, req: Requete) -> tuple:
    cur = cnx.cursor()
    cur.execute("EXEC core.usp_Mesure_Integrer @LotId = ?, @CfgId = ?", lot_id, req.cfg_id)
    return tuple(cur.fetchone())


def marquer(cnx, req: Requete, statut: str, empreinte_: bytes | None = None) -> None:
    if empreinte_ is None:
        cnx.cursor().execute("EXEC cfg.usp_Cfg_Marquer @CfgId = ?, @Statut = ?", req.cfg_id, statut)
    else:
        cnx.cursor().execute("EXEC cfg.usp_Cfg_Marquer @CfgId = ?, @Statut = ?, @Empreinte = ?",
                             req.cfg_id, statut, empreinte_)


def lire_catalogue(cnx, sources: list[str], filtre_jeu: str | None, filtre_zone: str | None) -> list[Requete]:
    marques = ",".join("?" * len(sources))
    cur = cnx.cursor()
    cur.execute(f"""
        SELECT c.CfgId, c.SourceCode, c.Jeu, c.Parametres, c.IndicateurCode, c.ZoneCode, z.CodeEic,
               c.ContrepartieCode, k.CodeEic AS EicContrepartie, c.DebutHistorique, c.FenetreJours,
               c.RecouvrementJours, c.DernierInstant, c.DerniereEmpreinte
        FROM cfg.RequeteACharger AS c
        LEFT JOIN core.Zone AS z ON z.Code = c.ZoneCode
        LEFT JOIN core.Zone AS k ON k.Code = c.ContrepartieCode
        WHERE c.Actif = 1 AND c.SourceCode IN ({marques})
        ORDER BY CASE c.SourceCode WHEN 'ODRE' THEN 1 WHEN 'RTE' THEN 2 WHEN 'ENTSOE' THEN 3 ELSE 4 END,
                 c.Jeu, c.CfgId""", *sources)
    liste = []
    for r in cur.fetchall():
        if filtre_jeu and filtre_jeu.lower() not in r.Jeu.lower():
            continue
        if filtre_zone and filtre_zone not in (r.ZoneCode or "", r.ContrepartieCode or ""):
            continue
        liste.append(Requete(r.CfgId, r.SourceCode, r.Jeu, json.loads(r.Parametres), r.IndicateurCode,
                             r.ZoneCode, r.CodeEic, r.ContrepartieCode, r.EicContrepartie,
                             r.DebutHistorique, r.FenetreJours, r.RecouvrementJours, r.DernierInstant,
                             bytes(r.DerniereEmpreinte) if r.DerniereEmpreinte else None))
    return liste


def zones_eurostat(cnx) -> set[str]:
    return {r[0] for r in cnx.cursor().execute("SELECT CodeEurostat FROM core.Zone WHERE CodeEurostat IS NOT NULL")}


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------
def analyser(ext: Extracteur, rep: Reponse, req: Requete) -> list[tuple]:
    if req.source == "ODRE":
        return analyser_odre(rep, req)
    if req.source == "ENTSOE":
        return analyser_entsoe(rep, req)
    if req.source == "RTE":
        return analyser_rte(rep, req)
    return analyser_eurostat(rep, req, ext.zones_eurostat)


def traiter_fenetre(cnx, ext: Extracteur, lot_id: int, req: Requete, a, b, forcer: bool,
                    brut_range: set[str], compteurs: dict, unique: bool) -> int:
    """Une requête, une fenêtre de temps. Renvoie le nombre de lignes intégrées (-1 si réponse identique)."""
    rep = ext.extraire(req, a, b)
    compteurs["appels"] += 1
    signature = empreinte([rep.texte])
    if unique and not forcer and req.derniere_empreinte == signature:
        compteurs["identiques"] += 1
        return -1
    if rep.url not in brut_range:                      # une réponse partagée n'est rangée qu'une fois
        ranger_brut(cnx, lot_id, req, rep)
        brut_range.add(rep.url)
    lignes = analyser(ext, rep, req)
    if not lignes:
        return 0
    charger_transit(cnx, lot_id, req, lignes)
    lues, inserees, revisees, inchangees, rejetees = integrer(cnx, lot_id, req)
    log.info("    %s → %s : %s lues | %s insérées | %s révisées | %s inchangées | %s rejetées",
             f"{a:%Y-%m-%d}", f"{b:%Y-%m-%d}", lues, inserees, revisees, inchangees, rejetees)
    if unique:
        req.derniere_empreinte = signature
    return lues


def executer(cnx, ext: Extracteur, config, lot_id: int, requetes: list[Requete], forcer: bool,
             limite: int | None, compteurs: dict) -> list[str]:
    fin = (maintenant_utc() + dt.timedelta(days=2)).replace(hour=0, minute=0, second=0, microsecond=0)
    pause = config.getfloat("http", "pause_entre_appels", fallback=0.3)
    plans = {r.cfg_id: fenetres(r, fin)[: limite or None] for r in requetes}
    etat = {r.cfg_id: {"lignes": 0, "statut": None, "identique": False} for r in requetes}
    brut_range: set[str] = set()
    sans_cle: set[str] = set()

    # les requêtes d'un même jeu avancent ensemble, fenêtre par fenêtre : un seul appel par fenêtre
    groupes = defaultdict(list)
    for r in requetes:
        groupes[(r.source, r.jeu, r.debut, r.fenetre)].append(r)

    for (source, jeu, _, _), membres in groupes.items():
        toutes = sorted({f for r in membres for f in plans[r.cfg_id]})
        log.info("[%s] %s : %s requête(s), %s fenêtre(s)", source, jeu, len(membres), len(toutes))
        for (a, b) in toutes:
            for req in membres:
                e = etat[req.cfg_id]
                if (a, b) not in plans[req.cfg_id] or e["statut"] in ("ECHEC", "SANS_CLE"):
                    continue
                if source in sans_cle:
                    e["statut"] = "SANS_CLE"
                    continue
                try:
                    n = traiter_fenetre(cnx, ext, lot_id, req, a, b, forcer, brut_range, compteurs,
                                        unique=len(plans[req.cfg_id]) == 1)
                    if n == -1:
                        e["identique"] = True
                        log.info("    %s : réponse identique à la précédente, intégration inutile", req.nom)
                    else:
                        e["lignes"] += n
                except SansCle as ex:
                    sans_cle.add(source)
                    e["statut"] = "SANS_CLE"
                    log.warning("    %s : %s : requêtes %s ignorées", source, ex, source)
                except Exception as ex:                  # une fenêtre en échec arrête CETTE requête, pas le lot
                    try:
                        cnx.cursor().execute("EXEC stg.usp_Transit_Purger ?, ?", lot_id, req.cfg_id)
                    except pyodbc.Error:
                        pass
                    e["statut"] = "ECHEC"
                    journal(cnx, lot_id, "ERREUR", req.nom[:100], f"{a:%Y-%m-%d} : {type(ex).__name__} : {ex}")
                    log.error("    ECHEC %s (%s) : %s : %s", req.nom, f"{a:%Y-%m-%d}", type(ex).__name__, ex)
                finally:
                    time.sleep(pause)

    resultats = []
    for req in requetes:
        e = etat[req.cfg_id]
        statut = e["statut"] or ("SUCCES" if e["lignes"] > 0 else ("INCHANGE" if e["identique"] else "VIDE"))
        marquer(cnx, req, statut, req.derniere_empreinte if statut == "SUCCES" else None)
        resultats.append(statut)
    return resultats


def tester(cnx, ext: Extracteur, source: str, jeu: str | None, zone: str | None) -> None:
    """Diagnostic : une requête de la source, une petite fenêtre récente, rien n'est écrit."""
    requetes = lire_catalogue(cnx, [source], jeu, zone)
    if not requetes:
        print("Aucune requête active pour", source)
        return
    req = requetes[0]
    b = (maintenant_utc() - dt.timedelta(days=2)).replace(hour=0, minute=0, second=0, microsecond=0)
    a = b - dt.timedelta(days=1)
    print(f"Requête testée : CfgId {req.cfg_id} · {req.nom} · {a:%Y-%m-%d} → {b:%Y-%m-%d}")
    rep = ext.extraire(req, a, b)
    print(f"HTTP {rep.statut}, {len(rep.texte):,} caractères. Début de la réponse :")
    print(rep.texte[:1200])
    if source == "ODRE":
        enr = json.loads(rep.texte)
        if enr:
            print("\nChamps disponibles :", sorted(enr[0].keys()))
    if source == "EUROSTAT":
        d = json.loads(rep.texte)
        for dim in d.get("id", []):
            cat = d["dimension"][dim]["category"]
            print(f"\n{dim} : " + ", ".join(f"{c} = {cat.get('label', {}).get(c, '')}"
                                          for c in list(cat["index"])[:40]))
    lignes = analyser(ext, rep, req)
    print(f"\nMesures reconnues : {len(lignes)}")
    for l in lignes[:5]:
        print("  ", l)


def lignes_procedure(cnx, sql: str, *params) -> list:
    """Exécute une procédure, lit son premier jeu de résultats, puis vide et ferme le curseur.
    Sans cela, la connexion reste « occupée » et la commande suivante est refusée."""
    cur = cnx.cursor()
    try:
        cur.execute(sql, *params)
        lignes = cur.fetchall() if cur.description else []
        while cur.nextset():
            pass
        return lignes
    finally:
        cur.close()


def empecher_la_veille() -> None:
    """Sous Windows, demande au système de ne pas se mettre en veille tant que le programme tourne.
    L'écran peut toujours s'éteindre ; la demande disparaît d'elle-même à la fin du programme."""
    if sys.platform != "win32":
        return
    try:
        import ctypes
        ES_CONTINUOUS, ES_SYSTEM_REQUIRED = 0x80000000, 0x00000001
        ctypes.windll.kernel32.SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)
    except Exception:   # jamais bloquant : au pire, le réglage d'alimentation de Windows s'applique
        pass


def main() -> int:
    parseur = argparse.ArgumentParser(description="EEIP : ingestion des indicateurs énergétiques européens")
    parseur.add_argument("--sources", nargs="+", choices=SOURCES, default=list(SOURCES))
    parseur.add_argument("--jeu", help="ne traiter que les jeux dont le nom contient ce texte")
    parseur.add_argument("--zone", help="ne traiter que cette zone (FR, DE_LU...)")
    parseur.add_argument("--limite-fenetres", type=int, help="nombre maximal de fenêtres par requête (chargement progressif)")
    parseur.add_argument("--forcer", action="store_true", help="intègre même une réponse identique à la précédente")
    parseur.add_argument("--declencheur", default="manuel")
    parseur.add_argument("--tester", choices=SOURCES, help="diagnostic d'une source : n'écrit rien")
    args = parseur.parse_args()
    empecher_la_veille()

    configurer_journal()
    config = lire_config()
    session = ouvrir_session_http(config)
    cnx = ouvrir_connexion(config)
    ext = Extracteur(session, config, zones_eurostat(cnx))

    if args.tester:
        tester(cnx, ext, args.tester, args.jeu, args.zone)
        return 0

    lot_id = ouvrir_lot(cnx, args.declencheur, ",".join(args.sources))
    log.info("=== Lot %s ouvert (%s) ===", lot_id, ", ".join(args.sources))
    compteurs = {"appels": 0, "identiques": 0}
    try:
        requetes = lire_catalogue(cnx, args.sources, args.jeu, args.zone)
        resultats = executer(cnx, ext, config, lot_id, requetes, args.forcer, args.limite_fenetres, compteurs)
        log.info("Agrégats quotidiens et contrôles qualité")
        jours = lignes_procedure(cnx, "EXEC mart.usp_MesureJour_Rafraichir @LotCourant = ?", lot_id)
        if jours and len(jours[0]) >= 2:
            log.info("    %s séries, %s jours-séries recalculés", jours[0][0], jours[0][1])
        else:
            log.info("    jours-séries recalculés : 0")
        for ligne in lignes_procedure(cnx, "EXEC dq.usp_Controler @LotId = ?", lot_id):
            log.info("    anomalies %s : %s", ligne[0], ligne[1])
    except Exception as e:
        journal(cnx, lot_id, "ERREUR", "main", f"{type(e).__name__} : {e}")
        fermer_lot(cnx, lot_id, "ECHEC", compteurs["appels"], compteurs["identiques"], str(e))
        log.exception("Lot %s en ECHEC", lot_id)
        return 1

    utiles = [s for s in resultats if s != "SANS_CLE"]
    echecs = utiles.count("ECHEC")
    statut = "ECHEC" if utiles and echecs == len(utiles) else ("PARTIEL" if echecs else "SUCCES")
    bilan = ", ".join(f"{s} : {resultats.count(s)}" for s in ("SUCCES", "INCHANGE", "VIDE", "ECHEC", "SANS_CLE")
                      if resultats.count(s))
    fermer_lot(cnx, lot_id, statut, compteurs["appels"], compteurs["identiques"], bilan or "rien à faire")
    log.info("=== Lot %s : %s (%s) ===", lot_id, statut, bilan)
    return 1 if statut == "ECHEC" else 0


if __name__ == "__main__":
    sys.exit(main())

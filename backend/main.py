"""
AgroSense Backend v2 — Farmer + Field + NDVI + Insights
Run: uvicorn main:app --reload --port 8000
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import math, os, json, logging, datetime, sqlite3

app = FastAPI(title="AgroSense API v2")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
logger = logging.getLogger(__name__)

DB_PATH = os.environ.get("DB_PATH", "/tmp/agrosense.db")

# ── GEE setup ─────────────────────────────────────────────────────────────────
GEE_OK = False
try:
    import ee
    sa_json = os.environ.get("GEE_SERVICE_ACCOUNT_JSON", "")
    project  = os.environ.get("GEE_PROJECT", "")
    if sa_json:
        key   = json.loads(sa_json)
        creds = ee.ServiceAccountCredentials(email=key["client_email"], key_data=json.dumps(key))
        ee.Initialize(credentials=creds, project=project or None)
    else:
        ee.Initialize(project=project) if project else ee.Initialize()
    GEE_OK = True
    logger.info("GEE ready")
except Exception as e:
    logger.warning(f"GEE unavailable: {e}")

# ── Database ──────────────────────────────────────────────────────────────────
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS farmers (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            name     TEXT NOT NULL,
            phone    TEXT,
            village  TEXT,
            acres    REAL DEFAULT 0,
            created  TEXT DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS fields (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            farmer_id  INTEGER REFERENCES farmers(id) ON DELETE CASCADE,
            name       TEXT DEFAULT 'Main Field',
            polygon    TEXT NOT NULL,
            area_acres REAL DEFAULT 0,
            crop       TEXT,
            created    TEXT DEFAULT (datetime('now'))
        );
    """)
    conn.commit()
    conn.close()

init_db()

# ── Models ────────────────────────────────────────────────────────────────────
class FarmerCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    village: Optional[str] = None
    acres: Optional[float] = 0.0

class FieldCreate(BaseModel):
    farmer_id: int
    name: Optional[str] = "Main Field"
    polygon: List[List[float]]   # [[lat,lng], [lat,lng], ...]
    crop: Optional[str] = None

class SowingRequest(BaseModel):
    latitude: float
    longitude: float

class FieldAnalysisRequest(BaseModel):
    field_id: int

# ── Helpers ───────────────────────────────────────────────────────────────────
def polygon_area_acres(coords: List[List[float]]) -> float:
    """Shoelace formula → acres"""
    if len(coords) < 3:
        return 0.0
    n = len(coords)
    area = 0.0
    for i in range(n):
        j = (i + 1) % n
        area += coords[i][1] * coords[j][0]
        area -= coords[j][1] * coords[i][0]
    area = abs(area) / 2.0
    # Convert sq degrees to acres (approx at 20°N)
    sq_km = area * 111.32 * 111.32 * math.cos(math.radians(coords[0][0]))
    return round(sq_km * 247.105, 2)

def centroid(coords: List[List[float]]):
    lat = sum(c[0] for c in coords) / len(coords)
    lng = sum(c[1] for c in coords) / len(coords)
    return lat, lng

# ── GEE data ──────────────────────────────────────────────────────────────────
def get_ndvi_timeseries(coords: List[List[float]]) -> List[dict]:
    lat, lng = centroid(coords)
    if not GEE_OK:
        return _mock_ndvi(lat, lng)
    try:
        polygon = ee.Geometry.Polygon([[[c[1], c[0]] for c in coords]])
        end   = datetime.date.today()
        start = end - datetime.timedelta(days=365)
        results = []
        for m in range(12):
            mo_start = start + datetime.timedelta(days=m * 30)
            mo_end   = mo_start + datetime.timedelta(days=30)
            col = (ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
                   .filterBounds(polygon)
                   .filterDate(str(mo_start), str(mo_end))
                   .filter(ee.Filter.lt("CLOUDY_PIXEL_PERCENTAGE", 30))
                   .map(lambda img: img.normalizedDifference(["B8", "B4"]).rename("ndvi")))
            if col.size().getInfo() == 0:
                results.append({"month": mo_start.strftime("%b %Y"), "ndvi": None})
                continue
            val = (col.max()
                   .reduceRegion(ee.Reducer.mean(), polygon, 10)
                   .get("ndvi").getInfo())
            results.append({
                "month": mo_start.strftime("%b %Y"),
                "ndvi":  round(float(val), 3) if val else None
            })
        return results
    except Exception as e:
        logger.error(f"NDVI error: {e}")
        return _mock_ndvi(lat, lng)

def _mock_ndvi(lat: float, lng: float) -> List[dict]:
    import random
    random.seed(int(abs(lat * 100 + lng * 100)))
    end   = datetime.date.today()
    start = end - datetime.timedelta(days=365)
    # Simulate a kharif crop season
    base  = [0.12, 0.14, 0.18, 0.22, 0.25, 0.45,
             0.68, 0.78, 0.72, 0.48, 0.22, 0.15]
    results = []
    for m in range(12):
        mo_start = start + datetime.timedelta(days=m * 30)
        ndvi = round(base[m] + random.uniform(-0.04, 0.04), 3)
        ndvi = max(0.05, min(0.95, ndvi))
        results.append({"month": mo_start.strftime("%b %Y"), "ndvi": ndvi})
    return results

def get_env_data(lat: float, lng: float) -> dict:
    if not GEE_OK:
        return _mock_env(lat, lng)
    try:
        point = ee.Geometry.Point(lng, lat)
        rain  = (ee.ImageCollection("UCSB-CHG/CHIRPS/DAILY")
                 .filterBounds(point)
                 .filterDate("2023-06-01", "2024-05-31")
                 .sum()
                 .reduceRegion(ee.Reducer.mean(), point, 5000)
                 .get("precipitation").getInfo() or 0)
        lst   = (ee.ImageCollection("MODIS/061/MOD11A2")
                 .filterBounds(point)
                 .filterDate("2023-06-01", "2024-05-31")
                 .select("LST_Day_1km").mean()
                 .multiply(0.02).subtract(273.15)
                 .reduceRegion(ee.Reducer.mean(), point, 1000)
                 .get("LST_Day_1km").getInfo() or 25)
        soil  = (ee.Image("OpenLandMap/SOL/SOL_CLAY-WFRACTION_USDA-3A1A1A_M/v02")
                 .select("b0")
                 .reduceRegion(ee.Reducer.mean(), point, 1000)
                 .get("b0").getInfo() or 25)
        return {"rainfall": round(float(rain), 1),
                "temp":     round(float(lst),  1),
                "soil":     round(float(soil), 1)}
    except Exception as e:
        logger.error(f"Env data error: {e}")
        return _mock_env(lat, lng)

def _mock_env(lat: float, lng: float) -> dict:
    s = abs(math.sin(lat * 12.9898 + lng * 78.233) * 43758.5453)
    f = s - int(s)
    return {"rainfall": round(400 + f * 1400, 1),
            "temp":     round(18  + f * 18,   1),
            "soil":     round(15  + f * 35,   1)}

# ── Insights engine ───────────────────────────────────────────────────────────
def compute_insights(ndvi_series: List[dict], env: dict, area_acres: float) -> dict:
    values = [x["ndvi"] for x in ndvi_series if x["ndvi"] is not None]
    if not values:
        return {}

    peak_ndvi   = max(values)
    avg_ndvi    = round(sum(values) / len(values), 3)
    peak_month  = ndvi_series[[x["ndvi"] for x in ndvi_series].index(peak_ndvi)]["month"] if peak_ndvi in [x["ndvi"] for x in ndvi_series] else "—"

    # Health score
    health_score = int(peak_ndvi * 100)

    # Water stress: big NDVI drop with low rain
    stress = False
    for i in range(1, len(values)):
        if values[i] < values[i-1] - 0.15 and env["rainfall"] < 400:
            stress = True

    # Yield estimate (quintals)
    crop_factors = {"Rice": 22, "Maize": 18, "Wheat": 16, "Cotton": 8, "Sorghum": 12}
    avg_factor = sum(crop_factors.values()) / len(crop_factors)
    yield_est  = round(peak_ndvi * area_acres * avg_factor, 1) if area_acres > 0 else None

    # Pest risk
    pest_risk = "High" if env["temp"] > 32 and avg_ndvi < 0.4 else \
                "Medium" if env["temp"] > 28 else "Low"

    # Sowing window (month after lowest NDVI in first half)
    first_half = values[:6]
    min_idx    = first_half.index(min(first_half))
    sow_month  = ndvi_series[(min_idx + 1) % 12]["month"]

    return {
        "health_score":  health_score,
        "peak_ndvi":     round(peak_ndvi, 3),
        "avg_ndvi":      avg_ndvi,
        "peak_month":    peak_month,
        "water_stress":  stress,
        "yield_estimate": yield_est,
        "pest_risk":     pest_risk,
        "best_sow_month": sow_month,
    }

def compute_crops(env: dict) -> List[dict]:
    rain, temp, soil = env["rainfall"], env["temp"], env["soil"]
    def shift(m):
        return m  # northern hemisphere default
    months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    def mr(s, e): return f"{months[s-1]} – {months[e-1]}"

    crops = []
    if rain > 900 and temp > 22 and soil > 25:
        crops.append({"crop":"Rice","emoji":"🌾","sowing":mr(6,7),"harvest":mr(10,11),"suitability":"high","reason":f"High rainfall {rain:.0f}mm suits paddy"})
    if rain > 500 and temp > 18:
        crops.append({"crop":"Maize","emoji":"🌽","sowing":mr(6,7),"harvest":mr(9,10),"suitability":"high" if rain>800 else "medium","reason":"Good moisture and warmth for maize"})
    if temp < 28 and rain > 300:
        crops.append({"crop":"Wheat","emoji":"🌿","sowing":mr(10,11),"harvest":mr(3,4),"suitability":"high" if temp<24 else "medium","reason":"Cool Rabi season suits wheat"})
    if rain < 800 or temp > 26:
        crops.append({"crop":"Sorghum","emoji":"🌱","sowing":mr(6,7),"harvest":mr(9,10),"suitability":"medium","reason":"Drought-tolerant, good for dry spells"})
    if rain > 500 and temp > 20 and soil > 20:
        crops.append({"crop":"Cotton","emoji":"☁️","sowing":mr(4,5),"harvest":mr(10,12),"suitability":"medium","reason":"Warm temp suits cotton bolls"})
    crops.append({"crop":"Chickpea","emoji":"🫘","sowing":mr(10,11),"harvest":mr(2,3),"suitability":"medium","reason":"Hardy pulse, fixes nitrogen"})
    order = {"high":0,"medium":1,"low":2}
    crops.sort(key=lambda c: order[c["suitability"]])
    return crops[:5]

# ── Farmer CRUD ───────────────────────────────────────────────────────────────
@app.post("/farmers")
def create_farmer(f: FarmerCreate):
    db = get_db()
    cur = db.execute(
        "INSERT INTO farmers (name, phone, village, acres) VALUES (?,?,?,?)",
        (f.name, f.phone, f.village, f.acres))
    db.commit()
    row = db.execute("SELECT * FROM farmers WHERE id=?", (cur.lastrowid,)).fetchone()
    db.close()
    return dict(row)

@app.get("/farmers")
def list_farmers():
    db  = get_db()
    rows = db.execute("SELECT * FROM farmers ORDER BY created DESC").fetchall()
    db.close()
    return [dict(r) for r in rows]

@app.get("/farmers/{farmer_id}")
def get_farmer(farmer_id: int):
    db  = get_db()
    row = db.execute("SELECT * FROM farmers WHERE id=?", (farmer_id,)).fetchone()
    if not row: raise HTTPException(404, "Farmer not found")
    fields = db.execute("SELECT * FROM fields WHERE farmer_id=?", (farmer_id,)).fetchall()
    db.close()
    return {**dict(row), "fields": [dict(f) for f in fields]}

@app.delete("/farmers/{farmer_id}")
def delete_farmer(farmer_id: int):
    db = get_db()
    db.execute("DELETE FROM farmers WHERE id=?", (farmer_id,))
    db.commit()
    db.close()
    return {"deleted": True}

# ── Field CRUD ────────────────────────────────────────────────────────────────
@app.post("/fields")
def create_field(f: FieldCreate):
    area = polygon_area_acres(f.polygon)
    db   = get_db()
    cur  = db.execute(
        "INSERT INTO fields (farmer_id, name, polygon, area_acres, crop) VALUES (?,?,?,?,?)",
        (f.farmer_id, f.name, json.dumps(f.polygon), area, f.crop))
    db.commit()
    row = db.execute("SELECT * FROM fields WHERE id=?", (cur.lastrowid,)).fetchone()
    db.close()
    return dict(row)

@app.get("/fields/{field_id}")
def get_field(field_id: int):
    db  = get_db()
    row = db.execute("SELECT * FROM fields WHERE id=?", (field_id,)).fetchone()
    if not row: raise HTTPException(404, "Field not found")
    db.close()
    return dict(row)

@app.delete("/fields/{field_id}")
def delete_field(field_id: int):
    db = get_db()
    db.execute("DELETE FROM fields WHERE id=?", (field_id,))
    db.commit()
    db.close()
    return {"deleted": True}

# ── Analysis ──────────────────────────────────────────────────────────────────
@app.post("/analyze")
def analyze_field(req: FieldAnalysisRequest):
    db  = get_db()
    row = db.execute("SELECT * FROM fields WHERE id=?", (req.field_id,)).fetchone()
    db.close()
    if not row: raise HTTPException(404, "Field not found")

    coords = json.loads(row["polygon"])
    lat, lng = centroid(coords)
    env      = get_env_data(lat, lng)
    ndvi     = get_ndvi_timeseries(coords)
    insights = compute_insights(ndvi, env, row["area_acres"])
    crops    = compute_crops(env)

    return {
        "field_id":   req.field_id,
        "area_acres": row["area_acres"],
        "centroid":   {"lat": lat, "lng": lng},
        "env":        env,
        "ndvi":       ndvi,
        "insights":   insights,
        "crops":      crops,
        "gee":        GEE_OK,
    }

@app.post("/sowing")
def get_sowing(req: SowingRequest):
    env   = get_env_data(req.latitude, req.longitude)
    crops = compute_crops(env)
    return {
        "latitude": req.latitude, "longitude": req.longitude,
        "env": env, "crops": crops,
        "season": _season(req.latitude),
        "location_name": _location_name(req.latitude, req.longitude),
    }

def _season(lat):
    m = datetime.datetime.now().month
    if lat >= 0:
        if m in [6,7,8,9]:    return "Kharif (Monsoon)"
        if m in [10,11,12,1]: return "Rabi (Winter)"
        return "Zaid (Summer)"
    return "Southern Hemisphere"

def _location_name(lat, lng):
    if 8<=lat<=37 and 68<=lng<=97:    return "India"
    if -35<=lat<=5 and 10<=lng<=52:   return "Africa"
    if 25<=lat<=50 and -125<=lng<=-65: return "North America"
    return "Your Location"

@app.get("/health")
def health():
    return {"status": "ok", "gee": GEE_OK, "version": "2.0"}

"""Local place names for the shared status-bar weather module."""

import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import tempfile
import urllib.parse
import urllib.request
from datetime import datetime

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "weather/location.json"
CITY_CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "weather/city.json"


class LocationError(Exception):
    pass


def configured_city():
    if not CONFIG.exists():
        return ""
    try:
        data = json.loads(CONFIG.read_text())
        if not isinstance(data, dict) or set(data) - {"city"}:
            raise ValueError("expected an object containing only city")
        city = data.get("city", "")
        if not isinstance(city, str):
            raise ValueError("city must be text")
        return city.strip()
    except (OSError, ValueError) as error:
        raise LocationError(f"Invalid weather/location.json: {error}") from error


def validate_fix(data):
    try:
        lat, lon = float(data["latitude"]), float(data["longitude"])
        accuracy, timestamp = float(data["accuracy"]), float(data["timestamp"])
        if not all(math.isfinite(x) for x in (lat, lon, accuracy, timestamp)):
            raise ValueError("non-finite location")
        if not -90 <= lat <= 90 or not -180 <= lon <= 180:
            raise ValueError("invalid coordinates")
        if not 0 <= accuracy <= 10000:
            raise ValueError("location uncertainty exceeds 10 km")
        if not -60 <= time.time() - timestamp <= 300:
            raise ValueError("location fix is older than 5 minutes")
        return lat, lon, accuracy
    except (KeyError, TypeError, ValueError) as error:
        raise LocationError(f"Unusable device location: {error}") from error


def run_helper(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=25)
    except subprocess.TimeoutExpired as error:
        raise LocationError("Location timed out; check location permission and Wi-Fi") from error
    except OSError as error:
        raise LocationError("Location helper could not start; see weather/README.md") from error
    if result.returncode:
        if "Location services are disabled or location access denied" in result.stdout:
            raise LocationError("Allow CoreLocationCLI in System Settings → Privacy & Security → Location Services")
        if "No module named 'gi'" in result.stderr or "Namespace Geoclue not available" in result.stderr:
            raise LocationError("Install GeoClue and Python GObject bindings; see weather/README.md")
        raise LocationError("Location helper failed; check location permission, Wi-Fi and weather/README.md")
    try:
        data = json.loads(result.stdout)
        if not isinstance(data, dict):
            raise ValueError("expected an object")
        return data
    except ValueError as error:
        raise LocationError("Location helper returned invalid data") from error


def mac_location():
    binary = shutil.which("CoreLocationCLI")
    if not binary:
        # GUI-launched bars may not inherit Homebrew's PATH.
        app = Path("/Applications/CoreLocationCLI.app/Contents/MacOS/CoreLocationCLI")
        if app.is_file():
            binary = str(app)
    if not binary:
        raise LocationError("Install CoreLocationCLI: brew install --cask corelocationcli")
    # --json also performs Apple's reverse geocoding, which can fail even when
    # positioning succeeds. Request only the native fix; both OSes share geocoding.
    output = ('{"latitude":"%latitude","longitude":"%longitude",'
              '"h_accuracy":"%h_accuracy","time":"%time"}')
    data = run_helper([binary, "--format", output])
    try:
        timestamp = datetime.strptime(data["time"], "%Y-%m-%d %H:%M:%S %z").timestamp()
    except (KeyError, TypeError, ValueError) as error:
        raise LocationError("Core Location returned an invalid timestamp") from error
    return {
        "latitude": data.get("latitude"), "longitude": data.get("longitude"),
        "accuracy": data.get("h_accuracy"), "timestamp": timestamp,
        "source": "Core Location",
    }


def geoclue_location():
    # Run in the system Python so distro-provided introspection bindings are visible.
    import gi
    gi.require_version("Geoclue", "2.0")
    from gi.repository import Geoclue

    client = Geoclue.Simple.new_sync("weather-location", Geoclue.AccuracyLevel.NEIGHBORHOOD, None)
    fix = client.get_location()
    data = {
        "latitude": fix.get_property("latitude"),
        "longitude": fix.get_property("longitude"),
        "accuracy": fix.get_property("accuracy"),
        "timestamp": fix.get_property("timestamp")[0],
        "source": "GeoClue",
    }
    return data


def address_label(address, detailed):
    def first(keys):
        return next((address[key].strip() for key in keys
                     if isinstance(address.get(key), str) and address[key].strip()), "")

    city = first(("city", "town", "village", "municipality"))
    country = first(("country",))
    locality = first(("neighbourhood", "suburb", "quarter", "borough", "city_district")) if detailed else ""
    if locality:
        parts = (locality, city or country)
    elif city:
        parts = (city, country)
    else:
        raise ValueError("no locality returned")
    return ", ".join(dict.fromkeys(part for part in parts if part))


def city_name(lat, lon, accuracy):
    query = f"{lat:.4f},{lon:.4f}"
    zoom = 14 if accuracy <= 1000 else 10
    try:
        cached = json.loads(CITY_CACHE.read_text())
        if (cached["query"] == query and cached["zoom"] == zoom
                and 0 <= time.time() - cached["timestamp"] < 86400
                and isinstance(cached["label"], str) and cached["label"]):
            return cached["label"]
    except (OSError, ValueError, KeyError, TypeError):
        pass
    params = urllib.parse.urlencode({"lat": f"{lat:.4f}", "lon": f"{lon:.4f}",
                                    "format": "jsonv2", "zoom": zoom, "accept-language": "en",
                                    "layer": "address"})
    request = urllib.request.Request("https://nominatim.openstreetmap.org/reverse?" + params,
                                     headers={"User-Agent": "status-bar-weather/1.0"})
    # All CLI modes hold refresh.lock, so concurrent clicks/probes cannot exceed
    # Nominatim's one-request-per-second limit. Cache repeated queries for a day.
    time.sleep(1)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            address = json.load(response)["address"]
        if not isinstance(address, dict):
            raise ValueError("invalid address returned")
        label = address_label(address, detailed=zoom == 14)
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise LocationError("Device located, but city lookup is unavailable; click to retry") from error
    CITY_CACHE.parent.mkdir(parents=True, exist_ok=True)
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile("w", dir=CITY_CACHE.parent, delete=False) as stream:
            temp_name = stream.name
            json.dump({"query": query, "zoom": zoom, "timestamp": time.time(), "label": label}, stream)
        os.replace(temp_name, CITY_CACHE)
    finally:
        if temp_name and os.path.exists(temp_name):
            os.unlink(temp_name)
    return label


def detect_location(city=""):
    if city:
        return {"query": city, "label": city, "source": "Configured city"}
    if sys.platform == "darwin":
        data = mac_location()
    elif sys.platform.startswith("linux"):
        data = run_helper(["/usr/bin/python3", str(Path(__file__).resolve()), "--geoclue"])
    else:
        raise LocationError("Automatic location requires macOS or Linux")
    lat, lon, accuracy = validate_fix(data)
    label = city_name(lat, lon, accuracy)
    return {"query": f"{lat:.4f},{lon:.4f}", "label": label,
            "source": data["source"], "accuracy": accuracy}


if __name__ == "__main__":
    try:
        if sys.argv[1:] != ["--geoclue"]:
            raise LocationError("Use weather.py --location for diagnostics")
        print(json.dumps(geoclue_location()))
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

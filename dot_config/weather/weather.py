#!/usr/bin/env python3
"""Shared SketchyBar/Waybar weather output with native device location."""

import argparse
import fcntl
import html
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request

from location import LocationError, configured_city, detect_location

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "weather"
CACHE_FILE = CACHE_DIR / "current.json"
TTL = 240  # Expire before the next five-minute bar tick, allowing for fetch time.

WEATHER_CODES = {
    "113": "☀️",
    "116": "⛅️",
    "119": "☁️",
    "122": "☁️",
    "143": "🌫",
    "176": "🌦",
    "179": "🌧",
    "182": "🌧",
    "185": "🌧",
    "200": "⛈",
    "227": "🌨",
    "230": "❄️",
    "248": "🌫",
    "260": "🌫",
    "263": "🌧",
    "266": "🌧",
    "281": "🌧",
    "284": "🌧",
    "293": "🌧",
    "296": "🌧",
    "299": "🌧",
    "302": "🌧",
    "305": "🌧",
    "308": "🌧",
    "311": "🌧",
    "314": "🌧",
    "317": "🌧",
    "320": "🌨",
    "323": "🌨",
    "326": "🌨",
    "329": "❄️",
    "332": "❄️",
    "335": "❄️",
    "338": "❄️",
    "350": "🌧",
    "353": "🌧",
    "356": "🌧",
    "359": "🌧",
    "362": "🌨",
    "365": "🌨",
    "368": "🌨",
    "371": "❄️",
    "374": "🌨",
    "377": "🌨",
    "386": "⛈",
    "389": "🌩",
    "392": "⛈",
    "395": "❄️",
}


def load_cache():
    try:
        data = json.loads(CACHE_FILE.read_text())
        if (isinstance(data, dict) and isinstance(data.get("result"), dict)
                and all(isinstance(data["result"].get(k), str) for k in ("text", "tooltip", "url"))
                and isinstance(data.get("timestamp"), (int, float))):
            return data
    except (OSError, ValueError):
        pass
    return None


def save_cache(result, city):
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile("w", dir=CACHE_DIR, delete=False, encoding="utf-8") as stream:
            temp_name = stream.name
            json.dump({"timestamp": time.time(), "city": city, "result": result}, stream)
        os.replace(temp_name, CACHE_FILE)
    finally:
        if temp_name and os.path.exists(temp_name):
            os.unlink(temp_name)


def fetch_weather(location):
    # The browser and forecast always use exactly the same resolved location.
    url = "https://wttr.in/" + urllib.parse.quote(location["query"], safe="")
    request = urllib.request.Request(url + "?format=j1", headers={"User-Agent": "status-bar-weather/1.0"})
    with urllib.request.urlopen(request, timeout=15) as response:
        data = json.load(response)
    current = data["current_condition"][0]
    temp = current["temp_C"]
    icon = WEATHER_CODES.get(current["weatherCode"], "✨")
    lines = [f"📍 {location['label']}",
             f"{current['weatherDesc'][0]['value']} {temp}°C",
             f"Feels like: {current['FeelsLikeC']}°C",
             f"Wind: {current['windspeedKmph']} km/h",
             f"Humidity: {current['humidity']}%"]
    return {"text": f"{temp}°C {icon}", "tooltip": "\n".join(lines),
            "class": "weather", "url": url}


def weather(force=False):
    city = configured_city()
    cached = load_cache()
    # A changed override must never reuse the previous location's weather.
    if cached and cached.get("city") != city:
        cached = None
    if cached and not force and 0 <= time.time() - cached["timestamp"] < TTL:
        return cached["result"]
    try:
        result = fetch_weather(detect_location(city))
        save_cache(result, city)
        return result
    except Exception as error:
        if isinstance(error, LocationError):
            reason = str(error)
        else:
            reason = "Weather service unavailable; click to retry"
        if cached:
            result = dict(cached["result"])
            age = max(0, int((time.time() - cached["timestamp"]) / 60))
            result["tooltip"] = (f"Last known weather · {age} min old\n" + result["tooltip"]
                                 + f"\n\n⚠️ {reason}")
            result["class"] = "stale"
            return result
        return {"text": "☔", "tooltip": reason, "class": "unavailable"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--refresh", "-r", action="store_true")
    mode.add_argument("--open", "-o", action="store_true")
    mode.add_argument("--location", action="store_true", help="probe location without fetching weather")
    args = parser.parse_args()
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        # Clicks, refresh timers and Linux network hooks can run concurrently.
        with (CACHE_DIR / "refresh.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.location:
                print(json.dumps(detect_location(configured_city())))
                return 0
            result = weather(args.refresh)
    except (OSError, LocationError) as error:
        if args.location:
            print(str(error), file=sys.stderr)
            return 1
        result = {"text": "☔", "tooltip": str(error), "class": "unavailable"}
    if args.open:
        if "url" not in result:
            print(result["tooltip"], file=sys.stderr)
            return 1
        subprocess.Popen(["open" if sys.platform == "darwin" else "xdg-open", result["url"]],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        # Waybar interprets tooltip markup; SketchyBar displays plain text.
        if sys.platform.startswith("linux"):
            result = dict(result, tooltip=html.escape(result["tooltip"]))
        print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())

import urllib.request
import urllib.parse
import json
import os
import sys
import time
import tempfile
import subprocess

CACHE_FILE = os.path.expanduser("~/.cache/waybar-weather.json")
TTL = 1500  # 25 minutes

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
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def save_cache(data):
    try:
        cache_dir = os.path.dirname(CACHE_FILE)
        os.makedirs(cache_dir, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            "w", dir=cache_dir, delete=False, encoding="utf-8"
        ) as tf:
            json.dump(data, tf)
            temp_name = tf.name
        os.replace(temp_name, CACHE_FILE)
    except Exception:
        pass


if "--open" in sys.argv or "-o" in sys.argv:
    cached_data = load_cache()
    url = "https://wttr.in/"
    if cached_data and isinstance(cached_data, dict) and "url" in cached_data:
        url = cached_data["url"]
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    subprocess.Popen(
        [opener, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    sys.exit(0)

force_refresh = "--refresh" in sys.argv or "-r" in sys.argv

if not force_refresh and os.path.exists(CACHE_FILE):
    try:
        if time.time() - os.path.getmtime(CACHE_FILE) < TTL:
            cached_data = load_cache()
            if cached_data and isinstance(cached_data, dict) and "text" in cached_data:
                print(json.dumps(cached_data))
                sys.exit(0)
    except Exception:
        pass

try:
    location_str = ""
    city_str = ""
    try:
        req_loc = urllib.request.Request(
            "http://ip-api.com/json", headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req_loc, timeout=5) as resp_loc:
            loc_data = json.loads(resp_loc.read().decode())
            if loc_data.get("status") == "success":
                lat = loc_data.get("lat")
                lon = loc_data.get("lon")
                city = loc_data.get("city")
                country = loc_data.get("country")
                if lat is not None and lon is not None:
                    location_str = f"{lat},{lon}"
                if city:
                    city_str = f"{city}" + (f", {country}" if country else "")
    except Exception:
        pass

    url_fetch = (
        f"https://wttr.in/{urllib.parse.quote(location_str)}?format=j1"
        if location_str
        else "https://wttr.in/?format=j1"
    )
    url_browser = (
        f"https://wttr.in/{urllib.parse.quote(city_str or location_str)}"
        if (city_str or location_str)
        else "https://wttr.in/"
    )

    req = urllib.request.Request(url_fetch, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=5) as response:
        data = json.loads(response.read().decode())

    current = data["current_condition"][0]

    temp = current["temp_C"]
    feels_like = current["FeelsLikeC"]
    desc = current["weatherDesc"][0]["value"]
    code = current["weatherCode"]
    humidity = current["humidity"]
    wind = current["windspeedKmph"]

    icon = WEATHER_CODES.get(code, "✨")

    text = f"{temp}°C {icon}"
    tooltip_lines = []
    if city_str:
        tooltip_lines.append(f"📍 {city_str}")
    tooltip_lines.extend(
        [
            f"{desc} {temp}°C",
            f"Feels like: {feels_like}°C",
            f"Wind: {wind}Km/h",
            f"Humidity: {humidity}%",
        ]
    )
    tooltip = "\n".join(tooltip_lines)

    result = {"text": text, "tooltip": tooltip, "class": "weather", "url": url_browser}
    save_cache(result)
    print(json.dumps(result))

except Exception as e:
    cached_data = load_cache()
    if cached_data and isinstance(cached_data, dict) and "tooltip" in cached_data:
        if "⚠️ Using cached weather" not in cached_data["tooltip"]:
            cached_data["tooltip"] += "\n\n⚠️ Using cached weather (network unreachable)"
        print(json.dumps(cached_data))
    else:
        print(
            json.dumps(
                {
                    "text": "☔",
                    "tooltip": "Weather unavailable (Offline)\nClick to refresh when online",
                    "class": "offline",
                }
            )
        )

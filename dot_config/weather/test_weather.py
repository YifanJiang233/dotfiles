import json
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch
import io

import location
import weather


LONDON = {"query": "51.5074,-0.1278", "label": "London, United Kingdom",
          "source": "Core Location", "accuracy": 100}
FORECAST = {"current_condition": [{"temp_C": "18", "FeelsLikeC": "17",
             "weatherCode": "113", "weatherDesc": [{"value": "Clear"}],
             "humidity": "65", "windspeedKmph": "12"}]}


class WeatherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        for module, name, value in [(weather, "CACHE_DIR", root),
                                    (weather, "CACHE_FILE", root / "current.json"),
                                    (location, "CONFIG", root / "location.json"),
                                    (location, "CITY_CACHE", root / "city.json")]:
            p = patch.object(module, name, value)
            p.start()
            self.addCleanup(p.stop)

    def cached(self, city="", age=0):
        weather.CACHE_FILE.write_text(json.dumps({"city": city, "timestamp": time.time()-age,
            "result": {"text": "13°C", "tooltip": "📍 Maidenhead, United Kingdom",
                       "url": "https://wttr.in/Maidenhead", "class": "weather"}}))

    def test_refresh_replaces_maidenhead_with_native_london(self):
        self.cached()
        with patch.object(weather, "detect_location", return_value=LONDON), patch.object(
                weather.urllib.request, "urlopen", return_value=io.StringIO(json.dumps(FORECAST))) as fetch:
            result = weather.weather(force=True)
        self.assertEqual(result["tooltip"].splitlines()[0], "📍 London, United Kingdom")
        self.assertNotIn("Maidenhead", weather.CACHE_FILE.read_text())
        self.assertEqual(fetch.call_args.args[0].full_url, result["url"] + "?format=j1")
        self.assertIn("51.5074%2C-0.1278", result["url"])

    def test_override_bypasses_native_location(self):
        location.CONFIG.write_text('{"city":"London, UK"}')
        with patch.object(location, "mac_location", side_effect=AssertionError("native called")):
            result = location.detect_location(location.configured_city())
        self.assertEqual(result["query"], "London, UK")
        self.assertEqual(result["source"], "Configured city")

    def test_changed_override_does_not_reuse_old_cache_even_offline(self):
        self.cached(city="Paris")
        location.CONFIG.write_text('{"city":"London, UK"}')
        with patch.object(weather, "fetch_weather", side_effect=OSError("offline")):
            result = weather.weather()
        self.assertEqual(result["class"], "unavailable")
        self.assertNotIn("Maidenhead", result["tooltip"])

    def test_recent_cache_avoids_location_request(self):
        self.cached()
        with patch.object(weather, "detect_location", side_effect=AssertionError("native called")):
            self.assertEqual(weather.weather()["class"], "weather")

    def test_permission_failure_labels_cached_location_as_last_known(self):
        self.cached(age=600)
        before = weather.CACHE_FILE.read_text()
        with patch.object(weather, "detect_location", side_effect=location.LocationError("Permission denied")):
            result = weather.weather()
        self.assertEqual(result["class"], "stale")
        self.assertTrue(result["tooltip"].startswith("Last known weather"))
        self.assertIn("Permission denied", result["tooltip"])
        self.assertEqual(weather.CACHE_FILE.read_text(), before)

    def test_no_ip_lookup_when_native_unavailable(self):
        with patch.object(weather, "detect_location", side_effect=location.LocationError("Permission denied")), patch.object(
                weather.urllib.request, "urlopen", side_effect=AssertionError("network called")):
            self.assertEqual(weather.weather(force=True)["class"], "unavailable")

    def test_bad_override_is_not_silently_ignored(self):
        for content in ('[]', '{"city":42}', '{"ctiy":"London"}', 'invalid'):
            with self.subTest(content=content):
                location.CONFIG.write_text(content)
                with self.assertRaises(location.LocationError):
                    location.configured_city()

    def test_old_cache_format_is_ignored(self):
        weather.CACHE_FILE.write_text('{"text":"13°C","tooltip":"Maidenhead"}')
        self.assertIsNone(weather.load_cache())

    def test_fix_validation(self):
        fix = {"latitude": 51.5, "longitude": -0.12, "accuracy": 100, "timestamp": time.time()}
        self.assertEqual(location.validate_fix(fix), (51.5, -0.12, 100))
        for field, value in [("latitude", float("nan")), ("longitude", 181),
                             ("accuracy", -1), ("accuracy", 20000),
                             ("timestamp", time.time()-601)]:
            with self.subTest(field=field, value=value), self.assertRaises(location.LocationError):
                location.validate_fix(dict(fix, **{field: value}))

    def test_macos_provider_parses_native_json(self):
        data = {"latitude": "51.5", "longitude": "-0.12", "h_accuracy": "100",
                "time": time.strftime("%Y-%m-%d %H:%M:%S +0000", time.gmtime()),
                "locality": "London", "country": "United Kingdom"}
        with patch.object(location.sys, "platform", "darwin"), patch.object(
                location.shutil, "which", return_value="CoreLocationCLI"), patch.object(
                location, "run_helper", return_value=data), patch.object(
                location, "city_name", return_value=LONDON["label"]):
            self.assertEqual(location.detect_location()["label"], LONDON["label"])

    def test_linux_dispatch_uses_system_python_and_validates_fix(self):
        fix = {"latitude": 51.5, "longitude": -0.12, "accuracy": 100,
               "timestamp": time.time(), "city": "London", "country": "United Kingdom", "source": "GeoClue"}
        with patch.object(location.sys, "platform", "linux"), patch.object(
                location, "run_helper", return_value=fix) as helper, patch.object(
                location, "city_name", return_value=LONDON["label"]):
            self.assertEqual(location.detect_location()["label"], LONDON["label"])
        self.assertEqual(helper.call_args.args[0][0], "/usr/bin/python3")

    def test_helper_timeout_and_bad_json(self):
        with patch.object(location.subprocess, "run", side_effect=subprocess.TimeoutExpired("helper", 25)):
            with self.assertRaisesRegex(location.LocationError, "timed out"):
                location.run_helper(["helper"])
        for output in ('bad', '[]'):
            with patch.object(location.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output)):
                with self.assertRaises(location.LocationError):
                    location.run_helper(["helper"])

    def test_reverse_geocoding_uses_city_and_caches_coordinates(self):
        response = {"address": {"city_district": "Hammersmith and Fulham",
                                "city": "Greater London", "country": "United Kingdom"}}
        with patch.object(location.time, "sleep"), patch.object(location.urllib.request, "urlopen",
                return_value=io.StringIO(json.dumps(response))) as fetch:
            self.assertEqual(location.city_name(51.49, -0.21), "Greater London, United Kingdom")
            self.assertEqual(location.city_name(51.49, -0.21), "Greater London, United Kingdom")
            self.assertEqual(fetch.call_count, 1)
            self.assertIn("zoom=10", fetch.call_args.args[0].full_url)

    def test_reverse_lookup_failure_does_not_invent_a_city(self):
        with patch.object(location.time, "sleep"), patch.object(location.urllib.request, "urlopen",
                return_value=io.StringIO('{"address":{"country":"United Kingdom"}}')):
            with self.assertRaisesRegex(location.LocationError, "city lookup"):
                location.city_name(51.49, -0.21)

    def test_macos_does_not_request_apples_reverse_geocoder(self):
        with patch.object(location.shutil, "which", return_value="CoreLocationCLI"), patch.object(
                location, "run_helper", return_value={"time": "2026-09-08 12:00:00 +0000"}) as helper:
            location.mac_location()
        self.assertEqual(helper.call_args.args[0][1], "--format")
        self.assertNotIn("%locality", helper.call_args.args[0][2])


if __name__ == "__main__":
    unittest.main()

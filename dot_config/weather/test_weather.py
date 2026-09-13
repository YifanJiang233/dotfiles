import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import ANY, Mock, patch
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

    def test_waybar_tooltip_lines_are_centered_without_affecting_single_lines(self):
        self.assertEqual(weather.centered_tooltip("123456\n12"), "123456\n\u00a0\u00a012")
        self.assertEqual(weather.centered_tooltip("📍 A\n123456"), "\u00a0📍 A\n123456")
        self.assertEqual(weather.centered_tooltip("Weather unavailable"), "Weather unavailable")

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
        with patch.object(weather, "fetch_weather", side_effect=OSError("offline")), \
                patch("sys.stderr", io.StringIO()):
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
        errors = io.StringIO()
        with patch.object(weather, "detect_location", side_effect=location.LocationError("Permission denied")), \
                patch("sys.stderr", errors):
            result = weather.weather()
        self.assertEqual(result["class"], "stale")
        self.assertTrue(result["tooltip"].startswith("Last known weather"))
        self.assertIn("Permission denied", result["tooltip"])
        self.assertIn("Permission denied", errors.getvalue())
        self.assertEqual(weather.CACHE_FILE.read_text(), before)

    def test_no_network_lookup_when_native_unavailable(self):
        with patch.object(weather, "detect_location", side_effect=location.LocationError("Permission denied")), patch.object(
                weather.urllib.request, "urlopen", side_effect=AssertionError("network called")), \
                patch("sys.stderr", io.StringIO()):
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
                             ("accuracy", -1), ("accuracy", 25000),
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

    def test_linux_coarse_fix_never_reaches_reverse_geocoding(self):
        fix = {"latitude": 51.5, "longitude": -0.12, "accuracy": 25000,
               "timestamp": time.time(), "city": "London", "country": "United Kingdom", "source": "GeoClue"}
        with patch.object(location.sys, "platform", "linux"), patch.object(
                location, "run_helper", return_value=fix) as helper, patch.object(
                location, "city_name", side_effect=AssertionError("reverse geocoder called")):
            with self.assertRaisesRegex(location.LocationError, "uncertainty exceeds 10 km"):
                location.detect_location()
        self.assertEqual(helper.call_args.args[0][0], "/usr/bin/python3")

    def test_geoclue_requests_street_accuracy_so_wifi_bsss_are_sent(self):
        fix = SimpleNamespace(get_property=lambda name: {
            "latitude": 51.49, "longitude": -0.21, "accuracy": 35,
            "timestamp": (time.time(), 0),
        }[name])
        client = SimpleNamespace(get_location=lambda: fix)
        new_sync = Mock(return_value=client)
        geoclue = SimpleNamespace(
            AccuracyLevel=SimpleNamespace(STREET="street"),
            Simple=SimpleNamespace(new_sync=new_sync),
        )
        gi = ModuleType("gi")
        gi.require_version = Mock()
        repository = ModuleType("gi.repository")
        repository.Geoclue = geoclue
        repository.GLib = SimpleNamespace()
        gi.repository = repository

        with patch.dict(sys.modules, {"gi": gi, "gi.repository": repository}):
            result = location.geoclue_location()

        new_sync.assert_called_once_with("weather-location", "street", None)
        self.assertEqual(result["accuracy"], 35)

    def test_geoclue_waits_for_wifi_after_initial_geoip_fix(self):
        def fake_fix(accuracy):
            return SimpleNamespace(get_property=lambda name: {
                "latitude": 51.49, "longitude": -0.21, "accuracy": accuracy,
                "timestamp": (time.time(), 0),
            }[name])

        client = SimpleNamespace(current=fake_fix(25000))
        client.get_location = lambda: client.current
        client.connect = Mock(return_value=7)
        client.disconnect = Mock()
        loop = SimpleNamespace(quit=Mock())

        def run_loop():
            client.current = fake_fix(35)
            client.connect.call_args.args[1]()

        loop.run = run_loop
        glib = SimpleNamespace(
            MainLoop=Mock(return_value=loop),
            timeout_add_seconds=Mock(return_value=9),
            source_remove=Mock(),
            MainContext=SimpleNamespace(default=lambda: SimpleNamespace(
                find_source_by_id=lambda _source_id: True)),
        )
        geoclue = SimpleNamespace(
            AccuracyLevel=SimpleNamespace(STREET="street"),
            Simple=SimpleNamespace(new_sync=Mock(return_value=client)),
        )
        gi = ModuleType("gi")
        gi.require_version = Mock()
        repository = ModuleType("gi.repository")
        repository.Geoclue = geoclue
        repository.GLib = glib
        gi.repository = repository

        with patch.dict(sys.modules, {"gi": gi, "gi.repository": repository}):
            result = location.geoclue_location()

        self.assertEqual(result["accuracy"], 35)
        client.connect.assert_called_once_with("notify::location", ANY)
        client.disconnect.assert_called_once_with(7)
        glib.timeout_add_seconds.assert_called_once_with(15, loop.quit)
        glib.source_remove.assert_called_once_with(9)

    def test_helper_timeout_and_bad_json(self):
        with patch.object(location.subprocess, "run", side_effect=subprocess.TimeoutExpired("helper", 25)):
            with self.assertRaisesRegex(location.LocationError, "timed out"):
                location.run_helper(["helper"])
        for output in ('bad', '[]'):
            with patch.object(location.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output)):
                with self.assertRaises(location.LocationError):
                    location.run_helper(["helper"])

    def test_geoclue_dbus_timeout_has_actionable_message(self):
        failed = subprocess.CompletedProcess([], 1, "", "g-io-error-quark: Timeout was reached (24)")
        with patch.object(location.subprocess, "run", return_value=failed), self.assertRaisesRegex(
                location.LocationError, "GeoClue permission agent"):
            location.run_helper(["helper", "--geoclue"])

    def test_reverse_geocoding_uses_city_and_caches_coordinates(self):
        response = {"address": {"city_district": "Hammersmith and Fulham",
                                "city": "Greater London", "country": "United Kingdom"}}
        with patch.object(location.time, "sleep"), patch.object(location.urllib.request, "urlopen",
                return_value=io.StringIO(json.dumps(response))) as fetch:
            self.assertEqual(location.city_name(51.49, -0.21, 2000), "Greater London, United Kingdom")
            self.assertEqual(location.city_name(51.49, -0.21, 2000), "Greater London, United Kingdom")
            self.assertEqual(fetch.call_count, 1)
            self.assertIn("zoom=10", fetch.call_args.args[0].full_url)

    def test_reverse_lookup_failure_does_not_invent_a_city(self):
        with patch.object(location.time, "sleep"), patch.object(location.urllib.request, "urlopen",
                return_value=io.StringIO('{"address":{"country":"United Kingdom"}}')):
            with self.assertRaisesRegex(location.LocationError, "city lookup"):
                location.city_name(51.49, -0.21, 35)

    def test_precise_lookup_retries_at_city_level_and_caches_fallback(self):
        responses = [
            {"address": {"country": "United Kingdom"}},
            {"address": {"city": "London", "country": "United Kingdom"}},
        ]
        with patch.object(location.time, "sleep"), patch.object(
                location.urllib.request, "urlopen",
                side_effect=lambda *args, **kwargs: io.StringIO(json.dumps(responses.pop(0)))) as fetch:
            self.assertEqual(location.city_name(51.49, -0.21, 35), "London, United Kingdom")
            self.assertEqual(location.city_name(51.49, -0.21, 35), "London, United Kingdom")
        self.assertEqual(fetch.call_count, 2)
        self.assertIn("zoom=14", fetch.call_args_list[0].args[0].full_url)
        self.assertIn("zoom=10", fetch.call_args_list[1].args[0].full_url)

    def test_locality_priority_and_missing_fields(self):
        address = {"neighbourhood": "West Kensington", "suburb": "Fulham",
                   "borough": "Hammersmith and Fulham", "city": "London", "country": "United Kingdom"}
        self.assertEqual(location.address_label(address, True), "West Kensington, London")
        del address["neighbourhood"]
        self.assertEqual(location.address_label(address, True), "Fulham, London")
        del address["suburb"]
        self.assertEqual(location.address_label(address, True), "Hammersmith and Fulham, London")
        address["city_district"] = address.pop("borough")
        self.assertEqual(location.address_label(address, True), "Hammersmith and Fulham, London")
        self.assertEqual(location.address_label(address, False), "London, United Kingdom")
        del address["city_district"]
        self.assertEqual(location.address_label(address, True), "London, United Kingdom")
        self.assertEqual(location.address_label({"suburb": "London", "city": "London"}, True), "London")

    def test_accuracy_change_invalidates_locality_cache(self):
        address = {"neighbourhood": "Fulham", "city": "London", "country": "United Kingdom"}
        with patch.object(location.time, "sleep"), patch.object(location.urllib.request, "urlopen",
                side_effect=lambda *args, **kwargs: io.StringIO(json.dumps({"address": address}))) as fetch:
            self.assertEqual(location.city_name(51.49, -0.21, 1000), "Fulham, London")
            self.assertIn("zoom=14", fetch.call_args.args[0].full_url)
            self.assertEqual(location.city_name(51.49, -0.21, 1001), "London, United Kingdom")
            self.assertIn("zoom=10", fetch.call_args.args[0].full_url)
            self.assertEqual(fetch.call_count, 2)

    def test_old_city_cache_cannot_hide_new_locality(self):
        location.CITY_CACHE.write_text(json.dumps({"query": "51.4900,-0.2100",
            "timestamp": time.time(), "label": "Greater London, United Kingdom"}))
        with patch.object(location.time, "sleep"), patch.object(location.urllib.request, "urlopen",
                return_value=io.StringIO('{"address":{"suburb":"Fulham","city":"London"}}')):
            self.assertEqual(location.city_name(51.49, -0.21, 35), "Fulham, London")

    def test_macos_does_not_request_apples_reverse_geocoder(self):
        with patch.object(location.shutil, "which", return_value="CoreLocationCLI"), patch.object(
                location, "run_helper", return_value={"time": "2026-09-08 12:00:00 +0000"}) as helper:
            location.mac_location()
        self.assertEqual(helper.call_args.args[0][1], "--format")
        self.assertNotIn("%locality", helper.call_args.args[0][2])


if __name__ == "__main__":
    unittest.main()

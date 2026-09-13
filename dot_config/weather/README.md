# Shared weather module

SketchyBar and Waybar run `~/.config/weather/weather.py`. The output is Waybar
JSON (`text`, `tooltip`, `class`) with a browser `url`. Location is checked every
five minutes. Left-click refreshes immediately; right-click opens the forecast.

Automatic mode uses Core Location on macOS and GeoClue on Linux. Both return
coordinates, an accuracy radius and a timestamp. OpenStreetMap Nominatim supplies
the place name: neighbourhood/suburb first, then borough, then city. Local names
include the city for context, such as `Fulham, London`. If the reported uncertainty
exceeds 1 km, only the broader city name is used. Missing map detail also results
in a broader label. This changes the label, not the forecast provider or its
resolution; it does not guarantee Apple Weather's place names or forecasts.
Fixes older than five minutes or uncertain by more than 10 km are rejected.
Accepted coarse fixes use city-level labels and precise fixes use local labels.
Native services still depend on their positioning databases; the accuracy radius
is an estimate, not a guarantee.

If location or weather fails, the last successful forecast is marked **Last known
weather** with its age and the error. It is never refreshed in the cache on failure.
Changing a configured city invalidates the previous city's cached weather.

## macOS

Install `brew install --cask corelocationcli` (also declared in the Brewfile).
Enable Wi-Fi and allow **CoreLocationCLI** in System Settings → Privacy & Security
→ Location Services. Run the probe below to request access. If macOS blocks the
downloaded application, approve it through Privacy & Security first.

## Linux

Install GeoClue and Python GObject introspection bindings.
On Arch these are `geoclue` and `python-gobject`.
On Debian/Ubuntu these are `geoclue-2.0`, `python3-gi`, and `gir1.2-geoclue-2.0`.
The helper uses `/usr/bin/python3` so it can load distro-installed bindings.

Enable desktop location services and approve the `weather-location` application
through your desktop's GeoClue agent. The dotfiles install a matching hidden
desktop entry and start GeoClue's permission agent with the Sway session. GeoClue
needs a working positioning source, such as a configured Wi-Fi location service.
Installing GeoClue alone does not guarantee city accuracy.

On systems where `wpa_supplicant` denies its D-Bus API to the `geoclue`
service user, install the bundled administrator policy. It allows only bulk
property reads, Wi-Fi scans and scan-result signals; property writes and all
network-management methods remain denied. D-Bus cannot filter `GetAll` by the
interface named inside its message body, so this is the narrowest policy that
works with GeoClue's generated proxies.

```sh
sudo install -Dm644 ~/.config/weather/geoclue-wpa-supplicant.conf \
  /etc/dbus-1/system.d/geoclue-wpa-supplicant.conf
sudo systemctl reload dbus.service
sudo systemctl restart geoclue.service
```

The helper requests GeoClue's `STREET` accuracy level. GeoClue intentionally
omits Wi-Fi BSS identifiers at lower accuracy levels, which otherwise makes an
enabled Wi-Fi source fall back to coarse GeoIP positioning.

Run `~/.config/weather/install-geoclue-wifi-policy.sh` for guided installation
and verification. If the default BeaconDB provider has no coverage for the
nearby access points, the wizard can install `geoclue-wifi-provider.conf` as a
Positon fallback. Submission is disabled; this only performs location queries.

If the Sway permission agent is unavailable, explicitly authorize this module for
your own user in `/etc/geoclue/geoclue.conf` instead:

```ini
[weather-location]
allowed=true
system=true
users=YOUR_NUMERIC_UID
```

Replace `YOUR_NUMERIC_UID` with the output of `id -u`. Restart the `geoclue`
system service after changing its configuration. This is an administrator setup
step on the Linux machine; chezmoi does not change system location permissions.

## Stationary desktop override

Create `~/.config/weather/location.json` (or under `$XDG_CONFIG_HOME`) with:

```json
{"city": "London, UK"}
```

This bypasses native location and uses the configured city in the tooltip.
Remove the file or set it to `{}` to restore automatic location. The override is
machine-local and is not copied between computers by chezmoi.

## Diagnostics and tests

```sh
python3 ~/.config/weather/weather.py --location
python3 ~/.config/weather/weather.py --refresh
python3 -m unittest discover -s ~/.config/weather -p 'test_*.py'
```

The location probe prints the resolved city, coordinates, source and accuracy;
it exits nonzero with an actionable message on failure. Cached weather lives at
`~/.cache/weather/current.json` (or under `$XDG_CACHE_HOME`). City lookups are
cached for a day in `city.json` for matching coordinates and detail level. Requests are serialized
and limited to at most one per second. The coordinates (rounded to four decimal
places) are sent to Nominatim for the city name and wttr.in for the weather.
The city override sends only the configured city to wttr.in.

References: [CoreLocationCLI](https://github.com/fulldecent/corelocationcli),
[GeoClue configuration](https://man.archlinux.org/man/geoclue.5),
[Nominatim reverse geocoding](https://nominatim.org/release-docs/latest/api/Reverse/).
City data: [© OpenStreetMap contributors, ODbL](https://www.openstreetmap.org/copyright).

# Self-Hosted Jellyfin Cast Receiver

Hosts [jellyfin-chromecast](https://github.com/jellyfin/jellyfin-chromecast) — the web
receiver that runs on your Chromecast / Google TV device when you press "cast".

A stable and unstable receiver are already bundled with the Jellyfin server, so
this is for people who want their own receiver (custom fork, or a backup that keeps
working if the publicly hosted receiver breaks).

## What this is / isn't

- ✅ Serves the receiver files that the Cast device loads when you cast.
- ❌ Not a replacement for your Jellyfin server — it only receives the cast message
  (server address, user token, media item) and drives playback on the TV.
- ❌ No mDNS / discovery needed — Google's Cast infrastructure handles discovery via
  the registered application ID.

## Requirements

- Docker + Docker Compose
- Jellyfin **10.9.x or newer** (custom receiver registration in `system.xml` was added in 10.9)
- A server on your LAN with an IP (or resolvable domain) the Chromecast can reach
- A Google account and maybe $5 (to register the Cast application)

## Step 1 — Build & run

```bash
docker compose up -d --build
docker compose logs jellyfin-cast-receiver
```

Verify the files are being served:

```bash
curl -I http://localhost/main.js
# 200 OK — the receiver's bundle is up
```

## Step 2 — Make the receiver reachable from the TV

The URL the Cast device loads the receiver from is **the URL you register in the
Google Cast console** (next step), so it must be reachable from your LAN:

- Use `http://<server-lan-ip>` (e.g. `http://192.168.1.50:8080`).
- If the server IP changes (DHCP), reserve the IP in your router or use a LAN DNS
  name (e.g. Pi-hole/Unbound entry) instead.
- If the server is behind Docker bridge networking, the published port is what the
  device talks to — no extra configuration needed. If you also run Jellyfin in Docker
  with bridge networking, make sure the **Jellyfin** port (8096) is reachable the
  same way, since the 1receiver connects back to your Jellyfin server after the cast
  handshake.

## Step 3 — Register a Google Cast application

1. Go to the [Google Cast Application Registration](https://developers.google.com/cast/docs/registration) page (Google account required).
2. Click **Register**.
3. **Application Type: "Custom application"** (required — the standard receiver type
   is for Google's own apps).
4. Fill in a name/description (e.g. "Jellyfin Cast (self-hosted)").
5. **URL: `http://<server-lan-ip>`** — the address from Step 2.
6. Register, and copy the resulting **Application ID** (8 hex chars).

Note: changes to the URL in the console can take some time to propagate to devices;
if the device still loads an old receiver, clear it by casting something else once
or restarting the TV.

## Step 4 — Register the receiver with Jellyfin

Stop your Jellyfin server, then edit `system.xml` in Jellyfin's `configuration` folder
(e.g. `/var/lib/jellyfin/system.xml` on Linux, or your Docker volume mount).

If the file doesn't exist yet, or you want to see the current defaults, note that
the two bundled receivers are Stable `F007D354` and Unstable `6F511C87`.
Add your entry to the `<CastReceiverApplications>` list:

```xml
<CastReceiverApplications>
    <CastReceiverApplication>
        <Id>F007D354</Id>
        <Name>Stable</Name>
    </CastReceiverApplication>
    ....
    <!-- your self-hosted receiver -->
    <CastReceiverApplication>
        <Id>YOUR_CAST_APP_ID</Id>
        <Name>Jellyfin Self-Hosted</Name>
    </CastReceiverApplication>
</CastReceiverApplications>
```

(If `system.xml` already has a `<CastReceiverApplications>` section, just append your
`<CastReceiverApplication>` entry inside it. If the server auto-generates the section
on first run, it will contain the two defaults above.)

Restart Jellyfin again. Verify it's registered via the API:

```bash
curl -s http://JELLYFIN.HOST.LOCAL/System/Info | jq '.CastReceiverApplications'
```

Your new app should appear in the list [1].

## Step 5 — Select the receiver in a client

The receiver choice is **per-user**:

1. Open the Jellyfin web client (or Android app).
2. User icon → **Settings** → **Playback**.
3. **Google Cast version** → pick "Jellyfin Self-Hosted".

From now on, casting from that user will load your self-hosted receiver.

## Step 6 — Verify

1. Cast any movie/show from a client. The TV should go through the normal
   "Casting screen" and start playback.
2. To debug the receiver on the device:
   - On a Chrome browser, go to `http://chrome.cast.com/remote_debugging` and enable
     remote debugging for your Cast device.
   - Open `chrome://inspect` → **Cast devices** → **Inspect** on the receiver frame.
   - The Console tab shows the receiver's JS errors — the first place to look when
     playback fails.

## Updating the receiver

Change `TAG` in `docker-compose.yml` to the next release and rebuild:

```bash
TAG=v1.3.1 docker compose up -d --build
```

You don't need to touch the Cast console or `system.xml` — the app ID stays the same,
only the code behind it changes.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Cast button works, TV shows "ready to cast" but nothing plays | Receiver can't reach your **Jellyfin server** (8096) from the TV — check firewall/bridge networking, or use `network_mode: host` for Jellyfin on a NAS |
| `curl` to the receiver works but the TV can't load it | Wrong/old URL in the Cast console, or TV is on a different network/VLAN |
| Receiver option missing in Settings | `system.xml` entry malformed, or Jellyfin < 10.9 (feature not supported) |
| Receiver loads but shows a blank white screen | Open `chrome://inspect` (Step 6) and read the console errors |

## Uninstall

Remove the `<CastReceiverApplication>` entry from `system.xml`, restart Jellyfin,
and `docker compose down` on the receiver. You can also delete the app in the
Google Cast console.

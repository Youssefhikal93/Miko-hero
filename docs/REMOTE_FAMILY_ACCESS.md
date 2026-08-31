# Remote family access — steps for the AI PC

This is a self-contained work order for an agent (or a person) on the
**AI PC** (the machine running the Iam-hero bridge, Ollama, and ComfyUI).
Goal: let a family member far away (different country, any network) open the
hosted web app in a plain browser, pair with this PC, and generate/read
stories — **without installing anything on their device**.

## The approach

Tailscale Funnel gives this PC a permanent public HTTPS address
(`https://<pc-name>.<tailnet>.ts.net`) with a real certificate, forwarding to
the bridge on localhost. No router changes, no port forwarding, works behind
carrier-grade NAT. The bridge keeps listening only on `127.0.0.1`.

**Owner-accepted trade-off (do not "fix" it):** the bridge URL becomes
publicly reachable. Access is protected by the existing pairing system
(bearer tokens; 6-digit codes shown only on this PC's console, 2-minute
expiry, 5 attempts). Per-account separation ("each parent sees only their own
kids") is a future login feature, deliberately not part of this task. Do not
weaken pairing, and do not add port forwarding.

## Step 1 — install Tailscale on this PC

Install Tailscale (free personal plan), sign in, and in the admin console
enable **MagicDNS** and **HTTPS certificates**. Funnel may ask once to be
enabled for the tailnet; approve it.

## Step 2 — publish the bridge

The bridge listens on `127.0.0.1:8765` (confirm the port in
`bridge_config.json`). Publish it publicly over HTTPS:

```
tailscale funnel --bg 8765
```

Check `tailscale funnel status` — it prints the public URL, e.g.
`https://<pc-name>.<tailnet>.ts.net`. Verify from a phone on mobile data that
`https://<that-url>/health` answers. (Command syntax moves between Tailscale
versions; `tailscale funnel --help` is authoritative. The requirement:
public HTTPS on 443 → local port 8765.)

Make it survive reboots: Tailscale runs as a service and `--bg` persists the
funnel config; confirm after one reboot that `tailscale funnel status` still
shows it.

## Step 3 — allow the web app's origin

The hosted web app's origin (the Vercel URL the family opens, scheme + host,
no path) must be listed in `bridge_config.json`:

```jsonc
"allowedWebOrigins": ["https://<your-app>.vercel.app"]
```

Restart the bridge. Without this, the browser's cross-origin check blocks
every call and pairing never starts.

## Step 4 — pair the remote family member

1. They open the web app URL in any browser (phone or computer).
2. In parent settings, they enter the bridge address:
   `https://<pc-name>.<tailnet>.ts.net` — no port, HTTPS.
3. They tap pair. The 6-digit code appears **on this PC's console**.
4. The owner sends them the code (phone/WhatsApp); they enter it within
   2 minutes. Paired.
5. They create profiles for their own children, add photos, and generate.
   Jobs from all devices share this PC's GPU queue, one at a time — a busy
   queue means waiting, not failure.
6. After their first sync, their stories and illustrations are cached in
   their browser: reading works even while this PC is off. New generation
   and sync need the PC on.

Remind them: browser storage is per-browser — clearing site data removes the
offline copies (the master stays on this PC), and story files can always be
re-synced.

## Step 5 — verify end to end

1. From a device outside this network (mobile data), open the web app, pair,
   generate a short story for a test profile, and read it.
2. Turn the bridge off briefly and confirm the already-synced story still
   opens in that remote browser.
3. Confirm an unpaired request is rejected: `https://<url>/library` without a
   token must return an auth error, not data.

## Troubleshooting

- Pairing button does nothing / console shows nothing → almost always the
  origin is missing from `allowedWebOrigins`, or has a typo (must match the
  browser's address bar origin exactly).
- `funnel` refuses to start → HTTPS certificates not enabled in the Tailscale
  admin console, or funnel not approved for the tailnet.
- Works at home, fails remotely → the funnel is off (`tailscale funnel
  status`) or the PC is asleep; disable sleep/hibernation while the bridge
  should be reachable.

## Known limitations (owner is aware)

- Every paired device currently sees every profile and every story. A login /
  per-family separation feature is planned separately.
- The public URL makes the bridge's existence visible; pairing is the only
  gate. The pairing rate limit is global today — a future enhancement makes
  it per-peer.
- The PC must be on (and not asleep) for generation and sync.

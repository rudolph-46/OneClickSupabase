# Supabase on Railway — 100% Reliable Template

A production-ready, self-hosted Supabase stack built specifically for Railway.
Fixes every common failure in existing templates.

> **What makes this different?**
> — JWT keys are auto-generated on first boot (no manual steps)
> — All secrets share a single source via Railway reference variables (no mismatches)
> — Every Docker image is pinned to a known-good SHA (no surprise breakage)
> — Studio is locked to private networking only (no accidental public exposure)

---

## Architecture

```
Internet
    │
    ▼
┌─────────────────┐  public Railway domain
│   Kong Gateway  │  ← only service with a public URL
└────────┬────────┘
         │ private network
    ┌────┴─────────────────────────────────┐
    │                                      │
    ▼                                      ▼
┌──────────┐  ┌──────────┐  ┌───────────┐ ┌─────────┐
│ PostgREST│  │  GoTrue  │  │ Realtime  │ │ Storage │
│  (REST)  │  │  (Auth)  │  │ (Sockets) │ │  (S3)   │
└────┬─────┘  └────┬─────┘  └─────┬─────┘ └────┬────┘
     └──────────────┴──────────────┴─────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Postgres 15    │  ← starts first
                    └─────────────────┘

                    ┌─────────────────┐
                    │     Studio      │  ← private network only
                    └─────────────────┘
```

Services: `db` · `auth` · `rest` · `realtime` · `storage` · `studio` · `kong` · `init-jwt`

---

## Step-by-Step Deploy Guide

### Step 1 — Fork this repo

Fork to your own GitHub account. Railway requires a public repo for templates.

### Step 2 — Create a new Railway project

Go to [railway.com](https://railway.com) → New Project → Empty Project.

### Step 3 — Add Shared Variables

Go to **Project Settings → Shared Variables** and add these (Railway will
auto-generate secrets for variables that use `${{secret(N)}}` syntax):

| Variable | Value |
|---|---|
| `JWT_SECRET` | `${{secret(40)}}` |
| `POSTGRES_PASSWORD` | `${{secret(32)}}` |
| `DASHBOARD_USERNAME` | `supabase` |
| `DASHBOARD_PASSWORD` | `${{secret(20)}}` |
| `ANON_KEY` | *(leave blank — fill after Step 5)* |
| `SERVICE_ROLE_KEY` | *(leave blank — fill after Step 5)* |

### Step 4 — Deploy all services

Add each folder as a separate Railway service pointing to your forked repo.
Set the **Root Directory** for each service:

| Service name | Root Directory |
|---|---|
| `db` | `/db` |
| `auth` | `/auth` |
| `rest` | `/rest` |
| `realtime` | `/realtime` |
| `storage` | `/storage` |
| `studio` | `/studio` |
| `kong` | `/kong` |
| `init-jwt` | `/init-jwt` |

Paste the matching variables from `service-variables.env.example` into each
service's Variables tab.

> Services will fail on first deploy — that's expected. Postgres isn't ready
> and ANON_KEY is empty. Continue to the next step.

### Step 5 — Generate JWT keys

Open the `init-jwt` service deploy logs. You'll see output like:

```
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5...
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5...
```

Copy both values. Go to **Project Settings → Shared Variables** and fill in
`ANON_KEY` and `SERVICE_ROLE_KEY`.

### Step 6 — Set private domain references

For each service below, go to its Variables tab and confirm these reference
variables are set. Railway autocompletes `${{ServiceName.RAILWAY_PRIVATE_DOMAIN}}`:

```
DB_HOST              = ${{db.RAILWAY_PRIVATE_DOMAIN}}
PGRST_PRIVATE_HOST   = ${{rest.RAILWAY_PRIVATE_DOMAIN}}
GOTRUE_PRIVATE_HOST  = ${{auth.RAILWAY_PRIVATE_DOMAIN}}
REALTIME_PRIVATE_HOST = ${{realtime.RAILWAY_PRIVATE_DOMAIN}}
STORAGE_PRIVATE_HOST = ${{storage.RAILWAY_PRIVATE_DOMAIN}}
```

### Step 7 — Generate a public domain for Kong only

Go to the `kong` service → Settings → Generate Domain.
Copy the domain (e.g. `https://kong-production-xxxx.up.railway.app`).

Update the Shared Variable:
```
SUPABASE_PUBLIC_URL = https://kong-production-xxxx.up.railway.app
SITE_URL            = https://kong-production-xxxx.up.railway.app
```

### Step 8 — Redeploy all services

Trigger a redeploy on all services. Deploy order that matters:

1. `db` — must be healthy first
2. `auth`, `rest`, `realtime`, `storage` — in any order
3. `kong` — last (needs all upstreams ready)
4. `studio` — any time after `db`

### Step 9 — Verify

```bash
# Test the REST API
curl https://your-kong-domain.up.railway.app/rest/v1/ \
  -H "apikey: YOUR_ANON_KEY"

# Test Auth
curl https://your-kong-domain.up.railway.app/auth/v1/health

# Test Storage
curl https://your-kong-domain.up.railway.app/storage/v1/status \
  -H "apikey: YOUR_ANON_KEY"
```

All three should return 200. Studio is accessible via Railway's private network.

---

## Connecting Your App

```js
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://your-kong-domain.up.railway.app',  // SUPABASE_PUBLIC_URL
  'YOUR_ANON_KEY'                              // shared.ANON_KEY
)
```

That's it. Same API as Supabase Cloud.

---

## Troubleshooting

### Auth returns 500 on boot
GoTrue starts before Postgres is ready. Railway will auto-retry. Wait 60 seconds
and check again. If it keeps failing, check `DB_HOST` references the correct
private domain.

### JWT validation fails / 401 everywhere
The most common cause: `JWT_SECRET` is different across services.
Fix: ensure every service references `${{shared.JWT_SECRET}}`, not a
hardcoded value. Redeploy all services after fixing.

### Studio SQL editor shows Zod validation error
You are running `supabase/studio:2025.10.09-sha-433e578` which has a known bug.
The Dockerfiles in this repo pin to `2025.10.01-sha-8460121` which is stable.
If you upgraded Studio manually, revert the image tag.

### Realtime won't connect
WebSocket connections require the API gateway to forward upgrade requests.
Ensure Kong is routing `/realtime/v1/*` to the realtime service.
Check Railway's WebSocket support docs if connections drop immediately.

### Storage uploads fail
If using local file storage, the storage service needs a Railway Volume mounted
at `/var/lib/storage`. Add a volume in the service settings.
For production, switch to S3 by setting `STORAGE_BACKEND=s3` and the S3 vars.

---

## Upgrading Images

When a new Supabase version releases:

1. Test the new image tags in a new Railway environment (not production)
2. Verify Studio SQL editor, Auth, and Storage all work
3. Update the `FROM` line in the affected Dockerfile
4. Merge and Railway will redeploy automatically

Never change a Dockerfile image tag directly in production without staging first.

---

## License

Apache 2.0 — same as Supabase.

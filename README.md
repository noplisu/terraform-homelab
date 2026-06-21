# terraform-homelab

Infrastructure-as-code for a Synology NAS homelab: Docker services via Portainer, public access via a shared Cloudflare Tunnel.

## Architecture

```
Internet
    │
    ▼
books.<domain>  (Cloudflare DNS + proxy)
    │
    ▼
Cloudflare Tunnel "homelab"  (ingress rules in Terraform)
    │
    ▼
cloudflared container  ──►  stump:10801  (Docker network: homelab)
    │
    ▼
Stump (digital book library)
```

**Two layers:**

| Layer | Tool | Responsibility |
|-------|------|----------------|
| Edge | Terraform + Cloudflare | Tunnel, ingress, DNS |
| Runtime | Compose in Git + Portainer | Containers on the NAS |

Portainer is assumed to already be running (bootstrap). Service stacks and the tunnel connector are deployed by Terraform.

## Repository layout

```
terraform-homelab/
├── README.md
├── stacks/
│   ├── cloudflared/
│   │   └── docker-compose.yml
│   ├── homepage/
│   │   ├── docker-compose.yml
│   │   ├── config/           # Dashboard YAML (synced to NAS)
│   │   └── nginx/            # Basic auth reverse proxy config
│   ├── gateway/
│   │   ├── docker-compose.yml
│   │   └── nginx/conf.d/     # LAN edge routing (synced to NAS)
│   └── stump/
│       └── docker-compose.yml
└── terraform/
    ├── providers.tf      # Cloudflare + Portainer providers
    ├── variables.tf
    ├── tunnels.tf        # Tunnel, ingress, token
    ├── services.tf       # Public DNS records
    ├── portainer.tf      # Network + stack deployments
    ├── homepage_sync.tf  # SSH sync for Homepage config/nginx
    ├── gateway_sync.tf   # SSH sync for gateway nginx config
    └── terraform.tfvars  # Secrets (not committed)
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.x
- Synology NAS with Docker and **Portainer** running
- Domain on Cloudflare (zone active, nameservers pointed at Cloudflare)
- API tokens:
  - **Cloudflare**: Account Tunnel Write, Zone DNS Edit
  - **Portainer**: Access token (My account → Access tokens)

## Configuration

Create `terraform/terraform.tfvars` with your values (see `terraform/variables.tf` for the full list). This file is gitignored — never commit API keys or tokens.

### Required variables

| Variable | Description |
|----------|-------------|
| `cloudflare_api_token` | Cloudflare API token |
| `cloudflare_account_id` | Cloudflare account ID |
| `cloudflare_zone_id` | Zone ID for your domain |
| `domain` | Apex domain, e.g. `example.com` |
| `portainer_url` | Portainer API URL, e.g. `http://192.168.x.x:9000` |
| `portainer_api_key` | Portainer access token |
| `nas_ssh_user` | Synology SSH user (Homepage config sync) |
| `nas_ssh_password` | SSH password for that user (sensitive) |
| `nas_lan_ip` | IP of the Synology NAS

Optional: `nas_ssh_port` (default `22`).

## Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This will:

1. Create the Cloudflare tunnel and ingress rules
2. Create the `books.<domain>` DNS record
3. Create the `homelab` Docker network on the NAS
4. Deploy the Stump and cloudflared stacks (tunnel token injected automatically)

## Services

| Service | Stack | Public URL | LAN | Network |
|---------|-------|------------|-----|---------|
| Stump | `stacks/stump/` | `https://books.<domain>` | `:5050` | `homelab` |
| Gitea | `stacks/gitea/` | `https://gitea.<domain>` | `:3123` | `homelab` |
| Yopass | `stacks/yopass/` | `https://secret.<domain>` | `:4040` | `homelab` |
| Homepage | `stacks/homepage/` | — | `:7575` or `*.local` | `homepage` |
| Gateway | `stacks/gateway/` | — | `:8888` (edge) | host |
| cloudflared | `stacks/cloudflared/` | — | — | `homelab` |
| RustDesk | `stacks/rustdesk/` | — | host ports | host |

Only services with ingress rules in `terraform/tunnels.tf` and DNS in `terraform/services.tf` are reachable from the internet. Everything else stays on the LAN by default.

### Homepage config

Dashboard layout lives in `stacks/homepage/config/` (YAML in Git). Nginx config lives in `stacks/homepage/nginx/`. `terraform apply` syncs both to the NAS over SSH and restarts the containers when files change.

Domain and LAN IP in links come from Terraform env vars (`HOMEPAGE_VAR_DOMAIN`, `HOMEPAGE_VAR_NAS_IP`).

LAN-only (no tunnel ingress). Access remotely via Tailscale to the NAS IP on port `7575`, or via the gateway hostname on port `80` (see below).

#### LAN gateway (path routing)

A **gateway nginx** on port **8888** routes traffic on a single mDNS hostname by path. No extra DNS required — use **`*.local`** (DSM server name).

The gateway uses **`network_mode: host`** so it reaches Homepage and Web Station via `127.0.0.1` (Synology Docker does not expose published ports through `host.docker.internal`).

```text
Browser  →  *.local:80  (mDNS)
              ↓
       DSM reverse proxy  →  localhost:8888  (gateway-nginx, host network)
              ↓
       /phpmyadmin/*  →  Web Station (NAS IP :80)
       /*             →  Homepage (127.0.0.1:7575)
```

| Path | Backend |
|------|---------|
| `/phpmyadmin/` | Web Station (`${nas_lan_ip}:80`) |
| `/` | Homepage (`127.0.0.1:7575`) |

Nginx config is `stacks/gateway/nginx/default.conf.tpl` (rendered with `nas_lan_ip`), synced to the NAS as a single file mount.

**One-time setup (manual):**

1. **DSM reverse proxy** — Control Panel → Login Portal → Reverse Proxy: source `*.local` port `80` → destination `localhost:8888`.
2. **Remove** any rule that sent port 80 straight to Homepage `:7575`.
3. If phpMyAdmin fails, confirm `http://<nas-ip>/phpmyadmin/` works directly — gateway proxies to DSM port `80`.

Set in `terraform.tfvars`:

```hcl
homepage_lan_hostname = "*.local"
```

Direct access without the gateway still works at `http://<nas-ip>:7575`.

#### LAN access (mDNS)

**mDNS:** Your NAS broadcasts **`*.local`** from DSM → Control Panel → **Network** → server name. No router DNS or hosts file needed.

Use **`http://*.local`** for Homepage and phpMyAdmin (via gateway on port 80), or **`http://*.local:7575`** for Homepage directly. Set `homepage_lan_hostname = "*.local"` in tfvars so dashboard links and `HOMEPAGE_ALLOWED_HOSTS` match.

Override in `terraform.tfvars`:

```hcl
homepage_lan_hostname = "*.local"   # must match mDNS / browser Host header
```

Rename the NAS in DSM → the `.local` name changes too (then update this variable).

#### Synology SSH for Terraform (one-time)

Use a **dedicated user** — not your personal DSM account.

**1. Enable SSH on the NAS**

DSM → Control Panel → **Terminal & SNMP** → enable SSH (port 22). Do not forward port 22 on your router; LAN or Tailscale only.

**2. Create user `terraform`**

DSM → Control Panel → **User & Group** → Create:

| Setting | Value |
|---------|--------|
| Username | `terraform` |
| Password | Strong password (stored in `terraform.tfvars`) |
| Groups | **administrators** — required on Synology for `docker` CLI via SSH |

**3. Shared folder permission**

DSM → Control Panel → **Shared Folder** → `docker` → **Permissions** → give `terraform` **Read/Write**.



**4. Wire into Terraform**

In `terraform.tfvars` (gitignored):

```hcl
nas_ssh_user     = "terraform"
nas_ssh_password = "your-strong-password"
```

**Security notes:** `terraform` is in `administrators` — config sync uses `sudo docker` (password from `nas_ssh_password`, base64-encoded in the remote script). Keep SSH LAN/Tailscale-only.

## Adding a new public service

1. Add `stacks/<service>/docker-compose.yml` and attach it to the `homelab` network
2. Add a `portainer_stack` resource in `terraform/portainer.tf`
3. Add an ingress rule in `terraform/tunnels.tf`
4. Add a DNS record in `terraform/services.tf`
5. Run `terraform apply`

## Adding a private service (LAN only)

1. Add compose under `stacks/<service>/`
2. Add a `portainer_stack` in `terraform/portainer.tf`
3. Do **not** add ingress or DNS — it won't be exposed via the tunnel

## Network isolation

`cloudflared` only reaches containers on the `homelab` Docker network by name (e.g. `http://stump:10801`). Private services should use a different network or no tunnel ingress.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Tunnel inactive | Portainer → `cloudflared` stack logs |
| 502 on public URL | Both containers on `homelab`? Stump running? |
| Stump works locally, not remotely | Cloudflare tunnel status (Healthy?) |
| `terraform plan` drift | Avoid manual changes in Portainer/Cloudflare UI |
| Stack/DNS already exists on apply | Import into state (see below) |
| Homepage sync docker `permission denied` | Use `sudo` on the NAS for docker/chown. One-time as admin: `sudo chown -R terraform:users /volume1/docker/homepage` (stop homepage stack first if it still fails) |

### Importing existing resources

If a service was created manually before Terraform managed it, import instead of recreating:

```bash
cd terraform

# Portainer stack — ID from Portainer → Stacks → gitea (URL ends with /stack/<id>)
terraform import portainer_stack.gitea <stack_id>

# Cloudflare DNS — record ID from Cloudflare → DNS → gitea → API or dashboard
terraform import cloudflare_dns_record.gitea '<zone_id>/<dns_record_id>'

terraform plan   # should show no changes or only env/compose updates
```

Alternative: delete the manual stack/DNS record in the UI, then run `terraform apply` again.

## Roadmap

- [ ] Migrate additional services to `stacks/`
- [ ] Automate Portainer itself
- [ ] CI/CD (e.g. Gitea Actions) for `terraform apply`

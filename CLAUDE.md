# WireGuard on Azure Setup

## Project Overview
WireGuard VPN server on Azure (Bicep + cloud-init). Single-purpose: full-tunnel VPN — every client routes all traffic (`0.0.0.0/0, ::/0`) through the Azure VM for privacy on public WiFi, geo-shifting, etc.

## Prerequisites
- Azure subscription
- Azure CLI installed locally (Bicep CLI ships with it)

## Architecture
- Single Ubuntu 22.04 VM (Standard_B1s) running WireGuard
- Static Public IP, NSG allows UDP 51820 + TCP 22
- Each device has its own peer + private config file (one device per profile)

### IP Allocation

| Peer | IP |
|---|---|
| Azure VM (server) | 10.100.0.1 |
| ipad-pro | 10.100.0.2 |
| ipad-air | 10.100.0.3 |
| iphone | 10.100.0.4 |
| studio | 10.100.0.5 |
| macair | 10.100.0.6 |
| macpro | 10.100.0.7 |

To add/remove devices, edit `DEVICES` in `scripts/cloud-init.yaml` and redeploy (or generate new peers manually on the running VM).

## Performance Tuning (baked into cloud-init)
- **BBR** congestion control + `fq` qdisc — material gain on RTT > 30 ms
- **64 MB TCP send/receive buffers** — saturates BDP on long-distance flows
- **TCP MSS clamping** on `wg0` forward path — prevents path-MTU black holes
- **MTU 1380** on client side — avoids fragmentation under typical IPv6/cellular
- **TCP Fast Open + MTU probing** enabled

Real-world throughput from Seattle → westus2 with these tunings on a 1 Gbps home link:
- Cloudflare / nearby CDNs: 200-300 Mbps single-stream
- Distant single-stream (Hetzner Ashburn): ~50 Mbps (TCP/RTT physics, not the VPN)
- Multi-stream tools (`aria2c -x 16`) saturate the link for large downloads

## Resource Estimates (Monthly)
- B1s VM: ~$7.60
- Public IP: ~$3.65
- Storage: ~$0.10
- **Total: ~$11.35/month**

CPU on B1s is *not* the bottleneck for one user — load average stays near 0 even at 300 Mbps. Don't upgrade unless you have many concurrent users.

## Directory Structure
```
wireguard/
├── CLAUDE.md
├── main.bicep                # Bicep deployment template
├── parameters.json           # SSH public key parameter
├── scripts/
│   └── cloud-init.yaml       # VM bootstrap (installs WG, generates configs, applies tuning)
└── client-configs/           # (gitignored) downloaded client .conf files — contain private keys
```

## Deployment

```bash
az login
az group create --name rg-wireguard --location westus2
az deployment group create \
  --resource-group rg-wireguard \
  --template-file main.bicep \
  --parameters @parameters.json

# Get VM public IP
az vm show -d -g rg-wireguard -n vm-wireguard --query publicIps -o tsv

# Pull all client configs locally
mkdir -p client-configs
scp 'azureuser@<VM_IP>:/root/wireguard-clients/*.conf' ./client-configs/
```

> Note: the VM's `cloud-init.yaml` writes configs to `/root/...`, which requires SSH'ing as root or using `sudo cat` / `az vm run-command` to retrieve. For ad-hoc retrieval the cleanest is:
> ```
> az vm run-command invoke -g rg-wireguard -n vm-wireguard \
>   --command-id RunShellScript --scripts "cat /root/wireguard-clients/macair.conf"
> ```

## Adding a Device on a Running VM (no redeploy)

```bash
NAME=newdevice
SUFFIX=8   # next free 10.100.0.X
az vm run-command invoke -g rg-wireguard -n vm-wireguard --command-id RunShellScript --scripts "
  cd /etc/wireguard
  K=\$(wg genkey); P=\$(echo \$K | wg pubkey)
  IP=10.100.0.${SUFFIX}
  echo -e '\n[Peer]\n# ${NAME}\nPublicKey = '\$P'\nAllowedIPs = '\$IP'/32' >> wg0.conf
  cat > /root/wireguard-clients/${NAME}.conf <<EOF
[Interface]
PrivateKey = \$K
Address = \$IP/32
DNS = 1.1.1.1, 1.0.0.1
MTU = 1380

[Peer]
PublicKey = \$(cat server_public.key)
Endpoint = \$(curl -s ifconfig.me):51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
  TMP=\$(mktemp); wg-quick strip wg0 > \$TMP; wg syncconf wg0 \$TMP; rm \$TMP
  cat /root/wireguard-clients/${NAME}.conf
"
```

`wg syncconf` reloads peers without disconnecting active clients.

## Importing Profiles

- **iOS / iPadOS**: `qrencode -t ansiutf8 < client-configs/iphone.conf` and scan with WireGuard app (`+` → "Create from QR code")
- **macOS**: WireGuard.app → `File → Import Tunnel(s) from File…`
- **Linux**: `sudo cp foo.conf /etc/wireguard/wg0.conf && sudo systemctl enable --now wg-quick@wg0`

⚠️ Each `.conf` carries a unique private key — do **not** import the same file on two devices simultaneously, they'll fight over the IP and kick each other.

## Security
- Private keys live in `client-configs/` (gitignored)
- Server private key lives only on the VM (`/etc/wireguard/server_private.key`, mode 600)
- NSG allows only UDP 51820 + TCP 22 from anywhere — consider restricting SSH source IP for hardening
- Public key auth only on VM (password auth disabled in Bicep)

## Monitoring
```bash
az vm run-command invoke -g rg-wireguard -n vm-wireguard --command-id RunShellScript --scripts "wg show"
```
Look for `latest handshake` per peer — if missing, that client never connected (or its config is stale).

## Useful Links
- [WireGuard Quickstart](https://www.wireguard.com/quickstart/)
- [Azure Bicep docs](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [BBR background](https://research.google/pubs/bbr-congestion-based-congestion-control/)

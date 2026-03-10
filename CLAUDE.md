# WireGuard on Azure Setup

## Project Overview
Setting up a WireGuard VPN server on Azure using Bicep templates and Azure CLI for personal use across multiple devices (phones, computers, iPads) with two connection profiles:
- **VPN profile** — full tunnel, all traffic routed through Azure for privacy/security
- **Home profile** — split tunnel, only WireGuard subnet traffic, to reach home servers via their WireGuard IPs

## Prerequisites
- Azure subscription with $200 credits
- Azure CLI installed locally
- Bicep CLI installed (comes with Azure CLI v2.20.0+)

## Architecture
- Single Ubuntu VM running WireGuard (hub)
- Public IP for VPN access
- Network Security Group (NSG) with WireGuard port (51820/UDP)
- Devices connect with either VPN or Home profile (one at a time)
- Home servers maintain always-on WireGuard connections to the hub

### IP Allocation

| Peer | IP | Type |
|---|---|---|
| Azure VM (hub) | 10.100.0.1 | Server |
| Device 1 | 10.100.0.2 | Device (2 profiles) |
| Device 2 | 10.100.0.3 | Device (2 profiles) |
| Home Server 1 | 10.100.0.4 | Always-on server |
| Home Server 2 | 10.100.0.5 | Always-on server |
| Home Server 3 | 10.100.0.6 | Always-on server |

## Resource Estimates (Monthly)
- B1s VM (1 vCPU, 1 GB RAM): ~$7.60/month
- Public IP: ~$3.65/month
- Storage: ~$0.10/month
- Total: ~$11.35/month (should last ~17 months with $200 credits)

## Directory Structure
```
wireguard/
├── CLAUDE.md                # This file
├── main.bicep               # Bicep deployment template
├── parameters.json          # Deployment parameters
├── scripts/
│   ├── cloud-init.yaml      # Cloud-init config (generates all WireGuard configs on VM)
│   └── setup-home-server.sh # Script to set up WireGuard on home servers
└── client-configs/          # Downloaded client configurations
```

## Generated Config Files (on Azure VM)

After deployment, the VM generates 7 configs in `/root/wireguard-clients/`:

| File | Purpose | AllowedIPs |
|---|---|---|
| `device1-vpn.conf` | Device 1 full tunnel | `0.0.0.0/0, ::/0` |
| `device1-home.conf` | Device 1 home access | `10.100.0.0/24` |
| `device2-vpn.conf` | Device 2 full tunnel | `0.0.0.0/0, ::/0` |
| `device2-home.conf` | Device 2 home access | `10.100.0.0/24` |
| `server1.conf` | Home Server 1 | `10.100.0.0/24` |
| `server2.conf` | Home Server 2 | `10.100.0.0/24` |
| `server3.conf` | Home Server 3 | `10.100.0.0/24` |

Device VPN and Home profiles share the same key pair and IP. Only one profile is active at a time per device.

## Deployment Steps
1. Login to Azure
2. Create resource group
3. Deploy Bicep template
4. SSH into VM and retrieve config files
5. Set up home servers
6. Import profiles on devices

## Azure CLI Commands
```bash
# Login
az login

# Set subscription (if multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource group
az group create --name rg-wireguard --location eastus

# Deploy Bicep template
az deployment group create \
  --resource-group rg-wireguard \
  --template-file main.bicep \
  --parameters @parameters.json

# Get VM public IP
az vm show -d -g rg-wireguard -n vm-wireguard --query publicIps -o tsv

# SSH into VM and copy configs
scp azureuser@<VM_IP>:/root/wireguard-clients/*.conf ./client-configs/
```

## Using the Two Profiles on Devices

Import both `deviceN-vpn.conf` and `deviceN-home.conf` into the WireGuard app on your device. Only activate one at a time:

- **VPN profile** (`deviceN-vpn.conf`): Use when you want all internet traffic encrypted through Azure (public WiFi, privacy).
- **Home profile** (`deviceN-home.conf`): Use when you want to SSH into home servers via their WireGuard IPs (e.g., `ssh user@10.100.0.4`). Regular internet traffic goes through your normal connection.

## Setting Up Home Servers

1. Copy the server config to the home server:
   ```bash
   scp server1.conf user@home-server-1:~/
   ```

2. Run the setup script on the home server:
   ```bash
   sudo ./setup-home-server.sh server1.conf
   ```

   This installs WireGuard, copies the config, and enables the service to start on boot.

3. Verify the connection:
   ```bash
   sudo wg show
   ping 10.100.0.1  # ping the Azure hub
   ```

Repeat for each home server with its respective config file.

## Security Considerations
- Use strong keys for WireGuard (auto-generated)
- Limit NSG rules to only WireGuard port
- Regular OS updates on VM
- Backup private keys securely
- Home server configs use split tunnel (no internet traffic through Azure)

## Monitoring
- Azure Monitor for VM metrics
- `sudo wg show` on the VM to see connected peers
- `systemctl status wg-quick@wg0` to check service status

## Cost Optimization Tips
- Use B-series burstable VMs
- Stop VM when not needed for extended periods
- Consider Spot instances for non-critical usage

## Useful Links
- [WireGuard Documentation](https://www.wireguard.com/quickstart/)
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)

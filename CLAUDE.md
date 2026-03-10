# WireGuard on Azure Setup

## Project Overview
Setting up a WireGuard VPN server on Azure using Bicep templates and Azure CLI for personal use across multiple devices (phones, computers, iPads).

## Prerequisites
- Azure subscription with $200 credits
- Azure CLI installed locally
- Bicep CLI installed (comes with Azure CLI v2.20.0+)

## Architecture
- Single Ubuntu VM running WireGuard
- Public IP for VPN access
- Network Security Group (NSG) with WireGuard port (51820/UDP)
- Storage account for scripts and configurations

## Resource Estimates (Monthly)
- B1s VM (1 vCPU, 1 GB RAM): ~$7.60/month
- Public IP: ~$3.65/month
- Storage: ~$0.10/month
- Total: ~$11.35/month (should last ~17 months with $200 credits)

## Directory Structure
```
wireguard/
├── CLAUDE.md           # This file
├── bicep/
│   ├── main.bicep     # Main deployment template
│   ├── modules/       # Bicep modules
│   └── parameters/    # Environment parameters
├── scripts/
│   ├── setup-wireguard.sh  # VM setup script
│   └── generate-configs.sh # Client config generator
└── configs/           # Generated client configurations
```

## Deployment Steps
1. Login to Azure
2. Create resource group
3. Deploy Bicep template
4. Configure WireGuard on VM
5. Generate client configurations
6. Connect devices

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
  --template-file bicep/main.bicep \
  --parameters @bicep/parameters/prod.parameters.json

# Get VM public IP
az vm show -d -g rg-wireguard -n vm-wireguard --query publicIps -o tsv
```

## Security Considerations
- Use strong keys for WireGuard
- Limit NSG rules to only WireGuard port
- Enable Azure Firewall if needed
- Regular OS updates on VM
- Backup private keys securely

## Client Configuration
Each device will need:
- WireGuard client app
- Generated configuration file
- QR code for mobile devices

## Monitoring
- Azure Monitor for VM metrics
- Log Analytics for diagnostics
- Network Watcher for connectivity

## Cost Optimization Tips
- Use B-series burstable VMs
- Stop VM when not needed for extended periods
- Consider Spot instances for non-critical usage
- Use Azure Reserved Instances for long-term savings

## Useful Links
- [WireGuard Documentation](https://www.wireguard.com/quickstart/)
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
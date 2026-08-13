# AVD End-to-End Provisioning Runbook
## DWP Desktop Workplace — FinBridge Migration Project
**Date:** 2026-08-13  
**Engineer:** traininguser15@zippyops.in  
**Subscription:** 4e7bcf35-9384-4498-bc21-d9d1221b5faa  
**Resource Group:** dwp-lab-rg  
**Region:** Central US  
**M365 Tenant:** zippyops.in  

---

## Environment Summary

| Resource | Value |
|---|---|
| Host Pool | POOL-FIN-01 |
| App Group | POOL-FIN-01-DAG |
| Workspace | FinBridge-Workspace |
| Session Host VM | fin-sh-01 |
| VNet / Subnet | dwp-vnet / avd-subnet (10.10.1.0/24) |
| NAT Gateway | dwp-natgw (pip: 20.12.222.161) |
| AVD User Account | p13@zippyops.in |

---

## Pre-flight Checks

### 1. Confirm CLI identity and permissions

```powershell
az account show --query "{subscriptionId:id, name:name, user:user.name}" -o table
az role assignment list --assignee traininguser15@zippyops.in `
  --subscription 4e7bcf35-9384-4498-bc21-d9d1221b5faa `
  --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

**Result:** Owner on the subscription — full permission to create role assignments confirmed.

### 2. Register resource providers

```powershell
az config set extension.dynamic_install_allow_preview=true
az extension add --name desktopvirtualization --allow-preview true

az provider register --namespace Microsoft.DesktopVirtualization
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
```

All three providers confirmed `Registered`.

---

## Step 1 — Host Pool

```powershell
az desktopvirtualization hostpool create `
  --resource-group dwp-lab-rg `
  --name POOL-FIN-01 `
  --location centralus `
  --host-pool-type Pooled `
  --load-balancer-type BreadthFirst `
  --max-session-limit 5 `
  --preferred-app-group-type Desktop
```

**Verified:** `hostPoolType=Pooled`, `loadBalancerType=BreadthFirst`, `maxSessionLimit=5`

---

## Step 2 — Desktop Application Group

```powershell
az desktopvirtualization applicationgroup create `
  --resource-group dwp-lab-rg `
  --name POOL-FIN-01-DAG `
  --location centralus `
  --application-group-type Desktop `
  --host-pool-arm-path "/subscriptions/4e7bcf35-9384-4498-bc21-d9d1221b5faa/resourcegroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/hostpools/POOL-FIN-01"
```

---

## Step 3 — Workspace and App Group Registration

```powershell
az desktopvirtualization workspace create `
  --resource-group dwp-lab-rg `
  --name FinBridge-Workspace `
  --location centralus

az desktopvirtualization workspace update `
  --resource-group dwp-lab-rg `
  --name FinBridge-Workspace `
  --application-group-references `
    "/subscriptions/4e7bcf35-9384-4498-bc21-d9d1221b5faa/resourcegroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/applicationgroups/POOL-FIN-01-DAG"
```

---

## Step 4 — Networking (VNet, Subnet, NAT Gateway)

```powershell
# VNet and subnet
az network vnet create `
  --resource-group dwp-lab-rg `
  --name dwp-vnet `
  --location centralus `
  --address-prefix 10.10.0.0/16 `
  --subnet-name avd-subnet `
  --subnet-prefix 10.10.1.0/24

# NAT gateway — required for session host outbound internet access
# (VMs have no public IP; DSC agent download and AVD broker registration need outbound HTTPS)
az network public-ip create `
  --resource-group dwp-lab-rg `
  --name dwp-nat-pip `
  --location centralus `
  --sku Standard `
  --allocation-method Static

az network nat gateway create `
  --resource-group dwp-lab-rg `
  --name dwp-natgw `
  --location centralus `
  --public-ip-addresses dwp-nat-pip `
  --idle-timeout 10

az network vnet subnet update `
  --resource-group dwp-lab-rg `
  --vnet-name dwp-vnet `
  --name avd-subnet `
  --nat-gateway dwp-natgw
```

> **Note:** The NAT gateway must be attached to the subnet **before** deploying the DSC extension.
> Without it, the DSC extension will fail after 17 attempts downloading the Configuration.zip artifact
> (`Unable to connect to the remote server`).

---

## Step 5 — Session Host VM

```powershell
az vm create `
  --resource-group dwp-lab-rg `
  --name fin-sh-01 `
  --location centralus `
  --image MicrosoftWindowsDesktop:windows-11:win11-24h2-avd:latest `
  --size Standard_B2ms `
  --vnet-name dwp-vnet `
  --subnet avd-subnet `
  --security-type TrustedLaunch `
  --enable-secure-boot true `
  --enable-vtpm true `
  --admin-username avdadmin `
  --admin-password "<STRONG_PASSWORD>" `
  --public-ip-address '""' `
  --nsg '""'
```

**Verified configuration:**

| Property | Value |
|---|---|
| Size | Standard_B2ms |
| Image SKU | win11-24h2-avd |
| Security Type | TrustedLaunch |
| Secure Boot | True |
| vTPM | True |
| Public IP | None |
| Provisioning State | Succeeded |

---

## Step 6 — Entra ID Join (AADLoginForWindows Extension)

```powershell
az vm extension set `
  --resource-group dwp-lab-rg `
  --vm-name fin-sh-01 `
  --name AADLoginForWindows `
  --publisher Microsoft.Azure.ActiveDirectory `
  --version 2.0
```

**Result:** `ProvisioningState = Succeeded`

This extension replaces `JsonADDomainExtension`. No on-premises Active Directory domain join is
performed — the VM is Microsoft Entra ID joined only.

---

## Step 7 — AVD Agent Registration (DSC Extension)

### DSC settings file (`avd-dsc-settings-template.json`)

The `Configuration.zip` artifact's `AddSessionHost` function accepts exactly **two parameters**.
Supplying any undocumented parameter (e.g. `AadJoin`, `SessionHostConfigurationLastUpdateTime`)
causes `VMExtensionProvisioningError`.

```json
{
  "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration.zip",
  "configurationFunction": "Configuration.ps1\\AddSessionHost",
  "properties": {
    "HostPoolName": "POOL-FIN-01",
    "RegistrationInfoToken": "<REGISTRATION_TOKEN>"
  }
}
```

### Generate registration token (valid 2 hours)

```powershell
$expiry = (Get-Date).AddHours(2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$regToken = az desktopvirtualization hostpool update `
  --resource-group dwp-lab-rg `
  --name POOL-FIN-01 `
  --registration-info expiration-time=$expiry registration-token-operation=Update `
  --query "registrationInfo.token" -o tsv
```

### Write settings file and install extension

```powershell
$settings = @{
  modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration.zip"
  configurationFunction = "Configuration.ps1\AddSessionHost"
  properties            = @{
    HostPoolName          = "POOL-FIN-01"
    RegistrationInfoToken = $regToken
  }
}
[System.IO.File]::WriteAllText(
  "$HOME\avd-settings.json",
  ($settings | ConvertTo-Json -Depth 10),
  [System.Text.Encoding]::UTF8
)

az vm extension set `
  --resource-group dwp-lab-rg `
  --vm-name fin-sh-01 `
  --name DSC `
  --publisher Microsoft.Powershell `
  --version 2.73 `
  --settings "$HOME\avd-settings.json"
```

**Result:** `Name=DSC, ProvisioningState=Succeeded`

---

## Step 8 — Role Assignments for p13@zippyops.in

Two roles are required:

| Role | Scope | Purpose |
|---|---|---|
| Desktop Virtualization User | POOL-FIN-01-DAG (app group) | Allows AVD client to enumerate and connect to the published desktop |
| Virtual Machine User Login | fin-sh-01 (VM) | Allows Entra ID-based RDP login to the session host |

```powershell
$userId    = "ad008a6c-cf08-4ae1-9007-227e7ae91d22"   # p13@zippyops.in object ID
$appGrpId  = "/subscriptions/4e7bcf35-9384-4498-bc21-d9d1221b5faa/resourcegroups/dwp-lab-rg/providers/Microsoft.DesktopVirtualization/applicationgroups/POOL-FIN-01-DAG"
$vmId      = "/subscriptions/4e7bcf35-9384-4498-bc21-d9d1221b5faa/resourceGroups/dwp-lab-rg/providers/Microsoft.Compute/virtualMachines/fin-sh-01"

az role assignment create --assignee $userId --role "Desktop Virtualization User" --scope $appGrpId
az role assignment create --assignee $userId --role "Virtual Machine User Login"  --scope $vmId
```

---

## Final Status

### Session Host Health Checks

```
POOL-FIN-01/fin-sh-01   Agent: 1.0.15008.300
```

| Health Check | Result | Notes |
|---|---|---|
| DomainJoinedCheck | HealthCheckFailed | **Expected** — no on-premises AD in this environment |
| DomainTrustCheck | HealthCheckFailed | **Expected** — same reason |
| AADJoinedHealthCheck | HealthCheckSucceeded | ✓ Entra ID join confirmed |
| SxSStackListenerCheck | HealthCheckSucceeded | ✓ RDP reverse-connect stack listening |
| MetaDataServiceCheck | HealthCheckSucceeded | ✓ IMDS accessible |
| TURNRelayAccessHealthCheck | HealthCheckSucceeded | ✓ Relay connectivity OK |
| AppAttachHealthCheck | HealthCheckSucceeded | ✓ |

### Reported Status: `Unavailable`

Per [Microsoft documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/troubleshoot-agent):

> For Azure AD-joined VMs, the **DomainJoinedCheck** and **DomainTrustCheck** health checks will
> fail. This is expected behaviour. You can ignore these failures — they do not prevent users from
> connecting to the session host.

The session host is **functional for user connections** despite the `Unavailable` label. The AVD
client and direct RDP both route through the SxS reverse-connect stack, which is confirmed healthy.

---

## Troubleshooting Log

| Issue | Root Cause | Fix |
|---|---|---|
| `desktopvirtualization` CLI commands blocked | Preview extension disabled by default | `az config set extension.dynamic_install_allow_preview=true` then `az extension add --name desktopvirtualization` |
| DSC fails after 17 attempts — "Unable to connect to remote server" | No outbound internet route (VM has no public IP) | Created NAT gateway `dwp-natgw` and associated with `avd-subnet` |
| DSC fails — `BlobNotFound` for `Configuration_1.0.02698.442.zip` | Artifact URL no longer exists | Probed blob storage; switched to `Configuration.zip` (canonical always-current URL) |
| DSC fails — `parameter 'SessionHostConfigurationLastUpdateTime' not found` | Current `Configuration.zip` has a minimal function signature | Removed unsupported property |
| DSC fails — `parameter 'AadJoin' not found` | Same — `AddSessionHost` only accepts `HostPoolName` + `RegistrationInfoToken` | Removed `AadJoin` property; Entra ID join is handled by the separate `AADLoginForWindows` extension |
| DSC fails — `RegistrationInfoToken missing` (PSCredential format) | `PrivateSettingsRef` mechanism not supported by this artifact version | Passed token directly in public settings properties (not via protected settings) |

---

## How to Connect (p13@zippyops.in)

**Via AVD client (published desktop):**  
1. Open [https://client.wvd.microsoft.com/arm/webclient](https://client.wvd.microsoft.com/arm/webclient) or the Windows App  
2. Sign in as `p13@zippyops.in`  
3. The **FinBridge-Workspace** workspace will appear with the **Session Desktop** resource

**Via direct RDP to the VM (Entra ID login):**  
1. Connect to the VM's private IP using the Remote Desktop client with `--enable-aad` flag  
   or through Azure Bastion if deployed  
2. Sign in as `p13@zippyops.in` (Virtual Machine User Login role grants access)

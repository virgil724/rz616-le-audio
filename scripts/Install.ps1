<#
.SYNOPSIS
  Installs the MediaTek LE Audio ACX driver and the patched RZ616 Bluetooth driver.
  Run as Administrator, after booting with "Disable driver signature enforcement" (F7).

.PARAMETER PatchedInf
  Path to the patched mtkbtfilter.inf produced by Patch-MtkBtInf.ps1.

.PARAMETER AcxInf
  Path to mtkbtacx.inf from the "MediaTek LE Audio" package (signed, installs normally).
#>
param(
    [Parameter(Mandatory)] [string]$PatchedInf,
    [Parameter(Mandatory)] [string]$AcxInf
)
$ErrorActionPreference = 'Stop'
$hwid = 'USB\VID_0E8D&PID_0616&MI_00'

if (-not (Get-PnpDevice -PresentOnly | Where-Object InstanceId -like "$hwid*")) { throw "No device matching $hwid found" }

'== Adding mtkbtacx (LE Audio ACX driver) to the driver store'
pnputil /add-driver $AcxInf | Out-String

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NewDev {
    [DllImport("newdev.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool UpdateDriverForPlugAndPlayDevicesW(IntPtr hwnd, string hwid, string inf, int flags, out bool reboot);
}
'@
'== Installing patched Bluetooth driver (accept the "unverified publisher" prompt)'
$reboot = $false
$ok = [NewDev]::UpdateDriverForPlugAndPlayDevicesW([IntPtr]::Zero, $hwid, (Resolve-Path $PatchedInf).Path, 1, [ref]$reboot)  # 1 = INSTALLFLAG_FORCE
"UpdateDriver ok=$ok err=$([Runtime.InteropServices.Marshal]::GetLastWin32Error()) reboot=$reboot"
if (-not $ok) { throw 'Driver install failed' }

$bt = (Get-PnpDevice -PresentOnly | Where-Object InstanceId -like "$hwid*").InstanceId
Get-PnpDeviceProperty -InstanceId $bt -KeyName DEVPKEY_Device_DriverInfPath, DEVPKEY_Device_DriverInfSection, DEVPKEY_Device_DriverVersion |
    Format-Table KeyName, Data -AutoSize

'Done. Reboot normally (no F7), then run Check.ps1.'

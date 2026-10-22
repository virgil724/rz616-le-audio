<#
.SYNOPSIS
  Reinstalls the original (signed) MediaTek Bluetooth driver from the driver store
  and removes the patched package. Run as Administrator; works on a normal boot.
#>
$ErrorActionPreference = 'Stop'
$hwid = 'USB\VID_0E8D&PID_0616&MI_00'

$pkgs = Get-ChildItem "$env:WINDIR\INF\oem*.inf" | Where-Object { Select-String -Path $_.FullName -Pattern 'mtkbtfilterx.sys' -SimpleMatch -Quiet }
$patched = $pkgs | Where-Object { Select-String -Path $_.FullName -Pattern '^;CatalogFile' -Quiet }
$signed  = $pkgs | Where-Object { $patched.Name -notcontains $_.Name } |
    Sort-Object { [version](((Select-String -Path $_.FullName -Pattern '^DriverVer\s*=.*,\s*([\d.]+)').Matches[0].Groups[1].Value)) } -Descending |
    Select-Object -First 1
if (-not $signed) { throw 'No signed MediaTek Bluetooth package found in the driver store' }
"Original package: $($signed.Name)"

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NewDev {
    [DllImport("newdev.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool UpdateDriverForPlugAndPlayDevicesW(IntPtr hwnd, string hwid, string inf, int flags, out bool reboot);
}
'@
$reboot = $false
$ok = [NewDev]::UpdateDriverForPlugAndPlayDevicesW([IntPtr]::Zero, $hwid, $signed.FullName, 1, [ref]$reboot)
"UpdateDriver ok=$ok err=$([Runtime.InteropServices.Marshal]::GetLastWin32Error()) reboot=$reboot"

foreach ($p in $patched) { "Removing patched package $($p.Name)"; pnputil /delete-driver $p.Name | Out-String }
'Done. Reboot.'

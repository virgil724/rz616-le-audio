<#
.SYNOPSIS
  Builds a patched copy of MediaTek's mtkbtfilter.inf that enables LE Audio
  (in-band, no ACP/DSP) for the generic AMD RZ616 / MT7922 USB ID.

.PARAMETER Source
  Folder containing the extracted MediaTek Bluetooth driver (mtkbtfilter.inf, mtkbtfilterx.sys, ...).

.PARAMETER Destination
  Output folder for the patched package. The .cat file is NOT copied on purpose:
  the package becomes plainly unsigned instead of "signed but tampered".
#>
param(
    [Parameter(Mandatory)] [string]$Source,
    [string]$Destination = (Join-Path (Split-Path $Source -Parent) 'mtkbt_patched')
)
$ErrorActionPreference = 'Stop'

$srcInf = Join-Path $Source 'mtkbtfilter.inf'
if (-not (Test-Path $srcInf)) { throw "mtkbtfilter.inf not found in $Source" }

New-Item -ItemType Directory -Force $Destination | Out-Null
Get-ChildItem $Source -File | Where-Object Extension -ne '.cat' | Copy-Item -Destination $Destination -Force

$inf = Join-Path $Destination 'mtkbtfilter.inf'
$t = [IO.File]::ReadAllText($srcInf)
$orig = $t

# 1. Map the generic RZ616 ID to the T0_3 section (ISO opt-in + AddComponent mtkbtacx)
$rx = '(?m)^(%[^%\r\n]+%\s*=\s*)MTKBT_T0_2(,\s*USB\\VID_0E8D&PID_0616&MI_00)\s*$'
if (([regex]::Matches($t, $rx)).Count -ne 1) { throw 'Could not find exactly one MTKBT_T0_2 line for USB\VID_0E8D&PID_0616&MI_00 (INF layout changed?)' }
$t = [regex]::Replace($t, $rx, '${1}MTKBT_T0_3${2}')
if ($t -notmatch '(?m)^\[MTKBT_T0_3\.NTamd64\.Components\]') { throw 'MTKBT_T0_3.NTamd64.Components section not found' }

# 2. Drop the catalog reference (the INF no longer matches it)
$t = $t -replace '(?m)^(CatalogFile[^\r\n]*)', ';$1'

# 3. In-band (software) streaming instead of ACP sideband
$t = $t -replace '(?m)^(HKR,Parameters\\mtkbt,(?:HFP|A2DP|LEAudio)_SideBand,0x00010001,)1', '${1}0'
$extra = @(
    'HKR,Parameters\mtkbt,LEAudio_switch,0x00010001,1'
    'HKR,Parameters\mtkbt,USB_switch,0x00010001,1'
    'HKR,Parameters\mtkbt,USB_standard,0x00010001,0'
) -join "`r`n"
if ($t -notmatch '(?m)^\[BLESIDEBAND\.AddReg\]\r?\n') { throw 'BLESIDEBAND.AddReg section not found' }
$t = [regex]::Replace($t, '(?m)^(\[BLESIDEBAND\.AddReg\]\r?\n)', "`${1}$extra`r`n")

[IO.File]::WriteAllText($inf, $t, [Text.Encoding]::ASCII)

Compare-Object ($orig -split "`r?`n") ($t -split "`r?`n") | Format-Table SideIndicator, InputObject -AutoSize -Wrap
"Patched package: $Destination"

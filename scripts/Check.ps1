<#
.SYNOPSIS
  Shows whether the patched driver, the ACX child device and LE Audio endpoints are present.
#>
$hwid = 'USB\VID_0E8D&PID_0616&MI_00'
$bt = Get-PnpDevice | Where-Object InstanceId -like "$hwid*"
"Adapter: $($bt.Status) $($bt.FriendlyName)"
Get-PnpDeviceProperty -InstanceId $bt.InstanceId -KeyName DEVPKEY_Device_DriverInfPath, DEVPKEY_Device_DriverInfSection, DEVPKEY_Device_ProblemCode |
    Format-Table KeyName, Data -AutoSize

'== MediaTek audio devices (expect "MediaTek Bluetooth Audio Device" under the adapter,'
'   plus LE Render/Capture once an LE Audio headset is connected)'
Get-PnpDevice | Where-Object FriendlyName -match 'MediaTek Bluetooth' | ForEach-Object {
    $parent = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_Parent -ErrorAction SilentlyContinue).Data
    "{0,-6} {1,-45} parent={2}" -f $_.Status, $_.FriendlyName, $parent
}

'== Filter parameters'
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\MTKBTFilterx64\Parameters\mtkbt' -ErrorAction SilentlyContinue |
    Select-Object LEAudio_switch, LEAudio_SideBand, A2DP_SideBand, HFP_SideBand, USB_switch, USB_standard | Format-List

'== ISO opt-in'
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$($bt.InstanceId)\Device Parameters\1a75888d-6e63-4978-b88e-b92747df5e8c" -ErrorAction SilentlyContinue |
    Select-Object LE* | Format-List

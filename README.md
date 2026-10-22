# RZ616 LE Audio on Windows desktops

> 🤖 This repository (scripts and README) was written by Claude (Anthropic's AI) while debugging this setup with the repo owner. Tested on one machine only. Use at your own risk.
>
> 🤖 本 repo 的腳本與說明由 Claude（Anthropic 的 AI）在與 repo 作者一起除錯時撰寫，只在一台電腦上測試過，使用風險自負。

[English](#english) | [繁體中文](#繁體中文)

---

## English

Enable real **Bluetooth LE Audio (LC3)** on an **AMD desktop** with the **AMD RZ616 (MediaTek MT7922)** Wi-Fi/Bluetooth card, without turning off Secure Boot or enabling test-signing mode.

### Tested setup

| | |
|---|---|
| Board / CPU | MSI MPG B650I EDGE WIFI, Ryzen 7 9800X3D (AM5, **no AMD ACP/DSP**) |
| OS | Windows 11 build 26300 |
| Bluetooth driver | MediaTek 1.1147.0.618 |
| LE Audio driver | MediaTek `mtkbtacx` 1.0007.0.52 |
| Headphones | Sony WH-1000XM6 ("LE Audio priority" set in Sony Sound Connect) |

Result: the **"Use LE Audio when available"** toggle appears, the XM6 connects over LE (ASCS/PACS/CAS/VCS…), and Windows creates the *MediaTek Bluetooth LE Render/Capture Audio Device* endpoints.

### Why it doesn't work out of the box

1. `mtkbtfilter.inf` maps the generic RZ616 ID `USB\VID_0E8D&PID_0616&MI_00` to section `MTKBT_T0_2`, which has **no** LE Audio. OEM IDs of the same chip (e.g. `PID_E616`) map to `MTKBT_T0_3`, which adds the Windows ISO opt-ins and `AddComponent mtkbtacx` (the LE Audio ACX audio driver).
2. Even in `T0_3`, the driver defaults to **sideband** mode (`LEAudio_SideBand=1`), which expects the AMD ACP audio DSP found only in **laptop** APUs. AM5 desktops don't have it. The driver also supports **in-band** (software) streaming over USB (`*_SideBand=0`).

The patch maps the generic ID to `T0_3` and switches to in-band mode. The `.sys` files are untouched, so after a one-time install they still load under the original Microsoft-signed catalog.

### Steps

1. **Download** both packages from the Microsoft Update Catalog and extract them (`expand file.cab -F:* <folder>`):
   - Bluetooth driver 1.1147.0.618: <https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=21288fbb-b2f3-401b-95da-453d6b78b6ce>
   - MediaTek LE Audio (mtkbtacx): <https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=cd649687-b0ad-4ab1-86e8-6e511d5499fa>
2. **Install the signed Bluetooth driver normally first** (keeps its signed catalog in the system):
   `pnputil /add-driver <bt>\mtkbtfilter.inf /install`
3. **Build the patched INF:**
   `powershell -ExecutionPolicy Bypass -File scripts\Patch-MtkBtInf.ps1 -Source <bt> -Destination <bt_patched>`
4. **Boot once with signature enforcement disabled:** Shift + Restart → Troubleshoot → Advanced options → Startup Settings → Restart → **F7**. (Secure Boot stays on; this only affects this one boot.)
5. **Install** (Administrator PowerShell), accept the "unverified publisher" prompt:
   `powershell -ExecutionPolicy Bypass -File scripts\Install.ps1 -PatchedInf <bt_patched>\mtkbtfilter.inf -AcxInf <acx>\mtkbtacx.inf`
6. **Reboot normally**, then run `scripts\Check.ps1`. Expect section `MTKBT_T0_3.NTamd64` and a *MediaTek Bluetooth Audio Device* whose parent is the RZ616.
7. Settings → Bluetooth & devices → Devices → turn on **Use LE Audio when available**. Turn off Bluetooth on your phone, remove and re-pair the headphones.

### Known issues / tips

- **Glitch when an app opens the headset mic** (Discord, etc.): LE Audio reconfigures from media to conversational mode. Use another microphone as the input device to keep media quality.
- **Stutters:** the RZ616 shares its radio with Wi-Fi. If you're on Ethernet, **turn Wi-Fi off** (background scans steal airtime). Other BLE devices (keyboards/mice) also compete.
- **Reconnect hang (not yet hit here):** a Feedback Hub report (<https://aka.ms/AA13kq1f>) describes playback hanging after the headset reconnects, caused by `Microsoft.Bluetooth.Audio.dll` skipping a CCCD write. Workaround until fixed: remove and re-pair.
- Windows Update may replace the patched driver with a newer signed one. Re-run the steps.
- In our working setup `LEAudio_switch=1` was additionally set under `HKLM\SYSTEM\CurrentControlSet\Services\mtkbtacx\Parameters` (unclear whether required).

### Rollback

Administrator PowerShell, normal boot: `scripts\Rollback.ps1`, then reboot.

### Credits

Approach based on a community post by the author of Feedback Hub report <https://aka.ms/AA13kq1f> (B650 + RZ616 + WH-1000XM6), who first got in-band LE Audio working by patching the MediaTek INFs.

MediaTek driver files are **not** included; download them from Microsoft.

---

## 繁體中文

在 **AMD 桌機**上，讓 **AMD RZ616（MediaTek MT7922）** 網卡用上真正的**藍牙 LE Audio（LC3）**。不需要關閉 Secure Boot，也不需要開 test signing。

### 測試環境

| | |
|---|---|
| 主機板 / CPU | MSI MPG B650I EDGE WIFI、Ryzen 7 9800X3D（AM5，**沒有 AMD ACP/DSP**） |
| 系統 | Windows 11 build 26300 |
| 藍牙驅動 | MediaTek 1.1147.0.618 |
| LE Audio 驅動 | MediaTek `mtkbtacx` 1.0007.0.52 |
| 耳機 | Sony WH-1000XM6（Sony Sound Connect 設為「LE Audio 優先」） |

結果：設定裡出現 **「可用時使用 LE Audio」**，XM6 透過 LE 連線（ASCS/PACS/CAS/VCS…），並產生 *MediaTek Bluetooth LE Render/Capture Audio Device*。

### 為什麼原本不行

1. `mtkbtfilter.inf` 把 RZ616 的通用 ID `USB\VID_0E8D&PID_0616&MI_00` 對應到**沒有** LE Audio 的 `MTKBT_T0_2` 區段。同一顆晶片的 OEM ID（例如 `PID_E616`）則對應到 `MTKBT_T0_3`，這個區段會開啟 Windows 的 ISO opt-in，並透過 `AddComponent` 建立 `mtkbtacx`（LE Audio 的 ACX 音訊驅動）。
2. 就算用 `T0_3`，預設也是 **sideband** 模式（`LEAudio_SideBand=1`），需要只有**筆電** APU 才有的 AMD ACP 音訊 DSP，AM5 桌機沒有。驅動其實也支援經由 USB 的 **in-band**（純軟體）傳輸，也就是 `*_SideBand=0`。

這個 patch 把通用 ID 改指向 `T0_3`，並切換成 in-band。`.sys` 檔沒有任何修改，所以只要安裝時繞過一次簽章檢查，之後正常開機仍會由 Microsoft 簽署的原版 catalog 驗證通過。

### 步驟

1. 從 Microsoft Update Catalog **下載**兩包驅動並解壓（`expand 檔案.cab -F:* <資料夾>`）：
   - 藍牙驅動 1.1147.0.618：<https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=21288fbb-b2f3-401b-95da-453d6b78b6ce>
   - MediaTek LE Audio（mtkbtacx）：<https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=cd649687-b0ad-4ab1-86e8-6e511d5499fa>
2. **先用正常方式安裝簽章版藍牙驅動**，讓它的 catalog 留在系統裡：
   `pnputil /add-driver <bt>\mtkbtfilter.inf /install`
3. **產生修改版 INF：**
   `powershell -ExecutionPolicy Bypass -File scripts\Patch-MtkBtInf.ps1 -Source <bt> -Destination <bt_patched>`
4. **用一次「停用驅動程式強制簽章」開機**：按住 Shift 點「重新啟動」→ 疑難排解 → 進階選項 → 啟動設定 → 重新啟動 → **F7**。Secure Boot 不用關，只影響這一次開機。
5. 用**系統管理員** PowerShell **安裝**，跳出「無法驗證發行者」時選「仍然安裝」：
   `powershell -ExecutionPolicy Bypass -File scripts\Install.ps1 -PatchedInf <bt_patched>\mtkbtfilter.inf -AcxInf <acx>\mtkbtacx.inf`
6. **正常重開機**，執行 `scripts\Check.ps1`。區段應該是 `MTKBT_T0_3.NTamd64`，而且 *MediaTek Bluetooth Audio Device* 的父裝置是 RZ616。
7. 設定 → 藍牙與裝置 → 裝置 → 開啟 **「可用時使用 LE Audio」**。關掉手機藍牙，移除耳機後重新配對。

### 已知問題與建議

- **程式開啟耳機麥克風時會卡一下**（Discord 等）：LE Audio 會從媒體模式切到通話模式。輸入裝置改用其他麥克風，就能維持音質。
- **斷斷續續**：RZ616 的 Wi-Fi 和藍牙共用同一顆射頻。有接網路線的話**把 Wi-Fi 關掉**，否則背景掃描會搶走傳輸時間。其他 BLE 鍵盤、滑鼠也會搶。
- **重新連線後卡住**（我們還沒遇到）：Feedback Hub 回報 <https://aka.ms/AA13kq1f> 指出，`Microsoft.Bluetooth.Audio.dll` 會略過一次 CCCD 寫入，導致耳機重新連線後播放卡住。修正前的暫時解法：移除耳機再重新配對。
- Windows Update 可能用新版簽章驅動蓋掉修改版，遇到時重做一次步驟即可。
- 我們的成功環境裡，`HKLM\SYSTEM\CurrentControlSet\Services\mtkbtacx\Parameters` 也另外設了 `LEAudio_switch=1`（不確定是否必要）。

### 還原

正常開機，用系統管理員 PowerShell 執行 `scripts\Rollback.ps1`，再重新開機。

### 致謝

做法來自 Feedback Hub 回報 <https://aka.ms/AA13kq1f> 作者的社群貼文（B650 + RZ616 + WH-1000XM6），他最先透過修改 MediaTek INF 讓 in-band LE Audio 成功運作。

本 repo **不包含** MediaTek 驅動檔案，請自行從 Microsoft 下載。

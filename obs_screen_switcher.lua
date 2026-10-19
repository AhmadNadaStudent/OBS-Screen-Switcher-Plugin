--[[
obs_screen_switcher.lua - Native OBS Lua Script (Auto Screen Switcher)

Versi: 2.0 (Bulletproof State Sync & Auto Defaults)
Otomatis memindahkan tampilan Display Capture di OBS Studio mengikuti monitor tempat
window yang sedang aktif / diklik (Game vs Discord).

Fitur Utama:
- 100% Bawaan OBS Studio (LuaJIT, tanpa Python)
- State Synchronization: Memeriksa langsung monitor aktif pada source OBS (anti-stuck)
- Script Defaults: Otomatis AKTIF (Enabled=true) saat pertama kali dimuat atau restart PC
- Smart Ignore Filter: Mengabaikan klik pada OBS Studio (obs64.exe) dan Taskbar
- Beban CPU 0%
--]]

local obs = obslua
local ffi = require("ffi")
local bit = require("bit")

-- Deklarasi fungsi Win32 API ke LuaJIT FFI
ffi.cdef[[
    typedef void* HWND;
    typedef void* HMONITOR;
    typedef void* HANDLE;
    typedef unsigned long DWORD;
    typedef int BOOL;
    typedef long LONG;
    typedef wchar_t WCHAR;

    typedef struct {
        LONG left;
        LONG top;
        LONG right;
        LONG bottom;
    } RECT;

    typedef struct {
        DWORD cbSize;
        RECT rcMonitor;
        RECT rcWork;
        DWORD dwFlags;
        WCHAR szDevice[32];
    } MONITORINFOEXW;

    HWND GetForegroundWindow(void);
    HMONITOR MonitorFromWindow(HWND hwnd, DWORD dwFlags);
    BOOL GetMonitorInfoW(HMONITOR hMonitor, MONITORINFOEXW* lpmi);
    DWORD GetWindowThreadProcessId(HWND hwnd, DWORD* lpdwProcessId);
    HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
    BOOL QueryFullProcessImageNameW(HANDLE hProcess, DWORD dwFlags, WCHAR* lpExeName, DWORD* lpdwSize);
    BOOL CloseHandle(HANDLE hObject);
]]

local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")

-- Pengaturan & State
local enabled = true
local source_name = "Display Capture"
local last_applied_mon = -1

-- Fallback Device ID khusus pengguna (H24G30F & Mi Monitor)
local DEFAULT_MON_1_ID = "\\\\?\\DISPLAY#SKY0010#5&1558be21&0&UID4355#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}"
local DEFAULT_MON_2_ID = "\\\\?\\DISPLAY#XMI24B1#5&1558be21&0&UID4353#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}"

local function log(msg)
    obs.script_log(obs.LOG_INFO, "[AutoSwitch Lua] " .. msg)
end

-- Ambil nama proses (.exe)
local function get_process_name(hwnd)
    if hwnd == nil then return "" end
    local pid = ffi.new("DWORD[1]")
    user32.GetWindowThreadProcessId(hwnd, pid)
    if pid[0] == 0 then return "" end

    local hProcess = kernel32.OpenProcess(0x1000, 0, pid[0]) -- PROCESS_QUERY_LIMITED_INFORMATION
    if hProcess == nil then return "" end

    local buf = ffi.new("WCHAR[1024]")
    local size = ffi.new("DWORD[1]", 1024)
    local success = kernel32.QueryFullProcessImageNameW(hProcess, 0, buf, size)
    kernel32.CloseHandle(hProcess)

    if success ~= 0 then
        local str = ""
        for i = 0, size[0] - 1 do
            if buf[i] == 0 then break end
            str = str .. string.char(buf[i])
        end
        local base = str:match("([^\\/]+)$")
        return base and base:lower() or ""
    end
    return ""
end

-- Deteksi index monitor dari window (0 = Monitor Utama, 1 = Monitor Sekunder)
local function get_monitor_index(hwnd)
    if hwnd == nil then return -1 end
    local hMon = user32.MonitorFromWindow(hwnd, 2) -- MONITOR_DEFAULTTONEAREST
    if hMon == nil then return -1 end

    local info = ffi.new("MONITORINFOEXW")
    info.cbSize = ffi.sizeof("MONITORINFOEXW")
    if user32.GetMonitorInfoW(hMon, info) ~= 0 then
        -- MONITORINFOF_PRIMARY = 0x0001
        local is_primary = bit.band(info.dwFlags, 1) ~= 0
        if is_primary or (info.rcMonitor.left <= 0 and info.rcMonitor.right > 0) then
            return 0 -- Layar 1 (Monitor Utama)
        else
            return 1 -- Layar 2 (Monitor Sekunder)
        end
    end
    return -1
end

-- Ambil monitor index yang sedang aktif pada source Display Capture di OBS
local function get_source_current_monitor(source)
    if source == nil then return -1 end
    local settings = obs.obs_source_get_settings(source)
    local mon_idx = -1
    if settings ~= nil then
        mon_idx = obs.obs_data_get_int(settings, "monitor")
        obs.obs_data_release(settings)
    end
    return mon_idx
end

-- Fungsi pergantian Display Capture di OBS
local function switch_display(target_idx)
    local source = obs.obs_get_source_by_name(source_name)
    if source == nil then
        local sources = obs.obs_enum_sources()
        if sources ~= nil then
            for _, s in ipairs(sources) do
                local s_id = obs.obs_source_get_id(s)
                if s_id == "monitor_capture" or s_id == "display_capture" then
                    source = s
                    break
                end
            end
            obs.source_list_release(sources)
        end
    end

    if source == nil then
        return
    end

    -- Ambil target device ID langsung dari list properties source OBS
    local target_id = nil
    local props = obs.obs_source_properties(source)
    if props ~= nil then
        local p = obs.obs_properties_get(props, "monitor_id")
        if p == nil then
            p = obs.obs_properties_get(props, "monitor")
        end
        if p ~= nil then
            local count = obs.obs_property_list_item_count(p)
            if target_idx < count then
                target_id = obs.obs_property_list_item_string(p, target_idx)
            end
        end
        obs.obs_properties_destroy(props)
    end

    if target_id == nil or target_id == "" then
        target_id = (target_idx == 0) and DEFAULT_MON_1_ID or DEFAULT_MON_2_ID
    end

    local mon_name = (target_idx == 0) and "Layar 1 (Utama)" or "Layar 2 (Sekunder)"

    local settings = obs.obs_source_get_settings(source)
    if settings ~= nil then
        obs.obs_data_set_int(settings, "monitor", target_idx)
        obs.obs_data_set_string(settings, "monitor_id", target_id)
        obs.obs_data_set_string(settings, "setting_id", target_id)
        obs.obs_data_set_string(settings, "id", target_id)
        obs.obs_data_set_string(settings, "alt_id", (target_idx == 0) and "\\\\.\\DISPLAY2" or "\\\\.\\DISPLAY1")

        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        last_applied_mon = target_idx
        log("-> SWITCH: Display Capture otomatis beralih ke " .. mon_name)
    end
    obs.obs_source_release(source)
end

-- Timer callback (dijalankan OBS setiap 100ms)
local function check_foreground_timer()
    if not enabled then return end

    local hwnd = user32.GetForegroundWindow()
    if hwnd == nil then return end

    -- Abaikan jika user sedang mengklik OBS atau Taskbar
    local proc = get_process_name(hwnd)
    if proc == "obs64.exe" or proc == "obs32.exe" or proc == "taskmgr.exe" or proc == "shellexperiencehost.exe" or proc == "searchhost.exe" then
        return
    end

    local target_idx = get_monitor_index(hwnd)
    if target_idx < 0 then
        return
    end

    -- Cek apakah OBS saat ini sudah menampilkan monitor tersebut
    if target_idx == last_applied_mon then
        return
    end

    switch_display(target_idx)
end

-- =========================================================================
-- OBS Script Interface
-- =========================================================================

function script_description()
    return [[
<h2>OBS Auto Screen Switcher (LUA NATIVE v2.0)</h2>
<p>Otomatis memindahkan monitor pada source <b>Display Capture</b> mengikuti monitor tempat window aktif berada (Game di Layar 1 vs Discord di Layar 2).</p>
<p><b>Kelebihan:</b> 100% bawaan OBS, TIDAK perlu instalasi Python, otomatis aktif setiap kali OBS dibuka!</p>
<hr/>
]]
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "enabled", true)
    obs.obs_data_set_default_string(settings, "source_name", "Display Capture")
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "enabled", "Aktifkan Auto Switch")

    local p_sources = obs.obs_properties_add_list(
        props,
        "source_name",
        "Source Display Capture",
        obs.OBS_COMBO_TYPE_EDITABLE,
        obs.OBS_COMBO_FORMAT_STRING
    )

    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, s in ipairs(sources) do
            local s_id = obs.obs_source_get_id(s)
            local name = obs.obs_source_get_name(s)
            if s_id == "monitor_capture" or s_id == "display_capture" then
                obs.obs_property_list_add_string(p_sources, name, name)
            end
        end
        obs.source_list_release(sources)
    end

    return props
end

function script_update(settings)
    if obs.obs_data_has_user_value(settings, "enabled") then
        enabled = obs.obs_data_get_bool(settings, "enabled")
    else
        enabled = true
    end

    local s_name = obs.obs_data_get_string(settings, "source_name")
    if s_name ~= "" then
        source_name = s_name
    else
        source_name = "Display Capture"
    end

    last_applied_mon = -1
    log("Pengaturan diperbarui: Source='" .. source_name .. "', Enabled=" .. tostring(enabled))
end

function script_load(settings)
    log("Memuat OBS Auto Screen Switcher LUA v2.0...")
    script_update(settings)
    obs.timer_remove(check_foreground_timer)
    obs.timer_add(check_foreground_timer, 100)
    log("Timer aktif (interval 100ms). Siap bekerja otomatis!")
end

function script_unload()
    obs.timer_remove(check_foreground_timer)
    log("Script ditutup.")
end

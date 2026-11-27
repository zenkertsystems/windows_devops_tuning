using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Threading;
using Microsoft.Win32;

namespace TrayAgenda;

/// <summary>Verbindet Uhr-Klick-Erkennung, Panel, Datenquellen und Tray-Icon.</summary>
sealed class Controller : IDisposable
{
    Config cfg = new();
    readonly AgendaStore store = new();
    AgendaWindow win = null!;
    readonly ClockLocator clock = new();
    MouseHook? hook;
    TrayIcon? tray;
    Dispatcher ui = null!;
    DispatcherTimer watch = null!, refreshTimer = null!;
    FileSystemWatcher? cfgWatcher;
    DispatcherTimer? cfgDebounce;

    // vom Hook-Thread gelesen
    volatile bool replaceMode;
    volatile bool shownFlag;
    readonly object rectGate = new();
    Native.RECT panelRect;
    long lastInsideClick;

    bool shown, waiting;
    long waitStart;

    public void Start()
    {
        ui = Dispatcher.CurrentDispatcher;
        cfg = Config.Load();
        replaceMode = cfg.ReplaceMode;
        if (cfg.IsNew) Autostart.Enabled = true;

        win = new AgendaWindow(cfg, store) { Width = cfg.PanelWidth };
        win.Init();
        win.HideRequested += HidePanel;
        win.RefreshRequested += () => _ = RefreshAsync();
        store.Changed += () => ui.BeginInvoke(() => win.Rebuild());

        clock.Start();
        hook = new MouseHook(OnMouse);
        hook.Start();

        tray = new TrayIcon(this);

        watch = new DispatcherTimer(DispatcherPriority.Normal, ui) { Interval = TimeSpan.FromMilliseconds(80) };
        watch.Tick += (_, _) => WatchTick();

        refreshTimer = new DispatcherTimer(DispatcherPriority.Background, ui) { Interval = TimeSpan.FromMinutes(Math.Max(1, cfg.RefreshMinutes)) };
        refreshTimer.Tick += (_, _) => _ = RefreshAsync();
        refreshTimer.Start();

        SystemEvents.PowerModeChanged += (_, e) => { if (e.Mode == PowerModes.Resume) ui.BeginInvoke(() => { clock.Rescan(); _ = RefreshAsync(); }); };
        SystemEvents.DisplaySettingsChanged += (_, _) => clock.Rescan();
        SystemEvents.TimeChanged += (_, _) => ui.BeginInvoke(() => win.Rebuild());

        WatchConfig();
        Log.Write("Gestartet, Modus=" + cfg.Mode);
        _ = RefreshAsync();
    }

    public Config Config => cfg;
    public AgendaStore Store => store;

    public Task RefreshAsync() => store.RefreshAsync(cfg);

    // ------------------------------------------------------------ Maus (läuft auf dem Hook-Thread!)

    bool OnMouse(int msg, Native.POINT pt)
    {
        bool replace = replaceMode;
        if (clock.HitTest(pt))
        {
            if (msg == Native.WM_LBUTTONDOWN) return replace;
            if (msg == Native.WM_LBUTTONUP) { ui.BeginInvoke(OnClockClicked); return replace; }
            return false; // Rechtsklick: Windows-Kontextmenü normal
        }
        if (shownFlag && msg is Native.WM_LBUTTONDOWN or Native.WM_RBUTTONDOWN)
        {
            Native.RECT r;
            lock (rectGate) r = panelRect;
            if (r.Contains(pt)) lastInsideClick = Environment.TickCount64;
            else if (replace) ui.BeginInvoke(HidePanel);
        }
        return false;
    }

    void OnClockClicked()
    {
        if (shown) { HidePanel(); return; }
        if (replaceMode) { ShowStandalone(); return; }
        // Beside: warten, bis das Windows-Flyout erscheint, dann daneben andocken
        waiting = true;
        waitStart = Environment.TickCount64;
        watch.Start();
    }

    static bool IsShellFlyout(IntPtr h, out Native.RECT r)
    {
        r = default;
        if (h == IntPtr.Zero) return false;
        if (Native.ClassOf(h) != "Windows.UI.Core.CoreWindow") return false;
        if (!string.Equals(Native.ProcessNameOf(h), "ShellExperienceHost", StringComparison.OrdinalIgnoreCase)) return false;
        return Native.GetWindowRect(h, out r) && !r.IsEmpty;
    }

    void WatchTick()
    {
        var fg = Native.GetForegroundWindow();
        bool fly = IsShellFlyout(fg, out var fr);

        if (waiting)
        {
            if (fly) { waiting = false; ShowBeside(fr); }
            else if (Environment.TickCount64 - waitStart > 1500) waiting = false;
        }
        else if (shown && !replaceMode && !fly && fg != win.Hwnd)
        {
            // kurz nach einem Klick ins Panel nicht schließen (der Klick soll noch ankommen)
            bool mouseDown = (Native.GetAsyncKeyState(0x01) & 0x8000) != 0;
            if (Environment.TickCount64 - lastInsideClick > 350 && !mouseDown) HidePanel();
        }

        if (!waiting && !(shown && !replaceMode)) watch.Stop();
    }

    void ShowBeside(Native.RECT flyout)
    {
        var anchor = new Native.POINT { X = (flyout.Left + flyout.Right) / 2, Y = flyout.Bottom - 20 };
        var (work, scale) = Native.MonitorAt(anchor);
        var (w, h) = PanelSize(work, scale);
        int gap = (int)Math.Round(12 * scale);
        // Das Flyout-Fenster hat rechts/links bereits ~12px transparenten Rand
        int x = flyout.Left - w;
        if (x < work.Left + gap) x = work.Left + gap;
        int y = work.Bottom - h - gap;
        Present(x, y, w, h, activate: false);
        watch.Start();
    }

    /// <summary>Eigenständig unten rechts am Monitor der Uhr (Replace-Modus oder per Tray-Icon).</summary>
    public void ShowStandalone()
    {
        Native.POINT anchor;
        if (clock.First is { } c) anchor = new Native.POINT { X = (c.Left + c.Right) / 2, Y = (c.Top + c.Bottom) / 2 };
        else Native.GetCursorPos(out anchor);
        var (work, scale) = Native.MonitorAt(anchor);
        var (w, h) = PanelSize(work, scale);
        int gap = (int)Math.Round(12 * scale);
        Present(work.Right - w - gap, work.Bottom - h - gap, w, h, activate: true);
    }

    (int w, int h) PanelSize(Native.RECT work, double scale)
    {
        double maxDip = work.Height / scale - 24;
        // 0 = volle Höhe (bündig mit der Windows-Flyout-Spalte)
        // im Windows-10-Stil (Replace) kompakt wie damals
        double hDip = cfg.PanelHeight > 0 ? Math.Min(cfg.PanelHeight, maxDip)
                    : cfg.ReplaceMode ? Math.Min(780, maxDip) : maxDip;
        win.Width = cfg.PanelWidth;
        win.Height = hDip;
        return ((int)Math.Round(cfg.PanelWidth * scale), (int)Math.Round(hDip * scale));
    }

    void Present(int x, int y, int w, int h, bool activate)
    {
        win.ResetToToday();
        lock (rectGate) panelRect = new Native.RECT { Left = x, Top = y, Right = x + w, Bottom = y + h };
        win.ShowAt(x, y, w, h, activate);
        shown = true;
        shownFlag = true;
        if ((DateTime.Now - store.LastRefresh).TotalSeconds > 90) _ = RefreshAsync();
    }

    public void HidePanel()
    {
        if (!shown) return;
        shown = false;
        shownFlag = false;
        win.Hide();
    }

    // ------------------------------------------------------------ Konfiguration

    public void SetMode(bool replace)
    {
        cfg.Mode = replace ? "Replace" : "Beside";
        cfg.Save(); // FileSystemWatcher lädt neu
        ApplyConfig(cfg);
    }

    void ApplyConfig(Config c)
    {
        cfg = c;
        replaceMode = c.ReplaceMode;
        refreshTimer.Interval = TimeSpan.FromMinutes(Math.Max(1, c.RefreshMinutes));
        win.SetConfig(c);
        tray?.Sync();
    }

    void WatchConfig()
    {
        cfgDebounce = new DispatcherTimer(DispatcherPriority.Background, ui) { Interval = TimeSpan.FromMilliseconds(600) };
        cfgDebounce.Tick += (_, _) =>
        {
            cfgDebounce.Stop();
            ApplyConfig(Config.Load());
            _ = RefreshAsync();
        };
        cfgWatcher = new FileSystemWatcher(Config.Dir, "config.json") { NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.Size | NotifyFilters.FileName };
        FileSystemEventHandler h = (_, _) => ui.BeginInvoke(() => { cfgDebounce.Stop(); cfgDebounce.Start(); });
        cfgWatcher.Changed += h;
        cfgWatcher.Created += h;
        cfgWatcher.Renamed += (_, _) => ui.BeginInvoke(() => { cfgDebounce.Stop(); cfgDebounce.Start(); });
        cfgWatcher.EnableRaisingEvents = true;
    }

    public void Exit()
    {
        System.Windows.Application.Current.Shutdown();
    }

    public void Dispose()
    {
        hook?.Dispose();
        clock.Dispose();
        cfgWatcher?.Dispose();
        tray?.Dispose();
    }
}

static class Autostart
{
    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    const string Name = "TrayAgenda";

    public static bool Enabled
    {
        get
        {
            using var k = Registry.CurrentUser.OpenSubKey(RunKey);
            return k?.GetValue(Name) is string;
        }
        set
        {
            using var k = Registry.CurrentUser.CreateSubKey(RunKey);
            if (value) k.SetValue(Name, $"\"{Environment.ProcessPath}\"");
            else k.DeleteValue(Name, false);
        }
    }
}

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;

namespace TrayAgenda;

/// <summary>Findet per UI Automation die Uhr-Schaltfläche(n) in der Taskleiste und hält deren Position aktuell.</summary>
sealed class ClockLocator : IDisposable
{
    static readonly Regex TimePattern = new(@"\d{1,2}[:.]\d{2}", RegexOptions.Compiled);

    readonly object gate = new();
    Native.RECT[] rects = Array.Empty<Native.RECT>();
    List<AutomationElement> cached = new();
    Timer? timer;
    int running;
    int tick;

    public void Start() => timer = new Timer(_ => Scan(), null, 0, 2500);

    public void Rescan() { lock (gate) cached.Clear(); ThreadPool.QueueUserWorkItem(_ => Scan()); }

    public bool HitTest(Native.POINT p)
    {
        var r = rects;
        foreach (var rc in r) if (rc.Contains(p)) return true;
        return false;
    }

    public Native.RECT? First { get { var r = rects; return r.Length > 0 ? r[0] : null; } }

    void Scan()
    {
        if (Interlocked.Exchange(ref running, 1) == 1) return;
        try
        {
            List<AutomationElement> elems;
            lock (gate) elems = cached;
            bool full = elems.Count == 0 || (++tick % 24 == 0); // ca. jede Minute komplett neu suchen
            if (full) elems = FindClocks();

            var list = new List<Native.RECT>();
            foreach (var e in elems)
            {
                try
                {
                    var b = e.Current.BoundingRectangle;
                    if (b.IsEmpty || b.Width <= 0) continue;
                    list.Add(new Native.RECT { Left = (int)b.Left, Top = (int)b.Top, Right = (int)b.Right, Bottom = (int)b.Bottom });
                }
                catch (ElementNotAvailableException) { full = true; }
                catch (COMException) { full = true; }
            }
            if (full && list.Count == 0 && elems != cached) { /* nichts gefunden */ }
            lock (gate) cached = list.Count > 0 ? elems : new List<AutomationElement>();
            rects = list.ToArray();
        }
        catch (Exception ex)
        {
            Log.Write("ClockLocator: " + ex.Message);
            lock (gate) cached = new List<AutomationElement>();
        }
        finally { Interlocked.Exchange(ref running, 0); }
    }

    static List<AutomationElement> FindClocks()
    {
        var result = new List<AutomationElement>();
        var barCond = new OrCondition(
            new PropertyCondition(AutomationElement.ClassNameProperty, "Shell_TrayWnd"),
            new PropertyCondition(AutomationElement.ClassNameProperty, "Shell_SecondaryTrayWnd"));
        foreach (AutomationElement bar in AutomationElement.RootElement.FindAll(TreeScope.Children, barCond))
        {
            // Windows 11: die Uhr ist ein "SystemTray.OmniButton" mit Namen "Uhr 13:02 27.11.2026"
            var buttons = bar.FindAll(TreeScope.Descendants,
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            foreach (AutomationElement b in buttons)
            {
                string cls = b.Current.ClassName ?? "";
                string name = b.Current.Name ?? "";
                bool isClock = cls == "SystemTray.OmniButton" && TimePattern.IsMatch(name)
                            || cls.Contains("Clock", StringComparison.OrdinalIgnoreCase)
                            || (name.StartsWith("Uhr", StringComparison.OrdinalIgnoreCase) || name.StartsWith("Clock", StringComparison.OrdinalIgnoreCase)) && TimePattern.IsMatch(name);
                if (isClock) result.Add(b);
            }
        }
        return result;
    }

    public void Dispose() => timer?.Dispose();
}

/// <summary>Globaler Low-Level-Maushook auf eigenem Thread (blockiert nie die Maus, auch wenn die UI beschäftigt ist).</summary>
sealed class MouseHook : IDisposable
{
    readonly Func<int, Native.POINT, bool> handler;
    Native.LowLevelMouseProc? proc;
    IntPtr hook;
    uint threadId;

    /// <param name="handler">Gibt true zurück, um den Klick zu verschlucken.</param>
    public MouseHook(Func<int, Native.POINT, bool> handler) => this.handler = handler;

    public void Start()
    {
        using var ready = new ManualResetEventSlim();
        var t = new Thread(() =>
        {
            threadId = Native.GetCurrentThreadId();
            proc = Callback;
            Install();
            ready.Set();
            // Windows entfernt Low-Level-Hooks stillschweigend, wenn ein Callback zu lange braucht
            // (z.B. unter Last beim Hochfahren). Darum regelmäßig neu einrichten.
            Native.SetTimer(IntPtr.Zero, IntPtr.Zero, RenewIntervalMs, IntPtr.Zero);
            while (Native.GetMessage(out var m, IntPtr.Zero, 0, 0) > 0)
            {
                if (m.message is Native.WM_TIMER or WM_RENEW) Install();
            }
            if (hook != IntPtr.Zero) Native.UnhookWindowsHookEx(hook);
        })
        { IsBackground = true, Name = "MouseHook", Priority = ThreadPriority.AboveNormal };
        t.Start();
        ready.Wait(3000);
    }

    const uint RenewIntervalMs = 120_000;
    const uint WM_RENEW = 0x8001; // WM_APP + 1

    /// <summary>Neuen Hook setzen, erst danach den alten entfernen – so geht kein Klick verloren.</summary>
    void Install()
    {
        var fresh = Native.SetWindowsHookEx(Native.WH_MOUSE_LL, proc!, Native.GetModuleHandle(null), 0);
        if (fresh == IntPtr.Zero)
        {
            Log.Write("SetWindowsHookEx fehlgeschlagen: " + Marshal.GetLastWin32Error());
            return;
        }
        var old = hook;
        hook = fresh;
        if (old != IntPtr.Zero) Native.UnhookWindowsHookEx(old);
    }

    /// <summary>Hook sofort erneuern (z.B. nach Standby).</summary>
    public void Renew()
    {
        if (threadId != 0) Native.PostThreadMessage(threadId, WM_RENEW, IntPtr.Zero, IntPtr.Zero);
    }

    IntPtr Callback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            int msg = (int)wParam;
            if (msg is Native.WM_LBUTTONDOWN or Native.WM_LBUTTONUP or Native.WM_RBUTTONDOWN)
            {
                var info = Marshal.PtrToStructure<Native.MSLLHOOKSTRUCT>(lParam);
                try { if (handler(msg, info.pt)) return new IntPtr(1); }
                catch (Exception ex) { Log.Write("Hook: " + ex.Message); }
            }
        }
        return Native.CallNextHookEx(hook, nCode, wParam, lParam);
    }

    public void Dispose()
    {
        if (threadId != 0) Native.PostThreadMessage(threadId, Native.WM_QUIT, IntPtr.Zero, IntPtr.Zero);
    }
}

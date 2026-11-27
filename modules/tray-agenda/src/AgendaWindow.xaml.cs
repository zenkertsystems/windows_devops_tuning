using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;
using Microsoft.Win32;

namespace TrayAgenda;

public partial class AgendaWindow : Window
{
    readonly AgendaStore store;
    Config cfg;
    DateTime selected = DateTime.Today;
    DateTime monthShown = new(DateTime.Today.Year, DateTime.Today.Month, 1);
    static readonly CultureInfo De = CultureInfo.GetCultureInfo("de-DE");

    public IntPtr Hwnd { get; private set; }
    public event Action? HideRequested;
    public event Action? RefreshRequested;

    public AgendaWindow(Config cfg, AgendaStore store)
    {
        InitializeComponent();
        this.cfg = cfg;
        this.store = store;
        ApplyTheme();
        SystemEvents.UserPreferenceChanged += (_, e) =>
        {
            if (e.Category is UserPreferenceCategory.General or UserPreferenceCategory.Color or UserPreferenceCategory.VisualStyle)
                Dispatcher.BeginInvoke(ApplyTheme);
        };
        Deactivated += (_, _) => HideRequested?.Invoke();
        clockTimer = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        clockTimer.Tick += (_, _) => UpdateClock();
        IsVisibleChanged += (_, _) => { if (IsVisible && cfg.MonthVisible) { UpdateClock(); clockTimer.Start(); } else clockTimer.Stop(); };
        PreviewKeyDown += (_, e) => { if (e.Key == Key.Escape) HideRequested?.Invoke(); };
    }

    public void Init()
    {
        Hwnd = new WindowInteropHelper(this).EnsureHandle();
        long ex = Native.GetWindowLongPtr(Hwnd, Native.GWL_EXSTYLE).ToInt64();
        Native.SetWindowLongPtr(Hwnd, Native.GWL_EXSTYLE, new IntPtr(ex | Native.WS_EX_TOOLWINDOW | Native.WS_EX_NOACTIVATE));
        int round = 2; // DWMWCP_ROUND
        Native.DwmSetWindowAttribute(Hwnd, 33 /*DWMWA_WINDOW_CORNER_PREFERENCE*/, ref round, sizeof(int));
        ApplyDwmBorder();
    }

    public void SetConfig(Config c) { cfg = c; Width = c.PanelWidth; Rebuild(); }

    public void SetActivatable(bool activatable)
    {
        long ex = Native.GetWindowLongPtr(Hwnd, Native.GWL_EXSTYLE).ToInt64();
        ex = activatable ? ex & ~Native.WS_EX_NOACTIVATE : ex | Native.WS_EX_NOACTIVATE;
        Native.SetWindowLongPtr(Hwnd, Native.GWL_EXSTYLE, new IntPtr(ex));
    }

    /// <summary>Zeigt das Panel an einer physischen Pixelposition.</summary>
    public void ShowAt(int x, int y, int w, int h, bool activate)
    {
        SetActivatable(activate);
        Native.SetWindowPos(Hwnd, Native.HWND_TOPMOST, x, y, w, h, Native.SWP_NOACTIVATE);
        if (!IsVisible) Show();
        Native.SetWindowPos(Hwnd, Native.HWND_TOPMOST, x, y, w, h, Native.SWP_NOACTIVATE | Native.SWP_SHOWWINDOW);
        if (activate)
        {
            Native.ForceForeground(Hwnd);
            Activate();
        }
        Scroller.ScrollToTop();
    }

    public void ResetToToday()
    {
        selected = DateTime.Today;
        monthShown = new DateTime(selected.Year, selected.Month, 1);
        Rebuild();
    }

    // ------------------------------------------------------------ Theme

    bool lightTheme;
    Color accent = Color.FromRgb(0x00, 0x67, 0xC0);

    void ApplyTheme()
    {
        lightTheme = ReadDword(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1) == 1;
        int abgr = ReadDword(@"Software\Microsoft\Windows\DWM", "AccentColor", unchecked((int)0xFFC06700));
        var raw = Color.FromRgb((byte)(abgr & 0xFF), (byte)((abgr >> 8) & 0xFF), (byte)((abgr >> 16) & 0xFF));
        accent = raw;

        void Set(string key, Color c) => Resources[key] = Freeze(new SolidColorBrush(c));
        if (lightTheme)
        {
            Set("BgBrush", Color.FromRgb(0xF9, 0xF9, 0xF9));
            Set("FooterBrush", Color.FromRgb(0xF0, 0xF0, 0xF0));
            Set("FgBrush", Color.FromRgb(0x1B, 0x1B, 0x1B));
            Set("SubBrush", Color.FromRgb(0x60, 0x60, 0x60));
            Set("HoverBrush", Color.FromArgb(0x0F, 0, 0, 0));
            Set("PressBrush", Color.FromArgb(0x1A, 0, 0, 0));
            Set("LineBrush", Color.FromRgb(0xE3, 0xE3, 0xE3));
            Set("AccentBrush", Darken(raw, 0.15));
        }
        else
        {
            Set("BgBrush", Color.FromRgb(0x20, 0x20, 0x20));
            Set("FooterBrush", Color.FromRgb(0x1A, 0x1A, 0x1A));
            Set("FgBrush", Colors.White);
            Set("SubBrush", Color.FromRgb(0xA8, 0xA8, 0xA8));
            Set("HoverBrush", Color.FromArgb(0x14, 0xFF, 0xFF, 0xFF));
            Set("PressBrush", Color.FromArgb(0x0C, 0xFF, 0xFF, 0xFF));
            Set("LineBrush", Color.FromRgb(0x33, 0x33, 0x33));
            Set("AccentBrush", Lighten(raw, 0.35));
        }
        if (Hwnd != IntPtr.Zero) ApplyDwmBorder();
        Rebuild();
    }

    void ApplyDwmBorder()
    {
        int colorRef = lightTheme ? 0x00DADADA : 0x003A3A3A; // COLORREF 0x00BBGGRR
        Native.DwmSetWindowAttribute(Hwnd, 34 /*DWMWA_BORDER_COLOR*/, ref colorRef, sizeof(int));
    }

    static int ReadDword(string path, string name, int fallback)
    {
        try { using var k = Registry.CurrentUser.OpenSubKey(path); return k?.GetValue(name) is int v ? v : fallback; }
        catch { return fallback; }
    }

    static Brush Freeze(SolidColorBrush b) { b.Freeze(); return b; }
    static Color Lighten(Color c, double f) => Color.FromRgb((byte)(c.R + (255 - c.R) * f), (byte)(c.G + (255 - c.G) * f), (byte)(c.B + (255 - c.B) * f));
    static Color Darken(Color c, double f) => Color.FromRgb((byte)(c.R * (1 - f)), (byte)(c.G * (1 - f)), (byte)(c.B * (1 - f)));

    static Brush ParseBrush(string hex, Brush fallback)
    {
        try { return Freeze(new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex))); }
        catch { return fallback; }
    }

    // ------------------------------------------------------------ Aufbau

    public void Rebuild()
    {
        if (AgendaPanel == null) return;
        var today = DateTime.Today;
        bool month = cfg.MonthVisible;
        ClockHeader.Visibility = month ? Visibility.Visible : Visibility.Collapsed;
        CompactHeader.Visibility = month ? Visibility.Collapsed : Visibility.Visible;
        UpdateClock();
        HeaderTitle.Text = selected == today ? "Heute" : selected == today.AddDays(1) ? "Morgen" : selected.ToString("dddd", De);
        HeaderSub.Text = selected.ToString("dddd, d. MMMM yyyy", De);
        BtnToday.Visibility = selected == today ? Visibility.Collapsed : Visibility.Visible;
        StatusText.Text = store.Busy ? "Aktualisiere …" : store.Status;
        StatusText.ToolTip = store.Status;
        BuildMonth();
        BuildAgenda();
    }

    readonly System.Windows.Threading.DispatcherTimer clockTimer;
    string lastClock = "";

    void UpdateClock()
    {
        var now = DateTime.Now;
        var t = now.ToString("HH:mm:ss", De);
        if (t == lastClock) return;
        lastClock = t;
        BigTime.Text = t;
        BigDate.Text = now.ToString("dddd, d. MMMM yyyy", De);
    }

    void BigDate_Click(object sender, MouseButtonEventArgs e) => ResetToToday();

    static bool Overlaps(AgendaEvent e, DateTime ds, DateTime de) =>
        e.End > e.Start ? e.Start < de && e.End > ds : e.Start >= ds && e.Start < de;

    void BuildMonth()
    {
        MonthPanel.Children.Clear();
        if (!cfg.MonthVisible) { MonthPanel.Visibility = Visibility.Collapsed; return; }
        MonthPanel.Visibility = Visibility.Visible;

        var head = new Grid { Margin = new Thickness(6, 0, 0, 4) };
        head.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        head.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        head.Children.Add(new TextBlock
        {
            Text = monthShown.ToString("MMMM yyyy", De),
            FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center,
        });
        var nav = new StackPanel { Orientation = Orientation.Horizontal };
        Grid.SetColumn(nav, 1);
        var prev = new Button { Content = "\uE70E", Style = (Style)FindResource("IconBtn"), FontSize = 12, ToolTip = "Voriger Monat" };
        var next = new Button { Content = "\uE70D", Style = (Style)FindResource("IconBtn"), FontSize = 12, ToolTip = "Nächster Monat" };
        prev.Click += (_, _) => { monthShown = monthShown.AddMonths(-1); BuildMonth(); };
        next.Click += (_, _) => { monthShown = monthShown.AddMonths(1); BuildMonth(); };
        nav.Children.Add(prev); nav.Children.Add(next);
        head.Children.Add(nav);
        MonthPanel.Children.Add(head);

        var grid = new UniformGrid { Columns = 7 };
        foreach (var wd in new[] { "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So" })
        {
            var t = new TextBlock { Text = wd, FontSize = 11.5, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 2, 0, 4) };
            t.SetResourceReference(TextBlock.ForegroundProperty, "SubBrush");
            grid.Children.Add(t);
        }

        int offset = ((int)monthShown.DayOfWeek + 6) % 7;
        var gridStart = monthShown.AddDays(-offset);
        var gridEnd = gridStart.AddDays(42);
        var busyDays = new HashSet<DateTime>();
        foreach (var e in store.Events)
        {
            if (e.End < gridStart || e.Start > gridEnd) continue;
            for (var d = e.Start.Date; d < gridEnd && (Overlaps(e, d, d.AddDays(1))); d = d.AddDays(1))
                busyDays.Add(d);
        }

        var accentBrush = (Brush)Resources["AccentBrush"];
        for (int i = 0; i < 42; i++)
        {
            var d = gridStart.AddDays(i);
            bool isToday = d == DateTime.Today, isSel = d == selected, inMonth = d.Month == monthShown.Month;

            var num = new TextBlock { Text = d.Day.ToString(), HorizontalAlignment = HorizontalAlignment.Center, FontSize = 12.5 };
            var dot = new Ellipse { Width = 4, Height = 4, Margin = new Thickness(0, 1, 0, 0), HorizontalAlignment = HorizontalAlignment.Center, Fill = accentBrush,
                Visibility = busyDays.Contains(d) ? Visibility.Visible : Visibility.Hidden };
            var stack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            stack.Children.Add(num); stack.Children.Add(dot);

            // Windows-10-Stil: quadratische Felder, heute farbig gefüllt, Auswahl umrandet
            var circle = new Border { Height = 40, CornerRadius = new CornerRadius(3), Child = stack, Padding = new Thickness(0, 5, 0, 0),
                BorderThickness = new Thickness(2), BorderBrush = Brushes.Transparent };
            if (isToday)
            {
                circle.Background = accentBrush;
                num.Foreground = lightTheme ? Brushes.White : Brushes.Black;
                num.FontWeight = FontWeights.SemiBold;
                dot.Fill = num.Foreground;
            }
            if (isSel)
            {
                circle.BorderBrush = isToday ? (lightTheme ? Brushes.Black : Brushes.White) : accentBrush;
                if (isToday) circle.BorderThickness = new Thickness(2);
            }

            var btn = new Button { Content = circle, Style = (Style)FindResource("FlatBtn"), Padding = new Thickness(0), Margin = new Thickness(1),
                HorizontalContentAlignment = HorizontalAlignment.Stretch, Opacity = inMonth ? 1 : 0.4 };
            btn.Click += (_, _) =>
            {
                selected = d;
                if (d.Month != monthShown.Month || d.Year != monthShown.Year) monthShown = new DateTime(d.Year, d.Month, 1);
                Rebuild();
                Scroller.ScrollToTop();
            };
            grid.Children.Add(btn);
        }
        MonthPanel.Children.Add(grid);
        var sep = new Border { Height = 1, Margin = new Thickness(4, 8, 4, 0) };
        sep.SetResourceReference(Border.BackgroundProperty, "LineBrush");
        MonthPanel.Children.Add(sep);
    }

    void BuildAgenda()
    {
        AgendaPanel.Children.Clear();
        var events = store.Events;
        var now = DateTime.Now;
        var start = selected.Date;
        var end = start.AddDays(Math.Max(1, cfg.DaysAhead));
        int shownDays = 0;

        for (var d = start; d < end; d = d.AddDays(1))
        {
            var dayEnd = d.AddDays(1);
            var dayEvents = events.Where(e => Overlaps(e, d, dayEnd))
                                  .OrderBy(e => e.AllDay || e.Start < d ? 0 : 1)
                                  .ThenBy(e => e.Start).ToList();
            if (dayEvents.Count == 0 && d != start) continue;

            AgendaPanel.Children.Add(DayHeader(d));
            shownDays++;
            if (dayEvents.Count == 0)
            {
                AgendaPanel.Children.Add(Muted(d == DateTime.Today ? "Heute keine Termine" : "Keine Termine"));
                continue;
            }
            foreach (var e in dayEvents) AgendaPanel.Children.Add(EventRow(e, d, now));
        }

        if (shownDays <= 1 && AgendaPanel.Children.Count <= 2)
            AgendaPanel.Children.Add(Muted($"Keine weiteren Termine in den nächsten {cfg.DaysAhead} Tagen"));
    }

    UIElement DayHeader(DateTime d)
    {
        var today = DateTime.Today;
        string rel = d == today ? "Heute" : d == today.AddDays(1) ? "Morgen" : d == today.AddDays(-1) ? "Gestern" : "";
        string date = d.ToString(d.Year == today.Year ? "ddd, d. MMMM" : "ddd, d. MMMM yyyy", De);
        var sp = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(8, AgendaPanel.Children.Count == 0 ? 2 : 14, 0, 4) };
        if (rel != "")
        {
            var r = new TextBlock { Text = rel, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 6, 0) };
            r.SetResourceReference(TextBlock.ForegroundProperty, d == today ? "AccentBrush" : "FgBrush");
            sp.Children.Add(r);
        }
        var t = new TextBlock { Text = date, FontWeight = rel == "" ? FontWeights.SemiBold : FontWeights.Normal };
        t.SetResourceReference(TextBlock.ForegroundProperty, rel == "" ? "FgBrush" : "SubBrush");
        sp.Children.Add(t);
        return sp;
    }

    UIElement Muted(string text)
    {
        var t = new TextBlock { Text = text, Margin = new Thickness(8, 2, 8, 2), FontSize = 12.5, TextWrapping = TextWrapping.Wrap };
        t.SetResourceReference(TextBlock.ForegroundProperty, "SubBrush");
        return t;
    }

    static string TimeText(AgendaEvent e, DateTime day)
    {
        if (e.AllDay)
        {
            var lastDay = e.End.AddDays(-1).Date;
            return lastDay > e.Start.Date ? $"Ganztägig · bis {lastDay.ToString("ddd d.M.", De)}" : "Ganztägig";
        }
        bool before = e.Start < day, after = e.End > day.AddDays(1);
        if (before && after) return "Ganztägig (mehrtägig)";
        if (before) return $"bis {e.End:HH:mm}";
        if (after) return $"ab {e.Start:HH:mm}";
        return e.End > e.Start ? $"{e.Start:HH:mm} – {e.End:HH:mm}" : $"{e.Start:HH:mm}";
    }

    UIElement EventRow(AgendaEvent e, DateTime day, DateTime now)
    {
        var accentBrush = (Brush)Resources["AccentBrush"];
        var color = ParseBrush(e.Color, accentBrush);
        bool past = !e.AllDay && e.End <= now;
        bool running = !e.AllDay && e.Start <= now && e.End > now;

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(4) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.Children.Add(new Border { Background = color, CornerRadius = new CornerRadius(2), Margin = new Thickness(0, 1, 0, 1) });

        var sp = new StackPanel { Margin = new Thickness(10, 0, 0, 0) };
        Grid.SetColumn(sp, 1);
        sp.Children.Add(new TextBlock { Text = e.Title, FontWeight = FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis });

        var sub = new TextBlock { FontSize = 12, TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(0, 1, 0, 0) };
        sub.SetResourceReference(TextBlock.ForegroundProperty, "SubBrush");
        if (running)
        {
            var nowRun = new System.Windows.Documents.Run("Jetzt · ") { FontWeight = FontWeights.SemiBold };
            nowRun.SetResourceReference(System.Windows.Documents.TextElement.ForegroundProperty, "AccentBrush");
            sub.Inlines.Add(nowRun);
        }
        string line = TimeText(e, day);
        if (!string.IsNullOrWhiteSpace(e.Location)) line += " · " + e.Location.Trim();
        sub.Inlines.Add(new System.Windows.Documents.Run(line));
        sp.Children.Add(sub);
        grid.Children.Add(sp);

        var tip = $"{e.Title}\n{TimeText(e, day)}" +
                  (e.AllDay ? "" : $"  ({e.Start.ToString("ddd d.M.", De)})") +
                  (string.IsNullOrWhiteSpace(e.Location) ? "" : $"\n{e.Location}") +
                  $"\nKalender: {e.Source}";
        var btn = new Button { Content = grid, Style = (Style)FindResource("RowBtn"), ToolTip = tip, Opacity = past ? 0.45 : 1 };
        btn.Click += (_, _) => OpenEvent(e);
        return btn;
    }

    void OpenEvent(AgendaEvent e)
    {
        if (!string.IsNullOrEmpty(e.EntryId)) OutlookSource.OpenItem(e.EntryId, e.StoreId);
        else if (!string.IsNullOrEmpty(e.Link)) Shell(e.Link);
        HideRequested?.Invoke();
    }

    static void Shell(string target, string? args = null)
    {
        try { Process.Start(new ProcessStartInfo(target) { UseShellExecute = true, Arguments = args ?? "" }); }
        catch (Exception ex) { Log.Write($"Start '{target}': {ex.Message}"); }
    }

    // ------------------------------------------------------------ Buttons

    void BtnToday_Click(object sender, RoutedEventArgs e) => ResetToToday();
    void BtnRefresh_Click(object sender, RoutedEventArgs e) => RefreshRequested?.Invoke();
    void BtnNew_Click(object sender, RoutedEventArgs e) { Shell("outlook.exe", "/c ipm.appointment"); HideRequested?.Invoke(); }
    void BtnOutlook_Click(object sender, RoutedEventArgs e) { Shell("outlook.exe", "/select outlook:calendar"); HideRequested?.Invoke(); }
    void BtnGoogle_Click(object sender, RoutedEventArgs e)
    {
        Shell($"https://calendar.google.com/calendar/r/day/{selected:yyyy}/{selected.Month}/{selected.Day}");
        HideRequested?.Invoke();
    }
}

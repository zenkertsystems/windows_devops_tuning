using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Ical.Net.CalendarComponents;

namespace TrayAgenda;

public sealed class AgendaEvent
{
    public string Title { get; set; } = "";
    public DateTime Start { get; set; }
    public DateTime End { get; set; }
    public bool AllDay { get; set; }
    public string? Location { get; set; }
    public string Source { get; set; } = "";
    public string Color { get; set; } = "#0F6CBD";
    public string? EntryId { get; set; }
    public string? StoreId { get; set; }
    public string? Link { get; set; }
}

static class OutlookSource
{
    static readonly string[] Palette = { "#0F6CBD", "#C239B3", "#CA5010", "#498205", "#038387", "#8764B8", "#E3008C", "#986F0B" };

    public static bool IsRunning => Process.GetProcessesByName("OUTLOOK").Length > 0;

    static T RunSta<T>(Func<T> fn, int timeoutSec)
    {
        T? result = default; Exception? err = null;
        var th = new Thread(() => { try { result = fn(); } catch (Exception ex) { err = ex; } })
        { IsBackground = true, Name = "OutlookCOM" };
        th.SetApartmentState(ApartmentState.STA);
        th.Start();
        if (!th.Join(TimeSpan.FromSeconds(timeoutSec))) throw new TimeoutException("Outlook antwortet nicht");
        if (err != null) throw err;
        return result!;
    }

    static dynamic GetApp()
    {
        var type = Type.GetTypeFromProgID("Outlook.Application")
                   ?? throw new InvalidOperationException("Outlook (classic) ist nicht installiert");
        return Activator.CreateInstance(type)!;
    }

    public static List<AgendaEvent> Fetch(DateTime from, DateTime to, Config cfg, bool quitAfter) => RunSta(() =>
    {
        dynamic app = GetApp();
        try { return FetchSta(app, from, to, cfg); }
        finally
        {
            if (quitAfter)
            {
                // Nur beenden, wenn wir Outlook selbst gestartet haben und niemand ein Fenster geöffnet hat
                try { if ((int)app.Explorers.Count == 0 && (int)app.Inspectors.Count == 0) app.Quit(); } catch { }
            }
            app = null!;
            GC.Collect();
            GC.WaitForPendingFinalizers();
        }
    }, 90);

    static List<AgendaEvent> FetchSta(dynamic app, DateTime from, DateTime to, Config cfg)
    {
        dynamic ns = app.GetNamespace("MAPI");
        var list = new List<AgendaEvent>();
        int colorIdx = 0;
        dynamic stores = ns.Stores;
        int storeCount = stores.Count;
        for (int i = 1; i <= storeCount; i++)
        {
            dynamic store = stores.Item(i);
            dynamic? cal;
            string storeId;
            try { cal = store.GetDefaultFolder(9 /*olFolderCalendar*/); storeId = store.StoreID; }
            catch { continue; } // z.B. Public Folders, Archive ohne Kalender
            Walk(cal, storeId, from, to, cfg, list, ref colorIdx, 0);
        }
        return list;
    }

    static void Walk(dynamic folder, string storeId, DateTime from, DateTime to, Config cfg, List<AgendaEvent> list, ref int colorIdx, int depth)
    {
        string name = folder.Name;
        bool excluded = cfg.OutlookExcludeFolders.Any(x => string.Equals(x, name, StringComparison.OrdinalIgnoreCase));
        if (!excluded && (int)folder.DefaultItemType == 1 /*olAppointmentItem*/)
        {
            string color = cfg.OutlookFolderColors.TryGetValue(name, out var c) ? c : Palette[colorIdx++ % Palette.Length];
            try { ReadFolder(folder, name, color, storeId, from, to, list); }
            catch (Exception ex) { Log.Write($"Outlook-Ordner '{name}': {ex.Message}"); }
        }
        if (depth > 4) return;
        dynamic subs = folder.Folders;
        int n = subs.Count;
        for (int i = 1; i <= n; i++)
        {
            try { Walk(subs.Item(i), storeId, from, to, cfg, list, ref colorIdx, depth + 1); }
            catch (Exception ex) { Log.Write("Outlook-Unterordner: " + ex.Message); }
        }
    }

    static void ReadFolder(dynamic folder, string name, string color, string storeId, DateTime from, DateTime to, List<AgendaEvent> list)
    {
        dynamic items = folder.Items;
        items.Sort("[Start]");
        items.IncludeRecurrences = true; // nach Sort setzen, sonst werden Serien nicht expandiert
        var ci = CultureInfo.CurrentCulture;
        string filter = $"[Start] < '{to.ToString("g", ci)}' AND [End] > '{from.ToString("g", ci)}'";
        dynamic restricted = items.Restrict(filter);
        dynamic? it = restricted.GetFirst();
        int guard = 0;
        while (it != null && guard++ < 5000)
        {
            try
            {
                if ((int)it.Class == 26 /*olAppointment*/)
                {
                    var ev = new AgendaEvent
                    {
                        Title = (string?)it.Subject ?? "(ohne Titel)",
                        Start = (DateTime)it.Start,
                        End = (DateTime)it.End,
                        AllDay = (bool)it.AllDayEvent,
                        Location = (string?)it.Location,
                        Source = name,
                        Color = color,
                        EntryId = (string?)it.EntryID,
                        StoreId = storeId,
                    };
                    if (string.IsNullOrWhiteSpace(ev.Title)) ev.Title = "(ohne Titel)";
                    list.Add(ev);
                }
            }
            catch (Exception ex) { Log.Write("Outlook-Termin: " + ex.Message); }
            it = restricted.GetNext();
        }
    }

    public static void OpenItem(string entryId, string? storeId)
    {
        var th = new Thread(() =>
        {
            try
            {
                dynamic app = GetApp();
                dynamic ns = app.GetNamespace("MAPI");
                dynamic item = storeId != null ? ns.GetItemFromID(entryId, storeId) : ns.GetItemFromID(entryId);
                item.Display();
                try { dynamic insp = item.GetInspector; insp.Activate(); } catch { }
            }
            catch (Exception ex) { Log.Write("Outlook öffnen: " + ex.Message); }
        })
        { IsBackground = true };
        th.SetApartmentState(ApartmentState.STA);
        th.Start();
    }
}

static class IcsSource
{
    static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(25) };

    public static async Task<List<AgendaEvent>> FetchAsync(FeedConfig feed, DateTime from, DateTime to)
    {
        var url = feed.Url.Trim();
        if (url.StartsWith("webcal://", StringComparison.OrdinalIgnoreCase)) url = "https://" + url[9..];
        var text = await Http.GetStringAsync(url).ConfigureAwait(false);
        return Parse(text, feed, from, to);
    }

    static List<AgendaEvent> Parse(string text, FeedConfig feed, DateTime from, DateTime to)
    {
        var cal = Ical.Net.Calendar.Load(text);
        bool google = feed.Url.Contains("google.com", StringComparison.OrdinalIgnoreCase);
        var list = new List<AgendaEvent>();
        // etwas früher anfangen, damit bereits laufende mehrtägige Termine erfasst werden
        foreach (var occ in cal.GetOccurrences(from.AddDays(-14), to))
        {
            if (occ.Source is not CalendarEvent ev) continue;
            if (string.Equals(ev.Status, "CANCELLED", StringComparison.OrdinalIgnoreCase)) continue;

            bool allDay = ev.IsAllDay;
            var ps = occ.Period.StartTime;
            DateTime start = allDay ? ps.Date : ps.AsSystemLocal;
            DateTime end;
            if (occ.Period.EndTime != null)
                end = allDay ? occ.Period.EndTime.Date : occ.Period.EndTime.AsSystemLocal;
            else
                end = start + (occ.Period.Duration > TimeSpan.Zero ? occ.Period.Duration : (allDay ? TimeSpan.FromDays(1) : TimeSpan.Zero));
            if (allDay && end <= start) end = start.AddDays(1);
            if (end < from || start > to) continue;

            list.Add(new AgendaEvent
            {
                Title = string.IsNullOrWhiteSpace(ev.Summary) ? "(ohne Titel)" : ev.Summary.Trim(),
                Start = start,
                End = end,
                AllDay = allDay,
                Location = ev.Location,
                Source = feed.Name,
                Color = feed.Color,
                Link = google ? $"https://calendar.google.com/calendar/r/day/{start:yyyy}/{start.Month}/{start.Day}" : ev.Url?.ToString(),
            });
        }
        return list;
    }
}

public sealed class AgendaStore
{
    sealed class OutlookCache { public DateTime Saved { get; set; } public List<AgendaEvent> Events { get; set; } = new(); }

    public event Action? Changed;
    public IReadOnlyList<AgendaEvent> Events { get; private set; } = Array.Empty<AgendaEvent>();
    public DateTime LastRefresh { get; private set; }
    public string Status { get; private set; } = "Lade Termine …";
    public bool Busy => busy == 1;
    int busy;

    static string CachePath => Path.Combine(Config.Dir, "outlook-cache.json");

    public async Task RefreshAsync(Config cfg)
    {
        if (Interlocked.Exchange(ref busy, 1) == 1) return;
        Changed?.Invoke();
        try
        {
            var from = DateTime.Today.AddDays(-40);
            var to = DateTime.Today.AddDays(Math.Max(cfg.DaysAhead, 70) + 1);
            var notes = new ConcurrentQueue<string>();

            var outlookTask = cfg.IncludeOutlook
                ? Task.Run(() => LoadOutlook(cfg, from, to, notes))
                : Task.FromResult(new List<AgendaEvent>());
            var feedTasks = cfg.IcsFeeds
                .Where(f => f.Enabled && !string.IsNullOrWhiteSpace(f.Url))
                .Select(f => LoadFeed(f, from, to, notes))
                .ToList();

            var all = new List<AgendaEvent>(await outlookTask.ConfigureAwait(false));
            foreach (var t in feedTasks) all.AddRange(await t.ConfigureAwait(false));

            // Doppelte (z.B. von OGCS synchronisierte) Termine entfernen – Outlook hat Vorrang
            var seen = new HashSet<string>();
            var merged = new List<AgendaEvent>();
            foreach (var e in all)
            {
                var key = $"{e.Title.Trim().ToLowerInvariant()}|{e.Start:yyyyMMddHHmm}|{e.AllDay}";
                if (seen.Add(key)) merged.Add(e);
            }
            Events = merged.OrderBy(e => e.Start).ThenBy(e => e.AllDay ? 0 : 1).ThenBy(e => e.Title).ToList();
            LastRefresh = DateTime.Now;
            Log.Write($"Refresh: {merged.Count} Termine, {string.Join(" | ", notes)}");
            Status = notes.IsEmpty ? $"Aktualisiert {DateTime.Now:HH:mm}" : string.Join(" · ", notes);
        }
        catch (Exception ex)
        {
            Log.Write("Refresh: " + ex);
            Status = "Fehler: " + ex.Message;
        }
        finally
        {
            Interlocked.Exchange(ref busy, 0);
            Changed?.Invoke();
        }
    }

    static List<AgendaEvent> LoadOutlook(Config cfg, DateTime from, DateTime to, ConcurrentQueue<string> notes)
    {
        bool running = OutlookSource.IsRunning;
        if (!running)
        {
            var c = LoadCache();
            bool cacheFresh = c != null && (DateTime.Now - c.Saved).TotalMinutes < Math.Max(5, cfg.OutlookStartIntervalMinutes);
            if (!cfg.StartOutlookIfNotRunning || cacheFresh)
            {
                if (c == null) notes.Enqueue("Outlook geschlossen");
                else if (!cacheFresh) notes.Enqueue($"Outlook geschlossen – Stand {c.Saved:dd.MM. HH:mm}");
                return c?.Events ?? new();
            }
        }
        try
        {
            Log.Write(running ? "Outlook-Abruf startet" : "Outlook-Abruf startet (Outlook wird unsichtbar gestartet)");
            var list = OutlookSource.Fetch(from, to, cfg, quitAfter: !running);
            Log.Write($"Outlook: {list.Count} Termine");
            try { File.WriteAllText(CachePath, Config.Serialize(new OutlookCache { Saved = DateTime.Now, Events = list })); } catch { }
            return list;
        }
        catch (Exception ex)
        {
            Log.Write("Outlook: " + ex);
            notes.Enqueue("Outlook-Fehler: " + Short(ex.Message));
            return LoadCache()?.Events ?? new();
        }
    }

    static async Task<List<AgendaEvent>> LoadFeed(FeedConfig f, DateTime from, DateTime to, ConcurrentQueue<string> notes)
    {
        try { return await IcsSource.FetchAsync(f, from, to).ConfigureAwait(false); }
        catch (Exception ex)
        {
            Log.Write($"Feed '{f.Name}': {ex}");
            notes.Enqueue($"{f.Name}: {Short(ex.Message)}");
            return new();
        }
    }

    static OutlookCache? LoadCache()
    {
        try { return File.Exists(CachePath) ? Config.Deserialize<OutlookCache>(File.ReadAllText(CachePath)) : null; }
        catch { return null; }
    }

    static string Short(string s) => s.Length > 60 ? s[..57] + "…" : s;
}

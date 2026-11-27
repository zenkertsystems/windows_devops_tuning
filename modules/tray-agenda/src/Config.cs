using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace TrayAgenda;

public sealed class FeedConfig
{
    public string Name { get; set; } = "Google";
    public string Url { get; set; } = "";
    public string Color { get; set; } = "#4285F4";
    public bool Enabled { get; set; } = true;
}

public sealed class Config
{
    public static string Dir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TrayAgenda");
    public static string FilePath => Path.Combine(Dir, "config.json");

    /// <summary>"Beside" = neben dem Windows-Kalender-Flyout, "Replace" = statt des Windows-Flyouts.</summary>
    public string Mode { get; set; } = "Beside";
    /// <summary>Monatsübersicht anzeigen. null = automatisch (nur im Replace-Modus).</summary>
    public bool? ShowMonth { get; set; }
    public int DaysAhead { get; set; } = 14;
    /// <summary>Höhe in DIP; 0 = volle Bildschirmhöhe (bündig mit dem Windows-Flyout).</summary>
    public int PanelHeight { get; set; } = 0;
    public int PanelWidth { get; set; } = 360;
    public int RefreshMinutes { get; set; } = 5;

    public bool IncludeOutlook { get; set; } = true;
    /// <summary>Outlook automatisch (unsichtbar) starten, wenn es nicht läuft. Sonst wird der letzte Stand angezeigt.</summary>
    public bool StartOutlookIfNotRunning { get; set; } = true;
    /// <summary>Wie oft Outlook höchstens im Hintergrund gestartet wird, wenn es geschlossen ist.</summary>
    public int OutlookStartIntervalMinutes { get; set; } = 30;
    public List<string> OutlookExcludeFolders { get; set; } = new();
    public Dictionary<string, string> OutlookFolderColors { get; set; } = new();

    /// <summary>iCal-Feeds, z.B. Google: Kalendereinstellungen → "Privatadresse im iCal-Format".</summary>
    public List<FeedConfig> IcsFeeds { get; set; } = new();

    [JsonIgnore] public bool ReplaceMode => string.Equals(Mode, "Replace", StringComparison.OrdinalIgnoreCase);
    [JsonIgnore] public bool MonthVisible => ShowMonth ?? ReplaceMode;
    [JsonIgnore] public bool IsNew { get; private set; }

    static readonly JsonSerializerOptions Opts = new()
    {
        WriteIndented = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
        PropertyNameCaseInsensitive = true,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public static Config Load()
    {
        Directory.CreateDirectory(Dir);
        if (!File.Exists(FilePath))
        {
            var c = new Config { IsNew = true };
            c.IcsFeeds.Add(new FeedConfig { Name = "Google (Beispiel – URL eintragen)", Url = "", Enabled = false });
            c.Save();
            return c;
        }
        for (int attempt = 0; ; attempt++)
        {
            try
            {
                return JsonSerializer.Deserialize<Config>(File.ReadAllText(FilePath), Opts) ?? new Config();
            }
            catch (IOException) when (attempt < 5)
            {
                System.Threading.Thread.Sleep(100);
            }
            catch (Exception ex)
            {
                Log.Write("Config fehlerhaft: " + ex.Message);
                return new Config();
            }
        }
    }

    public void Save()
    {
        Directory.CreateDirectory(Dir);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(this, Opts));
    }

    public static string Serialize<T>(T value) => JsonSerializer.Serialize(value, Opts);
    public static T? Deserialize<T>(string json) => JsonSerializer.Deserialize<T>(json, Opts);
}

static class Log
{
    static readonly object Gate = new();
    public static string FilePath => Path.Combine(Config.Dir, "log.txt");

    public static void Write(string msg)
    {
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(Config.Dir);
                var fi = new FileInfo(FilePath);
                if (fi.Exists && fi.Length > 1_000_000) fi.Delete();
                File.AppendAllText(FilePath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {msg}{Environment.NewLine}");
            }
        }
        catch { }
    }
}

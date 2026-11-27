using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows.Forms;
using System.Windows.Threading;

namespace TrayAgenda;

sealed class TrayIcon : IDisposable
{
    readonly Controller ctl;
    readonly NotifyIcon icon;
    readonly ToolStripMenuItem miBeside, miReplace, miAutostart;
    readonly DispatcherTimer dayTimer;
    IntPtr hIcon;
    int iconDay = -1;

    public TrayIcon(Controller ctl)
    {
        this.ctl = ctl;
        var menu = new ContextMenuStrip();
        menu.Items.Add("Termine anzeigen", null, (_, _) => ctl.ShowStandalone());
        menu.Items.Add("Jetzt aktualisieren", null, (_, _) => _ = ctl.RefreshAsync());
        menu.Items.Add(new ToolStripSeparator());
        miBeside = new ToolStripMenuItem("Uhr-Klick: neben dem Windows-Kalender", null, (_, _) => ctl.SetMode(false));
        miReplace = new ToolStripMenuItem("Uhr-Klick: statt des Windows-Kalenders", null, (_, _) => ctl.SetMode(true));
        menu.Items.Add(miBeside);
        menu.Items.Add(miReplace);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Einstellungen bearbeiten (config.json)", null, (_, _) => Open("notepad.exe", Config.FilePath));
        menu.Items.Add("Protokoll öffnen", null, (_, _) => Open("notepad.exe", Log.FilePath));
        miAutostart = new ToolStripMenuItem("Mit Windows starten", null, (_, _) => { Autostart.Enabled = !Autostart.Enabled; Sync(); });
        menu.Items.Add(miAutostart);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Beenden", null, (_, _) => ctl.Exit());

        icon = new NotifyIcon { ContextMenuStrip = menu, Visible = true, Text = "TrayAgenda" };
        icon.MouseClick += (_, e) => { if (e.Button == MouseButtons.Left) ctl.ShowStandalone(); };
        UpdateIcon();
        Sync();

        dayTimer = new DispatcherTimer { Interval = TimeSpan.FromMinutes(1) };
        dayTimer.Tick += (_, _) => UpdateIcon();
        dayTimer.Start();
    }

    public void Sync()
    {
        bool replace = ctl.Config.ReplaceMode;
        miBeside.Checked = !replace;
        miReplace.Checked = replace;
        miAutostart.Checked = Autostart.Enabled;
    }

    static void Open(string exe, string arg)
    {
        try { Process.Start(new ProcessStartInfo(exe, $"\"{arg}\"") { UseShellExecute = true }); }
        catch (Exception ex) { Log.Write("Öffnen: " + ex.Message); }
    }

    void UpdateIcon()
    {
        int day = DateTime.Today.Day;
        if (day == iconDay) return;
        iconDay = day;

        using var bmp = new Bitmap(32, 32);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.Clear(Color.Transparent);
            using var body = RoundRect(new RectangleF(1.5f, 3.5f, 29, 27), 5);
            using var white = new SolidBrush(Color.FromArgb(250, 250, 250));
            g.FillPath(white, body);
            using var clip = new Region(body);
            g.Clip = clip;
            using var accent = new SolidBrush(Color.FromArgb(0x0F, 0x6C, 0xBD));
            g.FillRectangle(accent, 0, 0, 32, 11);
            g.ResetClip();
            using var pen = new Pen(Color.FromArgb(0x0F, 0x6C, 0xBD), 1.5f);
            g.DrawPath(pen, body);
            using var font = new Font("Segoe UI", day >= 10 ? 13f : 14f, FontStyle.Bold, GraphicsUnit.Pixel);
            using var text = new SolidBrush(Color.FromArgb(0x1B, 0x1B, 0x1B));
            var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            g.DrawString(day.ToString(), font, text, new RectangleF(0, 11, 32, 20), sf);
        }
        var old = hIcon;
        hIcon = bmp.GetHicon();
        icon.Icon = Icon.FromHandle(hIcon);
        if (old != IntPtr.Zero) Native.DestroyIcon(old);
    }

    static GraphicsPath RoundRect(RectangleF r, float rad)
    {
        var p = new GraphicsPath();
        float d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    public void Dispose()
    {
        dayTimer.Stop();
        icon.Visible = false;
        icon.Dispose();
        if (hIcon != IntPtr.Zero) Native.DestroyIcon(hIcon);
    }
}

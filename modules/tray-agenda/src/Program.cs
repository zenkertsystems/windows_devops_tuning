using System;
using System.Threading;
using System.Windows;

namespace TrayAgenda;

public static class Program
{
    [STAThread]
    public static void Main()
    {
        using var mutex = new Mutex(true, @"Local\TrayAgenda.SingleInstance", out bool created);
        if (!created) return;

        AppDomain.CurrentDomain.UnhandledException += (_, e) => Log.Write("Fatal: " + e.ExceptionObject);

        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        app.DispatcherUnhandledException += (_, e) => { Log.Write("UI: " + e.Exception); e.Handled = true; };

        var controller = new Controller();
        app.Startup += (_, _) => controller.Start();
        app.Run();
        controller.Dispose();
    }
}

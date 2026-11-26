#Requires -Version 5.1
# Close only the optional promotion dialog. Never accept error/deletion dialogs.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
public static class QuietOgcs {
    delegate bool EnumProc(IntPtr hwnd, IntPtr param);
    delegate void EventProc(IntPtr hook,uint evt,IntPtr hwnd,int obj,int child,uint thread,uint time);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback,IntPtr param);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd,StringBuilder text,int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd,uint msg,IntPtr w,IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min,uint max,IntPtr module,EventProc callback,uint pid,uint thread,uint flags);
    [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr hook);
    static EventProc handler;
    static void Check(IntPtr hwnd) {
        if(hwnd==IntPtr.Zero) return;
        var text=new StringBuilder(256);
        GetWindowText(hwnd,text,text.Capacity);
        if(text.ToString()!="Help Promote OGCS") return;
        uint pid; GetWindowThreadProcessId(hwnd,out pid);
        try {
            using(var p=Process.GetProcessById((int)pid)) {
                if(!p.ProcessName.Equals("OutlookGoogleCalendarSync",StringComparison.OrdinalIgnoreCase)) return;
                PostMessage(hwnd,0x0010,IntPtr.Zero,IntPtr.Zero);
            }
        } catch(ArgumentException) {}
    }
    public static void Run() {
        handler=(hook,evt,hwnd,obj,child,thread,time)=>{if(obj==0) Check(hwnd);};
        var h=SetWinEventHook(0x8002,0x8002,IntPtr.Zero,handler,0,0,0);
        if(h==IntPtr.Zero) throw new InvalidOperationException("Could not register window hook.");
        EnumWindows((hwnd,param)=>{Check(hwnd);return true;},IntPtr.Zero);
        try {Application.Run();} finally {UnhookWinEvent(h);}
    }
}
'@
$mutex = New-Object Threading.Mutex($false, 'Local\WindowsDevOps-QuietOGCS')
if (-not $mutex.WaitOne(0)) { exit }
try { [QuietOgcs]::Run() } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }

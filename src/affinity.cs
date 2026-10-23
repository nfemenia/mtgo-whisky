using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

// Limits MTGO to a few CPU cores. MTGO freezes on "Loading Magic Online" after login under
// Wine when it sees all cores (see pauleve/docker-mtgo#160). Wine's `start /affinity` is ignored,
// but process affinity IS inherited by child processes, so we set it on ourselves and then start
// MTGO through its ClickOnce shortcut (MTGO refuses to run if MTGO.exe is started directly).
// The ClickOnce service dfsvc.exe must not already be running, or MTGO inherits from it instead.
//
// Usage: affinity.exe <hex mask> [program]   -> limit to CPUs in mask, then start program
//        affinity.exe check                  -> print the running MTGO's affinity
class P {
    static int Main(string[] a) {
        if (a.Length > 0 && a[0] == "check") {
            foreach (var p in Process.GetProcessesByName("MTGO"))
                Console.WriteLine("MTGO pid " + p.Id + " affinity 0x" + ((long)p.ProcessorAffinity).ToString("x"));
            return 0;
        }
        long mask = Convert.ToInt64(a.Length > 0 ? a[0] : "3", 16);
        string exe = a.Length > 1 ? a[1] : FindMtgo();
        if (exe == null) { Console.Error.WriteLine("MTGO.exe not found"); return 1; }
        Process.GetCurrentProcess().ProcessorAffinity = (IntPtr)mask;
        // .appref-ms goes through the shell -> dfsvc.exe, which then inherits the affinity and starts MTGO
        bool shell = exe.EndsWith(".appref-ms", StringComparison.OrdinalIgnoreCase);
        var psi = new ProcessStartInfo(exe) { UseShellExecute = shell, WorkingDirectory = Path.GetDirectoryName(exe) };
        Process.Start(psi);
        Console.WriteLine("started " + exe);
        return 0;
    }
    // Newest ClickOnce install of MTGO.exe (path changes on every MTGO update)
    static string FindMtgo() {
        var root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Apps\2.0");
        return Directory.GetFiles(root, "MTGO.exe", SearchOption.AllDirectories)
            .Where(f => !f.Contains(@"\Data\"))
            .OrderByDescending(f => File.GetLastWriteTimeUtc(f)).FirstOrDefault();
    }
}

// Game runtime component: reorder only windows owned by the parent game.
// Never activates windows, changes styles, or sends keyboard/mouse input.
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Collections.Generic;

internal static class NativeLayerOrder {
    [DllImport("user32.dll")] static extern IntPtr GetTopWindow(IntPtr window);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr window,uint command);
    [DllImport("user32.dll")] static extern IntPtr BeginDeferWindowPos(int count);
    [DllImport("user32.dll")] static extern IntPtr DeferWindowPos(IntPtr batch,IntPtr window,IntPtr after,int x,int y,int cx,int cy,uint flags);
    [DllImport("user32.dll")] static extern bool EndDeferWindowPos(IntPtr batch);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr window,IntPtr after,int x,int y,int cx,int cy,uint flags);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    static int Main(string[] args) {
        int parentId;
        if (args.Length != 1 || !int.TryParse(args[0], out parentId)) return 2;
        Process parent;
        try { parent=Process.GetProcessById(parentId); } catch { return 2; }
        var watcher=new Thread(delegate() {
            try { parent.WaitForExit(); } catch {}
            Environment.Exit(0);
        });
        watcher.IsBackground=true;
        watcher.Start();
        string line;
        while ((line=Console.ReadLine())!=null) {
            var desired=new List<IntPtr>();
            foreach (string token in line.Split(' ')) {
                long value;
                if (!long.TryParse(token,out value) || value==0) continue;
                var window=new IntPtr(value);
                uint owner;
                GetWindowThreadProcessId(window,out owner);
                if (owner!=(uint)parentId || !IsWindowVisible(window)) continue;
                if (!desired.Contains(window)) desired.Add(window);
            }
            // Moving a window does not necessarily change its stacking order.
            // Never cycle every surface through HWND_TOPMOST on every move:
            // those intermediate orders briefly obscure other transparent art.
            desired.Reverse(); // top to bottom
            var targets=new HashSet<IntPtr>(desired);
            var actual=new List<IntPtr>();
            for (var window=GetTopWindow(IntPtr.Zero);window!=IntPtr.Zero;window=GetWindow(window,2)) {
                if (targets.Contains(window)) actual.Add(window);
            }
            bool same=actual.Count==desired.Count;
            for (int i=0;same && i<actual.Count;i++) same=actual[i]==desired[i];
            if (same || desired.Count==0) continue;
            // Only relocate a window whose nearest game window above it is
            // wrong. Do not lift every furniture surface through the top.
            for(int i=0;i<desired.Count;i++) {
                var window=desired[i];
                var nearest=GetWindow(window,3); // GW_HWNDPREV
                while(nearest!=IntPtr.Zero && !targets.Contains(nearest)) nearest=GetWindow(nearest,3);
                var expected=i==0 ? IntPtr.Zero : desired[i-1];
                if(nearest==expected) continue;
                SetWindowPos(window,i==0 ? new IntPtr(-1) : expected,0,0,0,0,0x0010|0x0001|0x0002|0x0200);
            }
        }
        return 0;
    }
}

// Local keyboard/click activity bridge. No identities, positions or text leave it.
using System;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

internal static class TypingInput {
    private delegate IntPtr HookProc(int code, IntPtr message, IntPtr data);
    private static readonly HookProc Callback = OnKey;
    private static readonly HookProc MouseCallback = OnMouse;
    private static readonly bool[] Down = new bool[256];
    private static IntPtr hook;
    private static IntPtr mouseHook;
    private static long presses;
    [DllImport("user32.dll", SetLastError=true)] private static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr module, uint thread);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr handle);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr handle, int code, IntPtr message, IntPtr data);
    [DllImport("kernel32.dll", CharSet=CharSet.Auto)] private static extern IntPtr GetModuleHandle(string name);

    private static IntPtr OnKey(int code, IntPtr message, IntPtr data) {
        if (code >= 0) {
            int key = Marshal.ReadInt32(data);
            int kind = message.ToInt32();
            if (key >= 0 && key < Down.Length) {
                if (kind == 0x100 || kind == 0x104) {
                    // One press per down/up pair, not Windows auto-repeat.
                    if (!Down[key] && key != 16 && key != 17 && key != 18 && key != 91 && key != 92 && (key < 160 || key > 165)) presses++;
                    Down[key] = true;
                } else if (kind == 0x101 || kind == 0x105) Down[key] = false;
            }
        }
        return CallNextHookEx(hook, code, message, data);
    }

    private static IntPtr OnMouse(int code, IntPtr message, IntPtr data) {
        int kind = message.ToInt32();
        // Button-down only: left, right, middle and side buttons. Movement,
        // releases and wheel scrolling do not inflate the activity counter.
        if (code >= 0 && (kind == 0x201 || kind == 0x204 || kind == 0x207 || kind == 0x20B)) presses++;
        return CallNextHookEx(mouseHook, code, message, data);
    }

    [STAThread] private static void Main(string[] args) {
        if (args.Length != 3) return;
        int pid, port;
        if (!int.TryParse(args[0], out pid) || !int.TryParse(args[1], out port) || port < 1024 || port > 65535) return;
        if (args[2].Length != 32) return;
        try {
            using (Process parent = Process.GetProcessById(pid))
            using (UdpClient udp = new UdpClient())
            using (Timer timer = new Timer()) {
                udp.Connect(IPAddress.Loopback, port);
                hook = SetWindowsHookEx(13, Callback, GetModuleHandle(null), 0);
                if (hook == IntPtr.Zero) return;
                mouseHook = SetWindowsHookEx(14, MouseCallback, GetModuleHandle(null), 0);
                if (mouseHook == IntPtr.Zero) { UnhookWindowsHookEx(hook); return; }
                try {
                    long previous = -1;
                    int quietTicks = 0;
                    timer.Interval = 16;
                    timer.Tick += delegate {
                        try {
                            if (parent.HasExited) { Application.ExitThread(); return; }
                            // A heartbeat also confirms that the input bridge is alive.
                            if (presses != previous || ++quietTicks >= 30) {
                                byte[] packet = Encoding.ASCII.GetBytes(args[2] + ":" + presses.ToString(System.Globalization.CultureInfo.InvariantCulture));
                                udp.Send(packet, packet.Length);
                                previous = presses;
                                quietTicks = 0;
                            }
                        } catch { Application.ExitThread(); }
                    };
                    timer.Start();
                    Application.Run();
                } finally { UnhookWindowsHookEx(mouseHook); UnhookWindowsHookEx(hook); }
            }
        } catch { /* The game shows a disconnected status when startup fails. */ }
    }
}

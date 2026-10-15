# Local keyboard and click activity bridge

This Windows helper is original project code. BongoCat's installed files were
inspected for application structure and interface names only; no assets or code
were copied.

`TypingInput.exe` is built from `TypingInput.cs` with the Windows .NET Framework
C# compiler. Run from the project directory in PowerShell:

```powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ '/out:addons\typing_input\TypingInput.exe' /reference:System.Windows.Forms.dll 'addons\typing_input\TypingInput.cs'
```

- Starts only in typing mode; leaving that mode, pausing, or closing stops it.
- A Windows low-level keyboard hook counts distinct down/up pairs. Standalone
  modifiers and held-key auto-repeat do not generate extra animation pulses.
- A low-level mouse hook counts left/right/middle/side button-down events. Releases,
  movement and wheel scrolling are excluded. No mouse coordinates are read.
- Always calls `CallNextHookEx`; never suppresses or replaces keyboard/mouse input.
- Key identity is used transiently in a 256-element held-key array. No text,
  keystroke log, active-window information, or file output is produced.
- Only an aggregate counter plus a per-launch random token is sent to a UDP
  socket bound to `127.0.0.1`. No external network endpoint is used.
- A 16 ms message-loop timer sends counts outside the hook callback. A heartbeat
  lets the game show connection errors. Parent exit closes the helper.
- No service, startup registration, administrator privilege, or driver install.
- Protected desktops and elevated apps may restrict observation. The feature
  does not attempt to bypass Windows restrictions.

The typing window displays current speed: actions in the trailing 3 seconds
multiplied by 20 as APM, updated each frame. Sustained 5 actions/sec gives 300 APM;
stopping reaches zero within 3 seconds. This is our short-window estimator,
not a reproduction of StarCraft's internal formula. It also shows a session
total and activity time. Activity time
stops after 30 seconds without an action and while paused/disconnected or in
living mode. Reading without input is not measured as active computer use.
Species/mode changes preserve session statistics; exiting the game resets them.

Windows API reference: [LowLevelKeyboardProc](https://learn.microsoft.com/en-us/windows/win32/winmsg/lowlevelkeyboardproc).

Packaging must copy the executable outside the PCK to
`addons/typing_input/TypingInput.exe` beside the installed game.

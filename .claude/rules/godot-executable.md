# Godot executable

`godot` is not on `PATH`. Use this build for headless tests and imports:

`C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`

The folder name includes `.exe`. The binary is the file inside it. Headless output is cleaner from `Godot_v4.7-stable_win64_console.exe` in the same folder.

```powershell
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
```

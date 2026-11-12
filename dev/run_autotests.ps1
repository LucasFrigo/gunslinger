# Runs the headless autotest suites and prints one PASS / FAIL line each.
#
#   powershell -File dev/run_autotests.ps1                # every suite but steam / steamcycle
#   powershell -File dev/run_autotests.ps1 duel ragdoll   # just these
#
# Single-process suites run with `--fixed-fps 90` (one physics tick per frame, game time as fast
# as the CPU allows) and in parallel. Suites that host LAN share one port, so they and the
# multiplayer groups run one after another at real time: ENet handshakes are wall-clock.
# Logs land in $env:TEMP\gunslinger-autotest\<suite>.log. Exit code 1 if anything failed.

param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Suites)

$godot = "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
$root = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $env:TEMP "gunslinger-autotest"
New-Item -ItemType Directory -Force $logs | Out-Null

$parallel = "duel", "gauntlet", "multi", "horde", "props", "practice", "ragdoll", "chunks", "i18n"
$lan = "load", "lobby", "intro"
# First name hosts; the rest join after HOST_LEAD seconds.
$groups = [ordered]@{ host = @("host", "join"); lobbyhost = @("lobbyhost", "lobbyjoin", "lobbyjoin"); introhost = @("introhost", "introjoin") }
$HOST_LEAD = 4

if ($Suites) {
	$parallel = @($parallel | Where-Object { $Suites -contains $_ })
	$lan = @($lan + "steam", "steamcycle" | Where-Object { $Suites -contains $_ })
	foreach ($k in @($groups.Keys)) { if ($Suites -notcontains $k) { $groups.Remove($k) } }
}

function Start-Suite([string]$suite, [string]$tag, [bool]$fast) {
	$argv = @("--headless")
	if ($fast) { $argv += "--fixed-fps", "90", "--disable-vsync" }
	$argv += "--path", "`"$root`"", "--", "--autotest=$suite"
	$log = Join-Path $logs "$tag.log"
	$p = Start-Process -FilePath $godot -ArgumentList $argv -NoNewWindow -PassThru `
		-RedirectStandardOutput $log -RedirectStandardError "$log.err"
	$null = $p.Handle  # PS 5.1: without a cached handle, ExitTime reads empty
	[pscustomobject]@{ Name = $tag; Proc = $p; Log = $log }
}

function Report($runs) {
	foreach ($r in $runs) {
		$r.Proc.WaitForExit()
		$line = Select-String -Path $r.Log -Pattern "AUTOTEST (PASS|FAIL).*" | Select-Object -Last 1
		$text = if ($line) { $line.Matches[0].Value } else { "AUTOTEST FAIL: no result line (see $($r.Log))" }
		if ($text -notlike "AUTOTEST PASS*") { $script:failed = $true }
		"{0,-12} {1,4}s  {2}" -f $r.Name, [int]($r.Proc.ExitTime - $r.Proc.StartTime).TotalSeconds, $text
	}
}

$failed = $false
$total = [Diagnostics.Stopwatch]::StartNew()
$fastRuns = @($parallel | ForEach-Object { Start-Suite $_ $_ $true })
# The LAN lane runs beside the parallel suites, one process at a time.
foreach ($s in $lan) { Report @(Start-Suite $s $s ($s -notlike "steam*")) }
foreach ($k in $groups.Keys) {
	$runs = @(); $i = 0
	foreach ($s in $groups[$k]) {
		if ($i -gt 0) { Start-Sleep -Seconds $HOST_LEAD }
		$runs += Start-Suite $s ("{0}{1}" -f $s, $(if ($s -eq "lobbyjoin") { $i } else { "" })) $false
		$i++
	}
	Report $runs
}
Report $fastRuns
"total {0}s" -f [int]$total.Elapsed.TotalSeconds
exit [int]$failed

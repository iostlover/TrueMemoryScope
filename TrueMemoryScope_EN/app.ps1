Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$xamlPath = Join-Path $scriptDir "ui.xaml"

if (-not (Test-Path $xamlPath)) {
    [System.Windows.MessageBox]::Show("ui.xaml not found: $xamlPath", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit 1
}

[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Control references
$txtRamUsage = $window.FindName("TxtRamUsage")
$pbRamUsage = $window.FindName("PbRamUsage")
$txtRamDetails = $window.FindName("TxtRamDetails")
$txtCommitUsage = $window.FindName("TxtCommitUsage")
$txtCacheUsage = $window.FindName("TxtCacheUsage")
$txtPoolUsage = $window.FindName("TxtPoolUsage")
$gridProcesses = $window.FindName("GridProcesses")
$txtFilter = $window.FindName("TxtFilter")
$chkOnlyHidden = $window.FindName("ChkOnlyHidden")
$btnRefresh = $window.FindName("BtnRefresh")
$btnExplain = $window.FindName("BtnExplain")
$btnKill = $window.FindName("BtnKill")
$txtStatus = $window.FindName("TxtStatus")
$txtUpdateTime = $window.FindName("TxtUpdateTime")

$allProcessData = [System.Collections.Generic.List[PSCustomObject]]::new()

function Update-MemoryData {
    $txtStatus.Text = "Updating system memory information..."
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedGB = [math]::Round($totalGB - $freeGB, 2)
        $usedPercent = [math]::Round(($usedGB / $totalGB) * 100, 1)

        $txtRamUsage.Text = "$usedGB GB / $totalGB GB ($usedPercent%)"
        $pbRamUsage.Value = $usedPercent
        $txtRamDetails.Text = "Available: $freeGB GB | Hardware Reserved: $([math]::Round((64 - $totalGB), 2)) GB"

        if ($usedPercent -gt 85) {
            $pbRamUsage.Foreground = [System.Windows.Media.Brushes]::Red
        } elseif ($usedPercent -gt 70) {
            $pbRamUsage.Foreground = [System.Windows.Media.Brushes]::Orange
        } else {
            $pbRamUsage.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
        }
    } catch {}

    try {
        $perfCounters = Get-Counter -Counter @(
            "\Memory\Committed Bytes",
            "\Memory\Commit Limit",
            "\Memory\Pool Paged Bytes",
            "\Memory\Pool Nonpaged Bytes",
            "\Memory\Standby Cache Normal Priority Bytes",
            "\Memory\Standby Cache Reserve Bytes"
        ) -ErrorAction SilentlyContinue

        if ($perfCounters) {
            $samples = $perfCounters.CounterSamples
            $committedGB = [math]::Round(($samples | Where-Object { $_.Path -like "*committed bytes" }).CookedValue / 1GB, 1)
            $commitLimitGB = [math]::Round(($samples | Where-Object { $_.Path -like "*commit limit" }).CookedValue / 1GB, 1)
            $pagedPoolGB = [math]::Round(($samples | Where-Object { $_.Path -like "*pool paged bytes" }).CookedValue / 1GB, 2)
            $nonPagedPoolGB = [math]::Round(($samples | Where-Object { $_.Path -like "*pool nonpaged bytes" }).CookedValue / 1GB, 2)
            $standbyGB = [math]::Round((($samples | Where-Object { $_.Path -like "*standby cache*" } | Measure-Object CookedValue -Sum).Sum) / 1GB, 1)

            $txtCommitUsage.Text = "$committedGB / $commitLimitGB GB"
            $txtCacheUsage.Text = "$standbyGB GB"
            $txtPoolUsage.Text = "NP: $nonPagedPoolGB GB / P: $pagedPoolGB GB"
        }
    } catch {}

    $allProcessData.Clear()
    $processes = Get-Process
    foreach ($p in $processes) {
        if ($p.WorkingSet64 -lt 10MB) { continue }
        $wsMB = [math]::Round($p.WorkingSet64 / 1MB, 1)
        $pmMB = [math]::Round($p.PrivateMemorySize64 / 1MB, 1)
        $hiddenMB = [math]::Round($wsMB - $pmMB, 1)
        $virtGB = [math]::Round($p.VirtualMemorySize64 / 1GB, 2)

        $wsStr = if ($wsMB -ge 1024) { "$([math]::Round($wsMB/1024, 2)) GB" } else { "$wsMB MB" }
        $pmStr = if ($pmMB -ge 1024) { "$([math]::Round($pmMB/1024, 2)) GB" } else { "$pmMB MB" }
        $hiddenStr = if ([math]::Abs($hiddenMB) -ge 1024) { "$([math]::Round($hiddenMB/1024, 2)) GB" } else { "$hiddenMB MB" }

        $procPath = ""
        try { $procPath = $p.Path } catch { $procPath = "(Access Denied)" }

        $item = [PSCustomObject]@{
            Name = $p.ProcessName
            Id = $p.Id
            WorkingSet64 = $p.WorkingSet64
            WorkingSetStr = $wsStr
            PrivateMem64 = $p.PrivateMemorySize64
            PrivateMemStr = $pmStr
            HiddenMB = $hiddenMB
            HiddenMemStr = $hiddenStr
            VirtualMem64 = $p.VirtualMemorySize64
            VirtualMemStr = "$virtGB GB"
            Path = $procPath
            RawProcess = $p
        }
        $allProcessData.Add($item)
    }

    Apply-Filter
    $txtUpdateTime.Text = "Last updated: $(Get-Date -Format 'HH:mm:ss')"
    $txtStatus.Text = "Parsed $($allProcessData.Count) processes (Sorted by real physical RAM usage)"
}

function Apply-Filter {
    $filterText = $txtFilter.Text.Trim()
    $onlyHidden = $chkOnlyHidden.IsChecked

    $filtered = $allProcessData | Where-Object {
        $matchText = if ($filterText) { $_.Name -like "*$filterText*" } else { $true }
        $matchHidden = if ($onlyHidden) { $_.HiddenMB -gt 1000 } else { $true }
        $matchText -and $matchHidden
    } | Sort-Object WorkingSet64 -Descending

    $gridProcesses.ItemsSource = [System.Collections.ArrayList]@($filtered)
}

$btnRefresh.Add_Click({ Update-MemoryData })
$txtFilter.Add_TextChanged({ Apply-Filter })
$chkOnlyHidden.Add_Click({ Apply-Filter })

$btnExplain.Add_Click({
    $lines = @(
        "[ Why does Task Manager show misleading memory numbers? ]",
        "",
        "1. Task Manager's 'Processes' tab only shows 'Private Working Set'.",
        "   This represents memory strictly exclusive to that process that cannot be shared.",
        "",
        "2. Modern games (Unreal Engine, etc.) and heavy media apps map huge assets",
        "   (textures, 3D models, audio packs) directly using 'Memory Mapped Files'.",
        "",
        "3. Windows classifies Memory Mapped Files as 'Shareable', which causes Task Manager",
        "   to EXCLUDE them from the process list memory column!",
        "",
        "4. As a result, a game can easily hold 35 GB of physical RAM, yet Task Manager",
        "   reports only '7 GB', leaving 28 GB completely unaccounted for in the process list.",
        "",
        "The 'Real RAM Usage (WS)' column in TrueMemoryScope shows the TRUE physical RAM",
        "resident size (Working Set) currently occupied on your RAM hardware!"
    )
    $msg = $lines -join "`n"

    [System.Windows.MessageBox]::Show(
        $msg,
        "Understanding Windows Memory & Task Manager Pitfalls",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

$btnKill.Add_Click({
    $selected = $gridProcesses.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Please select a process to terminate.", "Notice", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $confirmMsg = "Process '$($selected.Name)' (PID: $($selected.Id))`nReal RAM: $($selected.WorkingSetStr)`n`nAre you sure you want to kill this process?`n(Unsaved data will be lost)"
    $result = [System.Windows.MessageBox]::Show(
        $confirmMsg,
        "Terminate Process Confirmation",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Stop-Process -Id $selected.Id -Force
            [System.Windows.MessageBox]::Show("Process '$($selected.Name)' terminated.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            Update-MemoryData
        } catch {
            [System.Windows.MessageBox]::Show("Failed to kill process: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
})

$window.Add_KeyDown({
    if ($_.Key -eq [System.Windows.Input.Key]::F5) {
        Update-MemoryData
    }
})

$window.Add_Loaded({
    Update-MemoryData
})

$window.ShowDialog() | Out-Null

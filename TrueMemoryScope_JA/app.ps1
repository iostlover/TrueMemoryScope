Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$xamlPath = Join-Path $scriptDir "ui.xaml"

if (-not (Test-Path $xamlPath)) {
    [System.Windows.MessageBox]::Show("ui.xaml が見つかりません: $xamlPath", "エラー", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit 1
}

[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# コントロール取得
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
    $txtStatus.Text = "システムメモリ情報を更新中..."
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedGB = [math]::Round($totalGB - $freeGB, 2)
        $usedPercent = [math]::Round(($usedGB / $totalGB) * 100, 1)

        $txtRamUsage.Text = "$usedGB GB / $totalGB GB ($usedPercent%)"
        $pbRamUsage.Value = $usedPercent
        $txtRamDetails.Text = "利用可能(空き): $freeGB GB | ハードウェア予約等: $([math]::Round((64 - $totalGB), 2)) GB"

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
            $txtPoolUsage.Text = "非ページ:$nonPagedPoolGB G / ページ:$pagedPoolGB G"
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
        try { $procPath = $p.Path } catch { $procPath = "(アクセス制限)" }

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
    $txtUpdateTime.Text = "最終更新: $(Get-Date -Format 'HH:mm:ss')"
    $txtStatus.Text = "合計 $($allProcessData.Count) プロセスを解析完了 (物理消費順にソート)"
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
        "【なぜタスクマネージャーの数値と食い違うのか？】",
        "",
        "1. タスクマネージャーの「プロセス」一覧のメモリ列は、",
        "   『プライベート作業セット (Private Working Set)』を表示しています。",
        "   これは「他のアプリと絶対に共有されない独自メモリ」だけを計上した数字です。",
        "",
        "2. 一方で、最新のゲーム（Unreal Engine製など）や動画編集ソフトは、",
        "   膨大なアセットやテクスチャを『メモリマップトファイル（ファイルマッピング）』",
        "   としてメモリに直接読み込みます。",
        "",
        "3. このマップされた領域は、Windowsの仕様上「共有可能 (Shareable)」と",
        "   みなされるため、タスクマネージャーのプロセス一覧からは除外されます！",
        "",
        "4. その結果、例えばゲームが実際には 35 GB もの物理RAMを消費していても、",
        "   タスクマネージャー上では「7 GB」としか表示されず、",
        "   残り「28 GB」が不可視になってしまうのです。",
        "",
        "本ツール『TrueMemoryScope』の「🔥 物理メモリ実消費 (WS)」列こそが、",
        "そのアプリが実際にRAMチップ上に占有している真のメモリ量です！"
    )
    $msg = $lines -join "`n"

    [System.Windows.MessageBox]::Show(
        $msg,
        "メモリ表示の仕組みとタスクマネージャーの罠",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

$btnKill.Add_Click({
    $selected = $gridProcesses.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("強制終了するプロセスを一覧から選択してください。", "案内", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $confirmMsg = "プロセス '$($selected.Name)' (PID: $($selected.Id))`n物理メモリ: $($selected.WorkingSetStr)`n`n本当にこのプロセスを終了しますか？`n(未保存のデータは失われます)"
    $result = [System.Windows.MessageBox]::Show(
        $confirmMsg,
        "プロセス終了の確認",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Stop-Process -Id $selected.Id -Force
            [System.Windows.MessageBox]::Show("プロセス '$($selected.Name)' を終了しました。", "成功", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            Update-MemoryData
        } catch {
            [System.Windows.MessageBox]::Show("プロセスの終了に失敗しました: $($_.Exception.Message)", "エラー", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
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

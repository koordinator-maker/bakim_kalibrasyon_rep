# REV: 1.0 | 2025-09-24 | Hash: 96858568 | Parça: 1/1
<#
  Windows Task Scheduler kaydı (PowerShell ScheduledTasks modülü ile)
  Çalışma klasörü, tetikleyici ve haklar düzgün ayarlanır.
#>

$ProjectRoot = "C:\dev\bakim_kalibrasyon"
$CmdPath     = Join-Path $ProjectRoot "scripts\calibration_reminders.cmd"
$TaskName    = "bk_calibration_reminders"
$Hour        = 9     # 09:00
$Minute      = 0

# Erişim: Mevcut kullanıcı ile en yüksek ayrıcalık
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

# GÜNLÜK tetikleyici (09:00)
$Trigger   = New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.AddHours($Hour).AddMinutes($Minute).TimeOfDay)

# Eylem: .cmd sarmalayıcıyı çalıştır
$Action    = New-ScheduledTaskAction -Execute $CmdPath

# Görev tanımı
$Settings  = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -StartWhenAvailable
$Task      = New-ScheduledTask -Action $Action -Principal $Principal -Trigger $Trigger -Settings $Settings

# Var ise sil (force) ve yeniden oluştur
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
Register-ScheduledTask -TaskName $TaskName -InputObject $Task | Out-Null

Write-Host "OK -> Task '$TaskName' registered to run daily at $Hour:$('{0:00}' -f $Minute)."

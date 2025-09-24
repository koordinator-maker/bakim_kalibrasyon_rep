# REV: 1.0 | 2025-09-24 | Hash: 611925f3 | Parça: 1/1
# scripts/open_mail_draft.ps1

param(
  [string[]] $To,
  [string[]] $Cc,
  [string[]] $Bcc,

  [Parameter(Mandatory = $true)]
  [string]   $Subject,

  [Parameter(Mandatory = $true)]
  [string]   $BodyText,

  [string[]] $Attachments,     # Varsayılanı gövdede vereceğiz
  [switch]   $AsHtml,          # HTML gövde isterse
  [string]   $FromAccount      # Outlook profilindeki gönderen hesap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Varsayılanlar
if (-not $Attachments) { $Attachments = @() }
$asHtmlFlag = $PSBoundParameters.ContainsKey('AsHtml') -and $AsHtml.IsPresent

function Get-OutlookApp {
  try { [Runtime.InteropServices.Marshal]::GetActiveObject('Outlook.Application') }
  catch { New-Object -ComObject Outlook.Application }
}

$ol = Get-OutlookApp
$mail = $ol.CreateItem(0)  # olMailItem

# Gönderen hesabı (varsa)
if ($FromAccount) {
  $acct = @($ol.Session.Accounts) | Where-Object { $_.SmtpAddress -ieq $FromAccount }
  if ($acct) { $mail.SendUsingAccount = $acct }
  else { Write-Warning "Outlook profilinde bu gönderici hesabı yok: $FromAccount" }
}

# Alıcılar
if ($To)  { $mail.To  = ($To  -join '; ') }
if ($Cc)  { $mail.CC  = ($Cc  -join '; ') }
if ($Bcc) { $mail.BCC = ($Bcc -join '; ') }

# Konu
$mail.Subject = $Subject

# Gövde
if ($asHtmlFlag) {
  Add-Type -AssemblyName System.Web
  $enc = [System.Web.HttpUtility]::HtmlEncode($BodyText)
  $mail.HTMLBody = "<pre style='font-family:Segoe UI Emoji, Segoe UI, Arial; font-size:11pt; white-space:pre-wrap;'>$enc</pre>"
} else {
  $mail.Body = $BodyText
}

# Ekler
foreach ($a in $Attachments) {
  if ([string]::IsNullOrWhiteSpace($a)) { continue }
  if (-not (Test-Path $a)) {
    Write-Warning "Ek bulunamadı: $a"
    continue
  }
  $mail.Attachments.Add((Resolve-Path $a).Path) | Out-Null
}

# Taslağı aç
$mail.Display() | Out-Null

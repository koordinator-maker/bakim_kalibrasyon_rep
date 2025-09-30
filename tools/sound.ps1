# Rev: 2025-09-30 21:30 r3

# tools/sound.ps1
# Exposes: Play-NotifySound -SoundProfile <preset|alias|off> -SoundFile <path>
# Presets (Windows Media): chimes, notify, ding, tada, chord
# Aliases (SystemSounds): asterisk, beep, exclamation, hand, question

param(
  [Parameter()][string]$SoundProfile = "notify",
  [Parameter()][string]$SoundFile = ""
)

function Resolve-PresetPath([string]$preset) {
  $media = "$env:WINDIR\Media"
  $map = @{
    "chimes"  = "chimes.wav"
    "notify"  = "Windows Notify.wav"
    "ding"    = "Windows Ding.wav"
    "tada"    = "tada.wav"
    "chord"   = "chord.wav"
  }
  if ($map.ContainsKey($preset)) {
    $p = Join-Path $media $map[$preset]
    if (Test-Path $p) { return $p }
  }
  return $null
}

function Play-NotifySound {
  param(
    [Parameter()][string]$SoundProfile = "notify",
    [Parameter()][string]$SoundFile = ""
  )
  try {
    if ($SoundProfile -eq "off") { return }

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Media         | Out-Null

    if ($SoundFile -and (Test-Path $SoundFile)) {
      $player = New-Object System.Media.SoundPlayer $SoundFile
      $player.Load(); $player.PlaySync(); return
    }

    $presetPath = Resolve-PresetPath($SoundProfile.ToLower())
    if ($presetPath) {
      $player = New-Object System.Media.SoundPlayer $presetPath
      $player.Load(); $player.PlaySync(); return
    }

    switch ($SoundProfile.ToLower()) {
      "asterisk"    { [System.Media.SystemSounds]::Asterisk.Play();    break }
      "beep"        { [System.Media.SystemSounds]::Beep.Play();        break }
      "exclamation" { [System.Media.SystemSounds]::Exclamation.Play(); break }
      "hand"        { [System.Media.SystemSounds]::Hand.Play();        break }
      "question"    { [System.Media.SystemSounds]::Question.Play();    break }
      default       { [System.Media.SystemSounds]::Asterisk.Play();    break }
    }
  } catch {
    Write-Verbose "Sound play failed: $($_.Exception.Message)"
  }
}

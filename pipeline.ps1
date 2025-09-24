# REV: 1.2 | 2025-09-24 | Hash: 3c1ee928 | Parça: 1/1
# Her dosya başında revizyon bilgisi sistemi olacak.

# >>> BLOK: SETUP | Pipeline ana betiği | ID:PS1-SET-1H7K9Q2A
Param(
  [switch]$Push,              # kullanirsaniz commit/push yapar
  [string]$PyTestArgs = "",   # orn: "-q"
  [string]$CommitMsg = "pipeline: revstamp+blockcheck+guardrail"
)
$ErrorActionPreference = "Stop"
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = "_otokodlama/out/$ts"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Step($name, $scriptBlock) {
  Write-Host "==> $name"
  try {
    & $scriptBlock 2>&1 | Tee-Object -FilePath "$outDir/$($name -replace '\s','_').log"
  } catch {
    Write-Host "X  $name FAILED"
    throw
  }
}
# <<< BLOK SONU: ID:PS1-SET-1H7K9Q2A

# >>> BLOK: REVSTAMP | Revizyon damgasi | ID:PS1-REV-B4N8M2Z6
Step "revstamp" { python tools/revstamp.py . --tracked }
# <<< BLOK SONU: ID:PS1-REV-B4N8M2Z6

# >>> BLOK: BLOCKCHECK | Blok indeks & dogrulama | ID:PS1-BLK-G3S7P1T4
Step "blockcheck" { python tools/blockcheck.py }
# <<< BLOK SONU: ID:PS1-BLK-G3S7P1T4

# >>> BLOK: GUARDRAIL | Base/Template kontrol | ID:PS1-GRD-K8D4V6R1
Step "guardrail_check" { python tools/guardrail_check.py }
# <<< BLOK SONU: ID:PS1-GRD-K8D4V6R1

# >>> BLOK: LONGFILES | 650+ satir raporu | ID:PS1-LNG-2W9E5H0C
if (Test-Path ".") {
  Step "longfile_report" { python tools/longfile_report.py --threshold 650 --out "$outDir/longfiles.json" }
}
# <<< BLOK SONU: ID:PS1-LNG-2W9E5H0C

# >>> BLOK: LINT | ruff/flake8 opsiyonel | ID:PS1-LIN-4E7C2M9Q
if (Get-Command ruff -ErrorAction SilentlyContinue) {
  Step "ruff_check" { ruff check . }
} elseif (Get-Command flake8 -ErrorAction SilentlyContinue) {
  Step "flake8" { flake8 . }
}
# <<< BLOK SONU: ID:PS1-LIN-4E7C2M9Q

# >>> BLOK: TEST | pytest opsiyonel | ID:PS1-TST-5C8R1L7U
if (Get-Command pytest -ErrorAction SilentlyContinue) {
  if ((Get-ChildItem -Recurse -Filter "test_*.py" | Measure-Object).Count -gt 0 -or (Test-Path ".\pytest.ini")) {
    Step "pytest" { Invoke-Expression "pytest $PyTestArgs" }
  } else {
    Write-Host "pytest: no tests; skipped."
  }
}
# <<< BLOK SONU: ID:PS1-TST-5C8R1L7U
Step "django_check" { .\scripts\django_check.ps1 }

# >>> BLOK: ARTIFACT | Ciktilarin paketlenmesi | ID:PS1-ART-9N3F6X2D
Copy-Item "_otokodlama/INDEX.json" "$outDir/INDEX.json" -ErrorAction SilentlyContinue
Compress-Archive -Path "$outDir\*" -DestinationPath "$outDir.zip" -Force
# <<< BLOK SONU: ID:PS1-ART-9N3F6X2D

# >>> BLOK: GIT | Istege bagli commit/push | ID:PS1-GIT-M0A4S7P9
if ($Push) {
  git add -A
  git commit -m "$CommitMsg ($ts)"
  git push
}
# <<< BLOK SONU: ID:PS1-GIT-M0A4S7P9

Write-Host ("OK - pipeline tamam. Ciktilar: {0}, arsiv: {0}.zip" -f $outDir)

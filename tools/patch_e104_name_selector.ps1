# Rev: 2025-10-06 12:05 r2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$path = "tests\e104_create_and_delete_equipment.spec.js"
if (!(Test-Path $path)) { Write-Error "Dosya bulunamadı: $path"; exit 1 }

$raw = Get-Content $path -Raw -Encoding UTF8

# ts/primaryText tanımının HEMEN ARDINA enjekte et
$anchor = 'const ts = Date\.now\(\)\.toString\(\);\s*let primaryText = null;'

$inject = @"
  // --- STABLE NAME SELECTOR (auto-injected) ---
  // Önce isim alanını kesin seçiciyle doldur, sonra generic doldurma devam etsin.
  try {
    const nameField =
      form.locator('input[name="name"]').first().or(
      form.locator('#id_name').first());
    if (await nameField.isVisible({ timeout: 1000 })) {
      const v = `AUTO-NAME-\${ts}`;
      await nameField.fill(v);
      primaryText = primaryText || v;
    }
  } catch {}
  // --- end stable name selector ---
"@

if ($raw -notmatch $anchor) {
  Write-Error "Yer işareti bulunamadı (ts/primaryText tanımı). Dosya beklenenden farklı."
  exit 1
}

$patched = [regex]::Replace($raw, $anchor, { param($m) $m.Value + "`r`n" + $inject }, 1)

[IO.File]::WriteAllText($path, $patched, [Text.UTF8Encoding]::new($false))
Write-Host "[ok] E104 name seçici yaması uygulandı: $path" -ForegroundColor Green
Rev: 2025-09-30 19:21 r1
# README-ops — OTOKODLAMA Pipeline (DMS / Bakım-Kalibrasyon)

Bu doküman, depo kökünde tutulacak **operasyonel çalışma kılavuzudur**. 
Hedef: Django Admin'de `/admin/maintenance/equipment/` için yaşanan **sonsuz 302 yönlendirme döngülerini** kırmak, **CRUD akışlarını kararlı** hale getirmek ve bunları **otomatik akış (pipeline)** ile güvence altına almak.

---

## 1) Amaç — Ne Çözüyoruz?
- Admin Equipment listesinde kanonik yol: `/admin/maintenance/equipment/`
- **Çözüm**: Tüm istek/yanıtları tek sıçrama ile **`/_direct/`** altına normlaştırmak, ardından CRUD UI akışlarını Playwright ile çalıştırmak ve **her adım sonunda Link Smoke** ile kırık link / hatalı redirect yakalamak.
- UI beklemelerini **dinamik timeout** ile stabilize etmek (`tools/pw_flow.py --timeout`).
- CRUD yeşile döndüğünde **ChatGPT entegrasyonu** için tek komutluk kurulum adımına zemin hazırlamak.

## 2) Yüksek Seviye Akış
1. **Backlog → Flow üretimi**  
   - `ops/backlog.json` içinden hedefler (ekran/CRUD) tanımlanır.  
   - `ops/gen_from_backlog.ps1` bu backlog'tan **.flow** dosyaları üretir.

2. **Akış Koşucu + Guard**  
   - `ops/run_backlog.ps1` üretilen flow’ları tek tek `ops/run_and_guard.ps1` ile koşturur.  
   - Her adımın sonunda **`ops/smoke_links.ps1`** ile **Link Smoke Gating** yapılır (fail-fast).

3. **Raporlama**  
   - `ops/report_crud.ps1`, `_otokodlama/out` altındaki sonuç JSON’larından **CSV/JSON/MD** özet rapor üretir.

4. **Yönlendirme Sertleştirme (server-side)**  
   - `core/mw_fix_equip_redirect.py`: Request/response’ta kanonik → `/_direct/` dönüştürme.  
   - `maintenance/admin.py`: EquipmentAdmin **monkeypatch**; `get_urls`, `changelist_view`, `response_post_save_*` dönüşleri `/_direct/`e yönlendirir.  
   - `core/settings_maintenance.py`: `APPEND_SLASH = False`, middleware en üstte.

## 3) Dosya/Dizin Envanteri (kökten)
```
core/mw_fix_equip_redirect.py      # Kanonik → /_direct/ dönüştürücü (req+resp)
core/urls.py                        # Kök URL + tek sıçrama redirect handler
core/settings_maintenance.py        # APPEND_SLASH=False + middleware ekli
maintenance/admin.py                # EquipmentAdmin monkeypatch bloğu
ops/backlog.json                    # Test backlog
ops/gen_from_backlog.ps1            # Backlog → .flow üretimi
ops/run_backlog.ps1                 # Flow koşucu + Link Smoke gating
ops/run_and_guard.ps1               # Tek flow çalıştırıcı
ops/smoke_links.ps1                 # Link smoke checker (BFS)
ops/report_crud.ps1                 # CRUD rapor üretici (CSV/JSON/MD)
tools/pw_flow.py                    # Playwright runner (--timeout patch’li)
tools/_ast_check.py                 # (Geçici) AST checker
_otokodlama/out, debug, smoke, reports/  # Koşu çıktıları
```
> Not: Node/NPM betiklerinde **`package.json` biçim hatası** görülürse (EJSONPARSE), dosyada birden fazla kök obje `{...}{...}` veya virgül/kaçış hatası var demektir. Tek kök obje olacak şekilde düzeltin.

## 4) Kurulum ve Ortam
- **Python 3.10+**, **Playwright** (chromium kurulum gerekebilir).
- **Django dev**: Admin kullanıcı adı `hp` (dev). HR LMS başka portta olabilir (`127.0.0.1:8000`); bu depo DMS'i **8001** veya **8010** portunda çalıştırın.
- **Base URL**: Örnekler `http://127.0.0.1:8010` kabul eder.

## 5) Günlük Kullanım (Cheat‑Sheet)
### 5.1 Backlog’u Hazırla / Güncelle
- `ops/backlog.json` içine test etmek istediğiniz ekran/CRUD hedeflerini ekleyin.

### 5.2 Flow Üret
```powershell
powershell -ExecutionPolicy Bypass -File ops\gen_from_backlog.ps1
```

### 5.3 Koş (Link Smoke dahil)
**Login smoke (20 sn timeout):**
```powershell
powershell -ExecutionPolicy Bypass -File ops\run_backlog.ps1 -Filter "login_smoke*" -LinkSmoke -BaseUrl "http://127.0.0.1:8010" -SmokeDepth 1 -SmokeLimit 150 -ExtraArgs "--timeout 20000"
```
**Equipment CRUD (tek sıçrama kanonik→/_direct kabul):**
```powershell
powershell -ExecutionPolicy Bypass -File ops\run_backlog.ps1 -Filter "equipment_ui_*" -LinkSmoke -BaseUrl "http://127.0.0.1:8010" -SmokeDepth 1 -SmokeLimit 200 -ExtraArgs "--timeout 20000"
```

### 5.4 Rapor Al
```powershell
powershell -ExecutionPolicy Bypass -File ops\report_crud.ps1 -OutDir "_otokodlama\out" -ReportDir "_otokodlama\reports" -Include "login_smoke.json,equipment_ui_*.json"
```

## 6) Neden “Link Smoke Gating”?
- UI adımı geçti diye sistem sağlıklı sayılmaz; menü/alt sayfalardaki kırık linkler ve **beklenmeyen redirect**’ler hemen görünür.
- **Fail fast**: Smoke “kırmızı”ysa koşu kesilir; `_otokodlama/smoke/<flow>_links.json` içinde **bad_list** net biçimde raporlanır.

## 7) Sık Görülen Sorunlar
- **Login step takılması**: Login submit sonrası `#user-tools a[href$="/logout/"]` beklenir; düşerse `_otokodlama/debug/*` artefact’larına bakın; selector’ü `#site-name`, `#content-main` gibi alternatiflerle özelleştirin.
- **Sonsuz redirect**: `core/mw_fix_equip_redirect.py` + `maintenance/admin.py` aktif mi? `APPEND_SLASH=False` mu? Middleware **en üstte** mi?
- **Timeoutlar**: `tools/pw_flow.py --timeout` patch’i var; koşucuya `-ExtraArgs "--timeout 20000"` verin.
- **UTF‑8 BOM/IndentationError**: `tools/pw_flow.py` **BOM’suz** yazıldı; yine olursa BOM temizleyici adımı uygulayın.
- **Smoke parse hatası**: `ops/smoke_links.ps1` yeni sürüm; beklenen redirect’leri `-OkRedirectTo "/_direct/.*"` gibi regex’le **meşru** sayın.

## 8) “Backlog” ile Yeni İş Nasıl Eklenir?
**Ekran/duman testi (screen) örneği** ve **CRUD admin** örneği için `ops/backlog.json` şablonuna bakın.  
Ardından:
```powershell
powershell -ExecutionPolicy Bypass -File ops\gen_from_backlog.ps1
powershell -ExecutionPolicy Bypass -File ops\run_backlog.ps1 -Filter "<id>_*" -LinkSmoke -BaseUrl "http://127.0.0.1:8010" -ExtraArgs "--timeout 20000"
```

## 9) ChatGPT Entegrasyonu (Sonraki Adım)
CRUD + login smoke **yeşil** olduğunda `chatgpt_setup` backlog item eklenir; tek komutla paket/env kurulumu, API anahtar konfigürasyonu ve hızlı smoke doğrulaması yapılır.

---

## Ek: Plan/Task Standardı + Excel→JSON/MD
- **CSV şablonu**: `plan/tasks_template.csv` (bu depo ile birlikte gelir)
- Dönüştürücü: `tools/tasks_from_csv.py`  
  ```powershell
  python tools\tasks_from_csv.py plan\tasks.csv --out-json plan\tasks.json --out-md plan\tasks.md
  ```
- (Opsiyonel) **PR açıcı**: `ops/make_prs.ps1`  
  ```powershell
  powershell -ExecutionPolicy Bypass -File ops\make_prs.ps1 -PlanJson plan\tasks.json -DryRun
  ```

> Bu dosya **OTOKODLAMA** projesinin operatif “tek sayfa” özetidir. Güncel tuttuğunuzdan emin olun.

# 🤖 OTOKODLAMA

Otomatik Test & Kod İyileştirme Sistemi

## 🎯 Özellikler

- ✅ Otomatik test koşturma (Playwright)
- ✅ Hata tespit ve raporlama
- ✅ Claude AI entegrasyonu
- ✅ Otomatik patch uygulama
- ✅ TODO List yönetimi
- ✅ HTML raporlama
- ✅ Screenshot & trace toplama

## 📦 Kurulum

\\\ash
# Python bağımlılıkları
pip install -r requirements-claude.txt

# Node.js bağımlılıkları
npm install

# Playwright browser'ları
npx playwright install chromium
\\\

## 🔑 Konfigürasyon

\.env\ dosyası oluştur:
\\\
ANTHROPIC_API_KEY=your_claude_api_key
BASE_URL=http://127.0.0.1:8010
\\\

## 🚀 Kullanım

\\\ash
# Orchestrator başlat
python _otokodlama/orchestrator.py

# Claude API ile bundle işle
python _otokodlama/claude_api.py <bundle_name>
\\\

## 📊 Raporlar

- HTML: \_otokodlama/reports/final_report.html\
- Bundles: \_otokodlama/bundle/\
- Logs: \_otokodlama/logs/\

## 🗂️ Yapı

\\\
_otokodlama/
├── orchestrator.py      # Ana döngü
├── claude_api.py        # Claude AI entegrasyonu
├── ai_bridge.py         # Manuel AI bridge
├── todolist.csv         # Task listesi
└── reports/             # HTML raporlar

tests/
├── *.spec.js           # Test dosyaları
└── helpers_*.js        # Test helper'ları
\\\

## 📝 Yedekleme: 20251017_081939

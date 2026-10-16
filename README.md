# FinansBot v2 — Gemini AI Destekli Kişisel Finans Asistanı (MVP)

`finansbot_v2`, ilk versiyonun (`finansbot`) koyu-altın (Dark & Gold) tasarım dilini koruyarak doğrudan **Google Gemini API** entegrasyonu, **Proaktif AI Fikir Bildirimleri** ve **Finansal Özet / Ayarlar Panosu** ile geliştirilmiş MVP sürümüdür.

## 🚀 Öne Çıkan MVP Özellikleri

1. **Doğrudan Google Gemini API Entegrasyonu (`lib/gemini_service.dart`)**
   - Google AI Studio (`generativelanguage.googleapis.com/v1beta`) üzerinden gerçek zamanlı **SSE Streaming** sohbet yanıtları.
   - Uygulama içinden (veya başlangıç ekranından) **API Anahtarı** ve **Gemini Modeli** (`gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-2.5-pro`) seçebilme.
   - API anahtarı henüz girilmemişse bile arayüzü ve akışları test edebilmek için **Akıllı Demo Modu** desteği.

2. **Ara Sıra Fikir Veren Yapay Zeka Bildirimleri (`lib/pages/insights_page.dart`)**
   - Kullanıcının hafızasını (`memory`) ve finansal verilerini (`Bakiye`, `Aylık Harcama`, `Birikim`, `Hedef`) analiz ederek periyodik veya anlık **Proaktif Finansal Fikir Bildirimleri** üretir.
   - **Uygulama İçi Bildirim Banner'ı:** Yeni bir AI fikri üretildiğinde ekranın üst kısmından kayarak gelen bildirim kartı ve **"Bu Fikri Konuşalım →"** aksiyonu.
   - **Ayarlanabilir Bildirim Sıklığı:** `Kapalı`, `Demo · 2 dk`, `15 dk`, `1 Saat`, `Günlük` periyotları ve **"Şimdi Yeni AI Fikri Üret"** butonu.

3. **3 Sekmeli Gelişmiş MVP Arayüzü (`lib/main.dart`)**
   - **Sohbet:** Sesli komut (`speech_to_text`), Markdown destekli mesaj balonları, otomatik finansal veri çıkarımı, hafıza güncelleme ve sohbet geçmişi çekmecesi (`Drawer`).
   - **AI Fikirler (Bildirim Merkezi):** Kategori bazlı (`Tasarruf`, `Yatırım`, `Bütçe`, `Fırsat`, `Uyarı`) filtreleme, okundu/okunmadı rozeti ve tek dokunuşla fikri sohbette detaylandırma.
   - **Özet & Ayarlar (`lib/pages/dashboard_page.dart`):** Net Bakiye, Harcama, Birikim ve Hedef kartlarını düzenleme, Tek Tıkla **AI Check-Up**, AI Hafıza düzenleyici, Gemini API ayarları ve Android Ekran Görüntüsü Koruması (`FLAG_SECURE`).

## 📂 Proje Klasör Yapısı

```text
lib/
├── main.dart                  # Uygulama girişi, ana iskelet, bildirim zamanlayıcısı ve üst bildirim banner'ı
├── theme.dart                 # Dark & Gold tasarım sabitleri ve ortak bileşenler (GoldOrb, DotPill)
├── models.dart                # ChatMessage, ConvMeta ve AiInsightNotification veri modelleri
├── storage.dart               # SharedPreferences tabanlı yerel veri ve ayar yönetimi
├── gemini_service.dart        # Doğrudan Google Gemini API (Streaming, JSON, Hafıza ve Fikir üretimi)
└── pages/
    ├── onboarding_page.dart   # Karşılama, isim ve isteğe bağlı Gemini API anahtarı kurulumu
    ├── chat_area.dart         # Streaming AI sohbet ekranı, sesli giriş ve öneri çipleri
    ├── insights_page.dart     # Proaktif AI Fikirler & Bildirim Merkezi
    └── dashboard_page.dart    # Finansal Özet Tablosu, AI Check-Up, Hafıza ve API Ayarları
```

## 🛠️ Kurulum ve Çalıştırma

```bash
flutter pub get
flutter run
```

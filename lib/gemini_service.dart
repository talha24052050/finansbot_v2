import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'storage.dart';

class GeminiService {
  static bool _isOpenRouterKey(String key) => key.startsWith('sk-or-');

  /// Streams chat completion from Google Gemini API (or OpenRouter if sk-or-* key is used).
  /// Falls back to an intelligent interactive demo advisor if no API key is configured yet.
  static Stream<String> streamChat({
    required String systemPrompt,
    required List<Map<String, dynamic>> history,
    required String userName,
    required Map<String, String?> stats,
  }) async* {
    final apiKey = await Storage.getGeminiApiKey();
    final model = await Storage.getGeminiModel();

    if (apiKey.isEmpty) {
      final lastUserMsg = history.lastWhere(
        (m) => m['role'] == 'user',
        orElse: () => {'content': ''},
      )['content'] as String;
      final demoReply = _buildDemoChatReply(
        userMessage: lastUserMsg,
        userName: userName,
        stats: stats,
      );
      final words = demoReply.split(' ');
      for (var i = 0; i < words.length; i++) {
        await Future.delayed(const Duration(milliseconds: 22));
        yield (i == 0 ? '' : ' ') + words[i];
      }
      return;
    }

    if (_isOpenRouterKey(apiKey)) {
      yield* _streamOpenRouter(
        apiKey: apiKey,
        model: model.contains('/') ? model : 'google/$model',
        systemPrompt: systemPrompt,
        history: history,
      );
      return;
    }

    final client = http.Client();
    try {
      final contents = <Map<String, dynamic>>[];
      for (final msg in history) {
        final role = msg['role'] as String?;
        final content = (msg['content'] as String? ?? '').trim();
        if (role == 'system' || content.isEmpty) continue;
        contents.add({
          'role': role == 'user' ? 'user' : 'model',
          'parts': [
            {'text': content}
          ],
        });
      }

      if (contents.isEmpty) {
        contents.add({
          'role': 'user',
          'parts': [
            {'text': 'Merhaba'}
          ],
        });
      }

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse&key=$apiKey',
      );
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 2048,
        },
      });

      final resp = await client.send(request);
      if (resp.statusCode != 200) {
        final errBody = await resp.stream.bytesToString();
        String errMsg = 'Gemini API Hatası (${resp.statusCode})';
        try {
          final decoded = jsonDecode(errBody) as Map<String, dynamic>;
          final apiErr = decoded['error']?['message'] as String?;
          if (apiErr != null) errMsg += ': $apiErr';
        } catch (_) {}
        yield '⚠️ **$errMsg**\n\nLütfen sağ üstteki veya **Özet & Ayarlar** sekmesindeki **Gemini API Ayarları** bölümünden API anahtarınızı ve seçili modeli kontrol edin.';
        return;
      }

      final lines = resp.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data.isEmpty || data == '[DONE]') continue;
        try {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          final candidates = parsed['candidates'] as List?;
          final parts = candidates?.firstOrNull?['content']?['parts'] as List?;
          if (parts != null) {
            for (final part in parts) {
              final text = part['text'] as String?;
              if (text != null && text.isNotEmpty) {
                yield text;
              }
            }
          }
        } catch (_) {}
      }
    } finally {
      client.close();
    }
  }

  static Stream<String> _streamOpenRouter({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<Map<String, dynamic>> history,
  }) async* {
    final client = http.Client();
    try {
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        ...history.where((m) => m['role'] != 'system'),
      ];
      final request = http.Request(
        'POST',
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      );
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'model': model, 'messages': messages, 'stream': true});
      final resp = await client.send(request);
      final lines = resp.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        try {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          final delta = (parsed['choices'] as List?)?.firstOrNull?['delta']?['content'] as String?;
          if (delta != null && delta.isNotEmpty) yield delta;
        } catch (_) {}
      }
    } finally {
      client.close();
    }
  }

  /// Non-streaming single-turn text generation via Google Gemini API (or OpenRouter).
  static Future<String?> generateText(String prompt, {bool jsonMode = false}) async {
    final apiKey = await Storage.getGeminiApiKey();
    if (apiKey.isEmpty) return null;
    final model = await Storage.getGeminiModel();

    try {
      if (_isOpenRouterKey(apiKey)) {
        final resp = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model.contains('/') ? model : 'google/$model',
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        );
        if (resp.statusCode != 200) return null;
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        return (decoded['choices'] as List?)?.firstOrNull?['message']?['content'] as String?;
      }

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );
      final body = <String, dynamic>{
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.5,
          if (jsonMode) 'responseMimeType': 'application/json',
        },
      };

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      final parts = candidates?.firstOrNull?['content']?['parts'] as List?;
      return parts?.firstOrNull?['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> updateMemory({
    required String userName,
    required String currentMemory,
    required String userMessage,
    required String aiReply,
  }) async {
    final res = await generateText(
      'Aşağıdaki konuşmadan kullanıcı ($userName) hakkında öğrenilen finansal bilgileri çıkar.\n'
      'Mevcut hafıza ile birleştir ve güncelle. Sadece özet paragraf yaz, başka bir şey yazma.\n\n'
      'Mevcut hafıza:\n${currentMemory.isEmpty ? '(boş)' : currentMemory}\n\n'
      'Yeni konuşma:\nKullanıcı: $userMessage\nAsistan: $aiReply\n\n'
      'Güncellenmiş özet (Türkçe, kısa ve öz):',
    );
    if (res != null && res.trim().isNotEmpty) return res.trim();
    return null;
  }

  static Future<String?> generateTitle({
    required String userMessage,
    required String aiReply,
  }) async {
    final res = await generateText(
      'Aşağıdaki sohbet için kısa ve açıklayıcı bir başlık üret (en fazla 5-6 kelime, Türkçe). '
      'Sadece başlığı yaz, başka hiçbir şey ekleme.\n\n'
      'Kullanıcı: $userMessage\nAsistan: $aiReply',
    );
    if (res != null && res.trim().isNotEmpty) {
      return res.trim().replaceAll('"', '').replaceAll("'", '');
    }
    final words = userMessage.trim().split(RegExp(r'\s+'));
    return words.take(4).join(' ');
  }

  static Future<Map<String, String?>?> extractStats({
    required Map<String, String?> currentStats,
    required String userMessage,
    required String aiReply,
  }) async {
    final res = await generateText(
      'Aşağıdaki konuşmadan finansal rakamları çıkar.\n'
      'Kullanıcı net bakiyesinden, aylık harcamasından, toplam birikiminden veya finansal hedefinden bahsettiyse değerleri döndür.\n'
      'Mevcut değerler: ${jsonEncode(currentStats)}\n'
      'Konuşma:\nKullanıcı: $userMessage\nAsistan: $aiReply\n\n'
      'Sadece kesin söylenen rakamları dahil et. Tahmini veya belirsiz değerleri dahil etme.\n'
      'Yanıtı sadece JSON olarak ver, başka hiçbir şey yazma.\n'
      'Format: {"balance":"₺ 50.000","spending":"₺ 8.000","savings":"₺ 15.000","goal":"₺ 250.000"}\n'
      'Bilinen alanı yoksa boş JSON {} döndür.',
      jsonMode: true,
    );
    if (res != null) {
      try {
        final jsonStr = res.trim().replaceAll('```json', '').replaceAll('```', '').trim();
        final extracted = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (extracted.isEmpty) return null;
        final updated = Map<String, String?>.from(currentStats);
        extracted.forEach((k, v) {
          if (v != null && v.toString().trim().isNotEmpty) {
            updated[k] = v.toString().trim();
          }
        });
        return updated;
      } catch (_) {}
    }
    return _fallbackExtractStats(currentStats, userMessage);
  }

  static Map<String, String?>? _fallbackExtractStats(
    Map<String, String?> currentStats,
    String userMessage,
  ) {
    final lower = userMessage.toLowerCase();
    final numMatch = RegExp(r'(\d[\d\.,]*)\s*(tl|₺|bin)?').firstMatch(lower);
    if (numMatch == null) return null;
    String rawNum = numMatch.group(1)!;
    final suffix = numMatch.group(2) ?? '';
    if (suffix == 'bin' && !rawNum.contains('.')) {
      rawNum = '$rawNum.000';
    }
    final formatted = '₺ $rawNum';
    final updated = Map<String, String?>.from(currentStats);
    var changed = false;
    if (lower.contains('bakiye') || lower.contains('maaş') || lower.contains('gelir')) {
      updated['balance'] = formatted;
      changed = true;
    } else if (lower.contains('harcama') || lower.contains('gider')) {
      updated['spending'] = formatted;
      changed = true;
    } else if (lower.contains('birikim') || lower.contains('kenarda')) {
      updated['savings'] = formatted;
      changed = true;
    } else if (lower.contains('hedef')) {
      updated['goal'] = formatted;
      changed = true;
    }
    return changed ? updated : null;
  }

  /// Generates a proactive, personalized AI financial idea notification using Gemini.
  static Future<AiInsightNotification> generateProactiveInsight({
    required String userName,
    required String memory,
    required Map<String, String?> stats,
    required List<AiInsightNotification> existingInsights,
  }) async {
    final recentTitles = existingInsights.take(6).map((e) => e.title).join(', ');
    final prompt = '''
Sen "$userName" adlı kullanıcının kişisel yapay zeka finans danışmanısın.
Kullanıcıya uygulama içi bildirim olarak gösterilecek YENİ, YARATICI, SOMUT ve UYGULANABİLİR bir finansal fikir/ipucu üret.

Kullanıcı Profili & Hafıza:
${memory.isEmpty ? 'Henüz detaylı hafıza yok; Türkiye şartlarına uygun genel ama çok pratik bir finans/yatırım/bütçe fikri ver.' : memory}

Finansal Rakamlar:
- Bakiye: ${stats['balance'] ?? 'Bilinmiyor'}
- Aylık Harcama: ${stats['spending'] ?? 'Bilinmiyor'}
- Birikim: ${stats['savings'] ?? 'Bilinmiyor'}
- Hedef: ${stats['goal'] ?? 'Bilinmiyor'}

Daha önce gönderilen bildirim başlıkları (bunları TEKRARLAMA, farklı bir açıdan yaklaş):
${recentTitles.isEmpty ? 'Yok' : recentTitles}

Yanıtı SADECE geçerli bir JSON nesnesi olarak döndür:
{
  "title": "En fazla 6-7 kelimelik dikkat çekici başlık",
  "body": "2-3 cümlelik, doğrudan kullanıcıya hitap eden, rakam veya oran içeren somut finansal fikir/öneri.",
  "category": "Tasarruf" | "Yatırım" | "Bütçe" | "Fırsat" | "Uyarı",
  "actionPrompt": "Kullanıcı bu bildirime tıkladığında sohbete gönderilecek 1 cümlelik soru (Örn: 'Aylık harcamalarımdan %15 tasarruf etmek için bana özel bir plan çıkarır mısın?')"
}
''';

    final res = await generateText(prompt, jsonMode: true);
    if (res != null) {
      try {
        final cleaned = res.trim().replaceAll('```json', '').replaceAll('```', '').trim();
        final map = jsonDecode(cleaned) as Map<String, dynamic>;
        return AiInsightNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: (map['title'] as String?)?.trim() ?? 'Yeni Finansal Fikir',
          body: (map['body'] as String?)?.trim() ?? '',
          category: (map['category'] as String?)?.trim() ?? 'Fırsat',
          actionPrompt: (map['actionPrompt'] as String?)?.trim() ??
              'Bu finansal fikri benim bütçeme göre nasıl uygulayabiliriz?',
          createdAt: DateTime.now(),
        );
      } catch (_) {}
    }

    return _buildFallbackInsight(
      userName: userName,
      stats: stats,
      existingCount: existingInsights.length,
    );
  }

  static AiInsightNotification _buildFallbackInsight({
    required String userName,
    required Map<String, String?> stats,
    required int existingCount,
  }) {
    final balance = stats['balance'];
    final spending = stats['spending'];
    final savings = stats['savings'];

    final templates = <Map<String, String>>[
      {
        'title': 'Maaş Günü Otomatik %20 Kuralı',
        'body':
            '$userName, gelir hesabına yattığı gün harcamaya başlamadan önce ${balance != null ? 'bakiyenin ($balance) ' : ''}en az %15-20\'sini para piyasası fonu veya altın hesabına otomatik talimatla aktarmak yıl sonunda ciddi bir bileşik getiri sağlar.',
        'category': 'Tasarruf',
        'actionPrompt':
            'Gelirim yattığı gün otomatik birikim ve fon dağılımı için bana özel bir oran planı yapar mısın?',
      },
      {
        'title': 'Atıl Nakit İçin Günlük Getiri Fırsatı',
        'body':
            'Vadesiz hesapta bekleyen nakit enflasyon karşısında erir. ${spending != null ? 'Aylık $spending harcama bütçeni ' : 'Kısa vadeli harcama nakdini '}günlük bozulabilen Para Piyasası Fonlarında (PPF) tutarak ay sonuna kadar ek getiri elde edebilirsin.',
        'category': 'Fırsat',
        'actionPrompt':
            'Vadesiz hesaptaki nakdimi Para Piyasası Fonlarında (PPF) nasıl değerlendirebilirim, örnek hesaplama yapar mısın?',
      },
      {
        'title': 'Sepet Portföy ile Kur & Enflasyon Koruması',
        'body':
            'Tek bir yatırım aracına bağlı kalmak yerine birikimini ${savings != null ? '($savings) ' : ''}%40 Kıymetli Maden, %30 Hisse/Borsa Fonu ve %30 Sabit Getirili Fon şeklinde bölmek oynaklığı büyük ölçüde düşürür.',
        'category': 'Yatırım',
        'actionPrompt':
            'Risk profilime göre dengeli bir yatırım sepeti (altın, fon, hisse) dağılımı oluşturabilir miyiz?',
      },
      {
        'title': 'Görünmez Abonelik ve Sabit Gider Taraması',
        'body':
            'Kullanmadığın dijital abonelikler ve küçük tekrarlayan ödemeler yılda 1 maaşa yakın bütçe sızıntısı yaratabilir. Bu hafta sonu son 30 günlük kart ekstreni birlikte inceleyelim.',
        'category': 'Bütçe',
        'actionPrompt':
            'Aylık sabit giderlerimi ve gereksiz aboneliklerimi azaltmak için kontrol listesi çıkarır mısın?',
      },
      {
        'title': 'Acil Durum Fonu Güvenlik Kalkanı',
        'body':
            'Beklenmedik harcamalarda kredi kartı borcuna düşmemek için en az 3-6 aylık temel giderin kadar likit bir Acil Durum Fonu oluşturmak finansal özgürlüğün ilk adımıdır.',
        'category': 'Uyarı',
        'actionPrompt':
            'Benim için ideal Acil Durum Fonu tutarını nasıl hesaplarız ve kaç ayda tamamlayabilirim?',
      },
    ];

    final chosen = templates[(existingCount + Random().nextInt(templates.length)) % templates.length];
    return AiInsightNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: chosen['title']!,
      body: chosen['body']!,
      category: chosen['category']!,
      actionPrompt: chosen['actionPrompt']!,
      createdAt: DateTime.now(),
    );
  }

  static String _buildDemoChatReply({
    required String userMessage,
    required String userName,
    required Map<String, String?> stats,
  }) {
    final lower = userMessage.toLowerCase();
    if (lower.contains('bütçe') || lower.contains('harcama')) {
      return '''Merhaba **$userName**! Bütçe yönetimi için **50/30/20 kuralını** Türkiye şartlarına uyarlayarak başlayabiliriz:

1. **%50 Zorunlu Giderler:** Kira, faturalar, mutfak ve ulaşım.
2. **%30 Yaşam & Esnek Harcamalar:** Sosyal yaşam, alışveriş, abonelikler.
3. **%20 Birikim & Yatırım:** Maaş yatar yatmaz ayrılan öncelikli pay.

${stats['balance'] != null ? 'Mevcut **${stats['balance']}** bakiyen üzerinden ' : ''}aylık gelir ve temel giderlerini yazarsan sana özel kuruşu kuruşuna bir tablo çıkarabilirim.

> 💡 *Not: Gerçek zamanlı Google Gemini AI yanıtları için üst menüdeki 🔑 simgesinden veya **Özet & Ayarlar** sekmesinden Gemini API anahtarınızı girebilirsiniz.*''';
    }

    if (lower.contains('yatırım') || lower.contains('birikim') || lower.contains('fon') || lower.contains('altın')) {
      return '''Harika bir soru **$userName**! Birikimlerini enflasyona karşı korumak ve büyütmek için **3 katmanlı sepet stratejisi** uygulayabilirsin:

* **Kısa Vade / Nakit Kalkanı (%30):** Günlük likiditesi olan Para Piyasası Fonları (PPF).
* **Orta Vade / Değer Koruma (%40):** Altın / Gümüş fonları veya döviz endeksli varlıklar.
* **Uzun Vade / Büyüme (%30):** BIST / Yabancı Hisse Senedi yoğun fonlar.

Risk iştahını (*düşük, orta, yüksek*) ve vade hedefini paylaşırsan bu yüzdeleri sana göre optimize edelim!

> 💡 *Not: Tam kapasiteli Google Gemini AI analizi için **Özet & Ayarlar** sekmesinden Gemini API anahtarınızı ekleyebilirsiniz.*''';
    }

    return '''Merhaba **$userName**, kişisel finans asistanın olarak yanındayım!

Şu konularda birlikte çalışabiliriz:
* **Gelir & Bütçe Planlaması:** Aylık nakit akışını optimize etme
* **Yatırım & Birikim Stratejileri:** Enflasyon üstü getiri için sepet önerileri
* **Akıllı AI Fikir Bildirimleri:** Alt menüdeki **AI Fikirler** sekmesinden sana özel finansal fırsatları inceleyebilir veya anında yeni fikir üretebilirsin.

Bana aylık gelirini, harcamanı veya finansal hedefini yazarak hemen başlayabilirsin!

> 🔑 *İpucu: Doğrudan **Google Gemini API** bağlantısını aktif etmek için sağ üstteki anahtar simgesine dokunarak Google AI Studio API anahtarınızı kaydedebilirsiniz.*''';
  }
}

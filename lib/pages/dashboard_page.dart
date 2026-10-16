import 'package:flutter/material.dart';
import '../storage.dart';
import '../theme.dart';

class DashboardPage extends StatefulWidget {
  final String userName;
  final Map<String, String?> stats;
  final bool screenshotProtected;
  final int notificationIntervalMinutes;
  final void Function(Map<String, String?> newStats) onStatsChanged;
  final void Function(bool protect) onScreenshotChanged;
  final void Function(int minutes) onIntervalChanged;
  final VoidCallback onApiSettingsUpdated;
  final void Function(String prompt) onAskAiWithPrompt;

  const DashboardPage({
    super.key,
    required this.userName,
    required this.stats,
    required this.screenshotProtected,
    required this.notificationIntervalMinutes,
    required this.onStatsChanged,
    required this.onScreenshotChanged,
    required this.onIntervalChanged,
    required this.onApiSettingsUpdated,
    required this.onAskAiWithPrompt,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _apiKeyController = TextEditingController();
  String _selectedModel = 'gemini-2.5-flash';
  String _memory = '';
  bool _obscureKey = true;
  bool _savedKeyBanner = false;

  static const _models = <(String, String)>[
    ('gemini-2.5-flash', 'Gemini 2.5 Flash (Önerilen · Hızlı & Zeki)'),
    ('gemini-2.0-flash', 'Gemini 2.0 Flash (Yüksek Hız)'),
    ('gemini-2.5-pro', 'Gemini 2.5 Pro (Derin Finansal Analiz)'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final key = await Storage.getGeminiApiKey();
    final model = await Storage.getGeminiModel();
    final mem = await Storage.getMemory();
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = key;
      _selectedModel = _models.any((m) => m.$1 == model) ? model : 'gemini-2.5-flash';
      _memory = mem;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiConfig() async {
    await Storage.setGeminiApiKey(_apiKeyController.text.trim());
    await Storage.setGeminiModel(_selectedModel);
    widget.onApiSettingsUpdated();
    if (!mounted) return;
    setState(() => _savedKeyBanner = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedKeyBanner = false);
    });
  }

  void _editStatDialog(String key, String label, String currentValue) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label Güncelle'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: kTextHi),
          decoration: InputDecoration(
            hintText: 'Örn: ₺ 45.000',
            hintStyle: const TextStyle(color: kText3),
            filled: true,
            fillColor: kSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: kTextMid)),
          ),
          TextButton(
            onPressed: () async {
              final next = Map<String, String?>.from(widget.stats);
              final val = ctrl.text.trim();
              next[key] = val.isEmpty ? null : val;
              await Storage.setStats(next);
              widget.onStatsChanged(next);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _editMemoryDialog() {
    final ctrl = TextEditingController(text: _memory);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Hafızasını Düzenle'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          style: const TextStyle(color: kTextHi, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Örn: Aylık gelirim 65.000 TL, altın ve fon yatırımı yapmayı seviyorum...',
            hintStyle: const TextStyle(color: kText3),
            filled: true,
            fillColor: kSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Storage.setMemory('');
              if (mounted) setState(() => _memory = '');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Sıfırla', style: TextStyle(color: kRed)),
          ),
          TextButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              await Storage.setMemory(val);
              if (mounted) setState(() => _memory = val);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.stats['balance'] ?? 'Belirtilmedi';
    final spending = widget.stats['spending'] ?? 'Belirtilmedi';
    final savings = widget.stats['savings'] ?? 'Belirtilmedi';
    final goal = widget.stats['goal'] ?? 'Belirtilmedi';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Financial Overview Cards ────────────────────────────
          Row(
            children: [
              const Text(
                'FİNANSAL ÖZET TABLOSU',
                style: TextStyle(
                  color: kText3,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => widget.onAskAiWithPrompt(
                  'Mevcut finansal verilerime (Bakiye: $balance, Harcama: $spending, Birikim: $savings, Hedef: $goal) göre bana detaylı bir aylık finansal check-up ve eylem planı çıkarır mısın?',
                ),
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome, size: 13, color: kGold),
                    SizedBox(width: 5),
                    Text(
                      'AI Check-Up Yap →',
                      style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Net Bakiye / Gelir',
                  value: balance,
                  icon: Icons.account_balance_wallet_outlined,
                  accent: kGold,
                  onTap: () => _editStatDialog(
                    'balance',
                    'Net Bakiye / Gelir',
                    widget.stats['balance'] ?? '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Aylık Harcama',
                  value: spending,
                  icon: Icons.trending_down_rounded,
                  accent: kRed,
                  onTap: () => _editStatDialog(
                    'spending',
                    'Aylık Harcama',
                    widget.stats['spending'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Toplam Birikim',
                  value: savings,
                  icon: Icons.savings_outlined,
                  accent: kGreen,
                  onTap: () => _editStatDialog(
                    'savings',
                    'Toplam Birikim',
                    widget.stats['savings'] ?? '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Finansal Hedef',
                  value: goal,
                  icon: Icons.flag_outlined,
                  accent: kBlue,
                  onTap: () => _editStatDialog(
                    'goal',
                    'Finansal Hedef',
                    widget.stats['goal'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'İpucu: Kartlara dokunarak rakamları düzenleyebilir veya sohbette bahsederek otomatik güncellenmesini sağlayabilirsiniz.',
            style: TextStyle(color: kText3, fontSize: 11.5),
          ),

          const SizedBox(height: 22),

          // ── Section 2: Gemini API Configuration ────────────────────────────
          const Text(
            'GOOGLE GEMINI API ENTEGRASYONU',
            style: TextStyle(
              color: kText3,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gemini API Anahtarı',
                  style: TextStyle(color: kTextHi, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Google AI Studio (aistudio.google.com) üzerinden aldığınız API anahtarını girin.',
                  style: TextStyle(color: kTextMid, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  style: const TextStyle(color: kTextHi, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    hintStyle: const TextStyle(color: kText3),
                    filled: true,
                    fillColor: kSurface2,
                    prefixIcon: const Icon(Icons.key_rounded, color: kGold, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: kTextMid,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Gemini Modeli',
                  style: TextStyle(color: kTextHi, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: kSurface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedModel,
                      isExpanded: true,
                      dropdownColor: kSurface,
                      style: const TextStyle(color: kTextHi, fontSize: 13.5),
                      items: _models
                          .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedModel = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _saveApiConfig,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: kGoldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _savedKeyBanner ? Icons.check_circle_outline : Icons.save_outlined,
                            size: 16,
                            color: const Color(0xFF15110A),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _savedKeyBanner ? 'Ayarlar Kaydedildi ✓' : 'API Ayarlarını Kaydet',
                            style: const TextStyle(
                              color: Color(0xFF15110A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── Section 3: AI Memory & Security ────────────────────────────────
          const Text(
            'KİŞİSEL AI HAFIZASI & GÜVENLİK',
            style: TextStyle(
              color: kText3,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined, color: kGold, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Asistanın Sizin Hakkınızda Bildikleri',
                        style: TextStyle(color: kTextHi, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _editMemoryDialog,
                      child: const Text('Düzenle'),
                    ),
                  ],
                ),
                Text(
                  _memory.isEmpty
                      ? 'Henüz kayıtlı hafıza yok. Sohbet ettikçe gelir, gider, risk tercihi ve hedefleriniz burada özetlenir.'
                      : _memory,
                  style: const TextStyle(color: kTextMid, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: kBorderSoft),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.security_outlined, color: kGold, size: 19),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ekran Görüntüsü Koruması (Android)',
                            style: TextStyle(color: kTextHi, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Uygulama ekranının kaydedilmesini engeller',
                            style: TextStyle(color: kTextMid, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.screenshotProtected,
                      activeThumbColor: kGold,
                      onChanged: widget.onScreenshotChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const Spacer(),
                const Icon(Icons.edit_outlined, size: 13, color: kText3),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: kText3,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kTextHi,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

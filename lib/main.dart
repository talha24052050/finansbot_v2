import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gemini_service.dart';
import 'models.dart';
import 'pages/chat_area.dart';
import 'pages/dashboard_page.dart';
import 'pages/insights_page.dart';
import 'pages/onboarding_page.dart';
import 'storage.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBg,
  ));
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finans Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kGold,
          onPrimary: Color(0xFF1A1200),
          surface: kSurface,
          onSurface: kTextHi,
          surfaceContainerHighest: kAiBg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          foregroundColor: kTextHi,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: kSurface2,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: kBorder,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kGold),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: kAiBg,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: kTextHi, fontSize: 18, fontWeight: FontWeight.w600),
          contentTextStyle: TextStyle(color: kTextMid, fontSize: 14, height: 1.6),
        ),
      ),
      home: const SplashPage(),
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final name = await Storage.getUserName();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => (name == null || name.isEmpty)
            ? OnboardingPage(mainPageBuilder: (n) => MainPage(userName: n))
            : MainPage(userName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: kGold, strokeWidth: 2)),
    );
  }
}

// ── Main Page ─────────────────────────────────────────────────────────────────

class MainPage extends StatefulWidget {
  final String userName;
  const MainPage({super.key, required this.userName});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _tabIndex = 0;
  List<ConvMeta> _conversations = [];
  String? _currentConvId;
  String? _pendingChatPrompt;
  bool _screenshotProtected = false;
  bool _hasApiKey = false;
  Map<String, String?> _stats = {};

  // AI Insight Notifications state
  List<AiInsightNotification> _insights = [];
  AiInsightNotification? _activeBannerInsight;
  bool _isGeneratingInsight = false;
  int _intervalMinutes = 15;
  Timer? _insightTimer;

  static const _screenshotChannel = MethodChannel('com.example.chatbot/screenshot');

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  @override
  void dispose() {
    _insightTimer?.cancel();
    super.dispose();
  }

  Future<void> _initAll() async {
    await Future.wait([
      _loadConversations(),
      _loadScreenshotPref(),
      _loadApiStatus(),
      _loadStats(),
      _loadInsightsAndSchedule(),
    ]);
  }

  Future<void> _loadApiStatus() async {
    final key = await Storage.getGeminiApiKey();
    if (!mounted) return;
    setState(() => _hasApiKey = key.isNotEmpty);
  }

  Future<void> _loadStats() async {
    final s = await Storage.getStats();
    if (!mounted) return;
    setState(() => _stats = s);
  }

  Future<void> _loadInsightsAndSchedule() async {
    final list = await Storage.getInsights();
    final interval = await Storage.getNotificationIntervalMinutes();
    if (!mounted) return;
    setState(() {
      _insights = list;
      _intervalMinutes = interval;
    });
    _startPeriodicInsightTimer();

    // Generate a welcome financial insight if none exist yet
    if (list.isEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _triggerNewInsight(showBanner: true);
      });
    } else {
      _checkScheduledInsightDue();
    }
  }

  void _startPeriodicInsightTimer() {
    _insightTimer?.cancel();
    _insightTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkScheduledInsightDue();
    });
  }

  Future<void> _checkScheduledInsightDue() async {
    if (_intervalMinutes <= 0 || _isGeneratingInsight) return;
    final lastTime = await Storage.getLastInsightTime();
    final now = DateTime.now();
    if (lastTime == null || now.difference(lastTime).inMinutes >= _intervalMinutes) {
      await _triggerNewInsight(showBanner: true);
    }
  }

  Future<void> _triggerNewInsight({bool showBanner = true}) async {
    if (_isGeneratingInsight) return;
    setState(() => _isGeneratingInsight = true);
    try {
      final memory = await Storage.getMemory();
      final stats = await Storage.getStats();
      final insight = await GeminiService.generateProactiveInsight(
        userName: widget.userName,
        memory: memory,
        stats: stats,
        existingInsights: _insights,
      );
      await Storage.addInsight(insight);
      final updated = await Storage.getInsights();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _insights = updated;
        if (showBanner) _activeBannerInsight = insight;
      });
    } finally {
      if (mounted) setState(() => _isGeneratingInsight = false);
    }
  }

  Future<void> _handleIntervalChanged(int minutes) async {
    await Storage.setNotificationIntervalMinutes(minutes);
    if (!mounted) return;
    setState(() => _intervalMinutes = minutes);
    _startPeriodicInsightTimer();
  }

  Future<void> _handleMarkInsightRead(String id) async {
    await Storage.markInsightRead(id);
    final updated = await Storage.getInsights();
    if (!mounted) return;
    setState(() => _insights = updated);
  }

  Future<void> _handleMarkAllRead() async {
    await Storage.markAllInsightsRead();
    final updated = await Storage.getInsights();
    if (!mounted) return;
    setState(() => _insights = updated);
  }

  Future<void> _handleDeleteInsight(String id) async {
    await Storage.deleteInsight(id);
    final updated = await Storage.getInsights();
    if (!mounted) return;
    setState(() {
      _insights = updated;
      if (_activeBannerInsight?.id == id) _activeBannerInsight = null;
    });
  }

  void _discussInsightInChat(AiInsightNotification insight) {
    _handleMarkInsightRead(insight.id);
    setState(() {
      _activeBannerInsight = null;
      _tabIndex = 0;
      _pendingChatPrompt =
          '💡 **${insight.title}** hakkında konuşalım: ${insight.actionPrompt}';
    });
  }

  void _askAiWithPrompt(String prompt) {
    setState(() {
      _tabIndex = 0;
      _pendingChatPrompt = prompt;
    });
  }

  Future<void> _loadConversations() async {
    final ids = await Storage.getConvIds();
    final metas = await Future.wait(
      ids.map((id) async => ConvMeta(id: id, title: await Storage.getTitle(id))),
    );
    if (!mounted) return;
    setState(() {
      _conversations = metas;
      _currentConvId = null;
    });
  }

  void _newChat() {
    setState(() {
      _currentConvId = null;
      _tabIndex = 0;
    });
    Navigator.pop(context);
  }

  void _selectConv(String id) {
    setState(() {
      _currentConvId = id;
      _tabIndex = 0;
    });
    Navigator.pop(context);
  }

  void _onConvCreated(String id, String title) {
    setState(() {
      _conversations.insert(0, ConvMeta(id: id, title: title));
    });
  }

  void _onTitleUpdated(String id, String title) {
    setState(() {
      _conversations = _conversations
          .map((c) => c.id == id ? ConvMeta(id: id, title: title) : c)
          .toList();
    });
  }

  Future<void> _deleteConv(String id) async {
    await Storage.deleteConv(id);
    setState(() {
      _conversations.removeWhere((c) => c.id == id);
      if (_currentConvId == id) {
        _currentConvId = _conversations.isNotEmpty ? _conversations.first.id : null;
      }
    });
  }

  Future<void> _showMemory() async {
    final memory = await Storage.getMemory();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology_outlined, color: kGold, size: 20),
            SizedBox(width: 8),
            Text('AI Hafızası'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(memory.isEmpty ? 'Henüz bilgi kaydedilmedi.' : memory),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _showQuickApiDialog() async {
    final currentKey = await Storage.getGeminiApiKey();
    final ctrl = TextEditingController(text: currentKey);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: kGold, size: 20),
            SizedBox(width: 8),
            Text('Google Gemini API Anahtarı'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google AI Studio (aistudio.google.com) üzerinden aldığınız Gemini API anahtarınızı yapıştırın:',
              style: TextStyle(color: kTextMid, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: kTextHi, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                hintStyle: const TextStyle(color: kText3),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: kTextMid)),
          ),
          TextButton(
            onPressed: () async {
              await Storage.setGeminiApiKey(ctrl.text.trim());
              await _loadApiStatus();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await Storage.clearUserName();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingPage(mainPageBuilder: (n) => MainPage(userName: n)),
      ),
    );
  }

  Future<void> _handleRename(String newName) async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainPage(userName: newName)),
    );
  }

  Future<void> _handleClearAll() async {
    final ids = await Storage.getConvIds();
    for (final id in ids) {
      await Storage.deleteConv(id);
    }
    if (!mounted) return;
    setState(() {
      _conversations = [];
      _currentConvId = null;
    });
  }

  Future<void> _loadScreenshotPref() async {
    final protected = await Storage.getScreenshotProtection();
    if (!mounted) return;
    setState(() => _screenshotProtected = protected);
    await _applyScreenshotProtection(protected);
  }

  Future<void> _applyScreenshotProtection(bool protect) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _screenshotChannel.invokeMethod(protect ? 'enable' : 'disable');
    } catch (_) {}
  }

  Future<void> _handleScreenshotToggle(bool protect) async {
    await Storage.setScreenshotProtection(protect);
    if (!mounted) return;
    setState(() => _screenshotProtected = protect);
    await _applyScreenshotProtection(protect);
  }

  void _showPrivacyAndAbout() {
    const sectionStyle = TextStyle(
      color: kText3,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    );
    const commands = [
      ('"adımı [isim] yap"', 'İsminizi değiştirir'),
      ('"hafızamı sil"', 'Öğrenilen bilgileri temizler'),
      ('"tüm sohbetleri sil"', 'Sohbet geçmişini temizler'),
      ('"bana yeni bir AI fikri üret"', 'Anında finansal fikir bildirimi üretir'),
      ('"ekran görüntüsü korumasını aç"', 'Ekran alıntısını engeller'),
      ('"çıkış yap"', 'Uygulamadan çıkar'),
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: kGold, size: 20),
            SizedBox(width: 8),
            Text('Gizlilik ve Hakkımda'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('GİZLİLİK', style: sectionStyle),
              const SizedBox(height: 6),
              const Text(
                'Tüm verileriniz yalnızca bu cihazda saklanır. '
                'Sohbet geçmişi, hafıza ve finansal bilgileriniz '
                'hiçbir harici sunucuda depolanmaz.',
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 16),
              const Text('HAKKINDA', style: sectionStyle),
              const SizedBox(height: 6),
              const Text(
                'Finans Asistanı — v0.2.0 MVP\n'
                'Kişisel yapay zeka destekli finansal danışmanınız.\n'
                'Google Gemini API · Proaktif Fikir Bildirimleri',
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 16),
              const Text('CHATBOT KOMUTLARI', style: sectionStyle),
              const SizedBox(height: 6),
              const Text(
                'Asistana yazarak aşağıdaki işlemleri yapabilirsiniz:',
                style: TextStyle(color: kTextMid, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              ...commands.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: kGold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, height: 1.4),
                            children: [
                              TextSpan(
                                text: '${e.$1}  ',
                                style: const TextStyle(color: kTextHi, fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: e.$2,
                                style: const TextStyle(color: kTextMid),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  String get _initials {
    final parts = widget.userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return widget.userName.substring(0, min(2, widget.userName.length)).toUpperCase();
  }

  int get _unreadInsightCount => _insights.where((e) => !e.isRead).length;

  @override
  Widget build(BuildContext context) {
    final unread = _unreadInsightCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: kTextMid),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            const GoldOrbFlat(size: 32, iconSize: 17),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Finans Asistanı',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: kTextHi,
                    letterSpacing: -0.1,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasApiKey ? kGreen : kGold,
                        boxShadow: [
                          BoxShadow(
                            color: (_hasApiKey ? kGreen : kGold).withValues(alpha: 0.7),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _hasApiKey ? 'GEMINI AI · AKTİF' : 'DEMO MODU · HAZIR',
                      style: const TextStyle(
                        color: kGold,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          // AI Notification Bell with Unread Badge
          IconButton(
            tooltip: 'AI Fikir Bildirimleri',
            onPressed: () => setState(() => _tabIndex = 1),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  color: unread > 0 ? kGold : kTextMid,
                ),
                if (unread > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                      decoration: BoxDecoration(
                        color: kGold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Color(0xFF15110A),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.key_rounded, color: _hasApiKey ? kGreen : kGold, size: 20),
            onPressed: _showQuickApiDialog,
            tooltip: 'Gemini API Anahtarı',
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined, color: kGold),
            onPressed: _showMemory,
            tooltip: 'Hafıza',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorderSoft),
        ),
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          IndexedStack(
            index: _tabIndex,
            children: [
              ChatArea(
                key: ValueKey(_currentConvId),
                userName: widget.userName,
                conversationId: _currentConvId,
                initialPrompt: _pendingChatPrompt,
                screenshotProtected: _screenshotProtected,
                hasApiKey: _hasApiKey,
                stats: _stats,
                onConvCreated: _onConvCreated,
                onTitleUpdated: _onTitleUpdated,
                onStatsUpdated: (s) => setState(() => _stats = s),
                onScreenshotToggle: _handleScreenshotToggle,
                onLogout: _handleLogout,
                onRename: _handleRename,
                onClearAll: _handleClearAll,
                onRequestNewInsight: () => _triggerNewInsight(showBanner: true),
                onOpenApiSettings: _showQuickApiDialog,
                onInitialPromptConsumed: () {
                  if (mounted) setState(() => _pendingChatPrompt = null);
                },
              ),
              InsightsPage(
                insights: _insights,
                isGenerating: _isGeneratingInsight,
                intervalMinutes: _intervalMinutes,
                onGenerateNow: () => _triggerNewInsight(showBanner: true),
                onIntervalChanged: _handleIntervalChanged,
                onDiscussInsight: _discussInsightInChat,
                onMarkRead: _handleMarkInsightRead,
                onMarkAllRead: _handleMarkAllRead,
                onDeleteInsight: _handleDeleteInsight,
              ),
              DashboardPage(
                userName: widget.userName,
                stats: _stats,
                screenshotProtected: _screenshotProtected,
                notificationIntervalMinutes: _intervalMinutes,
                onStatsChanged: (s) => setState(() => _stats = s),
                onScreenshotChanged: _handleScreenshotToggle,
                onIntervalChanged: _handleIntervalChanged,
                onApiSettingsUpdated: _loadApiStatus,
                onAskAiWithPrompt: _askAiWithPrompt,
              ),
            ],
          ),

          // ── Proactive In-App AI Idea Notification Banner ───────────────────
          if (_activeBannerInsight != null)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: _AiNotificationBanner(
                insight: _activeBannerInsight!,
                onDiscuss: () => _discussInsightInChat(_activeBannerInsight!),
                onDismiss: () => setState(() => _activeBannerInsight = null),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kSurface2,
          border: Border(top: BorderSide(color: kBorderSoft)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: kSurface2,
            indicatorColor: kGold.withValues(alpha: 0.18),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? kGold : kTextMid,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              );
            }),
          ),
          child: NavigationBar(
            height: 62,
            selectedIndex: _tabIndex,
            onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded, color: kTextMid, size: 20),
                selectedIcon: Icon(Icons.chat_bubble_rounded, color: kGold, size: 20),
                label: 'Sohbet',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: kGold,
                  textColor: const Color(0xFF15110A),
                  label: Text('$unread'),
                  child: const Icon(Icons.auto_awesome_outlined, color: kTextMid, size: 20),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: kGold,
                  textColor: const Color(0xFF15110A),
                  label: Text('$unread'),
                  child: const Icon(Icons.auto_awesome, color: kGold, size: 20),
                ),
                label: 'AI Fikirler',
              ),
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: kTextMid, size: 20),
                selectedIcon: Icon(Icons.dashboard_rounded, color: kGold, size: 20),
                label: 'Özet & Ayarlar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: DrawerThemeData(
          backgroundColor: kSurface2,
          surfaceTintColor: Colors.transparent,
          width: MediaQuery.of(context).size.width * 0.84,
        ),
      ),
      child: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 18,
                right: 18,
                bottom: 18,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorderSoft)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFE5C459), Color(0xFFB89324)],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: Color(0xFF1A1305),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: kTextHi,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              _conversations.isEmpty
                                  ? 'Yeni kullanıcı'
                                  : '${_conversations.length} sohbet · ${_insights.length} AI fikri',
                              style: const TextStyle(color: kTextMid, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _newChat,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGold.withValues(alpha: 0.45)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: kGold, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Yeni Sohbet',
                            style: TextStyle(
                              color: kGold,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Row(
                children: [
                  const Text(
                    'GEÇMİŞ SOHBETLER',
                    style: TextStyle(
                      color: kText3,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [kBorder, Colors.transparent]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _conversations.isEmpty
                  ? const Center(
                      child: Text(
                        'Henüz sohbet yok',
                        style: TextStyle(color: kTextMid, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _conversations.length,
                      itemBuilder: (_, i) {
                        final conv = _conversations[i];
                        final selected = conv.id == _currentConvId;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: selected
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [Color(0x1ACBAA35), Color(0x05CBAA35)],
                                  ),
                                  border: Border.all(color: kGold.withValues(alpha: 0.25)),
                                )
                              : null,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _selectConv(conv.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: kSurface,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: selected ? kGold.withValues(alpha: 0.25) : kBorder,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      size: 15,
                                      color: selected ? kGold : kTextMid,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      conv.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected ? kGold : kTextHi,
                                        fontSize: 13.5,
                                        fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _deleteConv(conv.id),
                                    child: const Icon(Icons.delete_outline, size: 15, color: kText3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorderSoft)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showPrivacyAndAbout();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: kTextMid, size: 18),
                      SizedBox(width: 12),
                      Text(
                        'Gizlilik ve Hakkımda',
                        style: TextStyle(color: kTextMid, fontSize: 13.5),
                      ),
                      Spacer(),
                      Icon(Icons.chevron_right, color: kText3, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiNotificationBanner extends StatelessWidget {
  final AiInsightNotification insight;
  final VoidCallback onDiscuss;
  final VoidCallback onDismiss;

  const _AiNotificationBanner({
    required this.insight,
    required this.onDiscuss,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = insight.categoryColor;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF162235),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withValues(alpha: 0.65), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 15, color: kGold),
                const SizedBox(width: 6),
                Text(
                  'YENİ AI FİKİR BİLDİRİMİ · ${insight.category.toUpperCase()}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close, size: 16, color: kTextMid),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              insight.title,
              style: const TextStyle(
                color: kTextHi,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              insight.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kTextMid,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'Daha Sonra',
                      style: TextStyle(color: kTextMid, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDiscuss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: kGoldGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Bu Fikri Konuşalım →',
                      style: TextStyle(
                        color: Color(0xFF15110A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

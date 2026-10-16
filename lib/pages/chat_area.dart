import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../gemini_service.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';

class ChatArea extends StatefulWidget {
  final String userName;
  final String? conversationId;
  final String? initialPrompt;
  final bool screenshotProtected;
  final bool hasApiKey;
  final Map<String, String?> stats;
  final void Function(String id, String title) onConvCreated;
  final void Function(String id, String title)? onTitleUpdated;
  final void Function(Map<String, String?> updatedStats)? onStatsUpdated;
  final void Function(bool)? onScreenshotToggle;
  final VoidCallback? onLogout;
  final void Function(String newName)? onRename;
  final VoidCallback? onClearAll;
  final VoidCallback? onRequestNewInsight;
  final VoidCallback? onOpenApiSettings;
  final VoidCallback? onInitialPromptConsumed;

  const ChatArea({
    super.key,
    required this.userName,
    required this.conversationId,
    this.initialPrompt,
    this.screenshotProtected = false,
    this.hasApiKey = false,
    required this.stats,
    required this.onConvCreated,
    this.onTitleUpdated,
    this.onStatsUpdated,
    this.onScreenshotToggle,
    this.onLogout,
    this.onRename,
    this.onClearAll,
    this.onRequestNewInsight,
    this.onOpenApiSettings,
    this.onInitialPromptConsumed,
  });

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  List<Map<String, dynamic>> _chatHistory = [];
  String _memory = '';
  String? _convId;
  DateTime _lastRender = DateTime.fromMillisecondsSinceEpoch(0);
  Map<String, String?> _stats = {};

  @override
  void initState() {
    super.initState();
    _convId = widget.conversationId;
    _stats = Map<String, String?>.from(widget.stats);
    _init();
  }

  @override
  void didUpdateWidget(covariant ChatArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stats != oldWidget.stats) {
      setState(() => _stats = Map<String, String?>.from(widget.stats));
    }
    if (widget.initialPrompt != null &&
        widget.initialPrompt!.isNotEmpty &&
        widget.initialPrompt != oldWidget.initialPrompt) {
      final promptToRun = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onInitialPromptConsumed?.call();
        _sendMessage(promptToRun);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _memory = await Storage.getMemory();
    final storedStats = await Storage.getStats();
    if (storedStats.isNotEmpty) {
      _stats = storedStats;
    }
    if (_convId != null) {
      final raw = await Storage.getMessages(_convId!);
      if (mounted) {
        setState(() => _messages = raw.map(ChatMessage.fromJson).toList());
      }
    }
    _buildHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
        final promptToRun = widget.initialPrompt!;
        widget.onInitialPromptConsumed?.call();
        _sendMessage(promptToRun);
      }
    });
  }

  String get _systemPrompt => '''
Sen "Finans Asistanı" adlı bir yapay zeka finansal danışmansın (Google Gemini altyapısıyla çalışıyorsun).
Türkçe konuşuyorsun. Kullanıcının adı: ${widget.userName}.

Kullanıcı hakkında bildiklerin (Hafıza):
${_memory.isEmpty ? 'Henüz bilgi yok, konuşurken öğreneceksin.' : _memory}

Bilinen Finansal Rakamlar:
- Bakiye / Gelir: ${_stats['balance'] ?? 'Bilinmiyor'}
- Aylık Harcama: ${_stats['spending'] ?? 'Bilinmiyor'}
- Toplam Birikim: ${_stats['savings'] ?? 'Bilinmiyor'}
- Finansal Hedef: ${_stats['goal'] ?? 'Bilinmiyor'}

Görevin:
- Bütçe yönetimi, yatırım sepeti, tasarruf, borç kapatma, fon/altın/borsa dağılımı ve emeklilik planlaması gibi finansal konularda uzman, net ve yapılandırılmış tavsiyeler ver.
- Kullanıcıyı tanıyorsun, geçmiş bilgilerini hatırlıyorsun ve konuşmada bunlara atıfta bulun.
- Samimi, teşvik edici ama profesyonel bir ton kullan.
- Finansal kararlar için somut, uygulanabilir öneriler (yüzdeler, adım adım planlar) sun.

Mevcut ayarlar:
- Ekran görüntüsü koruması: ${widget.screenshotProtected ? 'aktif ✓' : 'pasif ✗'}

Sistem işlemleri:
Kullanıcı aşağıdaki işlemleri açıkça isterse, yanıtının EN SONUNA (başka hiçbir yere değil) ilgili etiketi ekle:
- Adını değiştirmek isterse (örn. "adımı X yap", "ismimi X olarak değiştir") → [ACTION:rename:YeniAd]
- Hafızayı sıfırlamak isterse (örn. "hafızamı sil", "beni unut") → [ACTION:clear_memory]
- Tüm sohbetleri silmek isterse → [ACTION:clear_all]
- Çıkış yapmak isterse (örn. "çıkış yap", "hesabı sıfırla") → [ACTION:logout]
- Ekran görüntüsü korumasını açmak isterse → [ACTION:screenshot_on]
- Ekran görüntüsü korumasını kapatmak isterse → [ACTION:screenshot_off]
- Yeni bir yapay zeka bildirim fikri üretilmesini isterse (örn. "bana bildirim gönder", "yeni bir AI fikri üret") → [ACTION:new_insight]
Etiketleri kullanıcıya gösterme, sadece sistem okur.
''';

  void _buildHistory() {
    _chatHistory = [
      {'role': 'system', 'content': _systemPrompt},
    ];
    for (final msg in _messages.where((m) => m.text.isNotEmpty)) {
      _chatHistory.add({'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text});
    }
  }

  String get _nowTime {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _textController.text.trim();
    if (text.isEmpty || _isLoading) return;
    _textController.clear();
    final time = _nowTime;

    if (_convId == null) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _convId = id;
      await Storage.addConvId(id);
      await Storage.setTitle(id, 'Yeni Sohbet');
      widget.onConvCreated(id, 'Yeni Sohbet');
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, time: time));
      _isLoading = true;
      _messages.add(const ChatMessage(text: '', isUser: false));
    });
    _scrollToBottom();

    _chatHistory.add({'role': 'user', 'content': text});

    try {
      final stream = GeminiService.streamChat(
        systemPrompt: _systemPrompt,
        history: _chatHistory,
        userName: widget.userName,
        stats: _stats,
      );
      String fullReply = '';
      await for (final delta in stream) {
        if (!mounted) return;
        fullReply += delta;
        final now = DateTime.now();
        if (now.difference(_lastRender).inMilliseconds >= 50) {
          _lastRender = now;
          setState(() {
            _messages[_messages.length - 1] =
                ChatMessage(text: _stripActions(fullReply), isUser: false, time: _nowTime);
          });
          _scrollToBottom();
        }
      }
      final actionMatch = _actionRegex.firstMatch(fullReply);
      final displayReply = _stripActions(fullReply);
      if (mounted) {
        setState(() {
          _messages[_messages.length - 1] =
              ChatMessage(text: displayReply, isUser: false, time: _nowTime);
        });
      }
      _chatHistory.add({'role': 'assistant', 'content': displayReply});
      await _save();
      _updateMemory(userMessage: text, aiReply: displayReply);
      _updateStats(userMessage: text, aiReply: displayReply);
      if (_messages.where((m) => m.isUser).length == 1) {
        _generateTitle(userMessage: text, aiReply: displayReply);
      }
      if (actionMatch != null) _handleAction(actionMatch.group(1)!);
    } catch (e) {
      if (!mounted) return;
      _chatHistory.removeLast();
      setState(() {
        _messages[_messages.length - 1] =
            ChatMessage(text: 'Hata: $e', isUser: false, time: _nowTime);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _save() async {
    if (_convId == null) return;
    final json = _messages.where((m) => m.text.isNotEmpty).map((m) => m.toJson()).toList();
    await Storage.saveMessages(_convId!, json);
  }

  Future<void> _updateMemory({required String userMessage, required String aiReply}) async {
    final current = await Storage.getMemory();
    final updated = await GeminiService.updateMemory(
      userName: widget.userName,
      currentMemory: current,
      userMessage: userMessage,
      aiReply: aiReply,
    );
    if (updated != null && updated.isNotEmpty) {
      _memory = updated;
      await Storage.setMemory(_memory);
    }
  }

  Future<void> _generateTitle({required String userMessage, required String aiReply}) async {
    if (_convId == null) return;
    final title = await GeminiService.generateTitle(
      userMessage: userMessage,
      aiReply: aiReply,
    );
    if (title != null && title.isNotEmpty) {
      await Storage.setTitle(_convId!, title);
      widget.onTitleUpdated?.call(_convId!, title);
    }
  }

  static final _actionRegex = RegExp(r'\[ACTION:([^\]]+)\]');

  String _stripActions(String text) => text.replaceAll(_actionRegex, '').trim();

  Future<void> _handleAction(String action) async {
    if (action == 'logout') {
      widget.onLogout?.call();
    } else if (action == 'clear_memory') {
      await Storage.setMemory('');
      if (mounted) setState(() => _memory = '');
      _buildHistory();
    } else if (action == 'clear_all') {
      widget.onClearAll?.call();
    } else if (action.startsWith('rename:')) {
      final newName = action.substring(7).trim();
      if (newName.isNotEmpty) {
        await Storage.setUserName(newName);
        widget.onRename?.call(newName);
      }
    } else if (action == 'screenshot_on') {
      widget.onScreenshotToggle?.call(true);
    } else if (action == 'screenshot_off') {
      widget.onScreenshotToggle?.call(false);
    } else if (action == 'new_insight') {
      widget.onRequestNewInsight?.call();
    }
  }

  Future<void> _updateStats({required String userMessage, required String aiReply}) async {
    final extracted = await GeminiService.extractStats(
      currentStats: _stats,
      userMessage: userMessage,
      aiReply: aiReply,
    );
    if (extracted != null) {
      if (mounted) setState(() => _stats = extracted);
      await Storage.setStats(extracted);
      widget.onStatsUpdated?.call(extracted);
    }
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (s) {
        if ((s == 'notListening' || s == 'done') && mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    if (!available || !mounted) return;
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (r) {
        if (mounted) setState(() => _textController.text = r.recognizedWords);
      },
      localeId: 'tr_TR',
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showChipsRow = _messages.isNotEmpty && _messages.length <= 4 && !_isLoading;
    return Column(
      children: [
        if (!widget.hasApiKey)
          _ApiKeyNoticeBar(onTap: widget.onOpenApiSettings),
        _StatsRow(stats: _stats),
        Expanded(
          child: _messages.isEmpty
              ? _EmptyState(
                  userName: widget.userName,
                  memory: _memory,
                  onChipTap: (t) => _sendMessage(t),
                  onRequestInsight: widget.onRequestNewInsight,
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                  itemCount: _messages.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) return const _DateSeparator();
                    return _MessageBubble(message: _messages[i - 1]);
                  },
                ),
        ),
        if (showChipsRow)
          _SuggestionChipsRow(
            onTap: (t) => _sendMessage(t),
            onInsightTap: widget.onRequestNewInsight,
          ),
        _InputBar(
          controller: _textController,
          onSend: () => _sendMessage(),
          onMic: _toggleMic,
          isLoading: _isLoading,
          isListening: _isListening,
        ),
      ],
    );
  }
}

class _ApiKeyNoticeBar extends StatelessWidget {
  final VoidCallback? onTap;
  const _ApiKeyNoticeBar({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kGold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: const [
            Icon(Icons.key_rounded, color: kGold, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Demo modundasınız. Gerçek zamanlı Google Gemini AI için API anahtarınızı ekleyin.',
                style: TextStyle(color: kTextHi, fontSize: 12, height: 1.3),
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Ayarla →',
              style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, String?> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, String value, Color accent})>[];
    if (stats['balance'] != null && stats['balance']!.isNotEmpty) {
      entries.add((label: 'Bakiye', value: stats['balance']!, accent: kGold));
    }
    if (stats['spending'] != null && stats['spending']!.isNotEmpty) {
      entries.add((label: 'Harcama', value: stats['spending']!, accent: kRed));
    }
    if (stats['savings'] != null && stats['savings']!.isNotEmpty) {
      entries.add((label: 'Birikim', value: stats['savings']!, accent: kGreen));
    }
    if (stats['goal'] != null && stats['goal']!.isNotEmpty && entries.length < 3) {
      entries.add((label: 'Hedef', value: stats['goal']!, accent: kBlue));
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 8));
      children.add(
        Expanded(
          child: _StatCard(
            label: entries[i].label,
            value: entries[i].value,
            accent: entries[i].accent,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(children: children),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatCard({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
              ),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: kText3,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kTextHi, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: kBorderSoft)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Bugün · $t',
              style: const TextStyle(
                color: kText3,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: kBorderSoft)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String userName;
  final String memory;
  final void Function(String) onChipTap;
  final VoidCallback? onRequestInsight;

  const _EmptyState({
    required this.userName,
    required this.memory,
    required this.onChipTap,
    this.onRequestInsight,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const GoldOrb(size: 72, iconSize: 34),
            const SizedBox(height: 20),
            Text(
              memory.isEmpty ? 'Merhaba, $userName' : 'Tekrar hoş geldin, $userName',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kTextHi,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              memory.isEmpty
                  ? 'Google Gemini destekli finansal danışmanınız\nbütçe, yatırım ve birikim planlarınız için hazır.'
                  : 'Finansal durumunuzu takip ediyorum.\nBugün hangi hedefiniz üzerinde çalışalım?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextMid, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: memory.isEmpty
                  ? [
                      _SuggChip('Bütçe planı oluştur', Icons.pie_chart_outline, onChipTap),
                      _SuggChip('Yatırım sepeti önerisi ver', Icons.trending_up, onChipTap),
                      _SuggChip('Finansal hedef belirle', Icons.flag_outlined, onChipTap),
                      _SuggChip('Acil durum fonu hesapla', Icons.savings_outlined, onChipTap),
                    ]
                  : [
                      _SuggChip('Bu ay harcama durumum', Icons.pie_chart_outline, onChipTap),
                      _SuggChip('Enflasyon korumalı sepet', Icons.trending_up, onChipTap),
                      _SuggChip('Finansal özet ver', Icons.summarize_outlined, onChipTap),
                      _SuggChip('Hedeflerime ne kadar kaldı?', Icons.flag_outlined, onChipTap),
                    ],
            ),
            if (onRequestInsight != null) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onRequestInsight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kGold.withValues(alpha: 0.18),
                        kGold.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kGold.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.auto_awesome, size: 15, color: kGold),
                      SizedBox(width: 7),
                      Text(
                        'Bana Anlık AI Finans Fikri Bildirimi Gönder',
                        style: TextStyle(
                          color: kGold,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final void Function(String) onTap;
  const _SuggChip(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: kGold),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: kTextHi, fontSize: 12.5, letterSpacing: 0.1)),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChipsRow extends StatelessWidget {
  final void Function(String) onTap;
  final VoidCallback? onInsightTap;
  const _SuggestionChipsRow({required this.onTap, this.onInsightTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          if (onInsightTap != null) ...[
            GestureDetector(
              onTap: onInsightTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kGold.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, size: 13, color: kGold),
                    SizedBox(width: 6),
                    Text('AI Fikri Üret', style: TextStyle(color: kGold, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _InlineChip('Bu ay harcamam', Icons.pie_chart_outline, onTap),
          const SizedBox(width: 8),
          _InlineChip('Yatırım sepeti', Icons.trending_up, onTap),
          const SizedBox(width: 8),
          _InlineChip('Kart borcu stratejisi', Icons.credit_card_outlined, onTap),
        ],
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final void Function(String) onTap;
  const _InlineChip(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: kGold),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: kTextHi, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (!message.isUser && message.text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const GoldOrbFlat(size: 28, iconSize: 13),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kAiBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: kBorder),
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      );
    }

    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kUserBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(6),
                  ),
                  border: Border.all(color: kUserBdr),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.text,
                      style: const TextStyle(color: kTextHi, fontSize: 14.5, height: 1.5),
                    ),
                    if (message.time.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${message.time} · okundu',
                        style: const TextStyle(color: kText3, fontSize: 10.5, letterSpacing: 0.3),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const GoldOrbFlat(size: 28, iconSize: 13),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kAiBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: kTextHi, fontSize: 14.5, height: 1.6),
                      strong: const TextStyle(color: kTextHi, fontSize: 14.5, fontWeight: FontWeight.bold),
                      em: const TextStyle(color: kTextHi, fontSize: 14.5, fontStyle: FontStyle.italic),
                      h1: const TextStyle(color: kTextHi, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
                      h2: const TextStyle(color: kTextHi, fontSize: 17.5, fontWeight: FontWeight.bold, height: 1.4),
                      h3: const TextStyle(color: kTextHi, fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.4),
                      code: const TextStyle(color: kGold, fontSize: 13, fontFamily: 'monospace'),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder),
                      ),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: kGold, width: 3)),
                        color: Color(0x11D4AF37),
                      ),
                      listBullet: const TextStyle(color: kGold, fontSize: 14.5),
                    ),
                  ),
                  if (message.time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message.time,
                      style: const TextStyle(color: kText3, fontSize: 10.5, letterSpacing: 0.3),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
            final dy = sin(phase * pi) * -4.0;
            final opacity = 0.35 + sin(phase * pi) * 0.65;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGold.withValues(alpha: opacity),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final bool isLoading;
  final bool isListening;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onMic,
    required this.isLoading,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kBorderSoft, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(),
                          maxLines: null,
                          style: const TextStyle(color: kTextHi, fontSize: 14.5),
                          decoration: InputDecoration(
                            hintText: 'Gemini finans asistanına yazın…',
                            hintStyle: const TextStyle(color: kText3, fontSize: 14.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: GestureDetector(
                          onTap: onMic,
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              isListening ? Icons.mic : Icons.mic_none,
                              size: 18,
                              color: isListening ? kGold : kTextMid,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: isLoading ? null : onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isLoading ? null : kGoldGradient,
                    color: isLoading ? kSurface : null,
                    boxShadow: isLoading
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x40CBAA35),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Icon(
                    Icons.arrow_upward,
                    color: isLoading ? kTextMid : const Color(0xFF15110A),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

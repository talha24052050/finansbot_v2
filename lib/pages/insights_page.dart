import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

class InsightsPage extends StatefulWidget {
  final List<AiInsightNotification> insights;
  final bool isGenerating;
  final int intervalMinutes;
  final VoidCallback onGenerateNow;
  final void Function(int minutes) onIntervalChanged;
  final void Function(AiInsightNotification insight) onDiscussInsight;
  final void Function(String id) onMarkRead;
  final VoidCallback onMarkAllRead;
  final void Function(String id) onDeleteInsight;

  const InsightsPage({
    super.key,
    required this.insights,
    required this.isGenerating,
    required this.intervalMinutes,
    required this.onGenerateNow,
    required this.onIntervalChanged,
    required this.onDiscussInsight,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onDeleteInsight,
  });

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  String _selectedCategory = 'Tümü';

  static const _categories = ['Tümü', 'Tasarruf', 'Yatırım', 'Bütçe', 'Fırsat', 'Uyarı'];

  static const _intervals = <(int, String)>[
    (0, 'Kapalı'),
    (2, 'Demo · 2 dk'),
    (15, '15 dk'),
    (60, '1 Saat'),
    (1440, 'Günlük'),
  ];

  List<AiInsightNotification> get _filteredInsights {
    if (_selectedCategory == 'Tümü') return widget.insights;
    return widget.insights
        .where((e) => e.category.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.insights.where((e) => !e.isRead).length;
    final items = _filteredInsights;

    return Column(
      children: [
        // ── Top Hero Card: Generate AI Idea + Frequency Selector ─────────────
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF19263B), Color(0xFF101929)],
            ),
            border: Border.all(color: kGold.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kGold.withValues(alpha: 0.16),
                      border: Border.all(color: kGold.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.auto_awesome, color: kGold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Proaktif AI Finans Fikirleri',
                              style: TextStyle(
                                color: kTextHi,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kGold,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$unreadCount yeni',
                                  style: const TextStyle(
                                    color: Color(0xFF15110A),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Gemini hafızanızı ve bütçenizi analiz ederek ara sıra kişiselleştirilmiş fikir bildirimleri gönderir.',
                          style: TextStyle(color: kTextMid, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.isGenerating ? null : widget.onGenerateNow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: widget.isGenerating ? null : kGoldGradient,
                          color: widget.isGenerating ? kSurface : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.isGenerating) ...[
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kGold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Gemini Fikir Üretiyor…',
                                style: TextStyle(
                                  color: kTextHi,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              const Icon(
                                Icons.bolt_rounded,
                                size: 17,
                                color: Color(0xFF15110A),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Şimdi Yeni AI Fikri Üret',
                                style: TextStyle(
                                  color: Color(0xFF15110A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onMarkAllRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder),
                        ),
                        child: const Text(
                          'Tümünü Okundu Say',
                          style: TextStyle(color: kTextMid, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Periodic Notification Frequency Selector
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, size: 14, color: kGold),
                  const SizedBox(width: 6),
                  const Text(
                    'Bildirim Sıklığı:',
                    style: TextStyle(color: kTextMid, fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _intervals.map((item) {
                          final selected = widget.intervalMinutes == item.$1;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => widget.onIntervalChanged(item.$1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: selected ? kGold.withValues(alpha: 0.2) : kSurface,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected ? kGold : kBorder,
                                  ),
                                ),
                                child: Text(
                                  item.$2,
                                  style: TextStyle(
                                    color: selected ? kGold : kTextMid,
                                    fontSize: 11,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Category Filter Chips ────────────────────────────────────────────
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final selected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? kGold.withValues(alpha: 0.16) : kSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? kGold.withValues(alpha: 0.6) : kBorder,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: selected ? kGold : kTextMid,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // ── Insights List ────────────────────────────────────────────────────
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 46,
                          color: kGold.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Henüz bu kategoride AI fikri yok',
                          style: TextStyle(
                            color: kTextHi,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Yukarıdaki "Şimdi Yeni AI Fikri Üret" butonuna dokunarak Gemini\'den anında kişisel bir öneri alabilirsiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kTextMid, fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return _InsightCard(
                      insight: item,
                      onDiscuss: () => widget.onDiscussInsight(item),
                      onMarkRead: () => widget.onMarkRead(item.id),
                      onDelete: () => widget.onDeleteInsight(item.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AiInsightNotification insight;
  final VoidCallback onDiscuss;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _InsightCard({
    required this.insight,
    required this.onDiscuss,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = insight.categoryColor;
    return GestureDetector(
      onTap: onMarkRead,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: insight.isRead ? kSurface2 : kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: insight.isRead ? kBorder : color.withValues(alpha: 0.45),
          ),
          boxShadow: insight.isRead
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(insight.categoryIcon, size: 12, color: color),
                      const SizedBox(width: 5),
                      Text(
                        insight.category.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!insight.isRead)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kGold,
                      boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.8), blurRadius: 6)],
                    ),
                  ),
                const Spacer(),
                Text(
                  insight.formattedTime,
                  style: const TextStyle(color: kText3, fontSize: 11),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.close, size: 15, color: kText3),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              insight.title,
              style: const TextStyle(
                color: kTextHi,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              insight.body,
              style: const TextStyle(
                color: kTextMid,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onDiscuss,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                      decoration: BoxDecoration(
                        color: kGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kGold.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.chat_bubble_outline_rounded, size: 14, color: kGold),
                          SizedBox(width: 7),
                          Text(
                            'Bu Fikri Asistanla Detaylandır →',
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

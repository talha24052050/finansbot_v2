import 'package:flutter/material.dart';
import 'theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String time;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.time = '',
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'time': time,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String? ?? '',
        isUser: j['isUser'] as bool? ?? false,
        time: j['time'] as String? ?? '',
      );
}

class ConvMeta {
  final String id;
  final String title;
  const ConvMeta({required this.id, required this.title});
}

class AiInsightNotification {
  final String id;
  final String title;
  final String body;
  final String category; // 'Tasarruf', 'Yatırım', 'Bütçe', 'Fırsat', 'Uyarı'
  final String actionPrompt;
  final DateTime createdAt;
  final bool isRead;

  const AiInsightNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.actionPrompt,
    required this.createdAt,
    this.isRead = false,
  });

  AiInsightNotification copyWith({bool? isRead}) {
    return AiInsightNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      actionPrompt: actionPrompt,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'actionPrompt': actionPrompt,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AiInsightNotification.fromJson(Map<String, dynamic> j) {
    return AiInsightNotification(
      id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: j['title'] as String? ?? 'Finansal Fikir',
      body: j['body'] as String? ?? '',
      category: j['category'] as String? ?? 'Tasarruf',
      actionPrompt: j['actionPrompt'] as String? ?? 'Bu finansal fikri detaylandırır mısın?',
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      isRead: j['isRead'] as bool? ?? false,
    );
  }

  Color get categoryColor {
    switch (category.toLowerCase()) {
      case 'yatırım':
        return kGold;
      case 'tasarruf':
        return kGreen;
      case 'bütçe':
        return kBlue;
      case 'uyarı':
        return kRed;
      case 'fırsat':
        return kPurple;
      default:
        return kGold;
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'yatırım':
        return Icons.trending_up_rounded;
      case 'tasarruf':
        return Icons.savings_outlined;
      case 'bütçe':
        return Icons.pie_chart_outline_rounded;
      case 'uyarı':
        return Icons.warning_amber_rounded;
      case 'fırsat':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.lightbulb_outline_rounded;
    }
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────

const kBg         = Color(0xFF080C14);
const kSurface    = Color(0xFF131E2E);
const kSurface2   = Color(0xFF0E1626);
const kAiBg       = Color(0xFF141E2C);
const kBorder     = Color(0xFF1E2D45);
const kBorderSoft = Color(0xFF16243A);
const kGold       = Color(0xFFCBAA35);
const kTextHi     = Color(0xFFDDE6F5);
const kTextMid    = Color(0xFF6B7FA3);
const kText3      = Color(0xFF4A5C7A);
const kUserBg     = Color(0xFF0F1D10);
const kUserBdr    = Color(0xFF1A3820);
const kGreen      = Color(0xFF6FCB8B);
const kRed        = Color(0xFFE57373);
const kBlue       = Color(0xFF64B5F6);
const kPurple     = Color(0xFFB39DDB);

const kGoldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFD9B845), Color(0xFFB89324)],
);

// ── Shared Orb & Pill Widgets ─────────────────────────────────────────────────

class GoldOrb extends StatelessWidget {
  final double size;
  final double iconSize;
  final IconData icon;
  const GoldOrb({
    super.key,
    required this.size,
    required this.iconSize,
    this.icon = Icons.account_balance,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.4, -0.5),
              radius: 1.0,
              colors: [
                Color(0xFFF4DC8A),
                Color(0xFFE5C459),
                Color(0xFFCBAA35),
                Color(0xFF8E6F1B),
              ],
              stops: [0.0, 0.24, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(color: Color(0x40CBAA35), blurRadius: 28, offset: Offset(0, 8)),
            ],
          ),
          child: Icon(icon, size: iconSize, color: const Color(0xFF1A1305)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: const Alignment(0, 0.4),
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GoldOrbFlat extends StatelessWidget {
  final double size;
  final double iconSize;
  final IconData icon;
  const GoldOrbFlat({
    super.key,
    required this.size,
    required this.iconSize,
    this.icon = Icons.account_balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: kGoldGradient,
        boxShadow: [
          BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, size: iconSize, color: const Color(0xFF1A1305)),
    );
  }
}

class DotPill extends StatelessWidget {
  final String label;
  final Color dotColor;
  const DotPill(this.label, {super.key, this.dotColor = kGold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.7), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: kTextMid,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

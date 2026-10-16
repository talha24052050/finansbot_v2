import 'package:flutter/material.dart';
import '../storage.dart';
import '../theme.dart';

class OnboardingPage extends StatefulWidget {
  final Widget Function(String userName) mainPageBuilder;
  const OnboardingPage({super.key, required this.mainPageBuilder});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _nameFocused = false;
  bool _keyFocused = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _loadExistingKey();
  }

  Future<void> _loadExistingKey() async {
    final key = await Storage.getGeminiApiKey();
    if (mounted && key.isNotEmpty) {
      _apiKeyController.text = key;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await Storage.setUserName(name);
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      await Storage.setGeminiApiKey(apiKey);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.mainPageBuilder(name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: kBg),
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [kGold.withValues(alpha: 0.10), kGold.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: const [
                      GoldOrbFlat(size: 22, iconSize: 12),
                      SizedBox(width: 8),
                      Text(
                        'FINANSBOT V2 · MVP',
                        style: TextStyle(
                          color: kText3,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Türkiye · TR',
                        style: TextStyle(
                          color: kText3,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        const GoldOrb(size: 88, iconSize: 40),
                        const SizedBox(height: 20),
                        const Text(
                          'Finans Asistanı',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: kTextHi,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gemini AI destekli kişisel finans danışmanınız.\nAnlar, hatırlar, proaktif fikirler sunar.',
                          style: TextStyle(color: kTextMid, fontSize: 14.5, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: const [
                            DotPill('Sizi hatırlar'),
                            DotPill('Gemini AI Analiz'),
                            DotPill('Akıllı Fikir Bildirimleri'),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Container(
                          height: 1,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, kBorder, Colors.transparent],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ADINIZ',
                            style: TextStyle(
                              color: kTextMid,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Focus(
                          onFocusChange: (v) => setState(() => _nameFocused = v),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _nameFocused ? kGold.withValues(alpha: 0.7) : kBorder,
                              ),
                              boxShadow: _nameFocused
                                  ? [
                                      BoxShadow(
                                        color: kGold.withValues(alpha: 0.12),
                                        blurRadius: 0,
                                        spreadRadius: 3,
                                      )
                                    ]
                                  : null,
                            ),
                            child: TextField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              autofocus: true,
                              style: const TextStyle(color: kTextHi, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Örn. Talha',
                                hintStyle: const TextStyle(color: kText3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: const [
                            Text(
                              'GEMINI API ANAHTARI',
                              style: TextStyle(
                                color: kTextMid,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.4,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '(İsteğe bağlı · Sonra da eklenebilir)',
                              style: TextStyle(color: kText3, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Focus(
                          onFocusChange: (v) => setState(() => _keyFocused = v),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _keyFocused ? kGold.withValues(alpha: 0.7) : kBorder,
                              ),
                            ),
                            child: TextField(
                              controller: _apiKeyController,
                              obscureText: _obscureKey,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              style: const TextStyle(color: kTextHi, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'AIzaSy... (Google AI Studio Key)',
                                hintStyle: const TextStyle(color: kText3, fontSize: 13.5),
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
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tüm verileriniz ve API anahtarınız yalnızca bu cihazda saklanır.',
                            style: TextStyle(color: kText3, fontSize: 11.5, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: GestureDetector(
                            onTap: _submit,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: kGoldGradient,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33CBAA35),
                                    blurRadius: 24,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Başla',
                                    style: TextStyle(
                                      color: Color(0xFF15110A),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 16, color: Color(0xFF15110A)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class WalkthroughStep {
  final int stepNumber;
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;

  const WalkthroughStep({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
  });

  static const List<WalkthroughStep> defaultSteps = [
    WalkthroughStep(
      stepNumber: 1,
      title: 'Point & Scan Any Food Packet',
      subtitle: 'Instant offline barcode, OCR nutrition tables, and ingredient recognition in sub-20ms with zero internet.',
      badgeText: '⚡ 100% Offline AI Engine',
      icon: Icons.qr_code_scanner_rounded,
    ),
    WalkthroughStep(
      stepNumber: 2,
      title: 'Unmask Hidden Sugars & Toxins',
      subtitle: 'Our database checks 1,200+ chemical additives, clusters 56+ hidden sugar aliases, and triggers a strict 39/100 Hard Red Cap.',
      badgeText: '🔒 Strict 39/100 Red Cap',
      icon: Icons.security_rounded,
    ),
    WalkthroughStep(
      stepNumber: 3,
      title: 'Personalized Safe Dosage Math',
      subtitle: 'Never guess portion sizes. Get tailored gram ceilings and weekly consumption frequencies calculated for your exact body weight.',
      badgeText: '⚖️ Dynamic ADI Ceiling',
      icon: Icons.scale_rounded,
    ),
    WalkthroughStep(
      stepNumber: 4,
      title: 'Healthier Swaps & Setup',
      subtitle: 'Discover certified clean alternatives with 1-tap quick delivery, set your medical guardrails, and start eating safely.',
      badgeText: '🔄 1-Tap Quick Commerce',
      icon: Icons.swap_horizontal_circle_rounded,
    ),
  ];
}

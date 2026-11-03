import 'package:flutter/material.dart';

/// Warm Luxury Alabaster & Midnight Obsidian Editorial Color Palette
class AppColors {
  // Luxury Canvas & Card Surfaces
  static const Color canvasCream = Color(0xFFFBF8F4);        // Alabaster Canvas Background
  static const Color cardSurface = Color(0xFFFDFBF7);        // Soft Frosted Card Surface
  static const Color cardBorder = Color(0xFFEAE0D5);         // Delicate Golden-Beige Card Border
  static const Color watermarkRing = Color(0xFFEADBCE);      // Orbital Concentric Arc Accent

  // Typography
  static const Color textObsidian = Color(0xFF0E1424);       // Midnight Obsidian Headline Text
  static const Color textMutedMocha = Color(0xFF59524A);     // Warm Mocha Body Copy
  static const Color accentBronze = Color(0xFF8C7A6B);       // Warm Bronze Shield, Brand & Skip
  
  // Step Indicator & Pills
  static const Color stepPillBg = Color(0xFFF9F5EE);         // 'STEP X OF 4' Pill Background
  static const Color stepPillBorder = Color(0xFFE6D9C8);     // 'STEP X OF 4' Pill Border
  static const Color activeDotNavy = Color(0xFF0E1424);      // Active Elongated Pill Dot
  static const Color inactiveDot = Color(0xFFD9CFC4);        // Inactive Round Dot

  // Action Buttons
  static const Color primaryObsidian = Color(0xFF0E1424);    // Primary Action Button Background
  static const Color buttonSparkle = Color(0xFFF1E3D3);      // Four-point Sparkle Star Accent
  static const Color backButtonBg = Color(0xFFFDFBF7);       // Outlined Back Button Background
  static const Color backButtonBorder = Color(0xFFD8C8B8);   // Outlined Back Button Border
  static const Color backButtonText = Color(0xFF7A6A5C);     // Outlined Back Button Text

  // Step 1: Scanner Highlights
  static const Color scanLaserCyan = Color(0xFF00E5FF);      // Cyan Laser Beam
  static const Color scanBracketGold = Color(0xFFC7A97B);    // Reticle Viewfinder Bracket Accent
  static const Color scanCardBg = Color(0xFFF9F6F0);         // Inner Mockup Card Background

  // Step 2: Red Cap & Sugar Splitting Badges
  static const Color safetyRed = Color(0xFFBA1A1A);          // Hard Red Cap & Toxic Warning
  static const Color safetyRedBg = Color(0xFFFDF2F2);        // Soft Rose Container
  static const Color safetyRedBorder = Color(0xFFF0B8B8);    // Rose Border
  static const Color sugarPeachBg = Color(0xFFFDF5EB);       // Sugar Splitting Peach Background
  static const Color sugarPeachBorder = Color(0xFFF5D6B8);   // Sugar Splitting Peach Border
  static const Color sugarPeachText = Color(0xFFC05621);     // Deep Orange Sugar Heading

  // Step 3: Safe Dosage Ceiling Badges
  static const Color profilePillBg = Color(0xFFF9F3EA);      // Active Profile Golden Pill
  static const Color profilePillBorder = Color(0xFFE5D3BD);  // Active Profile Golden Border
  static const Color ceilingCardBg = Color(0xFFFBF5EC);      // Safe Serving Ceiling Box
  static const Color ceilingCardBorder = Color(0xFFEADBC8);  // Ceiling Box Golden Border
  static const Color ceilingGoldText = Color(0xFF8A6D3B);    // Ceiling Label Bronze Gold
  static const Color progressTrack = Color(0xFFEDE4D8);      // ADI Limit Background Track

  // Step 4: Healthier Swaps Badges
  static const Color safetyMint = Color(0xFF137333);         // Clean Swap Dark Green Text
  static const Color safetyMintBg = Color(0xFFEBF7EE);       // Clean Swap Soft Mint Container
  static const Color safetyMintBorder = Color(0xFFB4E2BF);   // Clean Swap Mint Border
  static const Color aiAdvisorBg = Color(0xFFF5F0EB);        // AI Advisor Pill Background
  static const Color aiAdvisorText = Color(0xFF6B5E52);      // AI Advisor Muted Bronze Text

  // Backward-Compatible Aliases
  static const Color primaryPurple = primaryObsidian;
  static const Color darkPurple = textObsidian;
  static const Color lightPurple = stepPillBg;
  static const Color surfaceLavender = canvasCream;
  static const Color textDark = textObsidian;
  static const Color textMuted = textMutedMocha;
  static const Color accentViolet = scanBracketGold;
}

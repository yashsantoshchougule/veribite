import 'package:flutter/material.dart';

class QuickMacroSliderSheet extends StatefulWidget {
  final double initialSugar;
  final double initialSatFat;
  final double initialSodium;
  final ValueChanged<Map<String, double>> onSubmit;

  const QuickMacroSliderSheet({
    super.key,
    this.initialSugar = 10.0,
    this.initialSatFat = 5.0,
    this.initialSodium = 200.0,
    required this.onSubmit,
  });

  @override
  State<QuickMacroSliderSheet> createState() => _QuickMacroSliderSheetState();
}

class _QuickMacroSliderSheetState extends State<QuickMacroSliderSheet> {
  late double _sugar;
  late double _satFat;
  late double _sodium;

  @override
  void initState() {
    super.initState();
    _sugar = widget.initialSugar;
    _satFat = widget.initialSatFat;
    _sodium = widget.initialSodium;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF0F9D58)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Quick Macro Manual Input',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Label unreadable? Slide the 3 key macros to compute safe dosage:',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          // Sugar slider
          Text('Sugar: ${_sugar.toStringAsFixed(1)}g / 100g', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _sugar,
            min: 0.0,
            max: 50.0,
            divisions: 50,
            activeColor: const Color(0xFFE53935),
            label: '${_sugar.toStringAsFixed(1)}g',
            onChanged: (val) => setState(() => _sugar = val),
          ),
          // Saturated Fat slider
          Text('Saturated Fat: ${_satFat.toStringAsFixed(1)}g / 100g', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _satFat,
            min: 0.0,
            max: 30.0,
            divisions: 30,
            activeColor: const Color(0xFFFB8C00),
            label: '${_satFat.toStringAsFixed(1)}g',
            onChanged: (val) => setState(() => _satFat = val),
          ),
          // Sodium slider
          Text('Sodium: ${_sodium.round()}mg / 100g', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _sodium,
            min: 0.0,
            max: 1500.0,
            divisions: 30,
            activeColor: const Color(0xFF3949AB),
            label: '${_sodium.round()}mg',
            onChanged: (val) => setState(() => _sodium = val),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F9D58),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              widget.onSubmit({
                'sugar_g_per_100g': _sugar,
                'sat_fat_g_per_100g': _satFat,
                'sodium_mg_per_100g': _sodium,
              });
            },
            child: const Text(
              'Compute Health Score & Dosage',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class MultiAngleCaptureStrip extends StatelessWidget {
  final int capturedFramesCount;
  final int maxFrames;
  final VoidCallback onSubmit;
  final VoidCallback onClear;
  final bool isSubmitting;

  const MultiAngleCaptureStrip({
    super.key,
    required this.capturedFramesCount,
    this.maxFrames = 4,
    required this.onSubmit,
    required this.onClear,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Curved Bottle Multi-Angle Mode ($capturedFramesCount/$maxFrames)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (capturedFramesCount > 0)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(maxFrames, (index) {
              final isCaptured = index < capturedFramesCount;
              return Expanded(
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isCaptured ? const Color(0xFF0F9D58) : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCaptured ? Colors.white : Colors.white24,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isCaptured ? 'Slot ${index + 1}: Captured' : 'Slot ${index + 1}: Empty',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: isCaptured ? Colors.white : Colors.white54,
                        fontWeight: isCaptured ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: capturedFramesCount > 0 && !isSubmitting ? const Color(0xFF4285F4) : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: capturedFramesCount > 0 && !isSubmitting ? onSubmit : null,
              child: isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text('Analyzing Multi-Angle Frames...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    )
                  : const Text('Submit Multi-Angle Cloud Scan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

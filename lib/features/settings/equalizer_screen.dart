import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/audio_service.dart';

class EqualizerState {
  final bool isEnabled;
  final String preset;
  final List<double> gains; // 5 bands: 60Hz, 230Hz, 910Hz, 4kHz, 14kHz

  EqualizerState({
    required this.isEnabled,
    required this.preset,
    required this.gains,
  });

  EqualizerState copyWith({
    bool? isEnabled,
    String? preset,
    List<double>? gains,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      preset: preset ?? this.preset,
      gains: gains ?? this.gains,
    );
  }
}

class EqualizerNotifier extends StateNotifier<EqualizerState> {
  EqualizerNotifier()
      : super(EqualizerState(
          isEnabled: false,
          preset: 'Normal',
          gains: [0.0, 0.0, 0.0, 0.0, 0.0],
        ));

  static const Map<String, List<double>> presets = {
    'Normal': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Pop': [1.5, 2.5, 0.5, -1.0, -1.5],
    'Rock': [4.0, 2.5, -1.5, 2.0, 3.5],
    'Jazz': [3.0, 1.5, -2.0, 1.5, 2.5],
    'Classical': [3.5, 2.0, -1.5, -2.0, -3.0],
    'Bass Booster': [6.0, 4.5, 1.0, 0.0, 0.0],
  };

  void toggleEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
    _applyToNativeEqualizer(enabled, state.gains);
  }

  void selectPreset(String presetName) {
    if (presets.containsKey(presetName)) {
      state = state.copyWith(
        preset: presetName,
        gains: List<double>.from(presets[presetName]!),
      );
      _applyToNativeEqualizer(state.isEnabled, state.gains);
    }
  }

  void updateBandGain(int index, double gain) {
    final newGains = List<double>.from(state.gains);
    newGains[index] = gain.clamp(-10.0, 10.0);
    state = state.copyWith(
      gains: newGains,
      preset: 'Custom',
    );
    _applyToNativeEqualizer(state.isEnabled, newGains);
  }

  Future<void> _applyToNativeEqualizer(bool enabled, List<double> gains) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final eq = (audioHandler as BeatFlowAudioHandler).equalizer;
      if (eq != null) {
        await eq.setEnabled(enabled);
        if (enabled) {
          final params = await eq.parameters;
          final bands = params.bands;
          for (int i = 0; i < bands.length && i < gains.length; i++) {
            final band = bands[i];
            await band.setGain(gains[i]);
          }
        }
      }
    } catch (e) {
      print('Error applying settings to native equalizer: $e');
    }
  }
}

final equalizerProvider = StateNotifierProvider<EqualizerNotifier, EqualizerState>((ref) {
  return EqualizerNotifier();
});

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);

    final List<String> bandLabels = [
      '60Hz\nBass',
      '230Hz\nMid-Bass',
      '910Hz\nMids',
      '4kHz\nPresence',
      '14kHz\nBrilliance',
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: NeumorphicBox(
                      shape: BoxShape.circle,
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back, size: 22, color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Equalizer Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enable/Disable Section
                    NeumorphicBox(
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audio Equalizer',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                eqState.isEnabled ? 'Active and processing audio' : 'Inactive, using raw stream',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: eqState.isEnabled,
                            onChanged: eqNotifier.toggleEnabled,
                            activeColor: AppTheme.textPrimary,
                            activeTrackColor: AppTheme.shadowDark,
                            inactiveThumbColor: AppTheme.textSecondary,
                            inactiveTrackColor: AppTheme.shadowDark.withOpacity(0.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Visualizer Wave Simulation
                    if (eqState.isEnabled)
                      _buildVisualizer(eqState.gains)
                    else
                      Container(
                        height: 80,
                        alignment: Alignment.center,
                        child: Text(
                          'Enable Equalizer to view audio response curve',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Sliders Section
                    Text(
                      'Frequency Bands',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    NeumorphicBox(
                      borderRadius: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(5, (index) {
                          final gainValue = eqState.gains[index];
                          return Opacity(
                            opacity: eqState.isEnabled ? 1.0 : 0.4,
                            child: Column(
                              children: [
                                Text(
                                  '${gainValue > 0 ? "+" : ""}${gainValue.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: eqState.isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 170,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: AppTheme.textPrimary,
                                        inactiveTrackColor: AppTheme.shadowDark,
                                        thumbColor: AppTheme.textPrimary,
                                        overlayColor: AppTheme.textPrimary.withOpacity(0.12),
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                      ),
                                      child: Slider(
                                        value: gainValue,
                                        min: -10.0,
                                        max: 10.0,
                                        onChanged: eqState.isEnabled
                                            ? (val) {
                                                eqNotifier.updateBandGain(index, val);
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  bandLabels[index],
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Presets Section
                    Text(
                      'Sound Presets',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    Opacity(
                      opacity: eqState.isEnabled ? 1.0 : 0.4,
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.2,
                        children: EqualizerNotifier.presets.keys.map((presetName) {
                          final isSelected = eqState.preset == presetName;
                          return GestureDetector(
                            onTap: eqState.isEnabled
                                ? () => eqNotifier.selectPreset(presetName)
                                : null,
                            child: NeumorphicBox(
                              style: isSelected ? NeumorphicStyle.pressed : NeumorphicStyle.flat,
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              alignment: Alignment.center,
                              child: Text(
                                presetName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizer(List<double> gains) {
    return NeumorphicBox(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 80,
      style: NeumorphicStyle.pressed,
      child: CustomPaint(
        size: const Size(double.infinity, 80),
        painter: EqualizerVisualizerPainter(gains: gains),
      ),
    );
  }
}

class EqualizerVisualizerPainter extends CustomPainter {
  final List<double> gains;

  EqualizerVisualizerPainter({required this.gains});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepWidth = size.width / 4;
    final centerHeight = size.height / 2;

    // Start of the path
    path.moveTo(0, centerHeight - (gains[0] * 3));

    for (int i = 0; i < 4; i++) {
      final x1 = (i * stepWidth) + (stepWidth / 2);
      final y1 = centerHeight - (gains[i] * 3);
      final x2 = (i + 1) * stepWidth;
      final y2 = centerHeight - (gains[i + 1] * 3);

      path.quadraticBezierTo(x1, y1, x2, y2);
    }

    canvas.drawPath(path, paint);

    // Draw grid lines for premium aesthetic
    final gridPaint = Paint()
      ..color = AppTheme.shadowDark.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw horizontal reference lines
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, centerHeight), Offset(size.width, centerHeight), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);
  }

  @override
  bool shouldRepaint(covariant EqualizerVisualizerPainter oldDelegate) {
    return oldDelegate.gains != gains;
  }
}

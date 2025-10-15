// lib/ui/screens/settings_screen.dart
// 접근성/시스템 설정을 즉시 반영. SharedPreferences 저장.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/models/settings_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.locale == 'ko' ? '설정' : 'Settings'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/calibration'),
            icon: const Icon(Icons.center_focus_strong),
            tooltip: s.locale == 'ko' ? '보정 다시하기' : 'Recalibrate',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/editor'),
            icon: const Icon(Icons.dashboard_customize),
            tooltip: s.locale == 'ko' ? '보드 편집' : 'Edit Board',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(s.locale == 'ko' ? '응시' : 'Dwell'),
          _slider(
            label: s.locale == 'ko' ? '응시 시간: ${s.dwellMs}ms' : 'Dwell: ${s.dwellMs}ms',
            value: s.dwellMs.toDouble(),
            min: 600,
            max: 3000,
            onChanged: (v) {
              s.dwellMs = v.round();
              SettingsScope.save(context);
            },
          ),
          _sectionTitle(s.locale == 'ko' ? '커서' : 'Cursor'),
          _slider(
            label: s.locale == 'ko' ? '크기: ${s.cursorSize.toStringAsFixed(0)}' : 'Size: ${s.cursorSize.toStringAsFixed(0)}',
            value: s.cursorSize,
            min: 16,
            max: 80,
            onChanged: (v) {
              s.cursorSize = v;
              SettingsScope.save(context);
            },
          ),
          ListTile(
            title: Text(s.locale == 'ko' ? '고대비' : 'High Contrast'),
            trailing: Switch(value: s.highContrast, onChanged: (v) { s.highContrast = v; SettingsScope.save(context); }),
          ),
          _slider(
            label: s.locale == 'ko' ? '글자 크기: ${s.fontScale.toStringAsFixed(1)}' : 'Font: ${s.fontScale.toStringAsFixed(1)}',
            value: s.fontScale,
            min: 1.0,
            max: 1.8,
            onChanged: (v) { s.fontScale = v; SettingsScope.save(context); },
          ),
          SwitchListTile(
            title: Text(s.locale == 'ko' ? '다크 모드' : 'Dark Mode'),
            value: s.darkMode,
            onChanged: (v) { s.darkMode = v; SettingsScope.save(context); },
          ),
          _sectionTitle('TTS'),
          _slider(
            label: s.locale == 'ko' ? '속도: ${s.ttsRate.toStringAsFixed(2)}' : 'Rate: ${s.ttsRate.toStringAsFixed(2)}',
            value: s.ttsRate,
            min: 0.1,
            max: 1.0,
            onChanged: (v) { s.ttsRate = v; SettingsScope.save(context); },
          ),
          _slider(
            label: s.locale == 'ko' ? '피치: ${s.ttsPitch.toStringAsFixed(2)}' : 'Pitch: ${s.ttsPitch.toStringAsFixed(2)}',
            value: s.ttsPitch,
            min: 0.5,
            max: 2.0,
            onChanged: (v) { s.ttsPitch = v; SettingsScope.save(context); },
          ),
          ListTile(
            title: Text(s.locale == 'ko' ? '모의 시선 사용' : 'Use Mock Gaze'),
            trailing: Switch(value: s.mockGaze, onChanged: (v) { s.mockGaze = v; SettingsScope.save(context); }),
            subtitle: Text(s.locale == 'ko' ? '꺼짐: 온디바이스 추론(안드로이드)' : 'Off: On-device inference (Android)'),
          ),
          SwitchListTile(
            title: Text(s.locale == 'ko' ? '시선 읽어주기(실시간)' : 'Realtime gaze readout'),
            subtitle: Text(s.locale == 'ko' ? '가리키는 카드/좌표를 주기적으로 발화' : 'Speak hovered card or coordinates periodically'),
            value: s.gazeReadout,
            onChanged: (v) { s.gazeReadout = v; SettingsScope.save(context); },
          ),
          _sectionTitle('SOS'),
          DropdownButtonFormField<SosMode>(
            value: s.sosMode,
            items: SosMode.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
            onChanged: (m) { if (m != null) { s.sosMode = m; SettingsScope.save(context); }},
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/calibration'),
            icon: const Icon(Icons.center_focus_strong),
            label: Text(s.locale == 'ko' ? '보정 다시하기' : 'Recalibration'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      );

  Widget _slider({required String label, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

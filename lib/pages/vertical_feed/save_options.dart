import 'package:PiliPlus/models/common/video/save_quality.dart';
import 'package:material_ui/material_ui.dart';

enum SaveMediaType { video, audio }

enum SaveAudioFormat {
  copy('原音质'),
  m4a('M4A'),
  mp3('MP3');

  const SaveAudioFormat(this.label);
  final String label;
}

enum AudioEffect {
  none('无效果'),
  battle('战损'),
  telephone('电话音'),
  vinyl('留声机');

  const AudioEffect(this.label);
  final String label;
}

class SaveOptions {
  const SaveOptions({
    required this.mediaType,
    required this.qn,
    required this.saveCover,
    this.mode = SaveVideoQuality.high,
    this.audioFormat = SaveAudioFormat.copy,
    this.effect = AudioEffect.none,
  });

  final SaveMediaType mediaType;
  final int qn;
  final bool saveCover;
  final SaveVideoQuality mode;
  final SaveAudioFormat audioFormat;
  final AudioEffect effect;
}

Future<SaveOptions?> showSaveOptions(BuildContext context) {
  return showModalBottomSheet<SaveOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF17181A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _SaveOptionsSheet(),
  );
}

class _SaveOptionsSheet extends StatefulWidget {
  const _SaveOptionsSheet();

  @override
  State<_SaveOptionsSheet> createState() => _SaveOptionsSheetState();
}

class _SaveOptionsSheetState extends State<_SaveOptionsSheet> {
  SaveMediaType _type = SaveMediaType.video;
  int _qn = 120;
  bool _saveCover = false;
  SaveVideoQuality _mode = SaveVideoQuality.high;
  SaveAudioFormat _audioFormat = SaveAudioFormat.copy;
  AudioEffect _effect = AudioEffect.none;

  static const _qualities = [
    (qn: 120, label: '最高画质'),
    (qn: 80, label: '1080P'),
    (qn: 64, label: '720P'),
    (qn: 32, label: '480P'),
    (qn: 16, label: '360P'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                '下载前设置',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '下载类型',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeButton('视频', SaveMediaType.video),
                const SizedBox(width: 8),
                _typeButton('音频', SaveMediaType.audio),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              '下载方式',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in SaveVideoQuality.values)
                  _chip(
                    item.label,
                    _mode == item,
                    () => setState(() => _mode = item),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              '视频画质',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _qualities)
                  _chip(
                    item.label,
                    _qn == item.qn,
                    () => setState(() => _qn = item.qn),
                  ),
              ],
            ),
            if (_type == SaveMediaType.audio) ...[
              const SizedBox(height: 18),
              const Text(
                '音频格式',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in SaveAudioFormat.values)
                    _chip(
                      item.label,
                      _audioFormat == item,
                      () => setState(() => _audioFormat = item),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              '音频效果',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in AudioEffect.values)
                  _chip(
                    item.label,
                    _effect == item,
                    () => setState(() => _effect = item),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveCover,
              activeColor: primary,
              onChanged: (value) => setState(() => _saveCover = value),
              title: const Text(
                '同时保存封面',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.pop(
                  context,
                  SaveOptions(
                    mediaType: _type,
                    qn: _qn,
                    saveCover: _saveCover,
                    mode: _mode,
                    audioFormat: _audioFormat,
                    effect: _effect,
                  ),
                ),
                child: const Text('开始下载'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String text, SaveMediaType type) {
    final selected = _type == type;
    final primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _type = type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.16)
                : Colors.white10,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? primary : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? primary : Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primary : Colors.white24,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? primary : Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

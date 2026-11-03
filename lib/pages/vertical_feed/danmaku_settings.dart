import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showVerticalDanmakuSettings(
  BuildContext context, {
  required bool enabled,
  required ValueChanged<bool> onToggle,
  required VoidCallback onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF17181A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: _VerticalDanmakuSettings(
        enabled: enabled,
        onToggle: onToggle,
        onApply: onApply,
      ),
    ),
  );
}

class _VerticalDanmakuSettings extends StatefulWidget {
  const _VerticalDanmakuSettings({
    required this.enabled,
    required this.onToggle,
    required this.onApply,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onApply;

  @override
  State<_VerticalDanmakuSettings> createState() =>
      _VerticalDanmakuSettingsState();
}

class _VerticalDanmakuSettingsState extends State<_VerticalDanmakuSettings> {
  late bool _enabled = widget.enabled;
  late double _opacity = Pref.danmakuOpacity;

  static const _blockTypes = [
    (value: 2, label: '滚动'),
    (value: 5, label: '顶部'),
    (value: 4, label: '底部'),
    (value: 6, label: '彩色'),
    (value: 7, label: '高级'),
  ];

  @override
  void dispose() {
    DanmakuOptions.save(_opacity);
    super.dispose();
  }

  void _apply() {
    setState(() {});
    widget.onApply();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            '弹幕设置',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '显示弹幕',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                value: _enabled,
                activeColor: primary,
                onChanged: (value) {
                  setState(() => _enabled = value);
                  widget.onToggle(value);
                },
              ),
              _slider(
                '智能云屏蔽 ${DanmakuOptions.danmakuWeight} 级',
                DanmakuOptions.danmakuWeight.toDouble(),
                0,
                11,
                11,
                (v) => _applySet(() {
                  DanmakuOptions.danmakuWeight = v.round();
                }),
              ),
              const Text(
                '按类型屏蔽',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in _blockTypes)
                    _chip(
                      item.label,
                      DanmakuOptions.blockTypes.contains(item.value),
                      () {
                        if (DanmakuOptions.blockTypes.contains(item.value)) {
                          DanmakuOptions.blockTypes.remove(item.value);
                        } else {
                          DanmakuOptions.blockTypes.add(item.value);
                        }
                        DanmakuOptions.blockColorful =
                            DanmakuOptions.blockTypes.contains(6);
                        _apply();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('海量弹幕', DanmakuOptions.danmakuMassiveMode, () {
                    DanmakuOptions.danmakuMassiveMode =
                        !DanmakuOptions.danmakuMassiveMode;
                    _apply();
                  }),
                  _chip('固定转滚动', DanmakuOptions.danmakuStatic2Scroll, () {
                    DanmakuOptions.danmakuStatic2Scroll =
                        !DanmakuOptions.danmakuStatic2Scroll;
                    _apply();
                  }),
                  _chip('固定滚动速度', DanmakuOptions.danmakuFixedV, () {
                    DanmakuOptions.danmakuFixedV =
                        !DanmakuOptions.danmakuFixedV;
                    _apply();
                  }),
                ],
              ),
              _slider(
                '不透明度 ${(_opacity * 100).toStringAsFixed(0)}%',
                _opacity,
                0.2,
                1,
                8,
                (v) => _applySet(() => _opacity = v),
              ),
              _slider(
                '显示区域 ${(DanmakuOptions.danmakuShowArea * 100).toStringAsFixed(1)}%',
                DanmakuOptions.danmakuShowArea,
                0.1,
                1,
                9,
                (v) => _applySet(() => DanmakuOptions.danmakuShowArea = v),
              ),
              _slider(
                '字体大小 ${(DanmakuOptions.danmakuFontScale * 100).toStringAsFixed(0)}%',
                DanmakuOptions.danmakuFontScale,
                0.5,
                2,
                15,
                (v) => _applySet(() => DanmakuOptions.danmakuFontScale = v),
              ),
              _slider(
                '滚动弹幕时长 ${DanmakuOptions.danmakuDuration.toStringAsFixed(1)} 秒',
                DanmakuOptions.danmakuDuration,
                3,
                12,
                18,
                (v) => _applySet(() => DanmakuOptions.danmakuDuration = v),
              ),
              _slider(
                '静态弹幕时长 ${DanmakuOptions.danmakuStaticDuration.toStringAsFixed(1)} 秒',
                DanmakuOptions.danmakuStaticDuration,
                1,
                8,
                14,
                (v) => _applySet(() => DanmakuOptions.danmakuStaticDuration = v),
              ),
              _slider(
                '弹幕行高 ${DanmakuOptions.danmakuLineHeight.toStringAsFixed(1)}',
                DanmakuOptions.danmakuLineHeight,
                1,
                2,
                10,
                (v) => _applySet(() => DanmakuOptions.danmakuLineHeight = v),
              ),
              _slider(
                '描边粗细 ${DanmakuOptions.danmakuStrokeWidth.toStringAsFixed(1)}',
                DanmakuOptions.danmakuStrokeWidth,
                0,
                3,
                12,
                (v) => _applySet(() => DanmakuOptions.danmakuStrokeWidth = v),
              ),
              _slider(
                '字体粗细 ${DanmakuOptions.danmakuFontWeight}',
                DanmakuOptions.danmakuFontWeight.toDouble(),
                1,
                9,
                8,
                (v) => _applySet(() => DanmakuOptions.danmakuFontWeight = v.round()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _applySet(VoidCallback set) {
    set();
    _apply();
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

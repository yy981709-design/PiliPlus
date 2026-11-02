import 'package:material_ui/material_ui.dart';

class DanmakuDraft {
  final String text;
  final int color;
  final int mode;
  final int fontSize;

  const DanmakuDraft({
    required this.text,
    required this.color,
    required this.mode,
    required this.fontSize,
  });
}

Future<DanmakuDraft?> showDanmakuComposer(BuildContext context) {
  return showModalBottomSheet<DanmakuDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF7F7F8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const _DanmakuComposer(),
  );
}

class _DanmakuComposer extends StatefulWidget {
  const _DanmakuComposer();

  @override
  State<_DanmakuComposer> createState() => _DanmakuComposerState();
}

class _DanmakuComposerState extends State<_DanmakuComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _advanced = false;
  bool _small = false;
  bool _top = false;
  int _color = 0xFFFFFF;

  static const _colors = [
    0xFFFFFF,
    0xFF0000,
    0xFFD700,
    0x00B34A,
    0x00A1D6,
    0xFF69B4,
    0x9ACD32,
    0x1E3A8A,
    0xFF8C00,
    0x800080,
    0x40E0D0,
    0x8B4513,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      DanmakuDraft(
        text: text,
        color: _color,
        mode: _top ? 5 : 1,
        fontSize: _small ? 18 : 25,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _advanced = !_advanced),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _advanced
                          ? primary.withValues(alpha: 0.16)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: _advanced ? primary : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: 100,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '发个友善的弹幕见证当下',
                      hintStyle: const TextStyle(color: Colors.black38),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(19),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _send,
                  icon: Icon(Icons.send, color: primary),
                ),
              ],
            ),
            if (_advanced) ...[
              const SizedBox(height: 14),
              _row(
                '字体大小',
                [
                  _chip('默认', !_small, () => setState(() => _small = false)),
                  _chip('较小', _small, () => setState(() => _small = true)),
                ],
              ),
              const SizedBox(height: 12),
              _row(
                '弹幕位置',
                [
                  _chip('滚动', !_top, () => setState(() => _top = false)),
                  _chip('置顶', _top, () => setState(() => _top = true)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 72,
                    child: Text(
                      '弹幕颜色',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (final color in _colors)
                          InkWell(
                            onTap: () => setState(() => _color = color),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(0xFF000000 | color),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _color == color
                                      ? primary
                                      : Colors.black12,
                                  width: _color == color ? 2 : 1,
                                ),
                              ),
                              child: _color == color
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '预览：[我是弹幕] ${_controller.text}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, List<Widget> children) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? primary : Colors.black12,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? primary : Colors.black54,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

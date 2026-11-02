import 'dart:convert';

import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

class _VideoNote {
  final int seconds;
  final String text;
  final int createdAt;

  const _VideoNote(this.seconds, this.text, this.createdAt);
}

void showVideoNotesSheet(
  BuildContext context, {
  required String bvid,
  required Player player,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF17181A),
    builder: (context) => _VideoNotesSheet(bvid: bvid, player: player),
  );
}

class _VideoNotesSheet extends StatefulWidget {
  const _VideoNotesSheet({required this.bvid, required this.player});

  final String bvid;
  final Player player;

  @override
  State<_VideoNotesSheet> createState() => _VideoNotesSheetState();
}

class _VideoNotesSheetState extends State<_VideoNotesSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<_VideoNote> _notes = [];
  late final String _key = 'videoNote:${widget.bvid}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    try {
      final raw = GStorage.setting.get(_key);
      if (raw is String && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          if (item is Map) {
            _notes.add(
              _VideoNote(
                item['seconds'] as int? ?? 0,
                item['text'] as String? ?? '',
                item['createdAt'] as int? ?? 0,
              ),
            );
          }
        }
        _notes.sort((a, b) => a.seconds.compareTo(b.seconds));
      }
    } catch (_) {}
  }

  void _save() {
    try {
      GStorage.setting.put(
        _key,
        jsonEncode([
          for (final note in _notes)
            {
              'seconds': note.seconds,
              'text': note.text,
              'createdAt': note.createdAt,
            },
        ]),
      );
    } catch (_) {}
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final seconds = widget.player.state.position.inSeconds;
    setState(() {
      _notes.add(
        _VideoNote(seconds, text, DateTime.now().millisecondsSinceEpoch),
      );
      _notes.sort((a, b) => a.seconds.compareTo(b.seconds));
      _controller.clear();
    });
    _save();
    SmartDialog.showToast('已记录 ${_time(seconds)}');
  }

  String _time(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  '时间戳笔记',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '当前 ${_time(widget.player.state.position.inSeconds)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '记下这一秒的想法...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _add,
                  icon: const Icon(Icons.add_circle, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: _notes.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有笔记',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            widget.player.seek(
                              Duration(seconds: note.seconds),
                            );
                            Navigator.pop(context);
                          },
                          leading: Text(
                            _time(note.seconds),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                            ),
                          ),
                          title: Text(
                            note.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setState(() => _notes.removeAt(index));
                              _save();
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white38,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

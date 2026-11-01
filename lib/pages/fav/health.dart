import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void showFavHealthSheet(BuildContext context, List<FavFolderInfo> folders) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF17181A),
    isScrollControlled: true,
    builder: (context) => _FavHealthSheet(folders: folders),
  );
}

class _FavHealthSheet extends StatefulWidget {
  const _FavHealthSheet({required this.folders});

  final List<FavFolderInfo> folders;

  @override
  State<_FavHealthSheet> createState() => _FavHealthSheetState();
}

class _FavHealthSheetState extends State<_FavHealthSheet> {
  bool _running = false;
  bool _scanning = false;
  final Map<int, ({int sampled, int invalid, int duplicate})> _stats = {};

  @override
  void initState() {
    super.initState();
    _scanAll();
  }

  Future<void> _scan(FavFolderInfo folder) async {
    final res = await FavHttp.userFavFolderDetail(
      mediaId: folder.id,
      pn: 1,
      ps: 20,
    );
    if (res case Success(:final response)) {
      final medias = response.medias ?? const [];
      final seen = <String>{};
      var invalid = 0;
      var duplicate = 0;
      for (final item in medias) {
        final title = item.title ?? '';
        if (title.isEmpty || title.contains('已失效')) invalid++;
        final key = item.bvid ?? item.id?.toString() ?? '';
        if (key.isNotEmpty && !seen.add(key)) duplicate++;
      }
      _stats[folder.id] = (
        sampled: medias.length,
        invalid: invalid,
        duplicate: duplicate,
      );
    }
  }

  Future<void> _scanAll() async {
    if (_scanning) return;
    _scanning = true;
    if (mounted) setState(() {});
    for (final folder in widget.folders) {
      await _scan(folder);
    }
    _scanning = false;
    if (mounted) setState(() {});
  }

  Future<void> _clean(FavFolderInfo folder) async {
    if (_running) return;
    _running = true;
    setState(() {});
    final res = await FavHttp.cleanFav(mediaId: folder.id);
    await _scan(folder);
    _running = false;
    if (mounted) setState(() {});
    SmartDialog.showToast(
      res.isSuccess ? '「${folder.title}」清理完成' : '清理失败：${res.toString()}',
    );
  }

  Future<void> _cleanAll() async {
    if (_running) return;
    _running = true;
    setState(() {});
    var ok = 0;
    for (final folder in widget.folders) {
      final res = await FavHttp.cleanFav(mediaId: folder.id);
      if (res.isSuccess) ok++;
    }
    _running = false;
    if (mounted) setState(() {});
    SmartDialog.showToast('已清理 $ok/${widget.folders.length} 个收藏夹');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  '收藏夹体检',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '重新扫描',
                  onPressed: _scanning ? null : _scanAll,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
                TextButton(
                  onPressed: _running ? null : _cleanAll,
                  child: const Text('一键清理'),
                ),
              ],
            ),
            Text(
              '共 ${widget.folders.length} 个收藏夹 · 抽样 ${_stats.values.fold<int>(0, (sum, e) => sum + e.sampled)} 个内容\n'
              '发现 ${_stats.values.fold<int>(0, (sum, e) => sum + e.invalid)} 个失效、'
              '${_stats.values.fold<int>(0, (sum, e) => sum + e.duplicate)} 个重复',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.folders.length,
                itemBuilder: (context, index) {
                  final folder = widget.folders[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      folder.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _stats[folder.id] == null
                          ? '${folder.mediaCount} 个内容 · 扫描中...'
                          : '${folder.mediaCount} 个内容 · 失效 ${_stats[folder.id]!.invalid} · 重复 ${_stats[folder.id]!.duplicate}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: TextButton(
                      onPressed: _running ? null : () => _clean(folder),
                      child: const Text('体检清理'),
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

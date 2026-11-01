import 'package:PiliPlus/http/fav.dart';
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

  Future<void> _clean(FavFolderInfo folder) async {
    if (_running) return;
    _running = true;
    setState(() {});
    final res = await FavHttp.cleanFav(mediaId: folder.id);
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
                TextButton(
                  onPressed: _running ? null : _cleanAll,
                  child: const Text('一键清理'),
                ),
              ],
            ),
            const Text(
              '清理收藏夹内已失效的视频，不会删除正常视频。',
              style: TextStyle(color: Colors.white54, fontSize: 12),
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
                      '${folder.mediaCount} 个内容',
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

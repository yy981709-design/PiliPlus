import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class VerticalFeedPage extends StatefulWidget {
  const VerticalFeedPage({super.key});

  @override
  State<VerticalFeedPage> createState() => _VerticalFeedPageState();
}

class _VerticalFeedPageState extends State<VerticalFeedPage> {
  final List<_VerticalItem> _items = [];
  final PageController _pageController = PageController();
  bool _loading = false;
  bool _loaded = false;
  int _page = 0;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      final bvid = args['bvid'] as String?;
      final cid = args['cid'] as int?;
      if (bvid != null && bvid.isNotEmpty && cid != null && cid > 0) {
        _items.add(
          _VerticalItem(
            bvid: bvid,
            cid: cid,
            title: args['title'] as String? ?? '',
            cover: args['cover'] as String? ?? '',
            author: '',
          ),
        );
      }
    }
    _fetchMore();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMore() async {
    if (_loading) return;
    _loading = true;
    try {
      for (var i = 0; i < 3; i++) {
        final res = await VideoHttp.rcmdVideoListApp(freshIdx: _page);
        _page++;
        if (res case Success(:final response)) {
          for (final item in response) {
            if (item.uri?.isVerticalFromUri != true) continue;
            final bvid = item.bvid;
            final cid = item.cid;
            if (bvid == null || bvid.isEmpty || cid == null || cid <= 0) {
              continue;
            }
            if (_items.any((e) => e.bvid == bvid && e.cid == cid)) continue;
            _items.add(
              _VerticalItem(
                bvid: bvid,
                cid: cid,
                title: item.title ?? '',
                cover: item.cover ?? '',
                author: item.owner?.name ?? '',
              ),
            );
          }
        }
        if (_items.length >= 12) break;
      }
    } catch (_) {}
    _loading = false;
    _loaded = true;
    if (mounted) setState(() {});
  }

  void _open(_VerticalItem item) {
    PageUtils.toVideoPage(
      bvid: item.bvid,
      cid: item.cid,
      cover: item.cover,
      title: item.title,
      isVertical: true,
      extraArguments: const {'noVerticalFeed': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('竖屏'),
        actions: [
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_index + 1}/${_items.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: _loaded
                  ? const Text(
                      '暂无竖屏视频',
                      style: TextStyle(color: Colors.white70),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            )
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _items.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                if (index >= _items.length - 2) _fetchMore();
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return GestureDetector(
                  onTap: () => _open(item),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkImgLayer(
                        src: item.cover,
                        width: size.width,
                        height: size.height,
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black54,
                            ],
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 64,
                          color: Colors.white70,
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 56,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            if (item.author.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                item.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _VerticalItem {
  final String bvid;
  final int cid;
  final String title;
  final String cover;
  final String author;

  const _VerticalItem({
    required this.bvid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.author,
  });
}

import 'dart:async';

import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/share_utils.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
            view: 0,
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
                view: item.stat?.view ?? 0,
              ),
            );
          }
        }
        if (_items.length >= 10) break;
      }
    } catch (_) {}
    _loading = false;
    _loaded = true;
    if (mounted) setState(() {});
  }

  void _next() {
    if (_index + 1 >= _items.length) {
      _fetchMore();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                return _VerticalPlayerItem(
                  key: ValueKey('${_items[index].bvid}_${_items[index].cid}'),
                  item: _items[index],
                  active: index == _index,
                  onCompleted: _next,
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
  final int view;

  const _VerticalItem({
    required this.bvid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.author,
    required this.view,
  });
}

class _VerticalPlayerItem extends StatefulWidget {
  const _VerticalPlayerItem({
    super.key,
    required this.item,
    required this.active,
    required this.onCompleted,
  });

  final _VerticalItem item;
  final bool active;
  final VoidCallback onCompleted;

  @override
  State<_VerticalPlayerItem> createState() => _VerticalPlayerItemState();
}

class _VerticalPlayerItemState extends State<_VerticalPlayerItem> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<bool>? _completedSub;
  bool _loading = false;
  bool _liked = false;
  bool _disliked = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initPlayer();
  }

  @override
  void didUpdateWidget(covariant _VerticalPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (_player == null) {
        _initPlayer();
      } else {
        _player!.play();
      }
    } else if (!widget.active && oldWidget.active) {
      _player?.pause();
    }
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    if (_loading || _player != null) return;
    _loading = true;
    try {
      final mediaUrl = await _resolveMediaUrl(widget.item);
      if (mediaUrl == null || !mounted || !widget.active) {
        _loading = false;
        return;
      }
      final player = await Player.create();
      final controller = await VideoController.create(player);
      player.setMediaHeader(
        userAgent: BrowserUa.pc,
        referer: HttpString.baseUrl,
      );
      await player.open(Media(mediaUrl), play: true);
      _completedSub = player.stream.completed.listen((completed) {
        if (completed && mounted && widget.active) widget.onCompleted();
      });
      if (!mounted) {
        player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _videoController = controller;
      });
    } catch (e) {
      if (mounted) {
        SmartDialog.showToast('加载失败：$e');
      }
    }
    _loading = false;
  }

  Future<String?> _resolveMediaUrl(_VerticalItem item) async {
    final res = await VideoHttp.videoUrl(
      bvid: item.bvid,
      cid: item.cid,
      qn: 64,
      tryLook: true,
      videoType: VideoType.ugc,
    );
    if (res case Success(:final response)) {
      final dash = response.dash;
      final videos = dash?.video;
      if (videos != null && videos.isNotEmpty) {
        final video = VideoUtils.getCdnUrl(videos.first.playUrls);
        final audios = dash?.audio;
        final audio = audios != null && audios.isNotEmpty
            ? VideoUtils.getCdnUrl(audios.first.playUrls, isAudio: true)
            : null;
        if (audio != null) {
          return 'edl://!no_chapters;%${video.length}%$video;'
              '!new_stream;!no_chapters;%${audio.length}%$audio';
        }
        return video;
      }
      final durl = response.durl;
      if (durl != null && durl.isNotEmpty) {
        final first = durl.first;
        final urls = <String>[
          if (first.url?.isNotEmpty == true) first.url!,
          ...?first.backupUrl,
        ];
        if (urls.isNotEmpty) return VideoUtils.getCdnUrl(urls);
      }
    }
    return null;
  }

  Future<void> _toggleLike() async {
    final res = await VideoHttp.likeVideo(
      bvid: widget.item.bvid,
      type: _liked,
    );
    if (res case Success(:final response)) {
      setState(() => _liked = !_liked);
      SmartDialog.showToast(response);
    } else {
      SmartDialog.showToast('点赞失败');
    }
  }

  Future<void> _toggleDislike() async {
    final res = await VideoHttp.dislikeVideo(
      bvid: widget.item.bvid,
      type: _disliked,
    );
    if (res.isSuccess) {
      setState(() => _disliked = !_disliked);
    } else {
      SmartDialog.showToast('操作失败');
    }
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) {
      _initPlayer();
    } else {
      player.playOrPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final size = MediaQuery.sizeOf(context);
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController != null)
            Video(
              controller: _videoController!,
              fit: BoxFit.contain,
              controls: (state) => const SizedBox.shrink(),
            )
          else
            Image.network(
              item.cover,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.black,
                child: SizedBox.expand(),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: MediaQuery.paddingOf(context).top + 8,
            child: IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
          ),
          if (!widget.active || _loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            right: 10,
            bottom: 190,
            child: Column(
              children: [
                _action(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  label: '点赞',
                  active: _liked,
                  onTap: _toggleLike,
                ),
                _action(
                  icon: Icons.chat_bubble_outline,
                  label: '评论',
                  onTap: () => SmartDialog.showToast('评论面板下一步接入'),
                ),
                _action(
                  icon: _disliked ? Icons.block : Icons.do_not_disturb_alt,
                  label: '不喜欢',
                  active: _disliked,
                  onTap: _toggleDislike,
                ),
                _action(
                  icon: Icons.star_border,
                  label: '收藏',
                  onTap: () => SmartDialog.showToast('收藏下一步接入'),
                ),
                _action(
                  icon: Icons.share_outlined,
                  label: '分享',
                  onTap: () => ShareUtils.shareText(
                    'https://www.bilibili.com/video/${item.bvid}',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 80,
            bottom: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.author.isEmpty ? 'UP 主' : item.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => SmartDialog.showToast('关注下一步接入'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('关注', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                if (item.view > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${item.view} 播放',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 46,
          child: Column(
            children: [
              Icon(
                icon,
                color: active ? const Color(0xFFFF6699) : Colors.white,
                size: 28,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

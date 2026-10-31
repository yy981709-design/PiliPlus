import 'dart:ui' show ImageFilter;

import 'dart:async';

import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/reply.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models_new/reply/data.dart';
import 'package:PiliPlus/models_new/reply/reply.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/date_utils.dart';
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
            aid: args['aid'] as int? ?? 0,
            mid: args['mid'] as int? ?? 0,
            bvid: bvid,
            cid: cid,
            title: args['title'] as String? ?? '',
            cover: args['cover'] as String? ?? '',
            author: '',
            view: 0,
            like: 0,
            pubdate: args['pubdate'] as int? ?? 0,
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
                aid: item.aid ?? 0,
                mid: item.owner?.mid ?? 0,
                bvid: bvid,
                cid: cid,
                title: item.title ?? '',
                cover: item.cover ?? '',
                author: item.owner?.name ?? '',
                view: item.stat?.view ?? 0,
                like: item.stat?.like ?? 0,
                pubdate: item.pubdate ?? 0,
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
  final int aid;
  final int mid;
  final String bvid;
  final int cid;
  final String title;
  final String cover;
  final String author;
  final int view;
  final int like;
  final int pubdate;

  const _VerticalItem({
    required this.aid,
    required this.mid,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.author,
    required this.view,
    required this.like,
    required this.pubdate,
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
  bool _statsLoading = false;
  int? _likeCount;
  int? _commentCount;
  int? _favoriteCount;
  int? _shareCount;
  int? _viewCount;
  String? _avatar;
  bool _followed = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initPlayer();
    _loadStats();
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

  Future<void> _loadStats() async {
    if (_statsLoading) return;
    _statsLoading = true;
    try {
      final res = await VideoHttp.videoIntro(bvid: widget.item.bvid);
      if (res case Success(:final response)) {
        final stat = response.stat;
        if (stat != null && mounted) {
          setState(() {
            _viewCount = stat.view;
            _likeCount = stat.like;
            _commentCount = stat.reply;
            _favoriteCount = stat.favorite;
            _shareCount = stat.share;
            _avatar = response.owner?.face;
          });
        }
      }
    } catch (_) {}
    _statsLoading = false;
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

  Future<void> _follow() async {
    if (_followLoading) return;
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    if (widget.item.mid <= 0) {
      SmartDialog.showToast('UP 信息缺失');
      return;
    }
    _followLoading = true;
    final res = await VideoHttp.relationMod(
      mid: widget.item.mid,
      act: _followed ? 2 : 1,
      reSrc: 14,
    );
    _followLoading = false;
    if (res.isSuccess) {
      if (mounted) setState(() => _followed = !_followed);
      SmartDialog.showToast(_followed ? '已关注' : '已取消关注');
    } else {
      SmartDialog.showToast('操作失败');
    }
  }

  void _openDetail() {
    PageUtils.toVideoPage(
      aid: widget.item.aid > 0 ? widget.item.aid : null,
      bvid: widget.item.bvid,
      cid: widget.item.cid,
      title: widget.item.title,
      cover: widget.item.cover,
      isVertical: true,
      extraArguments: const {'noVerticalFeed': true},
    );
  }

  void _search() {
    Get.toNamed(
      '/searchResult',
      parameters: {'keyword': widget.item.title},
      arguments: const {'initIndex': 0},
    );
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
      onDoubleTap: _toggleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Image.network(
              item.cover,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
            ),
          ),
          const ColoredBox(color: Colors.black38),
          if (_videoController != null)
            Video(
              controller: _videoController!,
              fit: BoxFit.contain,
              controls: (state) => const SizedBox.shrink(),
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
          ),          Positioned(
            right: 12,
            top: MediaQuery.paddingOf(context).top + 8,
            child: IconButton(
              onPressed: _openDetail,
              icon: const Icon(Icons.open_in_new, color: Colors.white),
            ),
          ),
          if (!widget.active || _loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            right: 10,
            bottom: 170,
            child: Column(
              children: [
                _action(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  label: '点赞',
                  count: (_likeCount ?? item.like) + (_liked ? 1 : 0),
                  active: _liked,
                  onTap: _toggleLike,
                ),
                _action(
                  icon: Icons.chat_bubble_outline,
                  label: '评论',
                  count: _commentCount ?? 0,
                  onTap: _openComments,
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
                  count: _favoriteCount ?? 0,
                  onTap: _openDetail,
                ),
                _action(
                  icon: Icons.share_outlined,
                  label: '分享',
                  count: _shareCount ?? 0,
                  onTap: () => ShareUtils.shareText(
                    'https://www.bilibili.com/video/${item.bvid}',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: InkWell(
              onTap: _openComments,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.white70, size: 17),
                    SizedBox(width: 8),
                    Text(
                      '发弹幕...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Spacer(),
                    Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.white70,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_player != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StreamBuilder<Duration>(
                stream: _player!.stream.position,
                builder: (context, snapshot) {
                  final duration = _player!.state.duration.inMilliseconds;
                  final position = (snapshot.data ?? Duration.zero).inMilliseconds;
                  return LinearProgressIndicator(
                    value: duration > 0
                        ? (position / duration).clamp(0.0, 1.0).toDouble()
                        : 0,
                    minHeight: 2,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  );
                },
              ),
            ),
          Positioned(
            left: 16,
            right: 84,
            bottom: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      backgroundImage:
                          _avatar?.isNotEmpty == true
                          ? NetworkImage(_avatar!)
                          : null,
                      child: _avatar?.isNotEmpty == true
                          ? null
                          : const Icon(
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
                    if (_followed)
                      OutlinedButton(
                        onPressed: _follow,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white38),
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text(
                          '已关注',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: _follow,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6699),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text(
                          '关注',
                          style: TextStyle(fontSize: 12),
                        ),
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
                if ((_viewCount ?? item.view) > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_viewCount ?? item.view} 播放${item.pubdate > 0 ? ' · ${DateFormatUtils.dateFormat(item.pubdate)}' : ''}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                InkWell(
                  onTap: _search,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '搜索 · ${item.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
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
    int count = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 58,
          child: Column(
            children: [
              Icon(
                icon,
                color: active ? const Color(0xFFFF6699) : Colors.white,
                size: 34,
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 6),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                count > 0 ? _shortCount(count) : label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  String _shortCount(int value) {
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
    return '$value';
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerticalComments(aid: widget.item.aid),
    );
  }

}

class _VerticalComments extends StatefulWidget {
  const _VerticalComments({required this.aid});

  final int aid;

  @override
  State<_VerticalComments> createState() => _VerticalCommentsState();
}

class _VerticalCommentsState extends State<_VerticalComments> {
  final List<ReplyItemModel> _replies = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  bool _sending = false;
  int _page = 1;
  int? _count;
  bool _loading = false;
  bool _end = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    _loading = true;
    final res = await ReplyHttp.replyList(
      isLogin: Accounts.main.isLogin,
      oid: widget.aid,
      nextOffset: '',
      type: 1,
      page: _page,
      sort: 1,
    );
    if (!mounted) return;
    if (res case Success(:final response)) {
      final list = response.replies ?? const <ReplyItemModel>[];
      _count = response.cursor?.allCount ?? _count;
      _replies.addAll(list);
      _page++;
      _end = (response.cursor?.isEnd ?? false) || list.length < 20;
    } else {
      _failed = true;
      _end = true;
    }
    _loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    _sending = true;
    final res = await VideoHttp.replyAdd(
      type: 1,
      oid: widget.aid,
      message: text,
    );
    _sending = false;
    if (res.isSuccess) {
      _inputController.clear();
      _page = 1;
      _replies.clear();
      _end = false;
      _count = null;
      await _loadMore();
      SmartDialog.showToast('评论成功');
    } else {
      SmartDialog.showToast('发送失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF17181A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(
                  _count == null ? '评论' : '评论 $_count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: _replies.isEmpty
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _failed ? '评论加载失败' : '还没有评论',
                            style: const TextStyle(color: Colors.white54),
                          ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _replies.length + (_end ? 0 : 1),
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index >= _replies.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                            ),
                          ),
                        );
                      }
                      final reply = _replies[index];
                      final avatar = reply.member?.avatar;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipOval(
                            child: avatar != null && avatar.isNotEmpty
                                ? Image.network(
                                    avatar,
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person,
                                      color: Colors.white54,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Colors.white54,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reply.member?.uname ?? '匿名',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reply.content?.message ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                if ((reply.like ?? 0) > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${reply.like} 赞',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                8,
                8 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '发条评论...',
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
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

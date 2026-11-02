import 'dart:ui' show ImageFilter;

import 'dart:async';

import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/grpc/dm.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/emote/view.dart';
import 'package:PiliPlus/models_new/emote/emote.dart';
import 'package:PiliPlus/pages/vertical_feed/daily_exp.dart';
import 'package:PiliPlus/pages/vertical_feed/save_video.dart';
import 'package:PiliPlus/pages/vertical_feed/danmaku_composer.dart';
import 'package:PiliPlus/pages/vertical_feed/video_notes.dart';
import 'package:PiliPlus/pages/vertical_feed/comment_detail.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/danmaku.dart';
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/reply.dart';
import 'package:PiliPlus/http/msg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models_new/reply/content.dart';
import 'package:PiliPlus/models_new/reply/data.dart';
import 'package:PiliPlus/models_new/reply/reply.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/services/watch_stats_service.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/share_utils.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
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
  final Map<String, Future<String?>> _mediaFutures = {};
  bool _loading = false;
  bool _loaded = false;
  bool _hasMore = true;
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
    if (_loading || !_hasMore) return;
    final oldLength = _items.length;
    final wasAtEnd = _index >= oldLength;
    var added = 0;
    _loading = true;
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
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
            added++;
          }
        }
        if (added >= 5) break;
      }
    } catch (_) {}
    _loading = false;
    _loaded = true;
    if (added == 0) _hasMore = false;
    if (mounted) {
      setState(() {});
      _preloadAround();
      if (wasAtEnd && _items.length > oldLength) {
        _index = oldLength;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(oldLength);
          }
        });
      }
    }
  }

  void _preloadAround() {
    for (var i = _index; i <= _index + 2 && i < _items.length; i++) {
      final item = _items[i];
      final key = '${item.bvid}_${item.cid}';
      _mediaFutures.putIfAbsent(key, () => _resolveVerticalMedia(item));
    }
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
              physics: const ClampingScrollPhysics(),
              scrollDirection: Axis.vertical,
              itemCount: _items.length + (_hasMore ? 1 : 0),
              onPageChanged: (index) {
                if (index >= _items.length) {
                  _fetchMore();
                  return;
                }
                setState(() => _index = index);
                _preloadAround();
                if (index >= _items.length - 2) _fetchMore();
              },
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return const _VerticalLoadingPage();
                }
                final item = _items[index];
                final key = '${item.bvid}_${item.cid}';
                return _VerticalPlayerItem(
                    key: ValueKey(key),
                    item: item,
                    active: index == _index,
                    preload: index == _index + 1,
                    mediaFuture: _mediaFutures.putIfAbsent(
                      key,
                      () => _resolveVerticalMedia(item),
                    ),
                    onCompleted: _next,
                  );
              },
            ),
    );
  }
}

class _VerticalLoadingPage extends StatelessWidget {
  const _VerticalLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 12),
            Text('加载更多...', style: TextStyle(color: Colors.white54)),
          ],
        ),
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
    this.preload = false,
    this.mediaFuture,
  });

  final _VerticalItem item;
  final bool active;
  final bool preload;
  final Future<String?>? mediaFuture;
  final VoidCallback onCompleted;

  @override
  State<_VerticalPlayerItem> createState() => _VerticalPlayerItemState();
}

class _VerticalPlayerItemState extends State<_VerticalPlayerItem> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _layoutSub;
  Timer? _statsTimer;
  int _lastHeartbeat = 0;
  bool _loading = false;
  bool _liked = false;
  bool _disliked = false;
  bool _statsLoading = false;
  bool _landscape = false;
  bool _landscapeWork = false;
  bool _landscapeControlsVisible = true;
  Timer? _landscapeTimer;
  bool _uiHidden = false;
  bool _speedBoosting = false;
  final GlobalKey<_DanmakuLayerState> _danmakuKey = GlobalKey();
  bool _danmakuOn = true;
  bool _autoNext = true;
  int? _likeCount;
  int? _commentCount;
  int? _favoriteCount;
  int? _shareCount;
  int? _viewCount;
  int? _coinCount;
  bool _likeLoading = false;
  bool _playing = true;
  String? _avatar;
  bool _followed = false;
  bool _favorited = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _initPlayer();
    } else if (widget.preload) {
      _initPlayer(play: false);
    }
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant _VerticalPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _loadStats();
      if (_player == null) {
        _initPlayer();
      } else {
        _player!.play();
      }
    } else if (!widget.active && oldWidget.active) {
      _player?.pause();
      if (_landscape) {
        _landscape = false;
        _uiHidden = false;
        SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  @override
  void dispose() {
    _landscapeTimer?.cancel();
    if (_landscape) {
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _completedSub?.cancel();
    _statsTimer?.cancel();
    _playingSub?.cancel();
    _layoutSub?.cancel();
    WatchStatsService.instance.onPlaybackStatus(false);
    WatchStatsService.instance.flush();
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
            _coinCount = stat.coin?.toInt();
            _avatar = response.owner?.face;
          });
        }
      }
    } catch (_) {}
    try {
      final rel = await VideoHttp.videoRelation(bvid: widget.item.bvid);
      if (rel case Success(:final response)) {
        _disliked = response.dislike ?? false;
        _followed = response.attention ?? false;
        _favorited = response.favorite ?? false;
        if (mounted) setState(() {});
      }
    } catch (_) {}
    _statsLoading = false;
  }

  double _rateBeforeLongPress = 1.0;

  void _startLongPressSpeed() {
    _rateBeforeLongPress = _player?.state.rate ?? 1.0;
    _player?.setRate(2.0);
    if (mounted) setState(() => _speedBoosting = true);
  }

  void _endLongPressSpeed() {
    _player?.setRate(_rateBeforeLongPress);
    if (mounted) setState(() => _speedBoosting = false);
  }

  Future<void> _initPlayer({bool play = true}) async {
    if (_loading || _player != null) return;
    _playing = play && widget.active;
    _loading = true;
    try {
      final mediaUrl = await (widget.mediaFuture ?? _resolveVerticalMedia(widget.item));
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
      await player.open(Media(mediaUrl), play: play && widget.active);
      _landscapeWork = player.state.width > player.state.height;
      _layoutSub = player.stream.position.listen((_) {
        if (!mounted) return;
        if (player.state.width > 0 && player.state.height > 0) {
          _layoutSub?.cancel();
          _layoutSub = null;
          setState(() {
            _landscapeWork = player.state.width > player.state.height;
          });
        }
      });
      _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final p = _player;
        if (p == null) return;
        WatchStatsService.instance.onPosition(
          id: '${widget.item.bvid}_${widget.item.cid}',
          title: widget.item.title,
          cover: widget.item.cover,
          author: widget.item.author,
          position: p.state.position,
          total: p.state.duration,
          playing: _playing && widget.active,
        );
        final seconds = p.state.position.inSeconds;
        if (widget.active &&
            _playing &&
            seconds - _lastHeartbeat >= 5) {
          _lastHeartbeat = seconds;
          VideoHttp.heartBeat(
            bvid: widget.item.bvid,
            cid: widget.item.cid,
            progress: seconds,
            videoType: VideoType.ugc,
          );
        }
      });
      _playingSub = player.stream.playing.listen((playing) {
        WatchStatsService.instance.onPlaybackStatus(playing);
        if (!playing && widget.active) {
          VideoHttp.heartBeat(
            bvid: widget.item.bvid,
            cid: widget.item.cid,
            progress: player.state.position.inSeconds,
            videoType: VideoType.ugc,
          );
        }
        if (mounted) setState(() => _playing = playing);
      });
      _completedSub = player.stream.completed.listen((completed) {
        if (completed && mounted && widget.active && _autoNext) {
          widget.onCompleted();
        }
      });
      if (!mounted) {
        player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _videoController = controller;
      });
      if (widget.active && !play) {
        player.play();
      }
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
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    if (_likeLoading) return;
    _likeLoading = true;
    final newVal = !_liked;
    final res = await VideoHttp.likeVideo(
      bvid: widget.item.bvid,
      type: newVal,
    );
    _likeLoading = false;
    if (res case Success(:final response)) {
      setState(() {
        _liked = newVal;
        _likeCount =
            (_likeCount ?? widget.item.like) + (newVal ? 1 : -1);
      });
      SmartDialog.showToast(
        newVal
            ? (response.isEmpty ? '点赞成功' : response)
            : '已取消点赞',
      );
    } else if (res case Error(:final errMsg)) {
      final msg = errMsg ?? '';
      if (msg.contains('已点赞')) {
        setState(() => _liked = true);
      } else if (msg.contains('未点赞')) {
        setState(() => _liked = false);
      } else {
        try {
          final rel = await VideoHttp.videoRelation(bvid: widget.item.bvid);
          if (rel case Success(:final response)) {
            setState(() => _liked = response.like ?? false);
          }
        } catch (_) {}
      }
      SmartDialog.showToast(msg.isEmpty ? '操作失败' : msg);
    }
  }

  Future<void> _toggleFavorite() async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    if (_favorited) {
      final res = await FavHttp.unfavAll(
        rid: widget.item.aid,
        type: 2,
      );
      if (res.isSuccess) {
        setState(() {
          _favorited = false;
          _favoriteCount = ((_favoriteCount ?? 1) - 1).clamp(0, 1 << 30).toInt();
        });
      } else {
        SmartDialog.showToast('取消收藏失败');
      }
      return;
    }
    final folders = await FavHttp.userfavFolder(
      pn: 1,
      ps: 50,
      mid: Accounts.main.mid,
    );
    if (folders case Success(:final response)) {
      final list = response.list;
      if (list == null || list.isEmpty) {
        SmartDialog.showToast('没有可用收藏夹');
        return;
      }
      final res = await FavHttp.favVideo(
        resources: widget.item.aid.toString(),
        addIds: list.first.id.toString(),
      );
      if (res.isSuccess) {
        setState(() {
          _favorited = true;
          _favoriteCount = (_favoriteCount ?? 0) + 1;
        });
        SmartDialog.showToast('已收藏到「${list.first.title}」');
      } else {
        SmartDialog.showToast('收藏失败');
      }
    }
  }

  Future<void> _showCoin() async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投币'),
        content: const Text('选择投币数量'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 1),
            child: const Text('1 币'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 2),
            child: const Text('2 币'),
          ),
        ],
      ),
    );
    if (count == null) return;
    final res = await VideoHttp.coinVideo(
      bvid: widget.item.bvid,
      multiply: count,
    );
    if (res.isSuccess) {
      setState(() {
        _coinCount = (_coinCount ?? 0) + count;
      });
      SmartDialog.showToast('投币成功');
    } else if (res case Error(:final errMsg)) {
      SmartDialog.showToast(errMsg ?? '操作失败');
    } else {
      SmartDialog.showToast('投币失败');
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

  void _toggleLandscapeControls() {
    if (_landscapeControlsVisible) {
      _landscapeTimer?.cancel();
      _landscapeTimer = null;
      setState(() => _landscapeControlsVisible = false);
    } else {
      _showLandscapeControls();
    }
  }

  void _showLandscapeControls() {
    if (!_landscape) return;
    if (!_landscapeControlsVisible) {
      setState(() => _landscapeControlsVisible = true);
    }
    _landscapeTimer?.cancel();
    _landscapeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _landscape) {
        setState(() => _landscapeControlsVisible = false);
      }
    });
  }

  void _enterLandscape() {
    _landscape = true;
    _uiHidden = true;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _showLandscapeControls();
    setState(() {});
  }

  void _exitLandscape() {
    _landscapeTimer?.cancel();
    _landscapeTimer = null;
    _landscape = false;
    _uiHidden = false;
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() {});
  }

  void _toggleScreen() {
    if (_landscapeWork) {
      if (_landscape) {
        _exitLandscape();
      } else {
        _enterLandscape();
      }
      return;
    }
    setState(() => _uiHidden = !_uiHidden);
    SystemChrome.setEnabledSystemUIMode(
      _uiHidden ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
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

  String get _viewerText {
    final n = _viewCount ?? widget.item.view;
    return n > 0 ? '${_shortCount(n)} 人在看' : '正在看';
  }

  Future<void> _showSpeed() async {
    final rates = [0.75, 1.0, 1.25, 1.5, 2.0];
    final rate = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('倍速'),
        children: [
          for (final r in rates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Text(r == 1.0 ? '1.0x' : '${r}x'),
            ),
        ],
      ),
    );
    if (rate != null) {
      await _player?.setRate(rate);
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1C1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.white70),
              title: const Text('稍后再看', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final res = await UserHttp.toViewLater(
                  bvid: widget.item.bvid,
                );
                SmartDialog.showToast(res.isSuccess ? '已加入稍后再看' : '添加失败');
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.white70),
              title: const Text('保存到相册', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                saveVideoToGallery(
                  bvid: widget.item.bvid,
                  cid: widget.item.cid,
                  title: widget.item.title,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined, color: Colors.white70),
              title: const Text('缓存', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openDetail();
                SmartDialog.showToast('请在详情页点缓存');
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.white70),
              title: const Text('倍速', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showSpeed();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.swipe_up, color: Colors.white70),
              title: const Text('自动上滑', style: TextStyle(color: Colors.white)),
              value: _autoNext,
              activeColor: const Color(0xFFFF6699),
              onChanged: (value) {
                Navigator.pop(context);
                setState(() => _autoNext = value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined, color: Colors.white70),
              title: const Text('时间戳笔记', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                final ctx = Get.context;
                Navigator.pop(context);
                final player = _player;
                if (ctx != null && player != null) {
                  showVideoNotesSheet(
                    ctx,
                    bvid: widget.item.bvid,
                    player: player,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.exposure_plus_1, color: Colors.white70),
              title: const Text('今日经验', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                showDailyExpSheet(
                  bvid: widget.item.bvid,
                  aid: widget.item.aid,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.subtitles, color: Colors.white70),
              title: const Text('弹幕设置', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                _showDanmakuSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.white70),
              title: const Text('举报', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                SmartDialog.showToast('举报入口下一步接入');
              },
            ),
            ListTile(
              leading: const Icon(Icons.feedback_outlined, color: Colors.white70),
              title: const Text('反馈建议', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                SmartDialog.showToast('反馈入口下一步接入');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDanmakuSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1C1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.subtitles, color: Colors.white70),
              title: const Text('显示弹幕', style: TextStyle(color: Colors.white)),
              value: _danmakuOn,
              activeColor: const Color(0xFFFF6699),
              onChanged: (value) {
                Navigator.pop(context);
                setState(() => _danmakuOn = value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: Colors.white70),
              title: const Text('完整弹幕设置', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                _openDetail();
              },
            ),
          ],
        ),
      ),
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
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _landscape ? null : _togglePlay,
      onDoubleTap: _landscape ? null : _toggleLike,
      onLongPressStart: _landscape ? null : (_) => _startLongPressSpeed(),
      onLongPressEnd: _landscape ? null : (_) => _endLongPressSpeed(),
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
            Transform.translate(
              offset: _landscapeWork ? const Offset(0, -40) : Offset.zero,
              child: Video(
                controller: _videoController!,
                fit: BoxFit.contain,
                controls: (state) => const SizedBox.shrink(),
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
          if (_danmakuOn && _player != null && item.cid > 0)
            _buildDanmakuLayer(item, size),
          if (!_uiHidden && !_landscape)
            Positioned(
              left: 4,
              top: MediaQuery.paddingOf(context).top,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),
                  const Icon(
                    Icons.people_outline,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _viewerText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (!_uiHidden && !_landscape)
            Positioned(
              right: 4,
              top: MediaQuery.paddingOf(context).top,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '搜索',
                    onPressed: () => Get.toNamed('/search'),
                    icon: const Icon(Icons.search, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: '更多',
                    onPressed: _showMoreMenu,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                ],
              ),
            ),
          if (_landscape) _buildLandscapeControls(item),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 58,
            right: 16,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _speedBoosting ? 1 : 0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: _speedBoosting ? 1 : 0.9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 16,
                          color: Colors.white70,
                        ),
                        Icon(
                          Icons.play_arrow,
                          size: 13,
                          color: Colors.white38,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '倍速中',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!widget.active || _loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _playing || _loading || !widget.active,
              child: AnimatedOpacity(
                opacity: (!_playing && !_loading && widget.active) ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _buildBiliPauseContent(),
              ),
            ),
          ),
          if (!_uiHidden && !_landscape)
            Positioned(
              right: 10,
              bottom: 48,
              child: Column(
              children: [
                _action(
                  icon: _liked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                  label: '点赞',
                  count: _likeCount ?? item.like,
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
                  icon: Icons.monetization_on_outlined,
                  label: '投币',
                  count: _coinCount ?? 0,
                  onTap: _showCoin,
                ),
                _action(
                  icon: _favorited ? Icons.star : Icons.star_border,
                  label: '收藏',
                  count: _favoriteCount ?? 0,
                  active: _favorited,
                  onTap: _toggleFavorite,
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
          if (!_landscape)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_uiHidden && !_landscape)
            Positioned(
              left: 12,
              right: 16,
              bottom: 8,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _sendDanmaku,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Colors.white70,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '发弹幕...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () =>
                              setState(() => _danmakuOn = !_danmakuOn),
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _danmakuOn
                                  ? primary.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  color: _danmakuOn
                                      ? primary
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                child: const Text('弹'),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '详情页',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 40),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _openDetail,
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white70,
                            size: 21,
                          ),
                        ),
                        IconButton(
                          tooltip:
                              _landscapeWork ? '横屏模式' : '隐藏界面',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 40),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _toggleScreen,
                          icon: Icon(
                            _landscapeWork
                                ? Icons.screen_rotation
                                : Icons.fullscreen,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!_uiHidden && !_landscape && _player != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 50,
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
          if (!_uiHidden && !_landscape)
            Positioned(
              left: 16,
              right: 84,
              bottom: 56,
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
                              fontSize: 13,
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
          if (_uiHidden && !_landscape)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _uiHidden = false);
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                },
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDanmakuLayer(_VerticalItem item, Size screen) {
    return Positioned(
      left: 0,
      right: 0,
      top: 80,
      bottom: 120,
      child: IgnorePointer(
        child: _DanmakuLayer(
          key: _danmakuKey,
          player: _player!,
          cid: item.cid,
        ),
      ),
    );
  }

  Widget _buildBiliPauseContent() {
    final player = _player;
    final position = player?.state.position ?? Duration.zero;
    final duration = player?.state.duration ?? Duration.zero;
    return Center(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0x5538BDF8),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 58,
                  color: Color(0xCC168FE5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${_biliTime(position)} / ${_biliTime(duration)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 5),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _biliTime(Duration d) {
    final total = d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildLandscapeControls(_VerticalItem item) {
    final player = _player;
    final duration = player?.state.duration ?? Duration.zero;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleLandscapeControls,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          IgnorePointer(
            ignoring: !_landscapeControlsVisible,
            child: AnimatedOpacity(
              opacity: _landscapeControlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          _viewerText,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              setState(() => _danmakuOn = !_danmakuOn),
                          icon: Icon(
                            _danmakuOn
                                ? Icons.subtitles
                                : Icons.subtitles_off,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: _exitLandscape,
                          icon: const Icon(
                            Icons.fullscreen_exit,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Spacer(),
                    StreamBuilder<Duration>(
                      stream: player?.stream.position,
                      builder: (context, snapshot) {
                        final position =
                            snapshot.data ??
                            player?.state.position ??
                            Duration.zero;
                        return Container(
                          padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
                          color: Colors.black45,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _togglePlay,
                                icon: Icon(
                                  _playing ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _formatLandscapeTime(position),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                              Expanded(
                                child: SizedBox(
                                  height: 24,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2,
                                      thumbShape:
                                          const RoundSliderThumbShape(
                                            enabledThumbRadius: 5,
                                          ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 10,
                                          ),
                                    ),
                                    child: Slider(
                                      value: duration.inMilliseconds > 0
                                          ? (position.inMilliseconds /
                                                    duration.inMilliseconds)
                                                .clamp(0.0, 1.0)
                                                .toDouble()
                                          : 0.0,
                                      onChanged: (value) {
                                        player?.seek(
                                          Duration(
                                            milliseconds:
                                                (duration.inMilliseconds *
                                                        value)
                                                    .round(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                _formatLandscapeTime(duration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLandscapeTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
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

  Future<void> _sendDanmaku() async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    final draft = await showDanmakuComposer(context);
    if (draft == null) return;
    final res = await DanmakuHttp.shootDanmaku(
      oid: widget.item.cid,
      bvid: widget.item.bvid,
      msg: draft.text,
      mode: draft.mode,
      color: draft.color,
      fontSize: draft.fontSize,
      progress: _player?.state.position.inMilliseconds ?? 0,
    );
    if (res.isSuccess) {
      _danmakuKey.currentState?.addSelf(draft);
      SmartDialog.showToast('弹幕已发送');
    } else {
      SmartDialog.showToast('发送失败：${res.toString()}');
    }
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerticalComments(aid: widget.item.aid),
    ).whenComplete(_loadStats);
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
  bool _hot = true;
  final Map<int, List<ReplyItemModel>> _moreReplies = {};
  final Set<int> _loadingReplies = {};
  Map<String, dynamic>? _pendingPicture;
  bool _pickingImage = false;

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

  void _reload() {
    _page = 1;
    _replies.clear();
    _end = false;
    _failed = false;
    _loadMore();
  }

  void _toggleSort() {
    setState(() => _hot = !_hot);
    _reload();
  }

  Future<void> _showEmoji() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17181A),
      builder: (context) => SizedBox(
        height: 250,
        child: EmotePanel(
          onChoose: (Emote emote, double? width, double? height) {
            _inputController.text += emote.text ?? '';
            Navigator.pop(context);
          },
        ),
      ),
    );
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
      sort: _hot ? 1 : 0,
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

  String? _emoteUrl(dynamic data) {
    if (data is Map) {
      for (final key in const ['url', 'gif_url', 'webp_url']) {
        final value = data[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  Widget _buildMessage(ReplyContent? content) {
    final text = content?.message ?? '';
    final emotes = content?.emotes;
    if (text.isEmpty) return const Text('');
    if (emotes == null || emotes.isEmpty) {
      return Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
      );
    }
    final keys = emotes.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(keys.map(RegExp.escape).join('|'));
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final key = match.group(0)!;
      final url = _emoteUrl(emotes[key]);
      spans.add(
        url == null
            ? TextSpan(text: key)
            : WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Image.network(
                  url,
                  width: 20,
                  height: 20,
                  errorBuilder: (_, _, _) => Text(key),
                ),
              ),
      );
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
    );
  }

  Widget _buildPictures(ReplyContent? content) {
    final pictures = content?.pictures;
    if (pictures == null || pictures.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final pic in pictures.take(3))
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                pic.imgSrc ?? '',
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadReplies(ReplyItemModel reply) async {
    final rpid = reply.rpid;
    if (rpid == null || _loadingReplies.contains(rpid)) return;
    _loadingReplies.add(rpid);
    if (mounted) setState(() {});
    final loaded = <ReplyItemModel>[];
    for (var page = 1; page <= 3; page++) {
      final res = await ReplyHttp.replyReplyList(
        isLogin: Accounts.main.isLogin,
        oid: widget.aid,
        root: rpid,
        pageNum: page,
        type: 1,
      );
      if (res case Success(:final response)) {
        final list = response.replies ?? const <ReplyItemModel>[];
        loaded.addAll(list);
        if (list.length < 20) break;
      } else {
        break;
      }
    }
    _moreReplies[rpid] = loaded;
    _loadingReplies.remove(rpid);
    if (mounted) setState(() {});
  }

  Widget _buildReplies(ReplyItemModel reply) {
    final rpid = reply.rpid;
    final replies = rpid == null ? reply.replies : _moreReplies[rpid];
    final count = reply.count ?? 0;
    final hasMore = rpid != null && count > (replies?.length ?? 0);
    if ((replies == null || replies.isEmpty) && !hasMore) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final sub in (replies ?? const <ReplyItemModel>[]).take(8))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${sub.member?.uname ?? '匿名'}：',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Expanded(child: _buildMessage(sub.content)),
                ],
              ),
            ),
          if (hasMore)
            TextButton(
              onPressed: _loadingReplies.contains(rpid)
                  ? null
                  : () => _loadReplies(reply),
              child: Text(
                _loadingReplies.contains(rpid)
                    ? '加载回复中...'
                    : '查看全部 $count 条回复',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Color _levelColor(int level) {
    return switch (level) {
      0 => const Color(0xFFC0C0C0),
      1 => const Color(0xFF95DDB3),
      2 => const Color(0xFF7BC6FF),
      3 => const Color(0xFF5D9CEC),
      4 => const Color(0xFFFFB37C),
      5 => const Color(0xFFFF8C00),
      _ => const Color(0xFFFF4D4F),
    };
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    _pickingImage = true;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) {
      _pickingImage = false;
      return;
    }
    final res = await MsgHttp.uploadBfs(
      path: file.path,
      category: 'comment',
      biz: 'comment',
    );
    _pickingImage = false;
    if (!mounted) return;
    if (res case Success(:final response)) {
      setState(() {
        _pendingPicture = {
          'img_src': response.imageUrl,
          'img_width': response.imageWidth ?? 0,
          'img_height': response.imageHeight ?? 0,
        };
      });
      SmartDialog.showToast('图片已选择，发送评论时一起提交');
    } else {
      SmartDialog.showToast('图片上传失败：${res.toString()}');
    }
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
      pictures: _pendingPicture == null ? null : [_pendingPicture],
    );
    _sending = false;
    if (res.isSuccess) {
      _inputController.clear();
      _pendingPicture = null;
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
                TextButton(
                  onPressed: _toggleSort,
                  child: Text(
                    _hot ? '最热' : '最新',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
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
                      return InkWell(
                        onTap: () => showCommentDetailSheet(
                          context,
                          reply,
                          widget.aid,
                        ),
                        child: Row(
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
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        reply.member?.uname ?? '匿名',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (reply.member?.levelInfo?.currentLevel case final level?)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: BiliUtils.levelPicture(
                                          level,
                                          height: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildMessage(reply.content),
                                _buildPictures(reply.content),
                                _buildReplies(reply),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if ((reply.like ?? 0) > 0) ...[
                                      Text(
                                        '${reply.like} 赞',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    if (reply.ctime != null)
                                      Text(
                                        DateFormatUtils.dateFormat(
                                          reply.ctime,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                    tooltip: '图片',
                    onPressed: _pickingImage ? null : _pickImage,
                    icon: Icon(
                      _pendingPicture == null
                          ? Icons.image_outlined
                          : Icons.image,
                      color: _pendingPicture == null
                          ? Colors.white70
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: '表情',
                    onPressed: _showEmoji,
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.white70,
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

Future<String?> _resolveVerticalMedia(_VerticalItem item) async {
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

class _DanmakuLayer extends StatefulWidget {
  const _DanmakuLayer({super.key, required this.player, required this.cid});

  final Player player;
  final int cid;

  @override
  State<_DanmakuLayer> createState() => _DanmakuLayerState();
}

class _DanmakuLayerState extends State<_DanmakuLayer> {
  final Map<int, List<DanmakuElem>> _segments = {};
  final Set<int> _requested = {};
  DanmakuController<DanmakuExtra>? _controller;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<double>? _rateSub;
  int _lastPosition = -1;
  bool _ready = false;
  bool _showScreen = false;

  @override
  void initState() {
    super.initState();
    _positionSub = widget.player.stream.position.listen(_onPosition);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showScreen = true);
    });
    _rateSub = widget.player.stream.rate.listen((rate) {
      _controller?.updateOption(
        DanmakuOptions.get(notFullscreen: false, speed: rate),
      );
    });
    _playingSub = widget.player.stream.playing.listen((playing) {
      if (playing) {
        _controller?.resume();
      } else {
        _controller?.pause();
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _rateSub?.cancel();
    _segments.clear();
    _requested.clear();
    super.dispose();
  }

  void addSelf(DanmakuDraft draft) {
    _controller?.addDanmaku(
      DanmakuContentItem(
        draft.text,
        color: Color(0xFF000000 | draft.color),
        type: draft.mode == 5
            ? DanmakuItemType.top
            : DanmakuItemType.scroll,
        selfSend: true,
      ),
    );
  }

  Future<void> _ensureSegment(int segment) async {
    if (_requested.contains(segment)) return;
    _requested.add(segment);
    final res = await DmGrpc.dmSegMobile(
      cid: widget.cid,
      segmentIndex: segment + 1,
    );
    if (res case Success(:final response)) {
      for (final elem in response.elems) {
        (_segments[elem.progress ~/ 100] ??= []).add(elem);
      }
    } else {
      _requested.remove(segment);
    }
  }

  void _onPosition(Duration position) {
    final controller = _controller;
    if (controller == null || !_ready) return;
    final ms = position.inMilliseconds;
    final segment = DmUtils.calcSegment(ms);
    _ensureSegment(segment);
    final key = ms ~/ 100;
    if (key == _lastPosition) return;
    _lastPosition = key;
    final list = _segments[key];
    if (list == null || list.isEmpty) return;
    for (final elem in list) {
      if (elem.mode == 7) continue;
      controller.addDanmaku(
        DanmakuContentItem(
          elem.content,
          color: DmUtils.decimalToColor(elem.color),
          type: DmUtils.getPosition(elem.mode),
          count: elem.count > 1 ? elem.count : null,
          selfSend: elem.isSelf,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showScreen) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => DanmakuScreen<DanmakuExtra>(
        createdController: (controller) {
          _controller = controller;
          _lastPosition = -1;
          _ready = true;
          if (widget.player.state.playing) {
            controller.resume();
          } else {
            controller.pause();
          }
        },
        option: DanmakuOptions.get(
          notFullscreen: false,
          speed: widget.player.state.rate,
        ),
        size: Size(constraints.maxWidth, constraints.maxHeight),
      ),
    );
  }
}

class _BiliTvPlay extends StatelessWidget {
  const _BiliTvPlay();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 4,
            left: 20,
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 18,
                height: 2,
                color: Colors.white70,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 20,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(
                width: 18,
                height: 2,
                color: Colors.white70,
              ),
            ),
          ),
          Positioned(
            top: 14,
            child: Container(
              width: 68,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundPlayButton extends StatelessWidget {
  const _RoundPlayButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

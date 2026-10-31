import 'package:PiliPlus/utils/storage.dart';

/// 本地观看统计。
///
/// 只记录真正播放的时间：播放器每秒上报一次进度，进度前进 1~3 秒才算观看，
/// 拖动进度条造成的大跳变会被忽略。数据全部保存在 Hive 的 `watchStats` 盒子中，
/// 不上传任何服务器。
class WatchStatsService {
  WatchStatsService._();

  static final WatchStatsService instance = WatchStatsService._();

  static const String _videosKey = 'videos';
  static const String _dayPrefix = 'day:';
  static const int _maxVideos = 300;

  String? _id;
  String _title = '';
  String _cover = '';
  String _author = '';
  int _lastPosMs = 0;
  int _pendingMs = 0;

  /// 播放器位置回调，每秒调用一次。
  void onPosition({
    required String id,
    required String title,
    String? cover,
    String? author,
    required Duration position,
    required bool playing,
  }) {
    if (id.isEmpty) return;
    if (id != _id) {
      flush();
      _id = id;
      _title = title;
      _cover = cover ?? '';
      _author = author ?? '';
      _lastPosMs = position.inMilliseconds;
      _pendingMs = 0;
    } else {
      if (title.isNotEmpty) _title = title;
      if (cover != null && cover.isNotEmpty) _cover = cover;
      if (author != null && author.isNotEmpty) _author = author;
    }
    final delta = position.inMilliseconds - _lastPosMs;
    if (playing && delta > 0 && delta <= 3000) {
      _pendingMs += delta;
    }
    _lastPosMs = position.inMilliseconds;
    if (_pendingMs >= 30000) flush();
  }

  /// 播放/暂停状态回调，暂停时把剩余时间落盘。
  void onPlaybackStatus(bool playing) {
    if (!playing) flush();
  }

  /// 把内存中的待写入时间写入 Hive。
  void flush() {
    if (_id == null || _pendingMs <= 0) {
      _pendingMs = 0;
      return;
    }
    final seconds = _pendingMs ~/ 1000;
    _pendingMs = 0;
    if (seconds <= 0) return;
    try {
      final box = GStorage.watchStats;
      final now = DateTime.now();
      final dayKey = '$_dayPrefix${_dayKey(now)}';
      box.put(dayKey, (box.get(dayKey) as int? ?? 0) + seconds);

      final videos = Map<String, dynamic>.from(
        (box.get(_videosKey) as Map?) ?? const {},
      );
      final old = videos[_id] is Map
          ? Map<String, dynamic>.from(videos[_id] as Map)
          : <String, dynamic>{};
      old['title'] = _title;
      old['cover'] = _cover;
      old['author'] = _author;
      old['seconds'] = (old['seconds'] as int? ?? 0) + seconds;
      old['lastAt'] = now.millisecondsSinceEpoch;
      videos[_id!] = old;

      if (videos.length > _maxVideos) {
        final sorted = videos.entries.toList()
          ..sort(
            (a, b) => ((a.value as Map)['lastAt'] as int? ?? 0).compareTo(
              (b.value as Map)['lastAt'] as int? ?? 0,
            ),
          );
        for (final entry in sorted.take(videos.length - _maxVideos)) {
          videos.remove(entry.key);
        }
      }
      box.put(_videosKey, videos);
    } catch (_) {
      // 统计失败不影响播放
    }
  }

  int get todaySeconds => daySeconds(DateTime.now());

  int get weekSeconds {
    final now = DateTime.now();
    var total = 0;
    for (var i = 0; i < 7; i++) {
      total += daySeconds(now.subtract(Duration(days: i)));
    }
    return total;
  }

  int get totalSeconds {
    try {
      final box = GStorage.watchStats;
      var total = 0;
      for (final key in box.keys) {
        if (key is String && key.startsWith(_dayPrefix)) {
          total += (box.get(key) as int? ?? 0);
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  int daySeconds(DateTime date) {
    try {
      return GStorage.watchStats.get('$_dayPrefix${_dayKey(date)}') as int? ??
          0;
    } catch (_) {
      return 0;
    }
  }

  /// 最近 [days] 天，从早到晚，每天一个秒数。
  List<({DateTime date, int seconds})> recentDays([int days = 7]) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      return (date: date, seconds: daySeconds(date));
    });
  }

  /// 看过的视频，按观看时长倒序。
  List<WatchVideoStat> topVideos({int limit = 50}) {
    try {
      final videos = (GStorage.watchStats.get(_videosKey) as Map?) ?? const {};
      final list = videos.entries.map((entry) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        return WatchVideoStat(
          id: entry.key.toString(),
          title: value['title'] as String? ?? '',
          cover: value['cover'] as String? ?? '',
          author: value['author'] as String? ?? '',
          seconds: value['seconds'] as int? ?? 0,
          lastAt: value['lastAt'] as int? ?? 0,
        );
      }).where((e) => e.seconds > 0).toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));
      return list.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 按 UP 聚合观看时长。
  List<({String author, int seconds})> topAuthors({int limit = 10}) {
    final map = <String, int>{};
    for (final video in topVideos(limit: _maxVideos)) {
      if (video.author.isEmpty) continue;
      map[video.author] = (map[video.author] ?? 0) + video.seconds;
    }
    final list = map.entries
        .map((e) => (author: e.key, seconds: e.value))
        .toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    return list.take(limit).toList();
  }

  void clear() {
    _id = null;
    _pendingMs = 0;
    try {
      GStorage.watchStats.clear();
    } catch (_) {}
  }

  static String _dayKey(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

class WatchVideoStat {
  final String id;
  final String title;
  final String cover;
  final String author;
  final int seconds;
  final int lastAt;

  const WatchVideoStat({
    required this.id,
    required this.title,
    required this.cover,
    required this.author,
    required this.seconds,
    required this.lastAt,
  });
}

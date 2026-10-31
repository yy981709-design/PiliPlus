import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/services/watch_stats_service.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:material_ui/material_ui.dart';

class WatchStatsPage extends StatefulWidget {
  const WatchStatsPage({super.key});

  @override
  State<WatchStatsPage> createState() => _WatchStatsPageState();
}

class _WatchStatsPageState extends State<WatchStatsPage> {
  final _service = WatchStatsService.instance;

  @override
  void initState() {
    super.initState();
    _service.flush();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _service.recentDays();
    final maxSeconds = days.fold<int>(
      1,
      (max, e) => e.seconds > max ? e.seconds : max,
    );
    final authors = _service.topAuthors();
    final videos = _service.topVideos(limit: 10);
    final total = _service.totalSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('观看统计'),
        actions: [
          if (total > 0)
            IconButton(
              tooltip: '清除统计',
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context: context,
                  title: const Text('清除观看统计？'),
                  content: const Text('只会删除本机的统计数据，不影响观看记录。'),
                );
                if (ok) {
                  _service.clear();
                  if (mounted) setState(() {});
                }
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _summaryCard(theme),
          if (total == 0)
            _emptyCard(theme)
          else ...[
            _weekCard(theme, days, maxSeconds),
            if (authors.isNotEmpty) _authorsCard(theme, authors),
            if (videos.isNotEmpty) _videosCard(theme, videos),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard(ThemeData theme) {
    final color = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Row(
          children: [
            _metric(color, '今日', _format(_service.todaySeconds)),
            _metric(color, '本周', _format(_service.weekSeconds)),
            _metric(color, '累计', _format(_service.totalSeconds)),
          ],
        ),
      ),
    );
  }

  Widget _metric(ColorScheme color, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.outline),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 44,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '还没有观看记录',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '去看几个视频，这里会记录今日、本周和累计观看时长。',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekCard(
    ThemeData theme,
    List<({DateTime date, int seconds})> days,
    int maxSeconds,
  ) {
    final color = theme.colorScheme;
    const weekNames = ['一', '二', '三', '四', '五', '六', '日'];
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近 7 天',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((e) {
                  final ratio = e.seconds / maxSeconds;
                  final barHeight = e.seconds == 0 ? 4.0 : 12 + ratio * 86;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          e.seconds == 0 ? '' : _formatShort(e.seconds),
                          style: TextStyle(
                            fontSize: 9,
                            color: color.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          height: barHeight,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: e.seconds == 0
                                ? color.secondaryContainer
                                : color.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '周${weekNames[e.date.weekday - 1]}',
                          style: TextStyle(
                            fontSize: 10,
                            color: color.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authorsCard(
    ThemeData theme,
    List<({String author, int seconds})> authors,
  ) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '看得最多的 UP',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < authors.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: i < 3
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        authors[i].author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _format(authors[i].seconds),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _videosCard(ThemeData theme, List<WatchVideoStat> videos) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '看得最久的视频',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            for (final video in videos) _videoTile(theme, video),
          ],
        ),
      ),
    );
  }

  Widget _videoTile(ThemeData theme, WatchVideoStat video) {
    final color = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: video.id.startsWith('BV') || video.id.startsWith('bv')
          ? () {
              final parts = video.id.split('_');
              final cid = int.tryParse(parts.length > 1 ? parts.last : '');
              if (cid == null) return;
              PageUtils.toVideoPage(
                bvid: parts.first,
                cid: cid,
                cover: video.cover,
                title: video.title,
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: NetworkImgLayer(
                src: video.cover,
                width: 96,
                height: 56,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title.isEmpty ? '未知视频' : video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.25),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    video.author.isEmpty ? '未知 UP' : video.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: color.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _format(video.seconds),
              style: TextStyle(fontSize: 11, color: color.primary),
            ),
          ],
        ),
      ),
    );
  }

  String _format(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分';
  }

  String _formatShort(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes / 60;
    return hours >= 10 ? '${hours.round()}h' : '${hours.toStringAsFixed(1)}h';
  }
}

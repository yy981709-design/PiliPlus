import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/services/watch_stats_service.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/share_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

class WatchStatsPage extends StatefulWidget {
  const WatchStatsPage({super.key});

  @override
  State<WatchStatsPage> createState() => _WatchStatsPageState();
}

class _WatchStatsPageState extends State<WatchStatsPage> {
  final _service = WatchStatsService.instance;

  int get _goalHours {
    try {
      return (GStorage.setting.get('watchGoalHours') as int?) ?? 5;
    } catch (_) {
      return 5;
    }
  }

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
    final level = _levelFor(total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('观看统计'),
        actions: [
          if (total > 0)
            IconButton(
              tooltip: '分享报告',
              onPressed: () {
                ShareUtils.shareText(_buildReport());
              },
              icon: const Icon(Icons.share_outlined),
            ),
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
            _levelCard(theme, level),
            _backfillCard(theme),
            _personaCard(theme),
            _goalCard(theme),
            _heatmapCard(theme),
            _weekCard(theme, days, maxSeconds),
            _hourCard(theme),
            _monthsCard(theme),
            _achievementsCard(theme),
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
            Text('还没有观看记录', style: theme.textTheme.titleMedium),
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

  Widget _levelCard(ThemeData theme, _LevelInfo level) {
    final color = theme.colorScheme;
    final next = level.nextHours;
    final progress = next == null
        ? 1.0
        : ((_service.totalSeconds - level.minHours * 3600) /
                  ((next - level.minHours) * 3600))
              .clamp(0.0, 1.0)
              .toDouble();
    final left = next == null
        ? 0
        : next * 3600 - _service.totalSeconds;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    level.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                if (_biliLevel != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'B站账号 LV${_biliLevel!}',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.onSecondaryContainer,
                      ),
                    ),
                  ),
                Text(
                  next == null ? '满级' : 'LV${level.index}/${_levelNames.length - 1}',
                  style: TextStyle(fontSize: 12, color: color.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: color.secondaryContainer,
            ),
            const SizedBox(height: 8),
            Text(
              next == null
                  ? '已达到最高观看等级，累计 ${_format(_service.totalSeconds)}'
                  : '累计 ${_format(_service.totalSeconds)}，距 LV${level.index + 1} 还差 ${_format(left)}',
              style: TextStyle(fontSize: 12, color: color.outline),
            ),
          ],
        ),
      ),
    );
  }

  int? get _biliLevel {
    try {
      return Pref.userInfoCache?.levelInfo?.currentLevel;
    } catch (_) {
      return null;
    }
  }

  Widget _backfillCard(ThemeData theme) {
    final base = _service.baseSeconds;
    final color = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(Icons.history_edu, color: color.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '历史补录',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    base > 0
                        ? '已补录 ${_format(base)}，计入总时长和等级'
                        : '把注册以来的观看时长补进来',
                    style: TextStyle(fontSize: 12, color: color.outline),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _editBase,
              child: Text(base > 0 ? '修改' : '补录'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBase() async {
    final controller = TextEditingController(
      text: (_service.baseSeconds / 3600).toStringAsFixed(
        _service.baseSeconds % 3600 == 0 ? 0 : 1,
      ),
    );
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('补录历史观看时长'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '小时',
            hintText: '例如 500',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    final hours = double.tryParse(text.trim());
    if (hours == null || hours < 0) return;
    _service.setBaseSeconds((hours * 3600).round());
    if (mounted) setState(() {});
  }

  Widget _personaCard(ThemeData theme) {
    final color = theme.colorScheme;
    final total = _service.totalSeconds;
    final late = _service.lateNightSeconds;
    final authors = _service.topAuthors(limit: 1);
    final top = authors.isEmpty ? 0 : authors.first.seconds;
    final started = _service.startedVideos;
    final completed = _service.completedVideos;
    final active = _service.activeDays;
    double ratio(int a, int b) {
      if (b <= 0) return 0;
      return (a / b).clamp(0.0, 1.0).toDouble();
    }

    final scores = <({String label, double value, String note})>[
      (
        label: '电子榨菜依赖度',
        value: (total / 3600 / 100).clamp(0.0, 1.0).toDouble(),
        note: '累计 ${_format(total)}',
      ),
      (
        label: '深夜修仙指数',
        value: ratio(late, total),
        note: '凌晨 0-5 点占 ${(ratio(late, total) * 100).round()}%',
      ),
      (
        label: '单推浓度',
        value: ratio(top, total),
        note: authors.isEmpty ? '还没有数据' : '最常看 ${authors.first.author}',
      ),
      (
        label: '视频仓鼠症',
        value: ratio(started, active * 3),
        note: '活跃 $active 天，看过 $started 个视频',
      ),
      (
        label: '弃坑指数',
        value: ratio(started - completed, started),
        note: '看完 $completed / $started',
      ),
    ];
    var persona = '电子榨菜成瘾者';
    if (ratio(late, total) >= 0.3) {
      persona = '深夜考古学家';
    } else if (ratio(started - completed, started) >= 0.6) {
      persona = '弃坑大师';
    } else if (ratio(top, total) >= 0.5 && total >= 3600) {
      persona = '单推狂魔';
    } else if (ratio(started, active * 3) >= 0.8) {
      persona = '视频仓鼠';
    } else if (ratio(completed, started) >= 0.7 && started >= 10) {
      persona = '认真看完党';
    }
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'B站成分报告',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '你的观看人格：$persona',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color.primary,
              ),
            ),
            const SizedBox(height: 10),
            for (final score in scores) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      score.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${(score.value * 100).round()}%',
                    style: TextStyle(fontSize: 11, color: color.outline),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: score.value,
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
                backgroundColor: color.secondaryContainer,
              ),
              const SizedBox(height: 3),
              Text(
                score.note,
                style: TextStyle(fontSize: 10, color: color.outline),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _goalCard(ThemeData theme) {
    final color = theme.colorScheme;
    final week = _service.weekSeconds;
    final goal = _goalHours * 3600;
    final progress = (week / goal).clamp(0.0, 1.0).toDouble();
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '本周目标',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _pickGoal,
                  child: const Text('设置'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: color.secondaryContainer,
            ),
            const SizedBox(height: 8),
            Text(
              progress >= 1
                  ? '目标达成：${_format(week)} / $_goalHours 小时'
                  : '${_format(week)} / $_goalHours 小时，还差 ${_format(goal - week)}',
              style: TextStyle(fontSize: 12, color: color.outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickGoal() async {
    final hours = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('每周观看目标'),
        children: [
          for (final h in [1, 3, 5, 7, 10, 20])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, h),
              child: Text('$h 小时'),
            ),
        ],
      ),
    );
    if (hours == null) return;
    try {
      GStorage.setting.put('watchGoalHours', hours);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Widget _heatmapCard(ThemeData theme) {
    final color = theme.colorScheme;
    final days = _service.recentDays(84);
    var max = 1;
    for (final day in days) {
      if (day.seconds > max) max = day.seconds;
    }
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '观看热力图',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '最近 12 周',
              style: TextStyle(fontSize: 11, color: color.outline),
            ),
            const SizedBox(height: 12),
            for (var row = 0; row < 7; row++)
              Row(
                children: [
                  for (var col = 0; col < 12; col++)
                    Expanded(
                      child: Container(
                        height: 14,
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: _heatColor(
                            color,
                            days[col * 7 + row].seconds,
                            max,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '少',
                  style: TextStyle(fontSize: 10, color: color.outline),
                ),
                const SizedBox(width: 4),
                for (final alpha in [0.15, 0.35, 0.6, 0.9])
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: color.primary.withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  '多',
                  style: TextStyle(fontSize: 10, color: color.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _heatColor(ColorScheme color, int seconds, int max) {
    if (seconds <= 0) return color.surfaceContainerHighest;
    final ratio = (seconds / max).clamp(0.0, 1.0);
    return color.primary.withValues(
      alpha: (0.15 + ratio * 0.8).clamp(0.15, 0.95).toDouble(),
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

  Widget _hourCard(ThemeData theme) {
    final color = theme.colorScheme;
    var max = 1;
    var bestHour = 0;
    for (var h = 0; h < 24; h++) {
      final seconds = _service.hourSeconds(h);
      if (seconds > max) {
        max = seconds;
        bestHour = h;
      }
    }
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '观看时段',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              max <= 1 ? '还没有足够的时段数据' : '最常在 $bestHour 点观看',
              style: TextStyle(fontSize: 11, color: color.outline),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 82,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var h = 0; h < 24; h++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 4 +
                                  (_service.hourSeconds(h) / max)
                                          .clamp(0.0, 1.0)
                                          .toDouble() *
                                      54,
                              decoration: BoxDecoration(
                                color: h == bestHour
                                    ? color.primary
                                    : color.primary.withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (h % 6 == 0 || h == 23)
                              Text(
                                '$h',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: color.outline,
                                ),
                              )
                            else
                              const SizedBox(height: 10),
                          ],
                        ),
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

  Widget _monthsCard(ThemeData theme) {
    final color = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '月度 / 年度',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metric(color, '本月', _format(_service.monthSeconds)),
                _metric(color, '今年', _format(_service.yearSeconds)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metric(color, '活跃天数', '${_service.activeDays} 天'),
                _metric(color, '最长连续', '${_service.maxStreak} 天'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '看完 ${_service.completedVideos} / ${_service.startedVideos} 个视频'
              ' · 完播率 ${_completionRate()}%',
              style: TextStyle(fontSize: 12, color: color.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementsCard(ThemeData theme) {
    final total = _service.totalSeconds;
    final topAuthors = _service.topAuthors(limit: 1);
    final topSeconds = topAuthors.isEmpty ? 0 : topAuthors.first.seconds;
    final achievements = <_Achievement>[
      _Achievement(
        Icons.play_circle_outline,
        '初次观影',
        '开始记录观看时间',
        total > 0,
      ),
      _Achievement(
        Icons.timelapse,
        '十小时',
        '累计观看 10 小时',
        total >= 10 * 3600,
      ),
      _Achievement(
        Icons.local_fire_department,
        '百小时',
        '累计观看 100 小时',
        total >= 100 * 3600,
      ),
      _Achievement(
        Icons.emoji_events,
        '千小时',
        '累计观看 1000 小时',
        total >= 1000 * 3600,
      ),
      _Achievement(
        Icons.calendar_month,
        '连看 3 天',
        '连续 3 天观看',
        _service.maxStreak >= 3,
      ),
      _Achievement(
        Icons.calendar_month,
        '连看 7 天',
        '连续 7 天观看',
        _service.maxStreak >= 7,
      ),
      _Achievement(
        Icons.calendar_month,
        '连看 30 天',
        '连续 30 天观看',
        _service.maxStreak >= 30,
      ),
      _Achievement(
        Icons.bolt,
        '单日 3 小时',
        '一天看了 3 小时',
        _service.maxDaySeconds >= 3 * 3600,
      ),
      _Achievement(
        Icons.check_circle_outline,
        '看完一部',
        '完整看完 1 个视频',
        _service.completedVideos >= 1,
      ),
      _Achievement(
        Icons.task_alt,
        '看完十部',
        '完整看完 10 个视频',
        _service.completedVideos >= 10,
      ),
      _Achievement(
        Icons.people_outline,
        '关注广泛',
        '看过 10 位不同 UP',
        _service.distinctAuthors >= 10,
      ),
      _Achievement(
        Icons.nights_stay,
        '夜猫子',
        '凌晨 0-5 点观看 1 小时',
        _service.lateNightSeconds >= 3600,
      ),
      _Achievement(
        Icons.wb_sunny_outlined,
        '早起鸟',
        '早上 5-8 点观看 1 小时',
        _service.earlySeconds >= 3600,
      ),
      _Achievement(
        Icons.weekend,
        '周末战士',
        '周末累计观看 5 小时',
        _service.weekendSeconds >= 5 * 3600,
      ),
      _Achievement(
        Icons.date_range,
        '常驻观众',
        '累计活跃 30 天',
        _service.activeDays >= 30,
      ),
      _Achievement(
        Icons.nightlight_round,
        '凌晨三点',
        '凌晨 3 点还在看视频',
        _service.hourSeconds(3) > 0,
      ),
      _Achievement(
        Icons.favorite,
        '单推狂魔',
        '一半观看时间给了同一个 UP',
        total > 3600 && topSeconds >= total ~/ 2,
      ),
    ];
    final unlocked = achievements.where((e) => e.unlocked).length;
    final color = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '成就',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$unlocked / ${achievements.length}',
                  style: TextStyle(fontSize: 12, color: color.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in achievements)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: item.unlocked ? color.primary : color.outline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: item.unlocked ? null : color.outline,
                            ),
                          ),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: color.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      item.unlocked
                          ? Icons.check_circle
                          : Icons.lock_outline,
                      size: 18,
                      color: item.unlocked ? color.primary : color.outline,
                    ),
                  ],
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
                      'Lv${((authors[i].seconds / 3600 / 10).floor() + 1).clamp(1, 10)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
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

  int _completionRate() {
    final started = _service.startedVideos;
    if (started <= 0) return 0;
    return (_service.completedVideos / started * 100).round();
  }

  String _buildReport() {
    final level = _levelFor(_service.totalSeconds);
    final authors = _service.topAuthors(limit: 3);
    final buffer = StringBuffer()
      ..writeln('PiliPlus 观看统计')
      ..writeln('等级：${level.name}')
      ..writeln('今日：${_format(_service.todaySeconds)}')
      ..writeln('本周：${_format(_service.weekSeconds)}')
      ..writeln('本月：${_format(_service.monthSeconds)}')
      ..writeln('累计：${_format(_service.totalSeconds)}')
      ..writeln('连续观看：${_service.currentStreak} 天')
      ..writeln(
        '看完：${_service.completedVideos} / ${_service.startedVideos} 个视频',
      );
    if (authors.isNotEmpty) {
      buffer.writeln(
        '最常看：${authors.map((e) => '${e.author}（${_format(e.seconds)}）').join('、')}',
      );
    }
    return buffer.toString();
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

const _levelNames = [
  '云观众',
  '萌新观众',
  '常驻观众',
  '老观众',
  '资深观众',
  '骨灰观众',
  '传说观众',
];

const _levelHours = [0, 1, 10, 50, 100, 300, 1000];

_LevelInfo _levelFor(int totalSeconds) {
  final hours = totalSeconds / 3600;
  var index = 0;
  for (var i = 0; i < _levelHours.length; i++) {
    if (hours >= _levelHours[i]) index = i;
  }
  return _LevelInfo(
    index: index,
    name: 'LV$index ${_levelNames[index]}',
    minHours: _levelHours[index],
    nextHours: index < _levelHours.length - 1
        ? _levelHours[index + 1]
        : null,
  );
}

class _LevelInfo {
  final int index;
  final String name;
  final int minHours;
  final int? nextHours;

  const _LevelInfo({
    required this.index,
    required this.name,
    required this.minHours,
    required this.nextHours,
  });
}

class _Achievement {
  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;

  const _Achievement(this.icon, this.title, this.description, this.unlocked);
}

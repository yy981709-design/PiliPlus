import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/history/widgets/item.dart' show onPushHistory;
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:material_ui/material_ui.dart';

/// 首页「继续观看」横条：只显示没看完的视频。
class ContinueWatchingBar extends StatelessWidget {
  const ContinueWatchingBar({
    super.key,
    required this.items,
    required this.onMore,
  });

  final List<HistoryItemModel> items;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 8, 0),
          child: Row(
            children: [
              Text(
                '继续观看',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onMore,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('全部'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _card(context, items[index]),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, HistoryItemModel item) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final duration = item.duration ?? 0;
    final progress = item.progress ?? 0;
    final ratio = duration > 0
        ? (progress / duration).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return SizedBox(
      width: 176,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          onPushHistory(item);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  NetworkImgLayer(
                    src: item.cover?.isNotEmpty == true
                        ? item.cover!
                        : (item.covers?.isNotEmpty == true
                              ? item.covers!.first
                              : ''),
                    width: 176,
                    height: 92,
                  ),
                  if (duration > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${DurationUtils.formatDuration(progress)} / '
                          '${DurationUtils.formatDuration(duration)}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 3,
                      backgroundColor: color.secondaryContainer,
                      color: color.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.title ?? '未知视频',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

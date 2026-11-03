import 'package:PiliPlus/models/common/enum_with_label.dart';

enum SaveFileNameStyle implements EnumWithLabel {
  titleBvid('标题 + BV 号', '示例：视频标题_BV1xx411c7mD'),
  title('仅标题', '示例：视频标题'),
  bvid('仅 BV 号', '示例：BV1xx411c7mD'),
  ;

  const SaveFileNameStyle(this.label, this.desc);

  @override
  final String label;
  final String desc;
}

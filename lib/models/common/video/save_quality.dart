import 'package:PiliPlus/models/common/enum_with_label.dart';

enum SaveVideoQuality implements EnumWithLabel {
  auto('智能', '优先高画质，失败自动回退'),
  high('高画质', '合并音视频，保存 1080P/4K'),
  low('省空间', '直接下载 MP4 直链，速度更快'),
  ;

  const SaveVideoQuality(this.label, this.desc);

  @override
  final String label;
  final String desc;
}

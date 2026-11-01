import 'package:PiliPlus/models_new/reply/picture.dart';

class ReplyContent {
  String? message;
  List<dynamic>? members;
  Map? jumpUrl;
  Map<String, dynamic>? emotes;
  int? maxLine;
  List<ReplyPicture>? pictures;
  double? pictureScale;

  ReplyContent({
    this.message,
    this.members,
    this.jumpUrl,
    this.emotes,
    this.maxLine,
    this.pictures,
    this.pictureScale,
  });

  factory ReplyContent.fromJson(Map<String, dynamic> json) => ReplyContent(
    message: json['message'] as String?,
    members: json['members'] as List<dynamic>?,
    jumpUrl: json['jump_url'],
    emotes: json['emote'] is Map
        ? Map<String, dynamic>.from(json['emote'] as Map)
        : (json['emotes'] is Map
              ? Map<String, dynamic>.from(json['emotes'] as Map)
              : null),
    maxLine: json['max_line'] as int?,
    pictures: (json['pictures'] as List<dynamic>?)
        ?.map((e) => ReplyPicture.fromJson(e as Map<String, dynamic>))
        .toList(),
    pictureScale: (json['picture_scale'] as num?)?.toDouble(),
  );
}

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/reply.dart';
import 'package:PiliPlus/models_new/reply/content.dart';
import 'package:PiliPlus/models_new/reply/reply.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class CommentDetailPage extends StatefulWidget {
  const CommentDetailPage({
    super.key,
    required this.comment,
    required this.oid,
  });

  final ReplyItemModel comment;
  final int oid;

  @override
  State<CommentDetailPage> createState() => _CommentDetailPageState();
}

class _CommentDetailPageState extends State<CommentDetailPage> {
  final List<ReplyItemModel> _replies = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _replies.addAll(widget.comment.replies ?? const []);
    _loadAll();
  }

  Future<void> _loadAll() async {
    final rpid = widget.comment.rpid;
    if (rpid == null) return;
    final count = widget.comment.count ?? 0;
    if (_replies.length >= count) return;
    _loading = true;
    if (mounted) setState(() {});
    final loaded = <ReplyItemModel>[];
    for (var page = 1; page <= 5; page++) {
      final res = await ReplyHttp.replyReplyList(
        isLogin: Accounts.main.isLogin,
        oid: widget.oid,
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
    _replies
      ..clear()
      ..addAll(loaded);
    _loading = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17181A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17181A),
        foregroundColor: Colors.white,
        title: const Text('评论详情'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildComment(widget.comment, main: true),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Text(
                  '相关回复共 ${widget.comment.count ?? _replies.length} 条',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
          for (final reply in _replies)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildComment(reply),
            ),
        ],
      ),
    );
  }

  Widget _buildComment(ReplyItemModel reply, {bool main = false}) {
    final avatar = reply.member?.avatar;
    final level = reply.member?.levelInfo?.currentLevel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: avatar != null && avatar.isNotEmpty
              ? Image.network(
                  avatar,
                  width: main ? 40 : 32,
                  height: main ? 40 : 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person,
                    color: Colors.white54,
                  ),
                )
              : const Icon(Icons.person, color: Colors.white54),
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
                  if (level != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: BiliUtils.levelPicture(level, height: 11),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _buildMessage(reply.content, main: main),
              _buildPictures(reply.content),
              if ((reply.like ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${reply.like} 赞',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(ReplyContent? content, {bool main = false}) {
    final text = content?.message ?? '';
    final emotes = content?.emotes;
    final style = TextStyle(
      color: Colors.white,
      fontSize: main ? 14 : 13,
      height: 1.5,
    );
    if (text.isEmpty) return const Text('');
    if (emotes == null || emotes.isEmpty) return Text(text, style: style);
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
      final data = emotes[key];
      String? url;
      if (data is Map) {
        for (final k in const ['url', 'gif_url', 'webp_url']) {
          final v = data[k];
          if (v is String && v.isNotEmpty) {
            url = v;
            break;
          }
        }
      }
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
    return Text.rich(TextSpan(children: spans), style: style);
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
          for (final pic in pictures.take(6))
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                pic.imgSrc ?? '',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

void showCommentDetailSheet(
  BuildContext context,
  ReplyItemModel comment,
  int oid,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: CommentDetailPage(comment: comment, oid: oid),
      ),
    ),
  );
}

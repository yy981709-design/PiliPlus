import 'package:PiliPlus/http/follow.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models_new/follow/list.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class FollowBatchPage extends StatefulWidget {
  const FollowBatchPage({super.key});

  @override
  State<FollowBatchPage> createState() => _FollowBatchPageState();
}

class _FollowBatchPageState extends State<FollowBatchPage> {
  final List<FollowItemModel> _all = [];
  final Map<int, int> _mtime = {};
  final Set<int> _selected = {};
  List<FollowItemModel> _shown = [];
  String _category = '全部';
  bool _loading = true;
  bool _processing = false;
  bool _relationsLoaded = false;
  String? _error;

  static const _categories = [
    '全部',
    '半年前',
    '一年前',
    '更早',
    '最常访问',
    '不常看',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    for (var pn = 1; pn <= 8; pn++) {
      final res = await FollowHttp.followings(
        vmid: Accounts.main.mid,
        pn: pn,
        ps: 20,
      );
      if (res case Success(:final response)) {
        final list = response.list ?? const <FollowItemModel>[];
        _all.addAll(list.where((e) => e.mid > 0));
        if (list.length < 20) break;
      } else {
        _error = res.toString();
        break;
      }
    }
    _shown = List.of(_all);
    _loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _loadRelations() async {
    if (_relationsLoaded) return;
    _relationsLoaded = true;
    for (var i = 0; i < _all.length; i += 10) {
      await Future.wait(
        _all.skip(i).take(10).map((user) async {
          final res = await UserHttp.userRelation(user.mid);
          if (res case Success(:final response)) {
            if (response.mtime != null) _mtime[user.mid] = response.mtime!;
          }
        }),
      );
    }
  }

  Future<void> _selectCategory(String category) async {
    setState(() {
      _category = category;
      _loading = true;
    });
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (category == '半年前' || category == '一年前' || category == '更早') {
      await _loadRelations();
    }
    if (category == '最常访问' || category == '不常看') {
      final res = await FollowHttp.followings(
        vmid: Accounts.main.mid,
        pn: 1,
        ps: 50,
        orderType: 'attention',
      );
      if (res case Success(:final response)) {
        final recent = (response.list ?? const <FollowItemModel>[])
            .map((e) => e.mid)
            .toSet();
        if (category == '最常访问') {
          _shown = _all.where((e) => recent.contains(e.mid)).toList();
        } else {
          _shown = _all.where((e) => !recent.contains(e.mid)).toList();
        }
        _selected.clear();
        _loading = false;
        if (mounted) setState(() {});
        return;
      }
    }
    _shown = switch (category) {
      '半年前' => _all.where((e) {
        final t = _mtime[e.mid];
        return t != null && now - t >= 180 * 86400;
      }).toList(),
      '一年前' => _all.where((e) {
        final t = _mtime[e.mid];
        return t != null && now - t >= 365 * 86400;
      }).toList(),
      '更早' => _all.where((e) {
        final t = _mtime[e.mid];
        return t != null && now - t >= 2 * 365 * 86400;
      }).toList(),
      _ => List.of(_all),
    };
    _selected.clear();
    _loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _unfollowSelected() async {
    if (_selected.isEmpty || _processing) return;
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    if (Accounts.main.csrf.isEmpty) {
      SmartDialog.showToast('登录状态异常，请重新登录');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量取消关注'),
        content: Text('确定取消关注选中的 ${_selected.length} 位 UP 主？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _processing = true);
    var ok = 0;
    final errors = <String>[];
    final names = {for (final u in _all) u.mid: u.uname ?? u.mid.toString()};
    for (final mid in _selected.toList()) {
      try {
        final res = await VideoHttp.relationMod(mid: mid, act: 2, reSrc: 11);
        if (res.isSuccess) {
          ok++;
        } else {
          errors.add('${names[mid] ?? mid}: $res');
        }
      } catch (e) {
        errors.add('${names[mid] ?? mid}: $e');
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _selected.clear();
    _processing = false;
    if (mounted) setState(() {});
    if (errors.isEmpty) {
      SmartDialog.showToast('已取消关注 $ok 位');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('完成：成功 $ok 位，失败 ${errors.length} 位'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final error in errors.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(error, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('批量取消关注'),
        actions: [
          TextButton(
            onPressed: _shown.isEmpty
                ? null
                : () => setState(() {
                    if (_selected.length == _shown.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(_shown.map((e) => e.mid));
                    }
                  }),
            child: Text(
              _selected.length == _shown.length && _shown.isNotEmpty
                  ? '取消全选'
                  : '全选',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _categories[index];
                return ChoiceChip(
                  label: Text(item),
                  selected: _category == item,
                  onSelected: (_) => _selectCategory(item),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _shown.isEmpty
                ? Center(
                    child: Text(
                      _error == null || _error!.isEmpty
                          ? '当前分类没有可管理的关注'
                          : '加载失败：$_error',
                    ),
                  )
                : ListView.builder(
                    itemCount: _shown.length,
                    itemBuilder: (context, index) {
                      final user = _shown[index];
                      return CheckboxListTile(
                        value: _selected.contains(user.mid),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(user.mid);
                            } else {
                              _selected.remove(user.mid);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          backgroundImage: user.face?.isNotEmpty == true
                              ? NetworkImage(user.face!)
                              : null,
                          child: user.face?.isNotEmpty == true
                              ? null
                              : const Icon(Icons.person),
                        ),
                        title: Text(user.uname ?? '未知用户'),
                        subtitle: Text(user.sign ?? ''),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton(
            onPressed: _selected.isEmpty || _processing
                ? null
                : _unfollowSelected,
            child: Text(
              _processing ? '处理中...' : '取消关注（${_selected.length}）',
            ),
          ),
        ),
      ),
    );
  }
}

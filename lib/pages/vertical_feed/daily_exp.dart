import 'package:PiliPlus/http/daily_exp.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class DailyExpSheet extends StatefulWidget {
  const DailyExpSheet({super.key, this.bvid, this.aid});

  final String? bvid;
  final int? aid;

  @override
  State<DailyExpSheet> createState() => _DailyExpSheetState();
}

class _DailyExpSheetState extends State<DailyExpSheet> {
  DailyExpStatus? _status;
  bool _loading = true;
  bool _running = false;
  bool _enableWatch = Pref.dailyExpWatch;
  bool _enableShare = Pref.dailyExpShare;
  bool _enableCoin = Pref.dailyExpCoin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await DailyExpHttp.reward();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res case Success(:final response)) _status = response;
    });
    if (res case Error(:final errMsg)) {
      SmartDialog.showToast(errMsg ?? '经验状态加载失败');
    }
  }

  Future<void> _run() async {
    if (_running) return;
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    _running = true;
    setState(() {});
    final messages = <String>[];
    if (_enableShare && _status?.share != true) {
      if (widget.bvid == null) {
        messages.add('分享任务需从竖屏视频进入');
      } else {
        final res = await DailyExpHttp.shareVideo(bvid: widget.bvid!);
        messages.add(res.isSuccess ? '分享任务完成' : '分享失败');
      }
    }
    if (_enableCoin && (_status?.coins ?? 0) < 50) {
      if (widget.bvid == null) {
        messages.add('投币任务需从竖屏视频进入');
        return _finish(messages);
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('投币任务'),
          content: const Text('是否投 1 个硬币到当前视频？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('投 1 币'),
            ),
          ],
        ),
      );
      if (ok == true) {
        final res = await VideoHttp.coinVideo(
          bvid: widget.bvid!,
          multiply: 1,
        );
        messages.add(res.isSuccess ? '投币任务完成' : '投币失败');
      }
    }
    if (_enableWatch && _status?.watch != true) {
      messages.add('观看任务需要实际观看，已跳过');
    }
    return _finish(messages);
  }

  Future<void> _finish(List<String> messages) async {
    _running = false;
    await _load();
    if (mounted) {
      SmartDialog.showToast(
        messages.isEmpty ? '没有可自动完成的任务' : messages.join('；'),
      );
    }
  }

  Future<void> _claimVip() async {
    final res = await UserHttp.vipExpAdd();
    SmartDialog.showToast(res.isSuccess ? '大会员经验领取成功' : '领取失败');
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.68;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF17181A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        '今日经验',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    children: [
                      _task('每日登录', '+5 经验', _status?.login == true),
                      _task(
                        '观看视频',
                        '+5 经验',
                        _status?.watch == true,
                        switchValue: _enableWatch,
                        onSwitch: (v) {
                          setState(() => _enableWatch = v);
                          GStorage.setting.put(SettingBoxKey.dailyExpWatch, v);
                        },
                      ),
                      _task(
                        '分享视频',
                        '+5 经验',
                        _status?.share == true,
                        switchValue: _enableShare,
                        onSwitch: (v) {
                          setState(() => _enableShare = v);
                          GStorage.setting.put(SettingBoxKey.dailyExpShare, v);
                        },
                      ),
                      _task(
                        '投币经验',
                        '${_status?.coins ?? 0}/50',
                        (_status?.coins ?? 0) >= 50,
                        switchValue: _enableCoin,
                        onSwitch: (v) {
                          setState(() => _enableCoin = v);
                          GStorage.setting.put(SettingBoxKey.dailyExpCoin, v);
                        },
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _running ? null : _run,
                            child: Text(_running ? '处理中...' : '一键完成已启用任务'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _claimVip,
                            child: const Text('领取大会员经验'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _task(
    String title,
    String exp,
    bool done, {
    bool? switchValue,
    ValueChanged<bool>? onSwitch,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(exp, style: const TextStyle(color: Colors.white54)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (switchValue != null)
            Switch(
              value: switchValue,
              activeColor: const Color(0xFFFF6699),
              onChanged: onSwitch,
            ),
          const SizedBox(width: 8),
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? const Color(0xFF4CAF50) : Colors.white38,
          ),
        ],
      ),
    );
  }
}

void showDailyExpSheet({String? bvid, int? aid}) {
  final context = Get.context;
  if (context == null) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DailyExpSheet(bvid: bvid, aid: aid),
  );
}

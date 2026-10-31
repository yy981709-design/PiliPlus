import 'dart:async';
import 'dart:math';

import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class HomeController extends GetxController
    with GetSingleTickerProviderStateMixin, ScrollOrRefreshMixin {
  late List<HomeTabType> tabs;
  late TabController tabController;

  RxBool? showTopBar;
  late final bool hideTopBar;

  bool enableSearchWord = Pref.enableSearchWord;
  late final RxString defaultSearch = ''.obs;
  late int lateCheckSearchAt = 0;

  /// 首页「继续观看」：只保留没看完的普通视频/番剧/课堂。
  final RxList<HistoryItemModel> continueWatching = <HistoryItemModel>[].obs;
  late final RxBool showContinueWatching = Pref.showContinueWatching.obs;
  bool _continueLoaded = false;
  Worker? _loginWorker;

  ScrollOrRefreshMixin get controller => tabs[tabController.index].ctr();

  @override
  ScrollController get scrollController => controller.scrollController;

  AccountService accountService = Get.find<AccountService>();

  @override
  void onInit() {
    super.onInit();

    hideTopBar = !Pref.useSideBar && Pref.hideTopBar;
    if (hideTopBar) {
      final mainCtr = Get.find<MainController>();
      switch (mainCtr.barHideType) {
        case .instant:
          showTopBar = RxBool(true);
        case .sync:
          mainCtr.barOffset ??= RxDouble(0.0);
      }
    }

    if (enableSearchWord) {
      lateCheckSearchAt = DateTime.now().millisecondsSinceEpoch;
      querySearchDefault();
    }

    setTabConfig();

    _loginWorker = ever(accountService.isLogin, (isLogin) {
      if (isLogin) fetchContinueWatching(force: true);
    });
    fetchContinueWatching();
  }

  @override
  Future<void> onRefresh() {
    fetchContinueWatching(force: true);
    return controller.onRefresh().catchError((e) {
      if (kDebugMode) debugPrint(e.toString());
    });
  }

  Future<void> fetchContinueWatching({bool force = false}) async {
    if (!force && _continueLoaded) return;
    _continueLoaded = true;
    if (!accountService.isLogin.value) {
      continueWatching.clear();
      return;
    }
    try {
      final res = await UserHttp.historyList(type: 'all', ps: 20);
      if (res case Success(:final response)) {
        final list = response.list ?? const <HistoryItemModel>[];
        continueWatching.value = list.where((e) {
          final progress = e.progress;
          final duration = e.duration;
          if (progress == null || duration == null) return false;
          if (progress <= 0 || duration <= 0 || progress == -1) return false;
          // 留一点余量：最后 15 秒视为已看完
          if (progress >= duration - 15) return false;
          final business = e.history.business;
          if (business == 'live') return false;
          if (business?.contains('article') == true) return false;
          return true;
        }).take(6).toList();
      }
    } catch (_) {}
  }

  void setTabConfig() {
    final tabs = GStorage.setting.get(SettingBoxKey.tabBarSort) as List?;
    if (tabs != null) {
      this.tabs = tabs.map((i) => HomeTabType.values[i]).toList();
    } else {
      this.tabs = HomeTabType.values;
    }

    tabController = TabController(
      initialIndex: max(0, this.tabs.indexOf(HomeTabType.rcmd)),
      length: this.tabs.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _loginWorker?.dispose();
    tabController.dispose();
    super.dispose();
  }

  Future<void> querySearchDefault() async {
    try {
      final res = await Request().get(
        Api.searchDefault,
        queryParameters: await WbiSign.makSign({'web_location': 333.1365}),
      );
      if (res.data['code'] == 0) {
        defaultSearch.value = res.data['data']?['name'] ?? '';
        // defaultSearch.value = res.data['data']?['show_name'] ?? '';
      }
    } catch (_) {}
  }
}

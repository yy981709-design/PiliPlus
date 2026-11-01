import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:dio/dio.dart';

class DailyExpStatus {
  bool? login;
  bool? watch;
  bool? share;
  int? coins;

  DailyExpStatus({this.login, this.watch, this.share, this.coins});

  factory DailyExpStatus.fromJson(Map<String, dynamic> json) =>
      DailyExpStatus(
        login: json['login'] as bool?,
        watch: json['watch'] as bool?,
        share: json['share'] as bool?,
        coins: json['coins'] as int?,
      );
}

abstract final class DailyExpHttp {
  static Future<LoadingState<DailyExpStatus>> reward() async {
    final res = await Request().get(Api.dailyExpReward);
    if (res.data['code'] == 0) {
      return Success(DailyExpStatus.fromJson(res.data['data']));
    }
    return Error(res.data['message']);
  }

  static Future<LoadingState<void>> shareVideo({
    required String bvid,
  }) async {
    final res = await Request().post(
      Api.shareVideo,
      data: {'bvid': bvid, 'csrf': Accounts.main.csrf},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    }
    return Error(res.data['message']);
  }
}

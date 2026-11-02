import 'dart:io';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:saver_gallery/saver_gallery.dart';

Future<void> saveVideoToGallery({
  required String bvid,
  required int cid,
  required String title,
}) async {
  SmartDialog.showLoading(msg: '正在获取视频直链...');
  try {
    final res = await VideoHttp.videoUrl(
      bvid: bvid,
      cid: cid,
      qn: 64,
      tryLook: true,
      videoType: VideoType.ugc,
      fnval: 1,
    );
    if (res case Success(:final response)) {
      final durl = response.durl;
      if (durl == null || durl.isEmpty) {
        SmartDialog.dismiss();
        SmartDialog.showToast('该视频没有 MP4 直链，暂时无法直接保存到相册');
        return;
      }
      final first = durl.first;
      final url = first.url;
      if (url == null || url.isEmpty) {
        SmartDialog.dismiss();
        SmartDialog.showToast('没有可用的下载地址');
        return;
      }
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在下载视频...');
      final dir = await Directory.systemTemp.createTemp('pili_save_');
      final file = File('${dir.path}/video.mp4');
      await Request.dio.download(
        url,
        file.path,
        options: Options(
          headers: {
            'referer': 'https://www.bilibili.com/video/$bvid',
            'user-agent': BrowserUa.pc,
          },
        ),
      );
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在保存到相册...');
      final save = await SaverGallery.saveFile(
        filePath: file.path,
        fileName: 'PiliPlus_${bvid}.mp4',
        albumPath: 'PiliPlus',
        skipIfExists: false,
      );
      SmartDialog.dismiss();
      if (save.isSuccess) {
        SmartDialog.showToast('已保存到相册：PiliPlus');
      } else {
        SmartDialog.showToast('保存失败：${save.errorMessage}');
      }
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    } else {
      SmartDialog.dismiss();
      SmartDialog.showToast('获取视频地址失败：${res.toString()}');
    }
  } catch (e) {
    SmartDialog.dismiss();
    SmartDialog.showToast('保存失败：$e');
  }
}

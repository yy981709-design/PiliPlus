import 'dart:io';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/save_quality.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/pages/vertical_feed/mpv_save.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:saver_gallery/saver_gallery.dart';

Future<void> saveVideoToGallery({
  required String bvid,
  required int cid,
  required String title,
}) async {
  final quality = Pref.saveVideoQuality;
  if (quality == SaveVideoQuality.low) {
    await _saveMp4Direct(bvid: bvid, cid: cid);
    return;
  }
  final saved = await _saveHighQuality(bvid: bvid, cid: cid);
  if (!saved) {
    if (quality == SaveVideoQuality.auto) {
      await _saveMp4Direct(bvid: bvid, cid: cid);
    } else {
      SmartDialog.showToast('高画质保存失败，可在设置中切换为省空间');
    }
  }
}

Future<bool> _saveHighQuality({
  required String bvid,
  required int cid,
}) async {
  SmartDialog.showLoading(msg: '正在获取高画质地址...');
  try {
    final res = await VideoHttp.videoUrl(
      bvid: bvid,
      cid: cid,
      qn: 120,
      tryLook: true,
      videoType: VideoType.ugc,
    );
    if (res case Success(:final response)) {
      final dash = response.dash;
      final videos = dash?.video;
      if (videos == null || videos.isEmpty) {
        SmartDialog.dismiss();
        return false;
      }
      final video = videos.reduce(
        (a, b) => (a.height ?? 0) >= (b.height ?? 0) ? a : b,
      );
      final videoUrl = VideoUtils.getCdnUrl(video.playUrls);
      final audios = dash?.audio;
      final audio = audios == null || audios.isEmpty
          ? null
          : audios.reduce(
              (a, b) => (a.bandWidth ?? 0) >= (b.bandWidth ?? 0) ? a : b,
            );
      final audioUrl = audio == null
          ? null
          : VideoUtils.getCdnUrl(audio.playUrls, isAudio: true);
      final source = audioUrl == null
          ? videoUrl
          : 'edl://!no_chapters;%${video.length}%$videoUrl;'
                '!new_stream;!no_chapters;%${audio.length}%$audioUrl';

      final dir = await Directory.systemTemp.createTemp('pili_save_hq_');
      final out = File('${dir.path}/video.mp4');
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在合并高画质视频...');
      final ok = await MpvSaveVideo().save(source, out.path);
      if (!ok || !await out.exists() || await out.length() == 0) {
        SmartDialog.dismiss();
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
        return false;
      }
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在保存到相册...');
      final save = await SaverGallery.saveFile(
        filePath: out.path,
        fileName: 'PiliPlus_${bvid}_${video.height ?? 0}p.mp4',
        albumPath: 'PiliPlus',
        skipIfExists: false,
      );
      SmartDialog.dismiss();
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
      if (save.isSuccess) {
        SmartDialog.showToast('已保存高画质到相册：PiliPlus');
        return true;
      }
      SmartDialog.showToast('保存失败：${save.errorMessage}');
      return false;
    }
    SmartDialog.dismiss();
    return false;
  } catch (e) {
    SmartDialog.dismiss();
    return false;
  }
}

Future<void> _saveMp4Direct({
  required String bvid,
  required int cid,
}) async {
  SmartDialog.showLoading(msg: '正在获取 MP4 直链...');
  try {
    final res = await VideoHttp.videoUrl(
      bvid: bvid,
      cid: cid,
      qn: 112,
      tryLook: true,
      videoType: VideoType.ugc,
      fnval: 1,
    );
    if (res case Success(:final response)) {
      final durl = response.durl;
      if (durl == null || durl.isEmpty) {
        SmartDialog.dismiss();
        SmartDialog.showToast('该视频没有 MP4 直链，请把保存画质切换为「高画质」');
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

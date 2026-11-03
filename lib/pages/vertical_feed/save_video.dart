import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/save_file_name.dart';
import 'package:PiliPlus/models/common/video/save_quality.dart';
import 'package:PiliPlus/pages/vertical_feed/save_options.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:PiliPlus/services/download_notification.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:saver_gallery/saver_gallery.dart';

Future<void> saveVideoToGallery({
  required String bvid,
  required int cid,
  required String title,
  String? cover,
  SaveOptions? options,
}) async {
  final opt = options ??
      const SaveOptions(
        mediaType: SaveMediaType.video,
        qn: 120,
        saveCover: false,
      );
  await DownloadNotification.init();
  if (opt.mediaType == SaveMediaType.audio) {
    await _saveHighQuality(
      bvid: bvid,
      cid: cid,
      title: title,
      qn: opt.qn,
      audioOnly: true,
      cover: cover,
      saveCover: opt.saveCover,
      audioFormat: opt.audioFormat,
      effect: opt.effect,
    );
    return;
  }
  if (opt.mode == SaveVideoQuality.low) {
    await _saveMp4Direct(bvid: bvid, cid: cid, title: title);
    return;
  }
  final saved = await _saveHighQuality(
    bvid: bvid,
    cid: cid,
    title: title,
    qn: opt.qn,
    audioOnly: opt.mediaType == SaveMediaType.audio,
    cover: cover,
    saveCover: opt.saveCover,
    audioFormat: opt.audioFormat,
    effect: opt.effect,
  );
  if (!saved) {
    if (opt.mode == SaveVideoQuality.auto) {
      await _saveMp4Direct(bvid: bvid, cid: cid, title: title);
    } else {
      SmartDialog.showToast('高画质保存失败，可在设置中切换为省空间');
    }
  }
}

Future<void> _saveCover(String? cover, String bvid, String title) async {
  if (cover == null || cover.isEmpty) return;
  try {
    final res = await Request.dio.get<List<int>>(
      cover,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'user-agent': BrowserUa.pc},
      ),
    );
    final data = res.data;
    if (data == null || data.isEmpty) return;
    await SaverGallery.saveImage(
      Uint8List.fromList(data),
      fileName: '${_baseName(bvid, title)}.jpg',
      albumPath: 'PiliPlus',
      skipIfExists: false,
    );
  } catch (_) {}
}

String _baseName(String bvid, String title) {
  final style = Pref.saveFileNameStyle;
  final safeTitle = title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final name = switch (style) {
    SaveFileNameStyle.titleBvid =>
      safeTitle.isEmpty ? bvid : 'PiliPlus_${safeTitle}_$bvid',
    SaveFileNameStyle.title =>
      safeTitle.isEmpty ? 'PiliPlus_$bvid' : 'PiliPlus_$safeTitle',
    SaveFileNameStyle.bvid => 'PiliPlus_$bvid',
  };
  return name.length > 120 ? name.substring(0, 120) : name;
}

String _effectFilter(AudioEffect effect) {
  return switch (effect) {
    AudioEffect.none => '',
    AudioEffect.battle =>
      'acrusher=bits=5:mix=0.55,lowpass=f=3200,highpass=f=180,volume=1.25',
    AudioEffect.telephone => 'highpass=f=300,lowpass=f=3400',
    AudioEffect.vinyl =>
      'aecho=0.8:0.7:40:0.35,highpass=f=100,lowpass=f=8000',
  };
}

String _audioCodec(SaveAudioFormat format, AudioEffect effect) {
  if (effect != AudioEffect.none) return '-c:a aac -b:a 192k';
  return switch (format) {
    SaveAudioFormat.copy => '-c:a copy',
    SaveAudioFormat.m4a => '-c:a aac -b:a 192k',
    SaveAudioFormat.mp3 => '-c:a libmp3lame -q:a 2',
  };
}

Future<bool> _saveHighQuality({
  required String bvid,
  required int cid,
  required String title,
  required int qn,
  required bool audioOnly,
  required String? cover,
  required bool saveCover,
  required SaveAudioFormat audioFormat,
  required AudioEffect effect,
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
      if (audioOnly && audioUrl == null) {
        SmartDialog.dismiss();
        SmartDialog.showToast('该视频没有可用的音频流');
        return false;
      }
      final dir = await Directory.systemTemp.createTemp('pili_save_hq_');
      final videoFile = File('${dir.path}/video.m4s');
      final audioFile = File('${dir.path}/audio.m4s');
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在下载高画质视频...');
      await DownloadNotification.progress(0, '准备下载...');
      final headers = {
        'referer': 'https://www.bilibili.com/video/$bvid',
        'user-agent': BrowserUa.pc,
      };
      if (!audioOnly) {
        await Request.dio.download(
          videoUrl,
          videoFile.path,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              DownloadNotification.progress(
                (received * 100 / total).round(),
                '下载视频中...',
              );
            }
          },
          options: Options(
            headers: headers,
            receiveTimeout: const Duration(minutes: 30),
          ),
        );
      }
      if (audioUrl != null) {
        await Request.dio.download(
          audioUrl,
          audioFile.path,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              DownloadNotification.progress(
                (received * 100 / total).round(),
                '下载音频中...',
              );
            }
          },
          options: Options(
            headers: headers,
            receiveTimeout: const Duration(minutes: 30),
          ),
        );
      }
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在用 ffmpeg 合并...');
      await DownloadNotification.progress(95, '正在合并...');
      final audioExt = audioOnly
          ? (audioFormat == SaveAudioFormat.mp3 ? 'mp3' : 'm4a')
          : 'mp4';
      final outName = audioOnly ? 'audio.$audioExt' : 'video.mp4';
      final out = File('${dir.path}/$outName');
      final effectFilter = _effectFilter(effect);
      final audioCodec = _audioCodec(audioFormat, effect);
      final command = audioOnly
          ? '-y -i "${audioFile.path}" -vn $audioCodec '
                '${effectFilter.isEmpty ? '' : '-af "$effectFilter" '}'
                '${audioFormat == SaveAudioFormat.mp3 ? '' : '-movflags +faststart '}'
                '"${out.path}"'
          : audioUrl == null
          ? '-y -i "${videoFile.path}" -c copy -movflags +faststart "${out.path}"'
          : '-y -i "${videoFile.path}" -i "${audioFile.path}" '
                '-map 0:v:0 -map 1:a:0? '
                '${effect == AudioEffect.none ? '-c copy' : '-c:v copy $audioCodec'} '
                '${effectFilter.isEmpty ? '' : '-af "$effectFilter" '}'
                '-movflags +faststart "${out.path}"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final ok = ReturnCode.isSuccess(returnCode) &&
          await out.exists() &&
          await out.length() > 1024;
      if (!ok) {
        final output = await session.getOutput() ?? '';
        await DownloadNotification.cancel();
        SmartDialog.dismiss();
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
        SmartDialog.showToast(
          'ffmpeg 合并失败：${output.length > 120 ? output.substring(output.length - 120) : output}',
        );
        return false;
      }
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在保存到相册...');
      final save = await SaverGallery.saveFile(
        filePath: out.path,
        fileName: audioOnly
            ? '${_baseName(bvid, title)}.${audioFormat == SaveAudioFormat.mp3 ? 'mp3' : 'm4a'}'
            : '${_baseName(bvid, title)}_${video.height ?? 0}p.mp4',
        albumPath: 'PiliPlus',
        skipIfExists: false,
      );
      SmartDialog.dismiss();
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
      if (save.isSuccess) {
        if (saveCover) await _saveCover(cover, bvid, title);
        await DownloadNotification.done('已保存到相册');
        SmartDialog.showToast('已保存到相册：PiliPlus');
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
  required String title,
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
      final parts = durl
          .where((item) => item.url?.isNotEmpty ?? false)
          .toList();
      if (parts.isEmpty) {
        SmartDialog.dismiss();
        SmartDialog.showToast('没有可用的下载地址');
        return;
      }
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在下载视频...');
      await DownloadNotification.progress(0, '准备下载...');
      final dir = await Directory.systemTemp.createTemp('pili_save_');
      final file = File('${dir.path}/video.mp4');
      final headers = {
        'referer': 'https://www.bilibili.com/video/$bvid',
        'user-agent': BrowserUa.pc,
      };
      if (parts.length == 1) {
        await Request.dio.download(
          parts.first.url!,
          file.path,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              DownloadNotification.progress(
                (received * 100 / total).round(),
                '下载视频中...',
              );
            }
          },
          options: Options(
            headers: headers,
            receiveTimeout: const Duration(minutes: 30),
          ),
        );
      } else {
        final sink = file.openWrite();
        try {
          for (var i = 0; i < parts.length; i++) {
            final partFile = File('${dir.path}/part_$i.mp4');
            await Request.dio.download(
              parts[i].url!,
              partFile.path,
              onReceiveProgress: (received, total) {
                if (total > 0) {
                  final part = (received / total).clamp(0.0, 1.0);
                  DownloadNotification.progress(
                    ((i + part) * 100 / parts.length).round(),
                    '下载视频中...',
                  );
                }
              },
              options: Options(
                headers: headers,
                receiveTimeout: const Duration(minutes: 30),
              ),
            );
            await sink.addStream(partFile.openRead());
            await partFile.delete();
          }
        } finally {
          await sink.close();
        }
      }
      final expected = parts.fold<int>(
        0,
        (sum, item) => sum + (item.size ?? 0),
      );
      final actual = await file.length();
      if (expected > 0 && actual < expected * 0.9) {
        SmartDialog.dismiss();
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
        SmartDialog.showToast(
          '下载不完整：${(actual / 1024 / 1024).toStringAsFixed(1)}MB / '
          '${(expected / 1024 / 1024).toStringAsFixed(1)}MB',
        );
        return;
      }
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在保存到相册...');
      final save = await SaverGallery.saveFile(
        filePath: file.path,
        fileName: '${_baseName(bvid, title)}.mp4',
        albumPath: 'PiliPlus',
        skipIfExists: false,
      );
      SmartDialog.dismiss();
      if (save.isSuccess) {
        await DownloadNotification.done('已保存到相册');
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
    await DownloadNotification.cancel();
    SmartDialog.dismiss();
    SmartDialog.showToast('保存失败：$e');
  }
}

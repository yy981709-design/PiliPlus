// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:ffi';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:media_kit/ffi/src/allocation.dart';
import 'package:media_kit/ffi/src/utf8.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit/src/player/native/core/initializer.dart';

class MpvSaveVideo {
  final _mpv = NativePlayer.mpv;
  late final Pointer<generated.mpv_handle> _ctx;
  final _completer = Completer<bool>();
  bool _success = false;

  Future<bool> save(
    String url,
    String outFile, {
    double? start,
    double? end,
  }) async {
    _ctx = await Initializer.create(
      _mpv,
      _onEvent,
      options: {
        'idle': 'once',
        'o': outFile,
        'of': 'mp4',
        'ovc': 'copy',
        'oac': 'copy',
        'force-window': 'no',
        if (start != null) 'start': start.toStringAsFixed(3),
        if (end != null) 'end': end.toStringAsFixed(3),
      },
    );
    NativePlayer.setHeader(
      _mpv,
      _ctx,
      userAgent: BrowserUa.pc,
      referer: HttpString.baseUrl,
    );
    _command(['loadfile', url]);
    return _completer.future.timeout(
      const Duration(minutes: 30),
      onTimeout: () {
        dispose();
        return false;
      },
    );
  }

  Future<void>? _onEvent(Pointer<generated.mpv_event> event) {
    switch (event.ref.event_id) {
      case generated.mpv_event_id.MPV_EVENT_FILE_LOADED:
        _success = true;
        break;
      case generated.mpv_event_id.MPV_EVENT_SHUTDOWN:
        if (!_completer.isCompleted) _completer.complete(_success);
        dispose();
        break;
    }
    return null;
  }

  void _command(List<String> args) {
    final pointers = args.map((e) => e.toNativeUtf8()).toList();
    final arr = calloc<Pointer<Uint8>>(pointers.length + 1);
    for (int i = 0; i < pointers.length; i++) {
      arr[i] = pointers[i];
    }
    _mpv.mpv_command(_ctx, arr);
    calloc.free(arr);
    pointers.forEach(calloc.free);
  }

  void dispose() {
    try {
      Initializer.dispose(_ctx);
      _mpv.mpv_terminate_destroy(_ctx);
    } catch (_) {}
  }
}

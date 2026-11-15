import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Opens Android's share sheet. Sharing never blocks or breaks the game:
/// failures are reported as `false`.
abstract class ShareService {
  /// Shares a PNG image together with a text (the text carries the link).
  Future<bool> shareImage({
    required Uint8List png,
    required String fileName,
    required String text,
  });

  /// Shares text only.
  Future<bool> shareText(String text);
}

/// Implementation on top of `share_plus`.
class PluginShareService implements ShareService {
  /// Diagnostics for on-device tests.
  int sharesOpened = 0;

  @override
  Future<bool> shareImage({
    required Uint8List png,
    required String fileName,
    required String text,
  }) async {
    try {
      sharesOpened++;
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile.fromData(png, mimeType: 'image/png')],
          fileNameOverrides: [fileName],
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Share failed: $e');
      return false;
    }
  }

  @override
  Future<bool> shareText(String text) async {
    try {
      sharesOpened++;
      await SharePlus.instance.share(ShareParams(text: text));
      return true;
    } catch (e) {
      debugPrint('Share failed: $e');
      return false;
    }
  }
}

/// Records what would be shared (tests).
class RecordingShareService implements ShareService {
  final List<String> texts = [];
  final List<Uint8List> images = [];

  @override
  Future<bool> shareImage({
    required Uint8List png,
    required String fileName,
    required String text,
  }) async {
    images.add(png);
    texts.add(text);
    return true;
  }

  @override
  Future<bool> shareText(String text) async {
    texts.add(text);
    return true;
  }
}

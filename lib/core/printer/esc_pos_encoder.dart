import 'dart:convert';
import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';

class EscPosEncoder {
  static const List<int> _esc = [0x1B];
  static const List<int> _gs = [0x1D];

  final List<int> _bytes = [];

  Uint8List get bytes => Uint8List.fromList(_bytes);

  void reset() {
    print('EscPosEncoder: Resetting printer state (ESC @)');
    _bytes.clear();
    _bytes.addAll([..._esc, 0x40]); // ESC @
  }

  Future<void> text(String text, {bool bold = false, bool doubleHeight = false, bool doubleWidth = false, String align = 'left'}) async {
    print('EscPosEncoder: Adding text: "$text" (align: $align, bold: $bold, dH: $doubleHeight, dW: $doubleWidth)');
    setAlign(align);
    setStyles(bold: bold, doubleHeight: doubleHeight, doubleWidth: doubleWidth);
    
    try {
      Uint8List encoded;
      // Try multiple charset names for Korean (EUC-KR is more standard on some Windows environments)
      try {
        encoded = await CharsetConverter.encode('EUC-KR', text);
      } catch (_) {
        try {
          encoded = await CharsetConverter.encode('CP949', text);
        } catch (_) {
          // Some systems might use numeric ID or a different variant
          encoded = await CharsetConverter.encode('949', text);
        }
      }
      _bytes.addAll(encoded);
    } catch (e) {
      print('EscPosEncoder: All Korean encodings failed for "$text": $e. Falling back to UTF-8.');
      _bytes.addAll(utf8.encode(text));
    }
  }

  void lineFeed([int n = 1]) {
    for (int i = 0; i < n; i++) {
        _bytes.add(0x0A);
    }
  }

  void setAlign(String align) {
    int n = 0;
    if (align == 'center') n = 1;
    else if (align == 'right') n = 2;
    _bytes.addAll([..._esc, 0x61, n]); // ESC a n
  }

  void setStyles({bool bold = false, bool doubleHeight = false, bool doubleWidth = false}) {
    int n = 0;
    if (bold) n |= 0x08;
    if (doubleHeight) n |= 0x10;
    if (doubleWidth) n |= 0x20;
    _bytes.addAll([..._esc, 0x21, n]); // ESC ! n
  }

  void cut() {
    print('EscPosEncoder: Adding cut command (ESC i)');
    _bytes.addAll([..._esc, 0x64, 3]); // Feed 3 lines
    _bytes.addAll([..._esc, 0x69]);    // ESC i (Partial cut)
  }

  Future<void> dashLine([int width = 42]) async {
    await text('-' * width);
    lineFeed();
  }

  Future<void> doubleDashLine([int width = 42]) async {
    await text('=' * width);
    lineFeed();
  }
}

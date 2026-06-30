import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/forms/data/signature_form_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodeSignaturePngForApi serializes drawable strokes as PNG base64', () async {
    final encoded = await encodeSignaturePngForApi([
      [const Offset(10, 20), const Offset(30, 40), const Offset(80, 35)],
    ]);

    expect(encoded, isNotNull);
    expect(isSignaturePngBase64Payload(encoded!), isTrue);
    final bytes = decodeSignaturePngValue(encoded);
    expect(bytes, isNotNull);
    expect(isPngBytes(bytes!), isTrue);
  });

  test('decodeSignaturePngValue restores PNG from data URI', () async {
    final encoded = await encodeSignaturePngForApi([
      [const Offset(5, 6), const Offset(7, 8), const Offset(40, 20)],
    ]);
    expect(encoded, isNotNull);

    final wrapped = 'data:image/png;base64,$encoded';
    final bytes = decodeSignaturePngValue(wrapped);
    expect(bytes, isNotNull);
    expect(base64Encode(bytes!), encoded);
  });

  test('encodeSignaturePngForApi returns null for empty pad', () async {
    expect(await encodeSignaturePngForApi(const []), isNull);
    expect(
      await encodeSignaturePngForApi([
        [const Offset(1, 2)],
      ]),
      isNull,
    );
  });

  test('parseSignatureDisplayValue resolves relative PNG paths', () async {
    final encoded = await encodeSignaturePngForApi([
      [const Offset(1, 2), const Offset(3, 4), const Offset(20, 10)],
    ]);
    expect(encoded, isNotNull);

    final fromBase64 = parseSignatureDisplayValue(encoded!);
    expect(fromBase64.bytes, isNotNull);
    expect(fromBase64.hasImage, isTrue);

    final fromPath = parseSignatureDisplayValue('/media/signatures/test.png');
    expect(fromPath.imageUrl, contains('110.225.254.51:5050'));
    expect(fromPath.imageUrl, endsWith('/media/signatures/test.png'));
  });

  test('exportSignaturePngFile writes PNG and returns short filename', () async {
    final export = await exportSignaturePngFile(
      fieldId: 46,
      strokes: [
        [const Offset(10, 20), const Offset(30, 40), const Offset(80, 35)],
      ],
    );

    expect(export, isNotNull);
    expect(export!.filename, 'sig_f46.png');
    expect(export.filename.length, lessThanOrEqualTo(100));
    expect(await File(export.path).exists(), isTrue);
    expect(isPngBytes(export.bytes), isTrue);
  });
}

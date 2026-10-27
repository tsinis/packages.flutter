import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';

void main() {
  group('PdfViewPinch lifecycle', () {
    testWidgets(
        'unmounting before a scheduled relayout fires does not call setState '
        'on the disposed state', (tester) async {
      final controller = PdfControllerPinch(
        document: Future.value(_FakeDocument()),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: PdfViewPinch(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Scroll the only page out of the view: `_determinePagesToShow` sees a
      // visibility change and schedules `_needReLayout` on a zero-delay timer.
      controller.value = Matrix4.translationValues(0, -100000, 0);

      // Unmount in the same turn, before that timer fires. `pumpWidget` does
      // not advance the fake clock, so the timer is still pending here.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'disposing the viewer while the document is still loading does not '
      'throw when the document arrives',
      (tester) async {
        final document = Completer<PdfDocument>();
        final controller = PdfControllerPinch(document: document.future);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(home: PdfViewPinch(controller: controller)),
        );
        await tester.pumpWidget(const SizedBox());

        document.complete(_FakeDocument());
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// A one-page document that "loads" without a platform channel.
class _FakeDocument extends PdfDocument {
  _FakeDocument() : super(sourceName: 'fake.pdf', id: 'doc-1', pagesCount: 1);

  @override
  Future<void> close() async => isClosed = true;

  @override
  Future<PdfPage> getPage(
    int pageNumber, {
    bool autoCloseAndroid = false,
  }) async =>
      _FakePage(this, pageNumber);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => id.hashCode;
}

class _FakePage extends PdfPage {
  _FakePage(PdfDocument document, int pageNumber)
      : super(
          document: document,
          id: 'page-$pageNumber',
          pageNumber: pageNumber,
          width: 595,
          height: 842,
          autoCloseAndroid: false,
        );

  @override
  Future<PdfPageImage?> render({
    required double width,
    required double height,
    PdfPageImageFormat format = PdfPageImageFormat.jpeg,
    String? backgroundColor,
    Rect? cropRect,
    int quality = 100,
    bool forPrint = false,
    bool removeTempFile = true,
  }) async =>
      null;

  @override
  Future<PdfPageTexture> createTexture() async =>
      _FakeTexture(pageId: id, pageNumber: pageNumber);

  @override
  Future<void> close() async => isClosed = true;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => Object.hash(id, pageNumber);
}

class _FakeTexture extends PdfPageTexture {
  _FakeTexture({required super.pageId, required super.pageNumber})
      : super(id: pageNumber);

  int? _textureWidth;
  int? _textureHeight;

  @override
  int? get textureWidth => _textureWidth;

  @override
  int? get textureHeight => _textureHeight;

  @override
  bool get hasUpdatedTexture => _textureWidth != null;

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> updateRect({
    required String documentId,
    int destinationX = 0,
    int destinationY = 0,
    int? width,
    int? height,
    int sourceX = 0,
    int sourceY = 0,
    int? textureWidth,
    int? textureHeight,
    double? fullWidth,
    double? fullHeight,
    String? backgroundColor,
    bool allowAntiAliasing = true,
  }) async {
    _textureWidth = textureWidth;
    _textureHeight = textureHeight;
    return true;
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => Object.hash(id, pageNumber);
}

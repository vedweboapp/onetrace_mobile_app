import 'package:pdfx/pdfx.dart';

import 'pdf_page_metadata.dart';

/// Loads and caches PDF page media-box dimensions per page number.
class PdfPageMetadataCache {
  PdfPageMetadataCache();

  final Map<int, PdfPageMetadata> _byPage = {};

  PdfPageMetadata? page(int pageOneBased) => _byPage[pageOneBased];

  int get pageCount => _byPage.length;

  void put(PdfPageMetadata metadata) {
    _byPage[metadata.pageNumber] = metadata;
  }

  /// Reads width/height from each page of a file on disk.
  static Future<PdfPageMetadataCache> fromFile(String path) async {
    final cache = PdfPageMetadataCache();
    final doc = await PdfDocument.openFile(path);
    try {
      final count = doc.pagesCount;
      for (var i = 1; i <= count; i++) {
        final page = await doc.getPage(i);
        cache.put(
          PdfPageMetadata(
            pageNumber: i,
            width: page.width,
            height: page.height,
            rotation: 0,
          ),
        );
        await page.close();
      }
    } finally {
      await doc.close();
    }
    return cache;
  }
}

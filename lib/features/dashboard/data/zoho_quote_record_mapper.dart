import 'dart:convert';

import 'package:red5/features/dashboard/data/quote_composite_parser.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';

/// Maps Zoho CRM quote JSON into the app payload shape consumed by the dashboard UI.
abstract final class ZohoQuoteRecordMapper {
  static List<QuoteSummary> extractQuoteSummaries(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is! List) return const [];
    final out = <QuoteSummary>[];
    for (final row in data) {
      if (row is Map<String, dynamic>) {
        final s = QuoteSummary.fromJson(row);
        if (s != null) out.add(s);
      } else if (row is Map) {
        final s = QuoteSummary.fromJson(Map<String, dynamic>.from(row));
        if (s != null) out.add(s);
      }
    }
    return out;
  }

  static Map<String, dynamic>? extractPayloadFromCrmResponse(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    if (first is Map<String, dynamic>) {
      return adaptCrmRecordToAppPayload(first);
    }
    if (first is Map) {
      return adaptCrmRecordToAppPayload(Map<String, dynamic>.from(first));
    }
    return null;
  }

  static Map<String, dynamic>? extractPayloadMap(Map<String, dynamic> root) {
    final detailsRaw = root['details'];
    final details = detailsRaw is Map<String, dynamic>
        ? detailsRaw
        : (detailsRaw is Map ? Map<String, dynamic>.from(detailsRaw) : null);
    if (details == null) return null;

    Map<String, dynamic>? parseJsonMapString(dynamic raw) {
      if (raw is! String) return null;
      final text = raw.trim();
      if (text.isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    }

    final outputRaw = details['output'];
    if (outputRaw is String && outputRaw.trim().isNotEmpty) {
      final normalized = outputRaw.trim().toLowerCase();
      if (normalized != 'no record found') {
        final map = parseJsonMapString(outputRaw);
        if (map != null) return map;
      }
    }

    final userMessageRaw = details['userMessage'];
    if (userMessageRaw is List) {
      for (final item in userMessageRaw) {
        final map = parseJsonMapString(item);
        if (map != null) return adaptCrmRecordToAppPayload(map);
      }
    }

    return null;
  }

  static (double, double) fallbackPinCoordinate(int index) {
    const columns = 4;
    const startX = 18.0;
    const startY = 20.0;
    const gapX = 18.0;
    const gapY = 18.0;
    final row = index ~/ columns;
    final col = index % columns;
    final x = (startX + (col * gapX)).clamp(8.0, 92.0);
    final y = (startY + (row * gapY)).clamp(8.0, 92.0);
    return (x, y);
  }

  static Map<String, dynamic> adaptCrmRecordToAppPayload(Map<String, dynamic> record) {
    String? readTopString(List<String> keys) {
      for (final key in keys) {
        final value = record[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    final quote = <String, dynamic>{
      'quote_name':
          readTopString(['Subject', 'quote_name', 'Quote_Name']) ??
          'Untitled Quote',
      'quote_number':
          readTopString(['Quote_Number', 'quote_number', 'Quote No']) ?? '—',
      'quote_stage': readTopString(['Quote_Stage', 'quote_stage']),
      'valid_till': readTopString(['Valid_Till', 'valid_till']),
      'property': readTopString(['Property', 'property']),
      'door_survey': readTopString(['Door_Survey', 'door_survey']),
      'deal_name': readTopString(['Deal_Name', 'deal_name']),
      'wardrive_pdf_link': readTopString([
        'Wardrive_pdf_link',
        'wardrive_pdf_link',
        'workdrive_pdf_link',
      ]),
      'workdrive_pdf_download': readTopString([
        'Download_link',
        'download_link',
        'workdrive_pdf_download',
      ]),
      'contact_name': readTopString(['Contact_Name', 'contact_name']),
    };

    final createdBy = record['Created_By'];
    if (createdBy is Map) {
      final createdByName = createdBy['name'];
      if (createdByName is String && createdByName.trim().isNotEmpty) {
        quote['created_by'] = createdByName.trim();
      }
    }

    final layout = record['Layout'];
    if (layout is Map) {
      final layoutName = layout['name'];
      if (layoutName is String && layoutName.trim().isNotEmpty) {
        quote['layout'] = layoutName.trim();
      }
    }

    final products = <Map<String, dynamic>>[];
    final quotedItems = record['Quoted_Items'];
    final productDetails = record['Product_Details'];
    final lineRows = quotedItems is List && quotedItems.isNotEmpty
        ? quotedItems
        : (productDetails is List ? productDetails : null);

    if (lineRows != null) {
      for (var index = 0; index < lineRows.length; index++) {
        final row = lineRows[index];
        if (row is! Map) continue;
        final m = Map<String, dynamic>.from(row);

        String? productName;
        final productNameField = m['Product_Name'];
        if (productNameField is Map) {
          final n = productNameField['name'];
          if (n is String && n.trim().isNotEmpty) {
            productName = n.trim();
          }
        }
        if (productName == null) {
          final product = m['product'];
          if (product is Map) {
            final pName = product['name'];
            if (pName is String && pName.trim().isNotEmpty) {
              productName = pName.trim();
            }
          }
        }

        final blockRaw = m['Block'];
        final levelLabel = blockRaw is String && blockRaw.trim().isNotEmpty
            ? blockRaw.trim()
            : readTopString(['Subject', 'quote_name', 'Quote_Name']);

        final locRaw = m['Location'] ?? m['location'];
        final plotLabel = locRaw is String && locRaw.trim().isNotEmpty
            ? locRaw.trim()
            : readTopString(['Product_Location', 'product_location']);

        final generated = fallbackPinCoordinate(index);
        final xRaw = m['X_Coordinate'] ?? m['x_coordinate'] ?? generated.$1;
        final yRaw = m['Y_Coordinate'] ?? m['y_coordinate'] ?? generated.$2;
        final plotPointsRaw =
            m['plot_points'] ??
            m['Plot_points'] ??
            m['Plot_Points'] ??
            m['Plot_X_Coordinate'] ??
            m['plot_x_coordinate'];
        final plotColorRaw = m['Plot_Color'] ?? m['plot_color'];
        final plotColor = plotColorRaw is String && plotColorRaw.trim().isNotEmpty
            ? plotColorRaw.trim()
            : null;

        products.add({
          'product_name': productName ?? 'Unknown Product',
          'quantity': m['Quantity'] ?? m['quantity'],
          'total': m['Total'] ?? m['total'],
          'levels': levelLabel,
          'plots': plotLabel,
          'x_coordinate': xRaw,
          'y_coordinate': yRaw,
          if (plotPointsRaw != null) 'plot_points': '$plotPointsRaw',
          if (plotColor != null) 'plot_color': plotColor,
        });
      }
    }

    final compositeGroups = parseCompositeItemGroupsFromZohoRecord(record);
    return {
      'quote': quote,
      'products': products,
      if (compositeGroups.isNotEmpty)
        'composite_groups': compositeGroups.map((g) => g.toJson()).toList(),
    };
  }
}

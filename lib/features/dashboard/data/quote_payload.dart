import 'package:red5/features/dashboard/data/quote_composite_models.dart';

/// Parsed CRM quote payload for the quote details screen.
class QuotePayload {
  QuotePayload({
    required this.quote,
    required this.products,
    this.compositeGroups = const [],
  });

  final QuoteHeader quote;
  final List<QuoteLineProduct> products;
  final List<QuoteCompositeItemGroup> compositeGroups;

  factory QuotePayload.fromJson(Map<String, dynamic> json) {
    final quoteJson = json['quote'] is Map<String, dynamic>
        ? json['quote'] as Map<String, dynamic>
        : <String, dynamic>{};
    final productsRaw = json['products'];
    final products = <QuoteLineProduct>[];
    if (productsRaw is List) {
      for (final raw in productsRaw) {
        if (raw is Map<String, dynamic>) {
          products.add(QuoteLineProduct.fromJson(raw));
        } else if (raw is Map) {
          products.add(QuoteLineProduct.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return QuotePayload(
      quote: QuoteHeader.fromJson(quoteJson),
      products: products,
      compositeGroups: compositeGroupsFromJson(json['composite_groups']),
    );
  }
}

class QuoteHeader {
  QuoteHeader({
    required this.quoteName,
    required this.quoteNumber,
    this.projectId,
    this.quoteStage,
    this.projectStatus,
    this.description,
    this.startDate,
    this.endDate,
    this.organization,
    this.client,
    this.validTill,
    this.property,
    this.doorSurvey,
    this.dealName,
    this.wardrivePdfLink,
    this.workdrivePdfDownload,
    this.contactName,
    this.createdBy,
    this.modifiedBy,
    this.createdAt,
    this.modifiedAt,
    this.deletedAt,
    this.deletedBy,
    this.isDeleted,
    this.layout,
  });

  final String quoteName;
  final String quoteNumber;
  final String? projectId;
  final String? quoteStage;
  final String? projectStatus;
  final String? description;
  final String? startDate;
  final String? endDate;
  final String? organization;
  final String? client;
  final String? validTill;
  final String? property;
  final String? doorSurvey;
  final String? dealName;
  final String? wardrivePdfLink;
  final String? workdrivePdfDownload;
  final String? contactName;
  final String? createdBy;
  final String? modifiedBy;
  final String? createdAt;
  final String? modifiedAt;
  final String? deletedAt;
  final String? deletedBy;
  final String? isDeleted;
  final String? layout;

  factory QuoteHeader.fromJson(Map<String, dynamic> json) {
    String? readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    return QuoteHeader(
      quoteName: (json['quote_name'] as String?)?.trim().isNotEmpty == true
          ? (json['quote_name'] as String).trim()
          : 'Untitled Quote',
      quoteNumber: (json['quote_number'] as String?)?.trim() ?? '—',
      projectId: readString(['id']),
      quoteStage: json['quote_stage'] as String?,
      projectStatus: readString(['project_status']),
      description: readString(['description']),
      startDate: readString(['start_date']),
      endDate: readString(['end_date']),
      organization: readString(['organization']),
      client: readString(['client']),
      validTill: json['valid_till'] as String?,
      property: json['property'] as String?,
      doorSurvey: json['door_survey'] as String?,
      dealName: json['deal_name'] as String?,
      wardrivePdfLink: readString([
        'wardrive_pdf_link',
        'workdrive_pdf_link',
        'Wardrive_pdf_link',
      ]),
      workdrivePdfDownload: readString([
        'workdrive_pdf_download',
        'download_link',
        'Download_link',
      ]),
      contactName: json['contact_name'] as String?,
      createdBy: readString(['created_by']),
      modifiedBy: readString(['modified_by']),
      createdAt: readString(['created_at']),
      modifiedAt: readString(['modified_at']),
      deletedAt: readString(['deleted_at']),
      deletedBy: readString(['deleted_by']),
      isDeleted: readString(['is_deleted']),
      layout: json['layout'] as String?,
    );
  }
}

class QuoteLineProduct {
  QuoteLineProduct({
    required this.productName,
    required this.quantity,
    required this.total,
    this.levels,
    this.plots,
    this.xCoordinate,
    this.yCoordinate,
    this.plotPoints,
    this.plotColor,
  });

  final String productName;
  final int quantity;
  final double total;
  final String? levels;
  final String? plots;
  final String? xCoordinate;
  final String? yCoordinate;
  final String? plotPoints;
  final String? plotColor;

  factory QuoteLineProduct.fromJson(Map<String, dynamic> json) {
    String? readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    num? readNum(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) return value;
        if (value is String) {
          final parsed = num.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return QuoteLineProduct(
      productName:
          readString(['product_name', 'Product_Name', 'name']) ??
          'Unknown Product',
      quantity: (readNum(['quantity', 'Quantity']) ?? 0).toInt(),
      total: (readNum(['total', 'Total']) ?? 0).toDouble(),
      levels: readString(['levels', 'block', 'Block']),
      plots: readString(['plots', 'location', 'Location']),
      xCoordinate: readString(['x_coordinate', 'X_Coordinate']),
      yCoordinate: readString(['y_coordinate', 'Y_Coordinate']),
      plotPoints: readString([
        'plot_points',
        'Plot_points',
        'Plot_Points',
        'plot_x_coordinate',
        'Plot_X_Coordinate',
      ]),
      plotColor: readString(['plot_color', 'Plot_Color']),
    );
  }

  Map<String, dynamic> toPinSeedJson() => {
    'product_name': productName,
    'levels': levels,
    'plots': plots,
    'x_coordinate': xCoordinate,
    'y_coordinate': yCoordinate,
    'quantity': quantity,
    if (plotPoints != null && plotPoints!.trim().isNotEmpty)
      'plot_points': plotPoints!.trim(),
    if (plotColor != null && plotColor!.trim().isNotEmpty)
      'plot_color': plotColor!.trim(),
  };
}

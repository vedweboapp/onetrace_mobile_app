final class JobRead {
  const JobRead({
    required this.id,
    required this.title,
    this.description,
    this.workerName,
    this.pinStatusName,
    this.formsDetails,
    this.jobPinStatus,
    this.jobSource,
    this.startDate,
    this.endDate,
    this.completedAt,
    this.comments,
    this.pinXCoordinate,
    this.pinYCoordinate,
    this.itemName,
    this.sectionName,
    this.plotName,
    this.pinName,
    this.quantity,
    this.sellingPrice,
    this.total,
    this.isVirtualPin = false,
    this.jobMeta = const <String, dynamic>{},
    this.pin,
    this.quotation,
    this.form,
    this.assignedWorker,
    this.jobStatus,
    this.client,
    this.project,
    this.site,
    this.organization,
    this.qrCode,
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String title;
  final String? description;
  final String? workerName;
  final String? pinStatusName;
  final String? formsDetails;
  final String? jobPinStatus;
  final String? jobSource;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? completedAt;
  final String? comments;
  final double? pinXCoordinate;
  final double? pinYCoordinate;
  final String? itemName;
  final String? sectionName;
  final String? plotName;
  final String? pinName;
  final int? quantity;
  final double? sellingPrice;
  final double? total;
  final bool isVirtualPin;
  final Map<String, dynamic> jobMeta;
  final int? pin;
  final int? quotation;
  final int? form;
  final int? assignedWorker;
  final int? jobStatus;
  final int? client;
  final int? project;
  final int? site;
  final int? organization;
  final int? qrCode;
  final Map<String, dynamic> raw;

  String get displayId => 'JB-$id';

  String get displayWorker {
    final direct = workerName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final fromMeta = jobMeta['worker_name']?.toString().trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    return assignedWorker == null
        ? 'Assigned Worker'
        : 'Worker $assignedWorker';
  }

  String get displayLocation {
    final section = sectionName?.trim();
    if (section != null && section.isNotEmpty) return section;
    final plot = plotName?.trim();
    if (plot != null && plot.isNotEmpty) return plot;
    final pinLabel = pinName?.trim();
    if (pinLabel != null && pinLabel.isNotEmpty) return pinLabel;
    return 'Job location';
  }

  String get displayStatus {
    final direct = pinStatusName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final pinStatus = jobPinStatus?.trim();
    if (pinStatus != null && pinStatus.isNotEmpty) return pinStatus;
    return completedAt == null ? 'Active' : 'Completed';
  }

  static JobRead? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final title = _readString(map, const ['title']) ?? 'Untitled Job';
    return JobRead(
      id: id,
      title: title,
      description: _readString(map, const ['description']),
      workerName: _readString(map, const ['worker_name']),
      pinStatusName: _readString(map, const ['pin_status_name']),
      formsDetails: _readString(map, const ['forms_details']),
      jobPinStatus: _readString(map, const ['job_pin_status']),
      jobSource: _readString(map, const ['job_source']),
      startDate: _readDate(map['start_date']),
      endDate: _readDate(map['end_date']),
      completedAt: _readDate(map['completed_at']),
      comments: _readString(map, const ['comments']),
      pinXCoordinate: _readDouble(map['pin_x_coordinate']),
      pinYCoordinate: _readDouble(map['pin_y_coordinate']),
      itemName: _readString(map, const ['item_name']),
      sectionName: _readString(map, const ['section_name']),
      plotName: _readString(map, const ['plot_name']),
      pinName: _readString(map, const ['pin_name']),
      quantity: _readInt(map['quantity']),
      sellingPrice: _readDouble(map['selling_price']),
      total: _readDouble(map['total']),
      isVirtualPin: _readBool(map['is_virtual_pin']) ?? false,
      jobMeta: _readMap(map['job_meta']),
      pin: _readInt(map['pin']),
      quotation: _readInt(map['quotation']),
      form: _readInt(map['form']) ?? _readInt(map['forms']),
      assignedWorker: _readInt(map['assigned_worker']),
      jobStatus: _readInt(map['job_status']),
      client: _readFkId(map['client']),
      project: _readFkId(map['project']),
      site: _readFkId(map['site']),
      organization: _readInt(map['organization']),
      qrCode: _readInt(map['qr_code']),
      raw: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toWritePayload({Map<String, dynamic>? jobMetaOverride}) {
    return <String, dynamic>{
      'title': title,
      if (description != null && description!.trim().isNotEmpty)
        'description': description,
      if (startDate != null) 'start_date': startDate!.toUtc().toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toUtc().toIso8601String(),
      if (comments != null && comments!.trim().isNotEmpty) 'comments': comments,
      if (assignedWorker != null) 'assigned_worker': assignedWorker,
      if (jobStatus != null) 'job_status': jobStatus,
      if (client != null) 'client': client,
      if (project != null) 'project': project,
      if (site != null) 'site': site,
      if (form != null) 'form': form,
      if (qrCode != null) 'qr_code': qrCode,
      'job_meta': jobMetaOverride ?? jobMeta,
    };
  }

  static int? _readFkId(dynamic value) {
    if (value is Map) {
      final map = value.map((k, v) => MapEntry(k.toString(), v));
      return _readInt(map['id']);
    }
    return _readInt(value);
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value == null) return null;
    final cleaned = value.toString().trim().replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString().trim());
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const <String, dynamic>{};
  }
}

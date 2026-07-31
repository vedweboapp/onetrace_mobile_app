import '../../../core/network/api_pagination.dart';
import '../enums/enums.dart';

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

double? _parseOptionalDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<int> _parseIntList(dynamic value) {
  if (value is List) {
    return value
        .where((item) => item != null)
        .map((item) => int.tryParse(item?.toString() ?? '') ?? 0)
        .where((item) => item > 0)
        .toList(growable: false);
  }
  return const <int>[];
}

final class EmployeeEarningProject {
  const EmployeeEarningProject({required this.id, required this.name});

  final int id;
  final String name;

  factory EmployeeEarningProject.fromMap(Map<String, dynamic> map) {
    return EmployeeEarningProject(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      name: map['name']?.toString() ?? 'Unknown project',
    );
  }
}

final class EmployeeEarningClient {
  const EmployeeEarningClient({required this.id, required this.name});

  final int id;
  final String name;

  factory EmployeeEarningClient.fromMap(Map<String, dynamic> map) {
    return EmployeeEarningClient(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      name: map['name']?.toString() ?? 'Unknown client',
    );
  }
}

final class EmployeeEarningSite {
  const EmployeeEarningSite({
    required this.id,
    required this.siteName,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
  });

  final int id;
  final String siteName;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String zipCode;

  String get fullAddress {
    return [
      siteName,
      addressLine1,
      addressLine2,
      city,
      state,
      country,
      zipCode,
    ].where((value) => value.isNotEmpty).join(', ');
  }

  factory EmployeeEarningSite.fromMap(Map<String, dynamic> map) {
    return EmployeeEarningSite(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      siteName: map['site_name']?.toString() ?? 'Unknown site',
      addressLine1: map['address_line_1']?.toString() ?? '',
      addressLine2: map['address_line_2']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      zipCode: map['zip_code']?.toString() ?? '',
    );
  }
}

final class EmployeePaymentDetails {
  const EmployeePaymentDetails({
    required this.paymentDate,
    required this.amountPaid,
    required this.paymentMethod,
    required this.transactionId,
  });

  final DateTime? paymentDate;
  final double amountPaid;
  final String paymentMethod;
  final String transactionId;

  factory EmployeePaymentDetails.fromMap(Map<String, dynamic> map) {
    return EmployeePaymentDetails(
      paymentDate: _parseDate(map['payment_date']),
      amountPaid: _parseDouble(map['amount_paid']),
      paymentMethod: map['payment_method']?.toString() ?? '',
      transactionId: map['transaction_id']?.toString() ?? '',
    );
  }
}

final class EmployeePaymentSummary {
  const EmployeePaymentSummary({
    required this.approvedOn,
    required this.paymentStatus,
    required this.paymentDate,
    required this.amount,
  });

  final DateTime? approvedOn;
  final String paymentStatus;
  final DateTime? paymentDate;
  final double amount;

  factory EmployeePaymentSummary.fromMap(Map<String, dynamic> map) {
    return EmployeePaymentSummary(
      approvedOn: _parseDate(map['approved_on']),
      paymentStatus: map['payment_status']?.toString() ?? '',
      paymentDate: _parseDate(map['payment_date']),
      amount: _parseDouble(map['amount']),
    );
  }
}

final class EmployeeEarningJob {
  const EmployeeEarningJob({
    required this.id,
    required this.jobSerialNumber,
    required this.project,
    required this.client,
    required this.site,
    required this.pinIds,
    required this.hoursWorked,
    required this.hourlyRate,
    required this.fixedRate,
    required this.jobAmount,
    required this.earningStatus,
    required this.paymentDetails,
    required this.paymentSummary,
  });

  final int id;
  final String jobSerialNumber;
  final EmployeeEarningProject? project;
  final EmployeeEarningClient client;
  final EmployeeEarningSite site;
  final List<int> pinIds;
  final double hoursWorked;
  final double? hourlyRate;
  final double? fixedRate;
  final double jobAmount;
  final String earningStatus;
  final EmployeePaymentDetails paymentDetails;
  final EmployeePaymentSummary paymentSummary;

  String get projectName => project?.name ?? 'Unassigned';
  String get clientName => client.name;
  String get siteAddress => site.fullAddress;
  String get jobName => jobSerialNumber;

  JobStatus get status {
    final normalized = earningStatus.trim().toLowerCase();
    switch (normalized) {
      case 'paid':
        return JobStatus.paid;
      case 'approved':
        return JobStatus.approved;
      default:
        return JobStatus.inApproval;
    }
  }

  factory EmployeeEarningJob.fromMap(Map<String, dynamic> map) {
    final projectRaw = map['project'];
    final clientRaw = map['client'];
    final siteRaw = map['site'];
    final paymentDetailsRaw = map['payment_details'];
    final paymentSummaryRaw = map['payment_summary'];

    return EmployeeEarningJob(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      jobSerialNumber: map['job_serial_number']?.toString() ?? '',
      project: projectRaw is Map<String, dynamic>
          ? EmployeeEarningProject.fromMap(projectRaw)
          : null,
      client: clientRaw is Map<String, dynamic>
          ? EmployeeEarningClient.fromMap(clientRaw)
          : const EmployeeEarningClient(id: 0, name: 'Unknown client'),
      site: siteRaw is Map<String, dynamic>
          ? EmployeeEarningSite.fromMap(siteRaw)
          : const EmployeeEarningSite(
              id: 0,
              siteName: 'Unknown site',
              addressLine1: '',
              addressLine2: '',
              city: '',
              state: '',
              country: '',
              zipCode: '',
            ),
      pinIds: _parseIntList(map['pin_ids']),
      hoursWorked: _parseDouble(map['hours_worked']),
      hourlyRate: _parseOptionalDouble(map['hourly_rate']),
      fixedRate: _parseOptionalDouble(map['fixed_rate']),
      jobAmount: _parseDouble(map['job_amount']),
      earningStatus: map['earning_status']?.toString() ?? '',
      paymentDetails: paymentDetailsRaw is Map<String, dynamic>
          ? EmployeePaymentDetails.fromMap(paymentDetailsRaw)
          : const EmployeePaymentDetails(
              paymentDate: null,
              amountPaid: 0,
              paymentMethod: '',
              transactionId: '',
            ),
      paymentSummary: paymentSummaryRaw is Map<String, dynamic>
          ? EmployeePaymentSummary.fromMap(paymentSummaryRaw)
          : const EmployeePaymentSummary(
              approvedOn: null,
              paymentStatus: '',
              paymentDate: null,
              amount: 0,
            ),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static double? _parseOptionalDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<int> _parseIntList(dynamic value) {
    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => int.tryParse(item?.toString() ?? '') ?? 0)
          .where((item) => item > 0)
          .toList(growable: false);
    }
    return const <int>[];
  }
}

final class EmployeeEarningsSummary {
  const EmployeeEarningsSummary({
    required this.totalJobs,
    required this.totalEarning,
    required this.paidAmount,
    required this.unpaidAmount,
  });

  final int totalJobs;
  final double totalEarning;
  final double paidAmount;
  final double unpaidAmount;

  factory EmployeeEarningsSummary.fromMap(Map<String, dynamic> map) {
    return EmployeeEarningsSummary(
      totalJobs: int.tryParse(map['total_jobs']?.toString() ?? '') ?? 0,
      totalEarning: _parseDouble(map['total_earning']),
      paidAmount: _parseDouble(map['paid_amount']),
      unpaidAmount: _parseDouble(map['unpaid_amount']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

final class EmployeeEarningsListResponse {
  const EmployeeEarningsListResponse({
    required this.summary,
    required this.jobs,
  });

  final EmployeeEarningsSummary summary;
  final List<EmployeeEarningJob> jobs;

  factory EmployeeEarningsListResponse.fromMap(Map<String, dynamic> root) {
    final rootMap = readApiMap(root);
    final dataMap = readApiMap(rootMap['data']);
    final summaryMap = readApiMap(dataMap['summary']);
    final jobsRaw = dataMap['jobs'];
    final jobs = jobsRaw is List
        ? jobsRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(EmployeeEarningJob.fromMap)
              .toList(growable: false)
        : const <EmployeeEarningJob>[];

    return EmployeeEarningsListResponse(
      summary: EmployeeEarningsSummary.fromMap(summaryMap),
      jobs: jobs,
    );
  }
}

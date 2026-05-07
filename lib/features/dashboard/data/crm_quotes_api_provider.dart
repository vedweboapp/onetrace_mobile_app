import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api.dart';

final crmQuotesApiProvider = Provider<CrmQuotesApi>(
  (ref) => sl<CrmQuotesApi>(),
);

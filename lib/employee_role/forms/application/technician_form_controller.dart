import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/forms/data/cached_technician_form.dart';
import 'package:red5/employee_role/forms/data/technician_form_repository.dart';

enum TechnicianFormSyncStatus {
  idle,
  offlineCached,
  syncing,
  refreshed,
}

final technicianFormControllerProvider =
    StateNotifierProvider.autoDispose<TechnicianFormController, TechnicianFormState>(
  (ref) {
    return TechnicianFormController(ref.read(technicianFormRepositoryProvider));
  },
);

final class TechnicianFormState {
  const TechnicianFormState({
    this.formId,
    this.bundle,
    this.isLoading = false,
    this.errorMessage,
    this.syncStatus = TechnicianFormSyncStatus.idle,
    this.showRefreshedNotice = false,
  });

  final int? formId;
  final TechnicianFormBundle? bundle;
  final bool isLoading;
  final String? errorMessage;
  final TechnicianFormSyncStatus syncStatus;
  final bool showRefreshedNotice;

  bool get isOfflineCached =>
      syncStatus == TechnicianFormSyncStatus.offlineCached ||
      bundle?.source == TechnicianFormSource.cache;

  TechnicianFormState copyWith({
    int? formId,
    TechnicianFormBundle? bundle,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    TechnicianFormSyncStatus? syncStatus,
    bool? showRefreshedNotice,
    bool clearRefreshedNotice = false,
  }) {
    return TechnicianFormState(
      formId: formId ?? this.formId,
      bundle: bundle ?? this.bundle,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      syncStatus: syncStatus ?? this.syncStatus,
      showRefreshedNotice: clearRefreshedNotice
          ? false
          : showRefreshedNotice ?? this.showRefreshedNotice,
    );
  }
}

final class TechnicianFormController extends StateNotifier<TechnicianFormState> {
  TechnicianFormController(this._repository) : super(const TechnicianFormState());

  final TechnicianFormRepository _repository;

  Future<void> load(int formId) async {
    state = state.copyWith(
      formId: formId,
      isLoading: true,
      clearError: true,
      syncStatus: TechnicianFormSyncStatus.idle,
      clearRefreshedNotice: true,
    );
    try {
      final bundle = await _repository.loadForm(formId);
      state = state.copyWith(
        bundle: bundle,
        isLoading: false,
        clearError: true,
        syncStatus: bundle.source == TechnicianFormSource.cache
            ? TechnicianFormSyncStatus.offlineCached
            : TechnicianFormSyncStatus.idle,
      );
    } on TechnicianFormLoadException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        syncStatus: TechnicianFormSyncStatus.offlineCached,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load form.',
      );
    }
  }

  Future<void> onConnectivityRestored() async {
    final formId = state.formId;
    if (formId == null || state.isLoading) return;

    final previousHash = state.bundle?.contentHash;
    state = state.copyWith(
      syncStatus: TechnicianFormSyncStatus.syncing,
      clearRefreshedNotice: true,
    );

    try {
      final bundle = await _repository.refreshForm(formId);
      final contentChanged = previousHash != null &&
          bundle.contentHash != null &&
          previousHash != bundle.contentHash;
      state = state.copyWith(
        bundle: bundle,
        syncStatus: contentChanged
            ? TechnicianFormSyncStatus.refreshed
            : TechnicianFormSyncStatus.idle,
        showRefreshedNotice: contentChanged,
        clearError: true,
      );
    } on TechnicianFormLoadException catch (error) {
      state = state.copyWith(
        syncStatus: TechnicianFormSyncStatus.offlineCached,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        syncStatus: TechnicianFormSyncStatus.offlineCached,
      );
    }
  }

  Future<void> retry() async {
    final formId = state.formId;
    if (formId == null) return;
    await load(formId);
  }

  void clearRefreshedNotice() {
    if (!state.showRefreshedNotice) return;
    state = state.copyWith(clearRefreshedNotice: true);
  }
}

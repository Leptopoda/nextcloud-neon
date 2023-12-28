import 'dart:async';

import 'package:meta/meta.dart';
import 'package:neon_framework/src/bloc/bloc.dart';
import 'package:neon_framework/src/bloc/result.dart';
import 'package:neon_framework/src/models/account.dart';
import 'package:neon_framework/src/utils/request_manager.dart';
import 'package:nextcloud/core.dart' as core;
import 'package:rxdart/rxdart.dart';

@internal
sealed class CapabilitiesBloc implements InteractiveBloc {
  /// Creates a new capabilities bloc.
  factory CapabilitiesBloc(final Account account) => _CapabilitiesBloc(account);

  BehaviorSubject<Result<core.OcsGetCapabilitiesResponseApplicationJson_Ocs_Data>> get capabilities;
}

class _CapabilitiesBloc extends InteractiveBloc implements CapabilitiesBloc {
  _CapabilitiesBloc(
    this.account,
  ) {
    unawaited(refresh());
  }

  final Account account;

  @override
  void dispose() {
    unawaited(capabilities.close());
    super.dispose();
  }

  @override
  BehaviorSubject<Result<core.OcsGetCapabilitiesResponseApplicationJson_Ocs_Data>> capabilities = BehaviorSubject();

  @override
  Future<void> refresh() async {
    await RequestManager.instance.wrapNextcloud(
      account.id,
      'capabilities',
      capabilities,
      account.client.core.ocs.getCapabilitiesRaw(),
      (final response) => response.body.ocs.data,
    );
  }
}

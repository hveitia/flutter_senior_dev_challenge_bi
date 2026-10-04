/// Accounts, balances and movements of the signed-in customer.
///
/// The app builds an `AccountsRepository` for the customer, provides an
/// `AccountsBloc` on it and mounts the routes. Firestore and device storage
/// are reached only through `package:feature_accounts/adapters.dart`, which
/// the composition root wires.
library;

export 'src/accounts_telemetry.dart';
export 'src/domain/account.dart';
export 'src/domain/accounts_repository.dart';
export 'src/domain/balance_trend.dart';
export 'src/domain/data_snapshot.dart';
export 'src/domain/load_state.dart';
export 'src/domain/movement.dart';
export 'src/domain/movement_filter.dart';
export 'src/domain/transfer.dart';
export 'src/domain/transfers_repository.dart';
export 'src/presentation/accounts/accounts_bloc.dart';
export 'src/presentation/accounts_routes.dart';
export 'src/presentation/detail/movements_bloc.dart';
export 'src/presentation/home/accounts_home_modules.dart';
export 'src/presentation/home/amount_visibility_cubit.dart';
export 'src/presentation/home/recent_movements_bloc.dart';
export 'src/presentation/home/recent_movements_module.dart'
    show RecentMovementsModule;
export 'src/presentation/transfer/account_provisioning_cubit.dart';
export 'src/presentation/transfer/transfer_notices.dart';
export 'src/presentation/transfer/transfer_outbox_cubit.dart';
export 'src/transfers_telemetry.dart';

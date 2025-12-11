import 'package:get_it/get_it.dart';
import '../../services/subscription_service.dart';

/// Service locator for dependency injection using GetIt
final getIt = GetIt.instance;

/// Initialize all services and register them with GetIt
/// Call this in main.dart before running the app
Future<void> setupServiceLocator() async {
  // Register ChessService as singleton
  getIt.registerLazySingleton<ChessService>(() => ChessService());
  
  // Register SubscriptionService as singleton
  getIt.registerLazySingleton<SubscriptionService>(() => SubscriptionService());
}


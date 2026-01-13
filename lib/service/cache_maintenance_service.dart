import 'dart:async';
import 'package:meal_palette/service/recipe_cache_service.dart';

/// Service that runs periodic background jobs to maintain cache quality
class CacheMaintenanceService {
  final RecipeCacheService _cacheService = RecipeCacheService();
  Timer? _maintenanceTimer;
  
  //* Run maintenance every 5 minutes
  static const Duration _maintenanceInterval = Duration(minutes: 5);
  
  /// Start periodic cache maintenance
  void startMaintenance() {
    print('🔧 Starting cache maintenance service');
    
    //* Run immediately on start
    _runMaintenance();
    
    //* Schedule periodic runs
    _maintenanceTimer = Timer.periodic(
      _maintenanceInterval,
      (_) => _runMaintenance(),
    );
  }
  
  /// Stop maintenance service
  void stopMaintenance() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = null;
    print('🛑 Stopped cache maintenance service');
  }
  
  /// Run maintenance tasks
  Future<void> _runMaintenance() async {
    try {
      print('🔧 Running cache maintenance...');
      
      //* Get cache statistics
      final stats = await _cacheService.getCacheStats();
      print('📊 Cache Stats: ${stats['with_details']}/${stats['total']} recipes have full details (${stats['cache_percentage']}%)');
      
      //* Fill in missing details for incomplete recipes
      if (stats['basic_only']! > 0) {
        print('🔄 Filling missing details for up to 10 recipes...');
        await _cacheService.fillMissingDetails(limit: 10);
      }
      
      print('✅ Cache maintenance completed');
    } catch (e) {
      print('⚠️ Cache maintenance error: $e');
    }
  }
  
  /// Get current cache statistics
  Future<Map<String, int>> getStats() async {
    return await _cacheService.getCacheStats();
  }
}

//* Global instance
final cacheMaintenanceService = CacheMaintenanceService();
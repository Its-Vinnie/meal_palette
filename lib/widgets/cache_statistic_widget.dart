import 'package:flutter/material.dart';
import 'package:meal_palette/service/cache_maintenance_service.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Widget to display cache statistics
/// Shows how many recipes are fully cached in the database
class CacheStatsWidget extends StatefulWidget {
  const CacheStatsWidget({super.key});

  @override
  State<CacheStatsWidget> createState() => _CacheStatsWidgetState();
}

class _CacheStatsWidgetState extends State<CacheStatsWidget> {
  Map<String, int>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final stats = await cacheMaintenanceService.getStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading cache stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryAccent,
          ),
        ),
      );
    }

    if (_stats == null) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.primaryAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //* Header
          Row(
            children: [
              Icon(
                Icons.storage,
                color: AppColors.primaryAccent,
                size: 24,
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                'Database Statistics',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.refresh, color: AppColors.primaryAccent),
                onPressed: _loadStats,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.lg),

          //* Total recipes
          _buildStatRow(
            icon: Icons.restaurant_menu,
            label: 'Total Recipes',
            value: '${_stats!['total']}',
            color: AppColors.info,
          ),

          SizedBox(height: AppSpacing.md),

          //* Fully cached
          _buildStatRow(
            icon: Icons.check_circle,
            label: 'Fully Cached',
            value: '${_stats!['with_details']}',
            color: AppColors.success,
          ),

          SizedBox(height: AppSpacing.md),

          //* Basic only
          _buildStatRow(
            icon: Icons.pending,
            label: 'Basic Info Only',
            value: '${_stats!['basic_only']}',
            color: AppColors.warning,
          ),

          SizedBox(height: AppSpacing.lg),

          //* Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cache Completeness',
                    style: AppTextStyles.labelMedium,
                  ),
                  Text(
                    '${_stats!['cache_percentage']}%',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: LinearProgressIndicator(
                  value: (_stats!['cache_percentage']! / 100),
                  minHeight: 8,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryAccent,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.md),

          //* Info text
          Text(
            'The app is automatically building a comprehensive recipe database for faster offline access.',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

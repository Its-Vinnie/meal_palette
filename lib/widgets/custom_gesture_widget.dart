import 'package:flutter/cupertino.dart';
import 'package:meal_palette/theme/theme_design.dart';

class CustomGestureWidget extends StatelessWidget {
  final String label;
  final Widget suffixIcon;
  final VoidCallback onTap;

  const CustomGestureWidget({
    super.key,
    required this.label,
    required this.suffixIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.bodyLarge),
        GestureDetector(onTap: onTap, child: suffixIcon),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme.dart';

class LoadingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(_opacityAnim.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: AppTheme.hairline.withOpacity(_opacityAnim.value * 0.5)),
          ),
        );
      },
    );
  }
}

class ExerciseSkeletonLoader extends StatelessWidget {
  const ExerciseSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar Skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LoadingSkeleton(width: 140, height: 16, borderRadius: 8),
              LoadingSkeleton(width: 60, height: 16, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 12),
          const LoadingSkeleton(width: double.infinity, height: 8, borderRadius: 4),
          const SizedBox(height: 28),

          // Question Card Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(width: 100, height: 14, borderRadius: 6),
                SizedBox(height: 14),
                LoadingSkeleton(width: double.infinity, height: 18, borderRadius: 6),
                SizedBox(height: 8),
                LoadingSkeleton(width: 220, height: 18, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Input Box Skeleton
          const LoadingSkeleton(width: double.infinity, height: 56, borderRadius: 16),
          const SizedBox(height: 20),

          // Submit Button Skeleton
          const LoadingSkeleton(width: double.infinity, height: 52, borderRadius: 16),
          const SizedBox(height: 16),

          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
                SizedBox(width: 10),
                Text(
                  "Preparing AI practice exercises...",
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/tree_model.dart';

class TreeWidget extends StatefulWidget {
  final TreeModel tree;

  const TreeWidget({super.key, required this.tree});

  @override
  State<TreeWidget> createState() => _TreeWidgetState();
}

class _TreeWidgetState extends State<TreeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(TreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tree.growthLevel != widget.tree.growthLevel) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getTreeEmoji() {
    final level = widget.tree.growthLevel;
    if (level == 0) return '🌱'; // Seed
    if (level == 1) return '🌿'; // Sprout
    if (level == 2) return '🪴'; // Small plant
    if (level == 3) return '🌳'; // Young tree
    if (level == 4) return '🌲'; // Growing tree
    return '🌴'; // Mighty tree (5+)
  }

  String _getGrowthStage() {
    final level = widget.tree.growthLevel;
    if (level == 0) return 'Seed';
    if (level == 1) return 'Sprout';
    if (level == 2) return 'Seedling';
    if (level == 3) return 'Young Tree';
    if (level == 4) return 'Growing Tree';
    return 'Mighty Tree';
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green[50]!,
                Colors.green[100]!,
              ],
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Your Recovery Tree',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Text(
                    _getTreeEmoji(),
                    style: TextStyle(
                      fontSize: 80 + (widget.tree.growthLevel * 0.5 * value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                _getGrowthStage(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Level ${widget.tree.growthLevel}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  // Progress toward the next stage (500 points per stage)
                  value: (widget.tree.totalGrowthPoints % 500) / 500,
                  minHeight: 12,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.tree.totalGrowthPoints} total growth points',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/navigation_order_service.dart';
import '../core/services/logger_service.dart';

/// A reorderable NavigationBar that allows long-press and drag-to-reorder
/// Home is locked to the first position
class ReorderableNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final ValueChanged<List<int>>? onOrderChanged;

  const ReorderableNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.onOrderChanged,
  });

  @override
  State<ReorderableNavigationBar> createState() => _ReorderableNavigationBarState();
}

class _ReorderableNavigationBarState extends State<ReorderableNavigationBar> {
  final NavigationOrderService _orderService = NavigationOrderService();
  bool _isReorderMode = false;
  int? _draggedIndex;
  int? _targetIndex;
  Offset? _dragOffset;
  List<int> _currentOrder = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _orderService.getNavigationOrder();
      if (mounted) {
        setState(() {
          _currentOrder = order;
        });
      }
    } catch (e) {
      Logger.error('Error loading navigation order', error: e, tag: 'ReorderableNavigationBar');
      // Use default order on error
      if (mounted) {
        setState(() {
          _currentOrder = [0, 1, 2, 3, 4, 5, 6];
        });
      }
    }
  }

  void _enterReorderMode() {
    if (!mounted) return;
    
    setState(() {
      _isReorderMode = true;
    });
    HapticFeedback.mediumImpact();
    
    // Show hint
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drag items to reorder. Tap outside to save.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _exitReorderMode() async {
    if (_isSaving || !mounted) return;
    
    // Save order if it changed before exiting
    final defaultOrder = [0, 1, 2, 3, 4, 5, 6];
    final orderChanged = _currentOrder.toString() != defaultOrder.toString();
    
    if (orderChanged) {
      await _saveOrder();
    }
    
    if (!mounted) return;
    
    setState(() {
      _isReorderMode = false;
      _draggedIndex = null;
      _targetIndex = null;
      _dragOffset = null;
    });
  }

  Future<void> _saveOrder() async {
    if (_isSaving || !mounted) return;
    
    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    try {
      await _orderService.saveNavigationOrder(_currentOrder);
      
      // Notify parent of order change AFTER save completes
      // Use a post-frame callback to avoid rebuild during build
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onOrderChanged?.call(List.from(_currentOrder));
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation order saved'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error saving navigation order', error: e, tag: 'ReorderableNavigationBar');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex == 0 || newIndex == 0) return; // Home is locked
    if (oldIndex == newIndex) return; // No change
    
    // Create a new list to avoid mutating during build
    final newOrder = List<int>.from(_currentOrder);
    
    // Adjust newIndex if moving forward
    int adjustedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedNewIndex = newIndex - 1;
    }
    
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(adjustedNewIndex, item);
    
    if (!mounted) return;
    
    setState(() {
      _currentOrder = newOrder;
      _draggedIndex = null;
      _targetIndex = null;
      _dragOffset = null;
    });
    
    HapticFeedback.lightImpact();
  }

  List<NavigationDestination> get _orderedDestinations {
    if (_currentOrder.isEmpty) return widget.destinations;
    return _currentOrder.map((screenIndex) => widget.destinations[screenIndex]).toList();
  }

  int get _selectedNavIndex {
    if (_currentOrder.isEmpty) return widget.selectedIndex;
    // Find which navigation position contains the selected screen index
    return _currentOrder.indexOf(widget.selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final orderedDestinations = _orderedDestinations;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: _isReorderMode ? _exitReorderMode : null,
      child: Container(
        decoration: _isReorderMode
            ? BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
              )
            : null,
        child: SafeArea(
          top: false,
          child: Container(
            height: 80,
            child: Row(
              children: orderedDestinations.asMap().entries.map((entry) {
                final index = entry.key;
                final destination = entry.value;
                final isHome = index == 0;
                final isSelected = !_isReorderMode && index == _selectedNavIndex;
                final isDragging = _isReorderMode && _draggedIndex == index;
                final isTarget = _isReorderMode && _targetIndex == index && _draggedIndex != index;

                return Expanded(
                  child: GestureDetector(
                    onLongPress: _isReorderMode || isHome
                        ? null
                        : () {
                            _enterReorderMode();
                          },
                    onPanStart: _isReorderMode && !isHome
                        ? (details) {
                            setState(() {
                              _draggedIndex = index;
                              _dragOffset = details.localPosition;
                            });
                            HapticFeedback.mediumImpact();
                          }
                        : null,
                    onPanUpdate: _isReorderMode && _draggedIndex == index
                        ? (details) {
                            if (!mounted) return;
                            
                            // Calculate target index based on global drag position
                            final RenderBox? box = context.findRenderObject() as RenderBox?;
                            if (box == null || !mounted) return;
                            
                            final globalPosition = details.globalPosition;
                            final localPosition = box.globalToLocal(globalPosition);
                            final itemWidth = box.size.width / orderedDestinations.length;
                            var newTargetIndex = (localPosition.dx / itemWidth).floor();
                            
                            // Clamp to valid range (1 to length-1, excluding Home at 0)
                            newTargetIndex = newTargetIndex.clamp(1, orderedDestinations.length - 1);
                            
                            // Don't allow dropping on self
                            if (newTargetIndex == _draggedIndex) {
                              newTargetIndex = _targetIndex ?? _draggedIndex!;
                            }
                            
                            if (newTargetIndex != _targetIndex && mounted) {
                              setState(() {
                                _dragOffset = details.localPosition;
                                _targetIndex = newTargetIndex;
                              });
                              HapticFeedback.selectionClick();
                            } else if (mounted) {
                              // Update drag offset even if target hasn't changed
                              setState(() {
                                _dragOffset = details.localPosition;
                              });
                            }
                          }
                        : null,
                    onPanEnd: _isReorderMode && _draggedIndex == index
                        ? (details) {
                            if (!mounted) return;
                            
                            if (_draggedIndex != null && _targetIndex != null && _draggedIndex != _targetIndex) {
                              _onReorder(_draggedIndex!, _targetIndex!);
                            } else if (mounted) {
                              setState(() {
                                _draggedIndex = null;
                                _targetIndex = null;
                                _dragOffset = null;
                              });
                            }
                          }
                        : null,
                    onTap: _isReorderMode
                        ? null
                        : () {
                            if (_currentOrder.isEmpty) {
                              widget.onDestinationSelected(index);
                            } else {
                              final screenIndex = _currentOrder[index];
                              widget.onDestinationSelected(screenIndex);
                            }
                          },
                    child: Container(
                      color: isTarget ? colorScheme.primaryContainer.withOpacity(0.3) : Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Transform.translate(
                                offset: isDragging && _dragOffset != null
                                    ? Offset(_dragOffset!.dx - 24, _dragOffset!.dy - 24)
                                    : Offset.zero,
                                child: Transform.scale(
                                  scale: isDragging ? 1.5 : 1.0, // Make dragged icon 50% larger
                                  child: Opacity(
                                    opacity: isDragging ? 0.9 : 1.0,
                                    child: isSelected
                                        ? destination.selectedIcon
                                        : destination.icon,
                                  ),
                                ),
                              ),
                              if (_isReorderMode && !isHome)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.drag_handle,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              if (isHome && _isReorderMode)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.lock,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            destination.label ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

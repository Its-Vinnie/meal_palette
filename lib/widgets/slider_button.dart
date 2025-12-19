import 'package:flutter/material.dart';

class SliderButton extends StatefulWidget {
  final String label;
  final VoidCallback onSlideComplete;
  final Color backgroundColor;
  final Color sliderColor;
  final Color textColor;
  final double height;
  final double borderRadius;
  final IconData icon;

  const SliderButton({
    super.key,
    required this.label,
    required this.onSlideComplete,
    this.backgroundColor = const Color(0xFFFF6B4A),
    this.sliderColor = const Color(0xFF1A1A1A),
    this.textColor = Colors.white,
    this.height = 64,
    this.borderRadius = 32,
    this.icon = Icons.arrow_forward,
  });

  @override
  State<SliderButton> createState() => _SliderButtonState();
}

class _SliderButtonState extends State<SliderButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  double _maxDrag = 0;
  bool _isSliding = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller)
      ..addListener(() {
        setState(() {
          _dragPosition = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    setState(() {
      _isSliding = true;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta.dx;
      
      // Clamp the position between 0 and max drag distance
      if (_dragPosition < 0) {
        _dragPosition = 0;
      } else if (_dragPosition > _maxDrag) {
        _dragPosition = _maxDrag;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // If dragged more than 80% of the way, complete the slide
    if (_dragPosition > _maxDrag * 0.8) {
      _completeSlide();
    } else {
      // Otherwise, animate back to start
      _resetSlide();
    }
  }

  void _completeSlide() {
    _animation = Tween<double>(
      begin: _dragPosition,
      end: _maxDrag,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward(from: 0).then((_) {
      widget.onSlideComplete();
      // Reset after a short delay
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _resetSlide();
        }
      });
    });
  }

  void _resetSlide() {
    _animation = Tween<double>(
      begin: _dragPosition,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward(from: 0).then((_) {
      setState(() {
        _isSliding = false;
        _dragPosition = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate max drag distance (width - slider button size)
        _maxDrag = constraints.maxWidth - widget.height;

        // Calculate progress (0.0 to 1.0)
        double progress = _dragPosition / _maxDrag;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Label Text
              Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor.withOpacity(1 - progress * 0.5),
                  ),
                ),
              ),

              // Slider Circle
              AnimatedPositioned(
                duration: _isSliding
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                left: _dragPosition,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: _onHorizontalDragStart,
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  child: Container(
                    width: widget.height,
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: widget.sliderColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.textColor,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Checkmark when complete
              if (progress > 0.8)
                Positioned(
                  left: _dragPosition,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: widget.height,
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: widget.sliderColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: widget.backgroundColor,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
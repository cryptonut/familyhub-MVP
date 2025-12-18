import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class BookRatingWidget extends StatefulWidget {
  final int? initialRating;
  final String? initialComment;
  final bool initialIsAnonymous;
  final Function(int rating, {String? comment, bool isAnonymous})? onRatingSubmitted;

  const BookRatingWidget({
    super.key,
    this.initialRating,
    this.initialComment,
    this.initialIsAnonymous = false,
    required this.onRatingSubmitted,
  });

  @override
  State<BookRatingWidget> createState() => _BookRatingWidgetState();
}

class _BookRatingWidgetState extends State<BookRatingWidget> {
  int? _selectedRating;
  final TextEditingController _commentController = TextEditingController();
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialRating;
    _commentController.text = widget.initialComment ?? '';
    _isAnonymous = widget.initialIsAnonymous;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Star rating
        Row(
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < (_selectedRating ?? 0)
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
              onPressed: () {
                setState(() {
                  _selectedRating = index + 1;
                });
              },
            );
          }),
        ),
        const SizedBox(height: AppTheme.spacingSM),

        // Comment field
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            hintText: 'Add a comment (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: AppTheme.spacingSM),

        // Anonymous toggle
        CheckboxListTile(
          title: const Text('Post anonymously'),
          value: _isAnonymous,
          onChanged: (value) {
            setState(() {
              _isAnonymous = value ?? false;
            });
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: AppTheme.spacingSM),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedRating != null && widget.onRatingSubmitted != null
                ? () {
                    widget.onRatingSubmitted!(
                      _selectedRating!,
                      comment: _commentController.text.trim().isEmpty
                          ? null
                          : _commentController.text.trim(),
                      isAnonymous: _isAnonymous,
                    );
                  }
                : null,
            child: const Text('Submit Rating'),
          ),
        ),
      ],
    );
  }
}


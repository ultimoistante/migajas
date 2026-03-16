import 'package:flutter/material.dart';

/// A horizontal row of color swatches for selecting a note color.
/// [value] is the current hex string (e.g. '#ff0000') or null for default.
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _palette = [
    null,
    '#ef9a9a', // red-200
    '#f48fb1', // pink-200
    '#ce93d8', // purple-200
    '#9fa8da', // indigo-200
    '#90caf9', // blue-200
    '#80deea', // cyan-200
    '#a5d6a7', // green-200
    '#fff59d', // yellow-200
    '#ffcc80', // orange-200
    '#bcaaa4', // brown-200
  ];

  static Color _fromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _palette.map((c) {
          final selected = value == c;
          return GestureDetector(
            onTap: () => onChanged(c),
            child: Container(
              margin: const EdgeInsets.all(4),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c == null
                    ? Theme.of(context).colorScheme.surface
                    : _fromHex(c),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: c == null && selected
                  ? const Icon(Icons.check, size: 16)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

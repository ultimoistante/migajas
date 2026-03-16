import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart'
    as quill_to_html;

/// A rich text editor backed by flutter_quill that reads/writes HTML content.
/// Set [readOnly] to true for view mode.
class RichEditor extends StatefulWidget {
  const RichEditor({
    super.key,
    required this.initialHtml,
    this.onChanged,
    this.readOnly = false,
    this.minHeight = 200,
    this.placeholder = 'Write something…',
  });

  final String initialHtml;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final double minHeight;
  final String placeholder;

  @override
  State<RichEditor> createState() => _RichEditorState();
}

class _RichEditorState extends State<RichEditor> {
  late final QuillController _ctrl;
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    Document doc;
    if (widget.initialHtml.isNotEmpty) {
      final delta = HtmlToDelta().convert(widget.initialHtml);
      doc = Document.fromDelta(delta);
    } else {
      doc = Document();
    }
    _ctrl = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _ctrl.readOnly = widget.readOnly;
    _ctrl.addListener(_handleChange);
  }

  void _handleChange() {
    if (widget.onChanged != null) {
      widget.onChanged!(_deltaToHtml(_ctrl.document));
    }
  }

  static String _deltaToHtml(Document doc) {
    final ops = doc.toDelta().toJson()
        .cast<Map<String, dynamic>>();
    final converter = quill_to_html.QuillDeltaToHtmlConverter(
      ops,
      quill_to_html.ConverterOptions.forEmail(),
    );
    return converter.convert();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_handleChange);
    _ctrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.readOnly)
          QuillSimpleToolbar(
            controller: _ctrl,
            config: const QuillSimpleToolbarConfig(
              showUndo: true,
              showRedo: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: false,
              showInlineCode: true,
              showListBullets: true,
              showListNumbers: true,
              showCodeBlock: true,
              showLink: true,
              showHeaderStyle: true,
              showQuote: true,
              showSearchButton: false,
              showFontFamily: false,
              showFontSize: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: true,
              showAlignmentButtons: false,
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          child: QuillEditor(
            controller: _ctrl,
            focusNode: _focusNode,
            scrollController: _scrollCtrl,
            config: QuillEditorConfig(
              scrollable: true,
              autoFocus: false,
              expands: false,
              padding: const EdgeInsets.all(12),
              placeholder: widget.placeholder,
              enableInteractiveSelection: true,
              showCursor: !widget.readOnly,
            ),
          ),
        ),
      ],
    );
  }
}

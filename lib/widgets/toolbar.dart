import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_quill/models/documents/attribute.dart';
import 'package:flutter_quill/models/documents/nodes/embed.dart';
import 'package:flutter_quill/models/documents/style.dart';
import 'package:flutter_quill/utils/color.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'controller.dart';

double iconSize = 18.0;
double kToolbarHeight = iconSize * 2;

typedef OnImagePickCallback = Future<String> Function(File file);
typedef ImagePickImpl = Future<String> Function(ImageSource source);

class InsertEmbedButton extends StatelessWidget {
  final QuillController controller;
  final IconData icon;

  const InsertEmbedButton({
    required this.controller,
    required this.icon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return QuillIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: iconSize * 1.77,
      icon: Icon(
        icon,
        size: iconSize,
        color: Theme.of(context).iconTheme.color,
      ),
      fillColor: Theme.of(context).canvasColor,
      onPressed: () {
        final index = controller.selection.baseOffset;
        final length = controller.selection.extentOffset - index;
        controller.replaceText(index, length, BlockEmbed.horizontalRule, null);
      },
    );
  }
}

class LinkStyleButton extends StatefulWidget {
  final QuillController controller;
  final IconData? icon;

  const LinkStyleButton({
    required this.controller,
    this.icon,
    Key? key,
  }) : super(key: key);

  @override
  _LinkStyleButtonState createState() => _LinkStyleButtonState();
}

class _LinkStyleButtonState extends State<LinkStyleButton> {
  void _didChangeSelection() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_didChangeSelection);
  }

  @override
  void didUpdateWidget(covariant LinkStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeSelection);
      widget.controller.addListener(_didChangeSelection);
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(_didChangeSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = !widget.controller.selection.isCollapsed;
    final pressedHandler = isEnabled ? () => _openLinkDialog(context) : null;
    return QuillIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: iconSize * 1.77,
      icon: Icon(
        widget.icon ?? Icons.link,
        size: iconSize,
        color: isEnabled ? theme.iconTheme.color : theme.disabledColor,
      ),
      fillColor: Theme.of(context).canvasColor,
      onPressed: pressedHandler,
    );
  }

  void _openLinkDialog(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        return const _LinkDialog();
      },
    ).then(_linkSubmitted);
  }

  void _linkSubmitted(String? value) {
    if (value == null || value.isEmpty) {
      return;
    }
    widget.controller.formatSelection(LinkAttribute(value));
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({Key? key}) : super(key: key);

  @override
  _LinkDialogState createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  String _link = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: TextField(
        decoration: const InputDecoration(labelText: 'Paste a link'),
        autofocus: true,
        onChanged: _linkChanged,
      ),
      actions: [
        TextButton(
          onPressed: _link.isNotEmpty ? _applyLink : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _linkChanged(String value) {
    setState(() {
      _link = value;
    });
  }

  void _applyLink() {
    Navigator.pop(context, _link);
  }
}

typedef ToggleStyleButtonBuilder = Widget Function(
  BuildContext context,
  Attribute attribute,
  IconData icon,
  bool? isToggled,
  VoidCallback? onPressed,
);

class ToggleStyleButton extends StatefulWidget {
  final Attribute attribute;

  final IconData icon;

  final QuillController controller;

  final ToggleStyleButtonBuilder childBuilder;

  const ToggleStyleButton({
    required this.attribute,
    required this.icon,
    required this.controller,
    this.childBuilder = defaultToggleStyleButtonBuilder,
    Key? key,
  }) : super(key: key);

  @override
  _ToggleStyleButtonState createState() => _ToggleStyleButtonState();
}

class _ToggleStyleButtonState extends State<ToggleStyleButton> {
  bool? _isToggled;

  Style get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {
      _isToggled =
          _getIsToggled(widget.controller.getSelectionStyle().attributes);
    });
  }

  @override
  void initState() {
    super.initState();
    _isToggled = _getIsToggled(_selectionStyle.attributes);
    widget.controller.addListener(_didChangeEditingValue);
  }

  bool _getIsToggled(Map<String, Attribute> attrs) {
    if (widget.attribute.key == Attribute.list.key) {
      Attribute? attribute = attrs[widget.attribute.key];
      if (attribute == null) {
        return false;
      }
      return attribute.value == widget.attribute.value;
    }
    return attrs.containsKey(widget.attribute.key);
  }

  @override
  void didUpdateWidget(covariant ToggleStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      _isToggled = _getIsToggled(_selectionStyle.attributes);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInCodeBlock =
        _selectionStyle.attributes.containsKey(Attribute.codeBlock.key);
    final isEnabled =
        !isInCodeBlock || widget.attribute.key == Attribute.codeBlock.key;
    return widget.childBuilder(context, widget.attribute, widget.icon,
        _isToggled, isEnabled ? _toggleAttribute : null);
  }

  void _toggleAttribute() {
    widget.controller.formatSelection(_isToggled!
        ? Attribute.clone(widget.attribute, null)
        : widget.attribute);
  }
}

class ToggleCheckListButton extends StatefulWidget {
  final IconData icon;

  final QuillController controller;

  final ToggleStyleButtonBuilder childBuilder;

  final Attribute attribute;

  const ToggleCheckListButton({
    required this.icon,
    required this.controller,
    required this.attribute,
    this.childBuilder = defaultToggleStyleButtonBuilder,
    Key? key,
  }) : super(key: key);

  @override
  _ToggleCheckListButtonState createState() => _ToggleCheckListButtonState();
}

class _ToggleCheckListButtonState extends State<ToggleCheckListButton> {
  bool? _isToggled;

  Style get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {
      _isToggled =
          _getIsToggled(widget.controller.getSelectionStyle().attributes);
    });
  }

  @override
  void initState() {
    super.initState();
    _isToggled = _getIsToggled(_selectionStyle.attributes);
    widget.controller.addListener(_didChangeEditingValue);
  }

  bool _getIsToggled(Map<String, Attribute> attrs) {
    if (widget.attribute.key == Attribute.list.key) {
      Attribute? attribute = attrs[widget.attribute.key];
      if (attribute == null) {
        return false;
      }
      return attribute.value == widget.attribute.value ||
          attribute.value == Attribute.checked.value;
    }
    return attrs.containsKey(widget.attribute.key);
  }

  @override
  void didUpdateWidget(covariant ToggleCheckListButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      _isToggled = _getIsToggled(_selectionStyle.attributes);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInCodeBlock =
        _selectionStyle.attributes.containsKey(Attribute.codeBlock.key);
    final isEnabled =
        !isInCodeBlock || Attribute.list.key == Attribute.codeBlock.key;
    return widget.childBuilder(context, Attribute.unchecked, widget.icon,
        _isToggled, isEnabled ? _toggleAttribute : null);
  }

  void _toggleAttribute() {
    widget.controller.formatSelection(_isToggled!
        ? Attribute.clone(Attribute.unchecked, null)
        : Attribute.unchecked);
  }
}

Widget defaultToggleStyleButtonBuilder(
  BuildContext context,
  Attribute attribute,
  IconData icon,
  bool? isToggled,
  VoidCallback? onPressed,
) {
  final theme = Theme.of(context);
  final isEnabled = onPressed != null;
  final iconColor = isEnabled
      ? isToggled == true
          ? theme.primaryIconTheme.color
          : theme.iconTheme.color
      : theme.disabledColor;
  final fillColor =
      isToggled == true ? theme.toggleableActiveColor : theme.canvasColor;
  return QuillIconButton(
    highlightElevation: 0,
    hoverElevation: 0,
    size: iconSize * 1.77,
    icon: Icon(icon, size: iconSize, color: iconColor),
    fillColor: fillColor,
    onPressed: onPressed,
  );
}

class SelectHeaderStyleButton extends StatefulWidget {
  final QuillController controller;

  const SelectHeaderStyleButton({required this.controller, Key? key})
      : super(key: key);

  @override
  _SelectHeaderStyleButtonState createState() =>
      _SelectHeaderStyleButtonState();
}

class _SelectHeaderStyleButtonState extends State<SelectHeaderStyleButton> {
  Attribute? _value;

  Style get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {
      _value =
          _selectionStyle.attributes[Attribute.header.key] ?? Attribute.header;
    });
  }

  void _selectAttribute(value) {
    widget.controller.formatSelection(value);
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      _value =
          _selectionStyle.attributes[Attribute.header.key] ?? Attribute.header;
    });
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant SelectHeaderStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      _value =
          _selectionStyle.attributes[Attribute.header.key] ?? Attribute.header;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _selectHeadingStyleButtonBuilder(context, _value, _selectAttribute);
  }
}

Widget _selectHeadingStyleButtonBuilder(BuildContext context, Attribute? value,
    ValueChanged<Attribute?> onSelected) {
  final style = const TextStyle(fontSize: 13);

  final Map<Attribute, String> _valueToText = {
    Attribute.header: 'Normal text',
    Attribute.h1: 'Heading 1',
    Attribute.h2: 'Heading 2',
    Attribute.h3: 'Heading 3',
  };

  return QuillDropdownButton<Attribute?>(
    highlightElevation: 0,
    hoverElevation: 0,
    height: iconSize * 1.77,
    fillColor: Theme.of(context).canvasColor,
    initialValue: value,
    items: [
      PopupMenuItem(
        value: Attribute.header,
        height: iconSize * 1.77,
        child: Text(_valueToText[Attribute.header]!, style: style),
      ),
      PopupMenuItem(
        value: Attribute.h1,
        height: iconSize * 1.77,
        child: Text(_valueToText[Attribute.h1]!, style: style),
      ),
      PopupMenuItem(
        value: Attribute.h2,
        height: iconSize * 1.77,
        child: Text(_valueToText[Attribute.h2]!, style: style),
      ),
      PopupMenuItem(
        value: Attribute.h3,
        height: iconSize * 1.77,
        child: Text(_valueToText[Attribute.h3]!, style: style),
      ),
    ],
    onSelected: onSelected,
    child: Text(
      !kIsWeb
          ? _valueToText[value!]!
          : _valueToText[value!.key == 'header'
              ? Attribute.header
              : (value.key == 'h1')
                  ? Attribute.h1
                  : (value.key == 'h2')
                      ? Attribute.h2
                      : Attribute.h3]!,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

class ImageButton extends StatefulWidget {
  final IconData icon;

  final QuillController controller;

  final OnImagePickCallback? onImagePickCallback;

  final ImagePickImpl? imagePickImpl;

  final ImageSource imageSource;

  const ImageButton({
    required this.icon,
    required this.controller,
    required this.imageSource,
    this.onImagePickCallback,
    this.imagePickImpl,
    Key? key,
  }) : super(key: key);

  @override
  _ImageButtonState createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  List<PlatformFile>? _paths;
  String? _extension;
  final _picker = ImagePicker();
  final FileType _pickingType = FileType.any;

  Future<String?> _pickImage(ImageSource source) async {
    final PickedFile? pickedFile = await _picker.getImage(source: source);
    if (pickedFile == null) return null;

    final File file = File(pickedFile.path);

    return widget.onImagePickCallback!(file);
  }

  Future<String?> _pickImageWeb() async {
    _paths = (await FilePicker.platform.pickFiles(
      type: _pickingType,
      allowedExtensions: (_extension?.isNotEmpty ?? false)
          ? _extension?.replaceAll(' ', '').split(',')
          : null,
    ))
        ?.files;
    var _fileName =
        _paths != null ? _paths!.map((e) => e.name).toString() : '...';

    if (_paths != null) {
      File file = File(_fileName);
      // We simply return the absolute path to selected file.
      return widget.onImagePickCallback!(file);
    } else {
      // User canceled the picker
    }
    return null;
  }

  Future<String> _pickImageDesktop() async {
    var filePath = await FilesystemPicker.open(
      context: context,
      rootDirectory: await getApplicationDocumentsDirectory(),
      fsType: FilesystemType.file,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
    if (filePath != null && filePath.isEmpty) return '';

    final File file = File(filePath!);
    return widget.onImagePickCallback!(file);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.iconTheme.color;
    final fillColor = theme.canvasColor;
    return QuillIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: iconSize * 1.77,
      icon: Icon(widget.icon, size: iconSize, color: iconColor),
      fillColor: fillColor,
      onPressed: () {
        final index = widget.controller.selection.baseOffset;
        final length = widget.controller.selection.extentOffset - index;
        Future<String?> image;
        if (widget.imagePickImpl != null) {
          image = widget.imagePickImpl!(widget.imageSource);
        } else {
          if (kIsWeb) {
            image = _pickImageWeb();
          } else if (Platform.isAndroid || Platform.isIOS) {
            image = _pickImage(widget.imageSource);
          } else {
            image = _pickImageDesktop();
          }
        }
        image.then((imageUploadUrl) => {
              widget.controller.replaceText(
                  index, length, BlockEmbed.image(imageUploadUrl!), null)
            });
      },
    );
  }
}

/// Controls color styles.
///
/// When pressed, this button displays overlay toolbar with
/// buttons for each color.
class ColorButton extends StatefulWidget {
  final IconData icon;
  final bool background;
  final QuillController controller;

  const ColorButton({
    required this.icon,
    required this.controller,
    required this.background,
    Key? key,
  }) : super(key: key);

  @override
  _ColorButtonState createState() => _ColorButtonState();
}

class _ColorButtonState extends State<ColorButton> {
  late bool _isToggledColor;
  late bool _isToggledBackground;
  late bool _isWhite;
  late bool _isWhitebackground;

  Style get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {
      _isToggledColor =
          _getIsToggledColor(widget.controller.getSelectionStyle().attributes);
      _isToggledBackground = _getIsToggledBackground(
          widget.controller.getSelectionStyle().attributes);
      _isWhite = _isToggledColor &&
          _selectionStyle.attributes['color']!.value == '#ffffff';
      _isWhitebackground = _isToggledBackground &&
          _selectionStyle.attributes['background']!.value == '#ffffff';
    });
  }

  @override
  void initState() {
    super.initState();
    _isToggledColor = _getIsToggledColor(_selectionStyle.attributes);
    _isToggledBackground = _getIsToggledBackground(_selectionStyle.attributes);
    _isWhite = _isToggledColor &&
        _selectionStyle.attributes['color']!.value == '#ffffff';
    _isWhitebackground = _isToggledBackground &&
        _selectionStyle.attributes['background']!.value == '#ffffff';
    widget.controller.addListener(_didChangeEditingValue);
  }

  bool _getIsToggledColor(Map<String, Attribute> attrs) {
    return attrs.containsKey(Attribute.color.key);
  }

  bool _getIsToggledBackground(Map<String, Attribute> attrs) {
    return attrs.containsKey(Attribute.background.key);
  }

  @override
  void didUpdateWidget(covariant ColorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      _isToggledColor = _getIsToggledColor(_selectionStyle.attributes);
      _isToggledBackground =
          _getIsToggledBackground(_selectionStyle.attributes);
      _isWhite = _isToggledColor &&
          _selectionStyle.attributes['color']!.value == '#ffffff';
      _isWhitebackground = _isToggledBackground &&
          _selectionStyle.attributes['background']!.value == '#ffffff';
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? iconColor = _isToggledColor && !widget.background && !_isWhite
        ? stringToColor(_selectionStyle.attributes['color']!.value)
        : theme.iconTheme.color;

    var iconColorBackground =
        _isToggledBackground && widget.background && !_isWhitebackground
            ? stringToColor(_selectionStyle.attributes['background']!.value)
            : theme.iconTheme.color;

    Color fillColor = _isToggledColor && !widget.background && _isWhite
        ? stringToColor('#ffffff')
        : theme.canvasColor;
    Color fillColorBackground =
        _isToggledBackground && widget.background && _isWhitebackground
            ? stringToColor('#ffffff')
            : theme.canvasColor;

    return QuillIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: iconSize * 1.77,
      icon: Icon(widget.icon,
          size: iconSize,
          color: widget.background ? iconColorBackground : iconColor),
      fillColor: widget.background ? fillColorBackground : fillColor,
      onPressed: _showColorPicker,
    );
  }

  void _changeColor(Color color) {
    String hex = color.value.toRadixString(16);
    if (hex.startsWith('ff')) {
      hex = hex.substring(2);
    }
    hex = '#$hex';
    widget.controller.formatSelection(
        widget.background ? BackgroundAttribute(hex) : ColorAttribute(hex));
    Navigator.of(context).pop();
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
          title: const Text('Select Color'),
          backgroundColor: Theme.of(context).canvasColor,
          content: SingleChildScrollView(
            child: MaterialPicker(
              pickerColor: const Color(0x00000000),
              onColorChanged: _changeColor,
            ),
          )),
    );
  }
}

class HistoryButton extends StatefulWidget {
  final IconData icon;
  final bool undo;
  final QuillController controller;

  const HistoryButton({
    required this.icon,
    required this.controller,
    required this.undo,
    Key? key,
  }) : super(key: key);

  @override
  _HistoryButtonState createState() => _HistoryButtonState();
}

class _HistoryButtonState extends State<HistoryButton> {
  Color? _iconColor;
  late ThemeData theme;

  @override
  Widget build(BuildContext context) {
    theme = Theme.of(context);
    _setIconColor();

    final fillColor = theme.canvasColor;
    widget.controller.changes.listen((event) async {
      _setIconColor();
    });
    return QuillIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: iconSize * 1.77,
      icon: Icon(widget.icon, size: iconSize, color: _iconColor),
      fillColor: fillColor,
      onPressed: _changeHistory,
    );
  }

  void _setIconColor() {
    if (!mounted) return;

    if (widget.undo) {
      setState(() {
        _iconColor = widget.controller.hasUndo
            ? theme.iconTheme.color
            : theme.disabledColor;
      });
    } else {
      setState(() {
        _iconColor = widget.controller.hasRedo
            ? theme.iconTheme.color
            : theme.disabledColor;
      });
    }
  }

  void _changeHistory() {
    if (widget.undo) {
      if (widget.controller.hasUndo) {
        widget.controller.undo();
      }
    } else {
      if (widget.controller.hasRedo) {
        widget.controller.redo();
      }
    }

    _setIconColor();
  }
}

class IndentButton extends StatefulWidget {
  final IconData icon;
  final QuillController controller;
  final bool isIncrease;

  const IndentButton({
    required this.icon,
    required this.controller,
    required this.isIncrease,
    Key? key,
  }) : super(key: key);

  @override
  _IndentButtonState createState() => _IndentButtonState();
}

class _IndentButtonState extends State<IndentButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.iconTheme.color;
    final fillColor = theme.canvasColor;
    return QuillIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: iconSize * 1.77,
      icon: Icon(widget.icon, size: iconSize, color: iconColor),
      fillColor: fillColor,
      onPressed: () {
        final indent = widget.controller
            .getSelectionStyle()
            .attributes[Attribute.indent.key];
        if (indent == null) {
          if (widget.isIncrease) {
            widget.controller.formatSelection(Attribute.indentL1);
          }
          return;
        }
        if (indent.value == 1 && !widget.isIncrease) {
          widget.controller
              .formatSelection(Attribute.clone(Attribute.indentL1, null));
          return;
        }
        if (widget.isIncrease) {
          widget.controller
              .formatSelection(Attribute.getIndentLevel(indent.value + 1));
          return;
        }
        widget.controller
            .formatSelection(Attribute.getIndentLevel(indent.value - 1));
      },
    );
  }
}

class ClearFormatButton extends StatefulWidget {
  final IconData icon;

  final QuillController controller;

  const ClearFormatButton({
    required this.icon,
    required this.controller,
    Key? key,
  }) : super(key: key);

  @override
  _ClearFormatButtonState createState() => _ClearFormatButtonState();
}

class _ClearFormatButtonState extends State<ClearFormatButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.iconTheme.color;
    final fillColor = theme.canvasColor;
    return QuillIconButton(
        highlightElevation: 0,
        hoverElevation: 0,
        size: iconSize * 1.77,
        icon: Icon(widget.icon, size: iconSize, color: iconColor),
        fillColor: fillColor,
        onPressed: () {
          for (Attribute k
              in widget.controller.getSelectionStyle().attributes.values) {
            widget.controller.formatSelection(Attribute.clone(k, null));
          }
        });
  }
}

class QuillToolbar extends StatefulWidget implements PreferredSizeWidget {
  final List<Widget> children;

  const QuillToolbar({required this.children, Key? key}) : super(key: key);

  factory QuillToolbar.basic({
    required QuillController controller,
    double toolbarIconSize = 18.0,
    bool showBoldButton = true,
    bool showItalicButton = true,
    bool showUnderLineButton = true,
    bool showStrikeThrough = true,
    bool showColorButton = true,
    bool showBackgroundColorButton = true,
    bool showClearFormat = true,
    bool showHeaderStyle = true,
    bool showListNumbers = true,
    bool showListBullets = true,
    bool showListCheck = true,
    bool showCodeBlock = true,
    bool showQuote = true,
    bool showIndent = true,
    bool showLink = true,
    bool showHistory = true,
    bool showHorizontalRule = false,
    OnImagePickCallback? onImagePickCallback,
    Key? key,
  }) {
    iconSize = toolbarIconSize;
    return QuillToolbar(key: key, children: [
      !showHistory
          ? const SizedBox.shrink()
          : HistoryButton(
              icon: Icons.undo_outlined,
              controller: controller,
              undo: true,
            ),
      !showHistory
          ? const SizedBox.shrink()
          : HistoryButton(
              icon: Icons.redo_outlined,
              controller: controller,
              undo: false,
            ),
      const SizedBox(width: 0.6),
      !showBoldButton
          ? const SizedBox.shrink()
          : ToggleStyleButton(
              attribute: Attribute.bold,
              icon: Icons.format_bold,
              controller: controller,
            ),
      const SizedBox(width: 0.6),
      !showItalicButton
          ? const SizedBox.shrink()
          : ToggleStyleButton(
              attribute: Attribute.italic,
              icon: Icons.format_italic,
              controller: controller,
            ),
      const SizedBox(width: 0.6),
      !showUnderLineButton
          ? const SizedBox.shrink()
          : ToggleStyleButton(
              attribute: Attribute.underline,
              icon: Icons.format_underline,
              controller: controller,
            ),
      const SizedBox(width: 0.6),
      !showStrikeThrough
          ? const SizedBox.shrink()
          : ToggleStyleButton(
              attribute: Attribute.strikeThrough,
              icon: Icons.format_strikethrough,
              controller: controller,
            ),
      const SizedBox(width: 0.6),
      !showColorButton
          ? const SizedBox.shrink()
          : ColorButton(
              icon: Icons.color_lens,
              controller: controller,
              background: false,
            ),
      const SizedBox(width: 0.6),
      !showBackgroundColorButton
          ? const SizedBox.shrink()
          : ColorButton(
              icon: Icons.format_color_fill,
              controller: controller,
              background: true,
            ),
      const SizedBox(width: 0.6),
      !showClearFormat
          ? const SizedBox.shrink()
          : ClearFormatButton(
              icon: Icons.format_clear,
              controller: controller,
            ),
      const SizedBox(width: 0.6),
      onImagePickCallback == null
          ? const SizedBox.shrink()
          : ImageButton(
              icon: Icons.image,
              controller: controller,
              imageSource: ImageSource.gallery,
              onImagePickCallback: onImagePickCallback,
            ),
      const SizedBox(width: 0.6),
      onImagePickCallback == null
          ? const SizedBox.shrink()
          : ImageButton(
              icon: Icons.photo_camera,
              controller: controller,
              imageSource: ImageSource.camera,
              onImagePickCallback: onImagePickCallback,
            ),
      !showHeaderStyle
          ? const SizedBox.shrink()
          : VerticalDivider(
              indent: 16,
              endIndent: 16,
              color: Colors.grey.shade400,
            ),
      !showHeaderStyle
          ? const SizedBox.shrink()
          : SelectHeaderStyleButton(controller: controller),
      // VerticalDivider(
      //   indent: 16,
      //   endIndent: 16,
      //   color: Colors.grey.shade400,
      // ),
      !showListNumbers
          ? const SizedBox.shrink()
          : ToggleStyleButton(
              attribute: Attribute.ol,
              controller: controller,
              icon: Icons.format_list_numbered,
            ),
      !showListBullets
          ? const SizedBox.shrink()
          : ToggleStyleButton(
              attribute: Attribute.ul,
              controller: controller,
              icon: Icons.format_list_bulleted,
            ),
      !showListCheck
          ? const SizedBox.shrink()
          : ToggleCheckListButton(
              attribute: Attribute.unchecked,
              controller: controller,
              icon: Icons.check_box,
            ),
      !showCodeBlock
          ? const SizedBox.shrink()
          : ToggleStyleButton(
              attribute: Attribute.codeBlock,
              controller: controller,
              icon: Icons.code,
            ),
      // Visibility(
      //     visible: !showListNumbers &&
      //         !showListBullets &&
      //         !showListCheck &&
      //         !showCodeBlock,
      //     child: VerticalDivider(
      //         indent: 16, endIndent: 16, color: Colors.grey.shade400)),
      !showQuote
          ? const SizedBox.shrink()
          : ToggleStyleButton(
              attribute: Attribute.blockQuote,
              controller: controller,
              icon: Icons.format_quote,
            ),
      !showIndent
          ? const SizedBox.shrink()
          : IndentButton(
              icon: Icons.format_indent_increase,
              controller: controller,
              isIncrease: true,
            ),
      !showIndent
          ? const SizedBox.shrink()
          : IndentButton(
              icon: Icons.format_indent_decrease,
              controller: controller,
              isIncrease: false,
            ),
      !showQuote
          ? const SizedBox.shrink()
          : VerticalDivider(
              indent: 16,
              endIndent: 16,
              color: Colors.grey.shade400,
            ),
      !showLink ? const SizedBox.shrink() : LinkStyleButton(controller: controller),
      !showHorizontalRule
          ? const SizedBox.shrink()
          : InsertEmbedButton(
              controller: controller,
              icon: Icons.horizontal_rule,
            ),
    ]);
  }

  @override
  _QuillToolbarState createState() => _QuillToolbarState();

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class _QuillToolbarState extends State<QuillToolbar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: BoxConstraints.tightFor(height: widget.preferredSize.height),
      color: Theme.of(context).canvasColor,
      child: CustomScrollView(
        scrollDirection: Axis.horizontal,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: widget.children,
            ),
          ),
        ],
      ),
    );
  }
}

class QuillIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final double size;
  final Color? fillColor;
  final double hoverElevation;
  final double highlightElevation;

  const QuillIconButton({
    required this.onPressed,
    this.icon,
    this.size = 40,
    this.fillColor,
    this.hoverElevation = 1,
    this.highlightElevation = 1,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: size, height: size),
      child: RawMaterialButton(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        fillColor: fillColor,
        elevation: 0,
        hoverElevation: hoverElevation,
        highlightElevation: hoverElevation,
        onPressed: onPressed,
        child: icon,
      ),
    );
  }
}

class QuillDropdownButton<T> extends StatefulWidget {
  final double height;
  final Color? fillColor;
  final double hoverElevation;
  final double highlightElevation;
  final Widget child;
  final T initialValue;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  const QuillDropdownButton({
    required this.child,
    required this.initialValue,
    required this.items,
    required this.onSelected,
    this.height = 40,
    this.fillColor,
    this.hoverElevation = 1,
    this.highlightElevation = 1,
    Key? key,
  }) : super(key: key);

  @override
  _QuillDropdownButtonState<T> createState() => _QuillDropdownButtonState<T>();
}

class _QuillDropdownButtonState<T> extends State<QuillDropdownButton<T>> {
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: widget.height),
      child: RawMaterialButton(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        fillColor: widget.fillColor,
        elevation: 0,
        hoverElevation: widget.hoverElevation,
        highlightElevation: widget.hoverElevation,
        onPressed: _showMenu,
        child: _buildContent(context),
      ),
    );
  }

  void _showMenu() {
    final popupMenuTheme = PopupMenuTheme.of(context);
    final button = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context)!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomLeft(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<T>(
      context: context,
      elevation: 4,
      // widget.elevation ?? popupMenuTheme.elevation,
      initialValue: widget.initialValue,
      items: widget.items,
      position: position,
      shape: popupMenuTheme.shape,
      // widget.shape ?? popupMenuTheme.shape,
      color: popupMenuTheme.color, // widget.color ?? popupMenuTheme.color,
      // captureInheritedThemes: widget.captureInheritedThemes,
    ).then((T? newValue) {
      if (!mounted) return null;
      if (newValue == null) {
        // if (widget.onCanceled != null) widget.onCanceled();
        return null;
      }
      widget.onSelected(newValue);
    });
  }

  Widget _buildContent(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 110),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            widget.child,
            Expanded(child: Container()),
            const Icon(Icons.arrow_drop_down, size: 15)
          ],
        ),
      ),
    );
  }
}

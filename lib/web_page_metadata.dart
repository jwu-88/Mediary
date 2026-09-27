import 'package:flutter/widgets.dart';

import 'web_metadata.dart';

class WebPageMetadata extends StatefulWidget {
  const WebPageMetadata({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  State<WebPageMetadata> createState() => _WebPageMetadataState();
}

class _WebPageMetadataState extends State<WebPageMetadata> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant WebPageMetadata oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.description != widget.description) {
      _sync();
    }
  }

  void _sync() {
    updateWebPageMetadata(title: widget.title, description: widget.description);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

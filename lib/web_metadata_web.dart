import 'package:web/web.dart' as web;

void updateWebPageMetadata({
  required String title,
  required String description,
  String? path,
}) {
  final document = web.document;
  document.title = title;
  _setMeta(document, name: 'description', content: description);
  _setMeta(document, property: 'og:title', content: title);
  _setMeta(document, property: 'og:description', content: description);
  if (path != null) {
    _setMeta(document, property: 'og:url', content: path);
  }
}

void _setMeta(
  web.Document document, {
  String? name,
  String? property,
  required String content,
}) {
  final selector = name != null
      ? 'meta[name="$name"]'
      : 'meta[property="$property"]';
  final meta =
      document.querySelector(selector) as web.HTMLMetaElement? ??
      (web.HTMLMetaElement()
        ..setAttribute(name != null ? 'name' : 'property', name ?? property!)
        ..content = content);
  meta.content = content;
  if (meta.parentNode == null) document.head?.append(meta);
}

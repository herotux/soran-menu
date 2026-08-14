import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class RemoteImage extends StatefulWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;

  const RemoteImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
  });

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = AppSettings.imageUrl(widget.path);
  }

  @override
  void didUpdateWidget(covariant RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.path != widget.path) {
      _urlFuture = AppSettings.imageUrl(widget.path);
    }
  }

  Widget _errorWidget() {
    return widget.error ??
        const Center(
          child: Icon(Icons.broken_image_outlined),
        );
  }

  Widget _placeholderWidget() {
    return widget.placeholder ??
        const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.path.trim().isEmpty) {
      return _errorWidget();
    }

    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholderWidget();
        }

        final url = snapshot.data?.trim() ?? '';

        if (url.isEmpty) {
          return _errorWidget();
        }

        return CachedNetworkImage(
          imageUrl: url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (_, __) => _placeholderWidget(),
          errorWidget: (_, __, ___) => _errorWidget(),
        );
      },
    );
  }
}

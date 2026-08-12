import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class RemoteImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (path.trim().isEmpty) {
      return error ??
          const Center(
            child: Icon(Icons.image_outlined),
          );
    }

    return FutureBuilder<String>(
      future: AppSettings.imageUrl(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder ??
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

        final url = snapshot.data ?? '';

        if (url.isEmpty) {
          return error ??
              const Center(
                child: Icon(Icons.broken_image_outlined),
              );
        }

        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) {
            return error ??
                const Center(
                  child: Icon(Icons.broken_image_outlined),
                );
          },
        );
      },
    );
  }
}

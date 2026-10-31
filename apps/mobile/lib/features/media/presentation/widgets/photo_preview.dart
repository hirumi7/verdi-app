import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/native/draft_bridge.g.dart';
import '../../../collection/presentation/widgets/presentation_helpers.dart';

class PhotoPreview extends StatefulWidget {
  final String photoId;
  final int revision;
  final double height;
  const PhotoPreview({
    super.key,
    required this.photoId,
    this.revision = 1,
    this.height = 180,
  });
  @override
  State<PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends State<PhotoPreview> {
  late Future<Uint8List> data;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    data = MediaPlatformHostApi().previewPhoto(widget.photoId);
  }

  @override
  void didUpdateWidget(PhotoPreview old) {
    super.didUpdateWidget(old);
    if (old.photoId != widget.photoId || old.revision != widget.revision) {
      load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: data,
    builder: (context, snapshot) => ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: snapshot.hasData
            ? Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                semanticLabel: strings(context).plantPhoto,
              )
            : snapshot.hasError
            ? Center(
                child: TextButton.icon(
                  onPressed: () => setState(load),
                  icon: const Icon(Icons.broken_image_outlined),
                  label: Text(strings(context).photoUnavailableRetry),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    ),
  );
}

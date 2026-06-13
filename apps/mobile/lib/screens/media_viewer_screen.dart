import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import 'chat_screen.dart';

class MediaViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String hubId;
  final String hubName;

  const MediaViewerScreen({
    super.key,
    required this.imageUrl,
    required this.hubId,
    required this.hubName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        final mediaWidget = Container(
          color: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );

        if (isTablet) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: mediaWidget,
                ),
                Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: ClosioTheme.backgroundColor,
                    border: Border(left: BorderSide(color: ClosioTheme.surfaceContainer)),
                  ),
                  child: Column(
                    children: [
                      AppBar(
                        backgroundColor: ClosioTheme.backgroundColor,
                        elevation: 0,
                        leading: const SizedBox.shrink(), // No back button needed here
                        leadingWidth: 0,
                        title: const Text('Thread'),
                      ),
                      Expanded(
                        child: ChatScreen(
                          hubId: hubId,
                          hubName: hubName,
                          isEmbedded: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: Colors.black,
            body: mediaWidget,
          );
        }
      },
    );
  }
}

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MarkerGenerator {
  static Future<BitmapDescriptor> createCustomMarker(String imageUrl, String username) async {
    final int width = 300;
    final int height = 350;
    final int avatarSize = 100;
    final int pinRadius = 40;
    
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Draw rounded rectangle for username tag
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width.toDouble(), 160),
      const Radius.circular(20)
    );
    canvas.drawRRect(rrect, paint);

    // Draw the black pin (a circle with a triangle pointing down)
    final double pinCenterX = width / 2;
    final double pinCenterY = 200;
    
    canvas.drawCircle(Offset(pinCenterX, pinCenterY), pinRadius.toDouble(), paint);
    
    // Draw triangle pointing down for the pin
    final Path path = Path();
    path.moveTo(pinCenterX - 15, pinCenterY + 10);
    path.lineTo(pinCenterX, pinCenterY + 70);
    path.lineTo(pinCenterX + 15, pinCenterY + 10);
    path.close();
    canvas.drawPath(path, paint);

    // Draw profile picture inside the rounded rectangle
    bool imageDrawn = false;
    final double avatarCenterX = width / 2;
    final double avatarCenterY = 60;
    
    if (imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final Uint8List imageBytes = response.bodyBytes;
          
          final ui.Codec codec = await ui.instantiateImageCodec(imageBytes, targetWidth: avatarSize, targetHeight: avatarSize);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image image = frameInfo.image;

          canvas.save();
          final Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(avatarCenterX, avatarCenterY), radius: avatarSize / 2));
          canvas.clipPath(clipPath);
          canvas.drawImage(image, Offset(avatarCenterX - avatarSize / 2, avatarCenterY - avatarSize / 2), Paint());
          canvas.restore();
          imageDrawn = true;
        }
      } catch (_) {}
    }

    // Fallback if no image
    if (!imageDrawn) {
      paint.color = Colors.white;
      canvas.drawCircle(Offset(avatarCenterX, avatarCenterY), avatarSize / 2, paint);
      
      final String fallbackLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';
      final textPainter = TextPainter(
        text: TextSpan(
          text: fallbackLetter, 
          style: const TextStyle(color: Colors.black, fontSize: 40, fontWeight: FontWeight.bold)
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(avatarCenterX - textPainter.width / 2, avatarCenterY - textPainter.height / 2));
    }

    // Draw Username text below the avatar, inside the rounded rect
    final textPainter = TextPainter(
      text: TextSpan(
        text: username, 
        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600)
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: width.toDouble() - 40);
    textPainter.paint(canvas, Offset(pinCenterX - textPainter.width / 2, 120));

    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(width, height);
    final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }
}

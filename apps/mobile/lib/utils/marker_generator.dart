import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MarkerGenerator {
  static Future<BitmapDescriptor> createCustomMarker(String imageUrl) async {
    final int size = 120;
    final int avatarSize = 100;
    
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final double radius = size / 2;

    // Draw the black pin (a circle with a triangle pointing down)
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    
    // Draw triangle pointing down
    final Path path = Path();
    path.moveTo(radius - 20, size.toDouble() - 20); // slightly above bottom of circle
    path.lineTo(radius, size.toDouble() + 25);      // point of the pin
    path.lineTo(radius + 20, size.toDouble() - 20);
    path.close();
    canvas.drawPath(path, paint);

    // Draw profile picture
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List imageBytes = response.bodyBytes;
        
        final ui.Codec codec = await ui.instantiateImageCodec(imageBytes, targetWidth: avatarSize, targetHeight: avatarSize);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image image = frameInfo.image;

        canvas.save();
        final Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: avatarSize / 2));
        canvas.clipPath(clipPath);
        canvas.drawImage(image, Offset(radius - avatarSize / 2, radius - avatarSize / 2), Paint());
        canvas.restore();
      } else {
        throw Exception('Failed to load image');
      }
    } catch (e) {
      // If image fails, draw a white circle inside with a fallback icon/text
      paint.color = Colors.white;
      canvas.drawCircle(Offset(radius, radius), avatarSize / 2, paint);
      
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'U', 
          style: TextStyle(color: Colors.black, fontSize: 40, fontWeight: FontWeight.bold)
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(radius - textPainter.width / 2, radius - textPainter.height / 2));
    }

    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(size, size + 30);
    final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }
}

import 'package:flutter/material.dart';
import 'package:mealprep_flutter/screens/product_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mealprep_flutter/services/food_api_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _ScannerOverlay extends StatelessWidget {
  final Rect scanWindow;

  const _ScannerOverlay({required this.scanWindow});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ScannerOverlayPainter(scanWindow),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  _ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6);

    final clearPaint = Paint()
      ..blendMode = BlendMode.clear;

    final background = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()..addRect(scanWindow);

    final finalPath = Path.combine(PathOperation.difference, background, cutout);

    canvas.drawPath(finalPath, overlayPaint);

    // Witte rand rond scanvak
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    final left = scanWindow.left;
    final right = scanWindow.right;
    final top = scanWindow.top;
    final bottom = scanWindow.bottom;

    // Top-left
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(right, top),
      Offset(right - cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - cornerLength),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - cornerLength, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  bool _isProcessing = false;

  void _openManualInput() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product manueel toevoegen'),
        content: TextField(
          controller: _manualController,
          decoration: const InputDecoration(
            labelText: 'Barcode of productcode',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _manualController.clear();
              Navigator.pop(context);
            },
            child: const Text('Annuleer'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _manualController.text.trim();
              if (code.isEmpty) return;

              Navigator.pop(context);
              _manualController.clear();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductScreen(barcode: code),
                ),
              );
            },
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final scanWidth = width * 0.8;
          final scanHeight = 200.0;

          final left = (width - scanWidth) / 2;
          final top = (height - scanHeight) / 2;

          final scanWindow = Rect.fromLTWH(
            left,
            top,
            scanWidth,
            scanHeight,
          );

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: scanWindow,
                onDetect: (capture) {
                  if (_isProcessing) return;

                  final barcodes = capture.barcodes;
                  if (barcodes.isEmpty) return;

                  final code = barcodes.first.rawValue;
                  if (code == null) return;

                  _isProcessing = true;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductScreen(barcode: code),
                    ),
                  ).then((_) {
                    _isProcessing = false;
                  });
                },
              ),

              // Overlay
              _ScannerOverlay(scanWindow: scanWindow),
              Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _openManualInput,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "Manueel toevoegen",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ],
          );
        },
      ),

    );
  }
}

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class MobileScannerSimple extends StatefulWidget {
  const MobileScannerSimple({super.key});

  @override
  State<MobileScannerSimple> createState() => _MobileScannerSimpleState();
}

class _MobileScannerSimpleState extends State<MobileScannerSimple> {
  Barcode? _barcode;
  bool _isScanning = false;
  final MobileScannerController _controller = MobileScannerController();
  double _focusAreaWidth = 200;
  double _focusAreaHeight = 100;
  double zoomScale = 0;
  bool isTorchOn = false;

  @override
  initState() {
    super.initState();
    // Inicializa el controlador del escáner

    Future.delayed(Duration(milliseconds: 50), () {
      final size = MediaQuery.of(context).size;
      setState(() {
        _focusAreaWidth = size.width * 0.9;
        _focusAreaHeight = size.width / 2;
        _controller.updateScanWindow(
          Rect.fromCenter(center: const Offset(0, 0), width: _focusAreaWidth, height: _focusAreaHeight),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Maneja el evento cuando se detecta un código
  void _handleBarcode(BarcodeCapture barcodes) {
    if (mounted) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
        if (!_isScanning && _barcode != null) {
          Navigator.pop(context, _barcode?.displayValue ?? '');
          _isScanning = true;
        }
      });
    }
  }

  // Aumentar el zoom (si el dispositivo lo soporta)
  void _increaseZoom() {
    if (zoomScale < 1) {
      zoomScale = zoomScale + 0.2;
      _controller.setZoomScale(zoomScale);
    }
  }

  void _resetZoom() {
    zoomScale = 0;
    _controller.resetZoomScale();
  }

  // Disminuir el zoom (si el dispositivo lo soporta)
  void _decreaseZoom() {
    if (zoomScale > 0) {
      zoomScale = zoomScale - 0.2;
      _controller.setZoomScale(zoomScale);
    }
  }

  void _onLlightButtonPressed() {
    setState(() {
      isTorchOn = !isTorchOn;
    });
    // Cambia el estado de la linterna
    _controller.toggleTorch();
  }

  // Control para cambiar el tamaño de la ventana de enfoque
  void _resizeFocusArea(DragUpdateDetails details) {
    if (details.localPosition.isFinite) {
      setState(() {
        _focusAreaWidth = details.localPosition.distance;
        _focusAreaHeight = details.localPosition.distance / 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escaner', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.grey,
      body: GestureDetector(
        onTap: _resetZoom,
        onPanUpdate: _resizeFocusArea,
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: _focusAreaWidth,
                  height: _focusAreaHeight,
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _handleBarcode,
                    errorBuilder: (context, error, stacktrace) {
                      return Center(child: Text('Error: $error'));
                    },
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              // child: Lottie.asset(
              //   'assets/lottie/scan.json',
              //   width: _focusAreaWidth,
              //   height: _focusAreaHeight,
              //   repeat: true,
              //   animate: true,
              // ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.zoom_in, color: Colors.white), onPressed: _increaseZoom),
                  IconButton(icon: Icon(Icons.restart_alt, color: Colors.white), onPressed: _resetZoom),
                  IconButton(icon: Icon(Icons.zoom_out, color: Colors.white), onPressed: _decreaseZoom),
                  IconButton(
                    icon: Icon(isTorchOn ? Icons.flash_off : Icons.flash_on, color: Colors.white),
                    onPressed: _onLlightButtonPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

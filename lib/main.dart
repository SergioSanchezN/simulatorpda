import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:simulatorpda/scanner_view.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewBypassSslPage(),
    );
  }
}

class WebViewBypassSslPage extends StatefulWidget {
  const WebViewBypassSslPage({super.key});

  @override
  State<WebViewBypassSslPage> createState() => _WebViewBypassSslPageState();
}

class _WebViewBypassSslPageState extends State<WebViewBypassSslPage> {
  InAppWebViewController? _controller;

  final Uri _url = Uri.parse(
    "https://vicky.productoslavictoria.com/WMS/index2.php?view=Vista/Logistica/scan_options",
  );

  Future<void> _escanear() async {
    var scanned = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MobileScannerSimple()),
    );

    if (scanned == null) return;

    final jsSafeCode = jsonEncode(scanned.toString());

    await _controller?.evaluateJavascript(
      source: """
    (function(){
      var el = document.activeElement;
      if (!el) return false;

      var code = $jsSafeCode;
      var tag  = (el.tagName || '').toUpperCase();
      var type = (el.type || '').toLowerCase();

      var isNumber   = (tag === 'INPUT' && type === 'number');
      var isTextLike = (tag === 'INPUT' && (
        type === 'text' || type === 'search' || type === 'tel' ||
        type === 'email' || type === 'url' || type === 'password'
      ));
      var isTextarea = (tag === 'TEXTAREA');
      var isEditable = !!el.isContentEditable;

      // 1) Escribir el valor (sin \\n ni \\t para evitar invalidar number)
      if (isNumber) {
        el.value = String(code);
      } else if (isTextLike || isTextarea) {
        el.value = String(code);
      } else if (isEditable) {
        el.innerText = String(code);
      } else {
        return false;
      }

      // 2) Notificar cambios
      el.dispatchEvent(new Event('input',  {bubbles:true}));
      // 'change' suele dispararse al perder foco; lo disparamos luego de blur

      // 3) Mover cursor al final (si aplica)
      if (el.setSelectionRange && (isTextLike || isTextarea)) {
        var len = el.value.length;
        el.setSelectionRange(len, len);
      }

      // 4) TAB REAL: cambiar el foco al siguiente (o anterior si goPrev)
      function focusablesInOrder(){
        return Array.from(document.querySelectorAll(
          'input, select, textarea, button, a[href], [tabindex]'
        )).filter(function(n){
          var style = window.getComputedStyle(n);
          var visible = n.offsetParent !== null && style.visibility !== 'hidden' && style.display !== 'none';
          var enabled = !n.disabled && n.tabIndex >= 0;
          return visible && enabled;
        }).sort(function(a,b){
          // ordenar por tabindex primero, luego por posición en el DOM
          var ta = a.tabIndex || 0, tb = b.tabIndex || 0;
          if (ta !== tb) return ta - tb;
          return 0;
        });
      }

      var list = focusablesInOrder();
      var i = list.indexOf(el);
      var dirPrev = false;

      // BLUR del actual para que 'change' se dispare como en un Tab real
      el.blur();
      el.dispatchEvent(new Event('change', {bubbles:true}));

      // Elegir siguiente/previo
      var next = null;
      if (i >= 0) {
          next = (i + 1 < list.length) ? list[i + 1] : list[0];
      }

      if (next) {
        next.focus();
        // si es texto, colocamos cursor al final
        if (next.setSelectionRange && next.value != null) {
          var L = next.value.length;
          try { next.setSelectionRange(L, L); } catch(e){}
        }
        return true;
      }

      return true;
    })();
  """,
    );
  }

  // Función para recargar la página
  Future<void> _recargar() async {
    if (_controller != null) {
      await _controller?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("WMS", style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFFBF1523),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _recargar,
            ),
          ],
        ),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri.uri(_url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              transparentBackground: false,
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;

              // Agregar el handler DESPUÉS de que el WebView se crea
              _controller?.addJavaScriptHandler(
                handlerName: 'openScanner',
                callback: (args) async {
                  print('Handler openScanner llamado con args: $args');
                  await _escanear();
                },
              );
            },
            onReceivedServerTrustAuthRequest: (controller, challenge) async {
              return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED,
              );
            },
            onLoadError: (controller, url, code, message) {
              debugPrint("LoadError [$code]: $message");
            },
            onLoadHttpError: (controller, url, statusCode, description) {
              debugPrint("HTTPError [$statusCode]: $description");
            },
            onLoadStop: (controller, url) {
              // Mejorar la detección de elementos con clase 'pda-scan'
              _controller?.evaluateJavascript(
                source: """
                  console.log('Configurando listeners para pda-scan');
                  
                  // Función para configurar los listeners
                  function setupScanListeners() {
                    var inputs = document.querySelectorAll('input.pda-scan');
                    console.log('Encontrados ' + inputs.length + ' inputs con clase pda-scan');
                    
                    inputs.forEach(function(input, index) {
                      console.log('Configurando listener para input ' + index + ', id: ' + input.id);
                      
                      // Remover listeners existentes para evitar duplicados
                      input.removeEventListener('focus', handleFocus);
                      input.removeEventListener('click', handleClick);
                      
                      // Agregar nuevos listeners
                      input.addEventListener('focus', handleFocus);
                      input.addEventListener('click', handleClick);
                    });
                  }
                  
                  function handleFocus(event) {
                    console.log('Focus en input con clase pda-scan, id: ' + event.target.id);
                    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                      window.flutter_inappwebview.callHandler('openScanner', event.target.id || 'no-id');
                    } else {
                      console.error('flutter_inappwebview no disponible');
                    }
                  }
                  
                  function handleClick(event) {
                    console.log('Click en input con clase pda-scan, id: ' + event.target.id);
                    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                      window.flutter_inappwebview.callHandler('openScanner', event.target.id || 'no-id');
                    }
                  }
                  
                  // Configurar listeners inicialmente
                  setupScanListeners();
                  
                  // También configurar un observer para elementos que se agreguen dinámicamente
                  var observer = new MutationObserver(function(mutations) {
                    var shouldResetup = false;
                    mutations.forEach(function(mutation) {
                      if (mutation.type === 'childList') {
                        mutation.addedNodes.forEach(function(node) {
                          if (node.nodeType === 1) { // Element node
                            if (node.classList && node.classList.contains('pda-scan')) {
                              shouldResetup = true;
                            } else if (node.querySelector && node.querySelector('.pda-scan')) {
                              shouldResetup = true;
                            }
                          }
                        });
                      }
                    });
                    
                    if (shouldResetup) {
                      console.log('Nuevos elementos pda-scan detectados, reconfigurando listeners');
                      setupScanListeners();
                    }
                  });
                  
                  observer.observe(document.body, {
                    childList: true,
                    subtree: true
                  });
                """,
              );
            },
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton(
          onPressed: _escanear,
          child: const Icon(Icons.barcode_reader),
        ),
      ),
    );
  }
}

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:permission_handler/permission_handler.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.bluetooth.request();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        camera: firstCamera, key: GlobalKey(),
      ),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({
    required Key key,
    required this.camera,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String text = ''; // define text as an instance variable

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.ultraHigh,
    );




    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _readTextFromImage() async {
    try {
      final XFile file = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      final RecognizedText recognisedText = await textRecognizer.processImage(inputImage);
      String text = recognisedText.text;
      Clipboard.setData(ClipboardData(text: text));
      // Copy the text to the clipboard
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 1),
      ));

      // Search the text on Perplexity
      String url = 'https://www.perplexity.ai/?q=$text&copilot=false&focus=wolfram';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewPage(url: url, key: GlobalKey(),),
        ),
      );
    } catch (e) {
      print(e);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PicSolve', textAlign: TextAlign.center),
        centerTitle: true,
      ),

      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: CameraPreview(_controller),
                  ),
                ),
                Container(
                    width: 150,
                    child:
                    Card(
                      child: IconButton(
                        icon: Icon(Icons.camera_enhance_rounded),
                        onPressed: () async {
                          await _readTextFromImage();
                        },
                      ),)
                )



              ],
            );


          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),

    );
  }
}

class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({Key? key, required this.url}) : super(key: key);

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  final _webViewController = FlutterWebviewPlugin();
  late String _textToSearch;

  @override
  void initState() {
    super.initState();
    _webViewController.onStateChanged.listen((state) {
      if (state.type == WebViewState.finishLoad) {
        // Wait for the page to load before interacting with it
        _interactWithPage();
      }
    });
    _textToSearch = _getTextToSearch();
  }

  @override
  void dispose() {
    _webViewController.dispose();
    super.dispose();
  }

  void _interactWithPage() async {
    // Find the input box and submit button on the page
    final inputBoxScript =
        'document.querySelector("#ppl-query-input")';
    final submitButtonScript =
        'document.querySelector("#ppl-search-button")';

    // Wait for the input box and submit button to appear on the page
    await Future.delayed(Duration(seconds: 3));

    // Enter the text into the input box
    await _webViewController.evalJavascript(
        '$inputBoxScript.value="$_textToSearch";');

    // Submit the form
    await _webViewController.evalJavascript(
        '$submitButtonScript.click();');
  }

  String _getTextToSearch() {
    // Get the text to search from the URL passed in through the constructor
    final uri = Uri.parse(widget.url);
    final textToSearch = uri.queryParameters['text'] ?? '';
    return textToSearch;
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _textToSearch));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Text copied to clipboard'),
      duration: Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.grey[900],
    ));

    return WebviewScaffold(
      url: widget.url,
      withZoom: true,
      withLocalStorage: true,
      initialChild: Center(child: CircularProgressIndicator()),
      appBar: AppBar(
        title: Text('Search Results'),
        actions: [
          IconButton(
            icon: Icon(Icons.copy),
            onPressed: _copyToClipboard,
          ),
        ],
      ),
    );
  }
}



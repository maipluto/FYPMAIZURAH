import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../common.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _loading = false;
  bool _isPickingImage = false;
  File? _image;
  final picker = ImagePicker();
  String pred = "";
  List<String> classes = [];
  String currentLanguage = "EN"; // State variable to track current language

  @override
  void initState() {
    super.initState();
    loadLabels();
  }

  Future<void> loadLabels() async {
    final String response = await rootBundle.loadString('assets/labels.txt');
    setState(() {
      classes = response.split('\n').map((e) => e.trim()).toList();
    });
  }

  Future<void> classifyImage(File image) async {
    setState(() {
      _loading = true;
    });
    await Future.delayed(Duration(seconds: 2));

    try {
      final interpreter =
          await tfl.Interpreter.fromAsset('assets/model_fruit.tflite');

      Uint8List imageData = image.readAsBytesSync();
      img.Image? pngImage = img.decodeImage(imageData);
      if (pngImage == null) {
        setState(() {
          _loading = false;
          pred = "Invalid";
        });
        return;
      }

      img.Image resizedImage =
          img.copyResize(pngImage, width: 224, height: 224);
      List<List<List<List<double>>>> input =
          _convertToCorrectInputShape(resizedImage, 224, 224);

      var output =
          List.filled(classes.length, 0.0).reshape([1, classes.length]);
      interpreter.run(input, output);

      List<double> processedOutput = output[0].sublist(0, classes.length);
      double maxValue = processedOutput.reduce((a, b) => a > b ? a : b);
      int argmax = processedOutput.indexOf(maxValue);

      double sum = processedOutput.reduce((a, b) => a + b);
      List<double> probabilities = processedOutput.map((e) => e / sum).toList();

      double confidenceThreshold = 0.1;
      String resultClass = probabilities[argmax] > confidenceThreshold
          ? classes[argmax]
          : "Invalid";

      if (resultClass == 'No fruit') {
        resultClass = "No fruit";
      }

      interpreter.close();

      setState(() {
        _loading = false;
        pred = resultClass;
        print("pred ${pred}");
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        _loading = false;
        pred = "Error occurred";
      });
    }
  }

  List<List<List<List<double>>>> _convertToCorrectInputShape(
      img.Image image, int width, int height) {
    List<List<List<List<double>>>> inputList = List.generate(
      1,
      (_) => List.generate(
        height,
        (_) => List.generate(
          width,
          (_) => List.filled(3, 0.0),
        ),
      ),
    );

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        img.Pixel pixel = image.getPixel(x, y);
        inputList[0][y][x][0] = (pixel.r.toDouble() - 127.5) / 127.5;
        inputList[0][y][x][1] = (pixel.g.toDouble() - 127.5) / 127.5;
        inputList[0][y][x][2] = (pixel.b.toDouble() - 127.5) / 127.5;
      }
    }

    return inputList;
  }

  Future<void> pickImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() {
      _isPickingImage = true;
      _loading = true;
    });

    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) {
        setState(() {
          _isPickingImage = false;
          _loading = false;
        });
        return;
      }

      setState(() {
        _image = File(pickedFile.path);
      });

      await classifyImage(_image!);
    } catch (e) {
      print("Error picking image: $e");
    } finally {
      setState(() {
        _isPickingImage = false;
      });
    }
  }

  Future<void> resetPrediction() async {
    setState(() {
      pred = "";
      _loading = false;
      _image = null;
    });
  }

  Future<void> toggleLanguage() async {
    setState(() {
      currentLanguage = currentLanguage == "EN" ? "MY" : "EN";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: Visibility(
        visible: pred != "",
        child: InkWell(
          onTap: toggleLanguage,
          child: Container(
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: Colors.yellow[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              "assets/icons/translation.png",
              height: 50,
              width: 50,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: double.infinity,
            child: Image.asset(
              "assets/icons/home_page.png",
              fit: BoxFit.cover,
            ),
          ),
          pred.isNotEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_image != null)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.yellow[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              _image!,
                              height: 250,
                              width: 250,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      padding: EdgeInsets.all(10),
                      margin:
                          EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${translateGeneral[currentLanguage]!['Result']} : ${labelTranslations[currentLanguage]![pred]}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (suggestions[currentLanguage]!.containsKey(pred))
                      Container(
                        padding: EdgeInsets.all(10),
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.yellow[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${translateGeneral[currentLanguage]!['Suggestion']} : ${suggestions[currentLanguage]![pred]!}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    SizedBox(height: 10),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_loading)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.black,
                          ),
                          SizedBox(width: 20),
                          Text("Loading…"),
                        ],
                      ),
                    SizedBox(height: 40),
                    InkWell(
                      onTap: () {
                        pickImage(ImageSource.camera);
                      },
                      child: Image.asset(
                        "assets/icons/camera.png",
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 25),
                    InkWell(
                      onTap: () {
                        pickImage(ImageSource.gallery);
                      },
                      child: Image.asset(
                        "assets/icons/gallery.png",
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
          Visibility(
            visible: pred.isNotEmpty,
            child: Positioned(
              top: 50,
              left: 25,
              child: Align(
                alignment: Alignment.topLeft,
                child: InkWell(
                  onTap: resetPrediction,
                  child: Container(
                    height: 45,
                    width: 50,
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset("assets/icons/back.png"),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

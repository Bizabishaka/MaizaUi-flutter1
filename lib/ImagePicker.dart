import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'JsonParser.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class ImagePickerApp extends StatefulWidget {
  const ImagePickerApp({Key? key}) : super(key: key);

  @override
  State<ImagePickerApp> createState() => _ImagePickerAppState();
}

class _ImagePickerAppState extends State<ImagePickerApp> {
  File? _image;
  String _serverResponse = '';

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null) return;
      final imagePermanent = await _savedFilePermanently(pickedFile.path);

      setState(() {
        _image = imagePermanent;
      });
    } on PlatformException catch (e) {
      print('Failed to pick image: $e');
    }
  }

  Future<File> _savedFilePermanently(String imagePath) async {
    final name = basename(imagePath);
    final directory = await getApplicationDocumentsDirectory();
    final image = File('${directory.path}/$name');

    return File(imagePath).copy(image.path);
  }

  Future<void> _uploadImage(String title, File file) async {
    setState(() {
    _isLoading = true;
    _serverResponse = '';
  });
    try {
      // Check if the app has permission to access the device's location
      bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        // Handle if location services are disabled
        setState(() {
          _serverResponse = 'Location services are disabled';
        });
        return;
      }

      // Check location permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Request location permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          // Handle if permission is permanently denied
          setState(() {
            _serverResponse = 'Location permission is permanently denied';
          });
          return;
        }
        if (permission == LocationPermission.denied) {
          // Handle if permission is denied
          setState(() {
            _serverResponse = 'Location permission is denied';
          });
          return;
        }
      }

      // Get the current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Extract latitude and longitude from the position
      double latitude = position.latitude;
      double longitude = position.longitude;

      // Now you have latitude and longitude, proceed with uploading the image
      var request = http.MultipartRequest("POST", Uri.parse("http://maiza.hawkinswinja.me/predict"));

      request.fields['title'] = "image";
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.headers['Authorization'] = ""; // Add your authorization header

      var picture = await http.MultipartFile.fromPath('image', file.path);
      request.files.add(picture);

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var result = String.fromCharCodes(responseData);



      // Parse the JSON response using JsonParser
    try {
      final parsedData = JsonParser.fromJson(result);
      // Access specific fields assuming parsedData has structure: `status`, `message`, `data`
      setState(() {
        _serverResponse = "Status: ${parsedData.status}\n"
                          "Message: ${parsedData.message}\n"
                          "Data: ${parsedData.data}";
      });
    } catch (jsonError) {
      setState(() {
        _serverResponse = 'Failed to parse response: $jsonError';
      });
    }
  } catch (e) {
    setState(() {
      _serverResponse = 'Error uploading image: $e';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick an Image'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                height: 100,
              ),
              _image != null
                  ? Image.file(
                _image!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              )
                  : Image.asset('assets/download.png'),
              SizedBox(
                height: 100,
              ),
              CustomButton(
                title: 'Pick From Gallery',
                icon: Icons.image_outlined,
                onClick: () => _getImage(ImageSource.gallery),
              ),
              CustomButton(
                title: 'Pick From Camera',
                icon: Icons.camera_alt_outlined,
                onClick: () => _getImage(ImageSource.camera),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () {
                  if (_image != null) {
                    _uploadImage('image', _image!);
                  } else {
                    setState(() {
                      _serverResponse = 'Please pick an image first';
                    });
                  }
                },
                child: Container(
                  height: 55,
                  width: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 35, 178, 135),
                        Color(0xff281537),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Overall Results',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _serverResponse,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClick;

  const CustomButton({
    required this.title,
    required this.icon,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.transparent, // Button text color
        ),
        onPressed: onClick,
        child: Row(
          children: [
            Icon(icon),
            SizedBox(
              width: 20,
            ),
            Text(title),
          ],
        ),
      ),
    );
  }
}


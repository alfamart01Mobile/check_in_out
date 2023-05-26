// A screen that allows users to take a picture using a given camera.
import 'dart:async';
import 'dart:io';
import 'package:FaceNetAuthentication/config/constant.dart';
import 'package:FaceNetAuthentication/services/camera.service.dart';
import 'package:FaceNetAuthentication/services/facenet.service.dart';
import 'package:FaceNetAuthentication/services/ml_vision_service.dart';
import 'package:FaceNetAuthentication/views/home.dart';
import 'package:FaceNetAuthentication/widgets/FacePainter.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show join;
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:FaceNetAuthentication/config/session.dart' as session;
import 'package:awesome_dialog/awesome_dialog.dart';

class SignIn extends StatefulWidget {
  final CameraDescription cameraDescription;

  const SignIn({
    Key key,
    @required this.cameraDescription,
  }) : super(key: key);

  @override
  SignInState createState() => SignInState();
}

class Employee {
  int employeeID;
  String employeeNo;
  String fullName;

  Employee({this.employeeID, this.employeeNo, this.fullName});

  static Employee fromDB(data) {
    return new Employee(
        employeeID: data['employeeID'],
        employeeNo: data['employeeNo'],
        fullName: data['fullName']);
  }
}

class SignInState extends State<SignIn> {
  /// Service injection
  CameraService _cameraService = CameraService();
  MLVisionService _mlVisionService = MLVisionService();
  FaceNetService _faceNetService = FaceNetService();

  Future _initializeControllerFuture;

  bool cameraInitializated = false;
  bool _detectingFaces = false;
  bool pictureTaked = false;

  // switchs when the user press the camera
  bool _saving = false;
  bool _bottomSheetVisible = false;

  String imagePath;
  Size imageSize;
  Face faceDetected;

  Employee employee;

  int type;
  String lattitude;
  String longitude;
  StreamSubscription<Position> positionStreamSubscription;

  bool isValidFace = false;
  @override
  void initState() {
    super.initState();

    _toggleListening();
    _start();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _cameraService.dispose();
    super.dispose();
  }

  void _toggleListening() {
    if (positionStreamSubscription == null) {
      const LocationOptions locationOptions =
          LocationOptions(accuracy: LocationAccuracy.medium);
      final Stream<Position> positionStream =
          Geolocator().getPositionStream(locationOptions);
      positionStreamSubscription = positionStream.listen((Position position) {
        if (mounted) {
          setState(() {
            this.lattitude = position.latitude.toString();
            this.longitude = position.longitude.toString();
          });
        }
      });
      positionStreamSubscription.pause();
    }

    setState(() {
      if (positionStreamSubscription.isPaused) {
        positionStreamSubscription.resume();
      } else {
        positionStreamSubscription.pause();
      }
    });
  }

  /// starts the camera & start framing faces
  _start() async {
    _initializeControllerFuture =
        _cameraService.startService(widget.cameraDescription);
    await _initializeControllerFuture;

    setState(() {
      cameraInitializated = true;
    });

    _frameFaces();
  }

  /// draws rectangles when detects faces
  _frameFaces() {
    imageSize = _cameraService.getImageSize();

    _cameraService.cameraController.startImageStream((image) async {
      if (_cameraService.cameraController != null) {
        // if its currently busy, avoids overprocessing
        if (_detectingFaces) return;

        _detectingFaces = true;

        try {
          List<Face> faces = await _mlVisionService.getFacesFromImage(image);

          if (faces != null) {
            if (faces.length > 0) {
              // preprocessing the image
              setState(() {
                faceDetected = faces[0];
              });

              if (_saving) {
                _saving = false;
                _faceNetService.setCurrentPrediction(image, faceDetected);
              }
            } else {
              setState(() {
                faceDetected = null;
              });
            }
          }

          _detectingFaces = false;
        } catch (e) {
          print(e);
          _detectingFaces = false;
        }
      }
    });
  }

  /// handles the button pressed event
  Future<void> onShot() async {
    if (faceDetected == null) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Text('No face detected!'),
            );
          });

      return false;
    } else {
      imagePath =
          join((await getTemporaryDirectory()).path, '${DateTime.now()}.png');

      _saving = true;

      await Future.delayed(Duration(milliseconds: 500));
      await _cameraService.cameraController.stopImageStream();
      await Future.delayed(Duration(milliseconds: 200));
      await _cameraService.takePicture(imagePath);

      setState(() {
        _bottomSheetVisible = true;
        pictureTaked = true;
      });
      bool isValid = await _faceNetService.checkFace(
          session.selectedFaceNet.toList(), _faceNetService.predictedData);

      if (isValid) {
        setState(() {
          isValidFace = isValid;
        });
      } else {
        print("invalid>>>>>>>>>>>>>>>>");
      }

      setState(() {});
      return true;
    }
  }

  Future _checkFace(faceNet) async {
    try {
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap(
          {"employeeID": 0, "faceNet": faceNet, "userEmpID": 0});
      var response = await dio.post(FR_IN_OUT_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });

      if (response.data == null) {
        return null;
      }
      print("Employee: ${response.data['fullName']}");

      return response.data;
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.WARNING,
        animType: AnimType.BOTTOMSLIDE,
        title: 'Error!',
        desc: 'Server connection failed!. ',
        dismissOnTouchOutside: false,
        btnOkText: "Ok",
        btnOkColor: Colors.orangeAccent,
        btnOkOnPress: () {},
      )..show();
      print("Connecting to server failed!.");
    }
  }

  Future _inOut() async {
    try {
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap({
        "employeeID": session.selectedEmployeeID,
        "type": type,
        "locationID": session.locationID,
        "lattitude": lattitude,
        "longitude": longitude,
        "isQRCode": 0
      });
      var response = await dio.post(FR_IN_OUT_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });

      if (response.data == null) {
        return null;
      }
      if (int.parse(response.data[0]['RETURN']) >= 0) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.SUCCES,
          animType: AnimType.BOTTOMSLIDE,
          title: 'Successfully!',
          desc: '${response.data[0]['MESSAGE']}',
          btnOkOnPress: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => Home()));
          },
        )..show();
        _uploadImage(response.data[0]['RETURN'].toString());
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.ERROR,
          animType: AnimType.BOTTOMSLIDE,
          title: 'Failed!',
          desc: '${response.data[0]['MESSAGE']}',
          btnOkOnPress: () {},
        )..show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.WARNING,
        animType: AnimType.BOTTOMSLIDE,
        title: 'Error!',
        desc: 'Server connection failed!. ',
        dismissOnTouchOutside: false,
        btnOkText: "Ok",
        btnOkColor: Colors.orangeAccent,
        btnOkOnPress: () {},
      )..show();
      print("Connecting to server failed!.");
    }
  }

  Future _uploadImage(id) async {
    try {
      print("Image is being upload...");
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap({
        "image":
            await MultipartFile.fromFile(imagePath, filename: '$type-$id.png')
      });
      var response = await dio.post(INOUT_UPLOAD_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });

      if (response.data == null) {
        return null;
      }
      print("Upload: ${response.data}");
      return response.data;
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.WARNING,
        animType: AnimType.BOTTOMSLIDE,
        title: 'Error!',
        desc: 'Server connection failed!. ',
        dismissOnTouchOutside: false,
        btnOkText: "Ok",
        btnOkColor: Colors.orangeAccent,
        btnOkOnPress: () {},
      )..show();
      print("Connecting to server failed!.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final double mirror = math.pi;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height - 300;
    return Phoenix(
      child: Scaffold(
        appBar: AppBar(
            title: Column(
          children: [
            session.locationID == null
                ? Text("CHECK IN & OUT")
                : Text('${session.locationCode} - ${session.location}'),
            Text(
              "${DateFormat('yyyy-MM-dd hh : mm : ss').format(DateTime.now())}",
              style: TextStyle(fontSize: 14),
            ),
          ],
        )),
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (pictureTaked) {
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: width,
                        height: height,
                        child: Transform(
                            alignment: Alignment.center,
                            child: Image.file(File(imagePath)),
                            transform: Matrix4.rotationY(mirror)),
                      ),
                      !isValidFace
                          ? Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Row(
                                        children: <Widget>[
                                          Text(
                                              "Sorry, you are not recognized as "),
                                          Text(
                                            " ${session.selectedEmployeeName}",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          )
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        new SizedBox(
                                          width: 150.0,
                                          height: 50,
                                          child: RaisedButton(
                                            color: Colors.redAccent,
                                            child: Text(
                                              "BACK TO HOME",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          Home()));
                                            },
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50.0),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Text(
                                        "Welcome, ${session.selectedEmployeeName}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        new SizedBox(
                                          width: 150.0,
                                          height: 50,
                                          child: RaisedButton(
                                            color: Colors.green,
                                            child: Text(
                                              "IN",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                type = 1;
                                              });
                                              _inOut();
                                            },
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50.0),
                                            ),
                                          ),
                                        ),
                                        new SizedBox(
                                          width: 20.0,
                                        ),
                                        new SizedBox(
                                          width: 150.0,
                                          height: 50,
                                          child: RaisedButton(
                                            color: Colors.orangeAccent,
                                            child: Text(
                                              "OUT",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                type = 0;
                                              });
                                              _inOut();
                                            },
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50.0),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            )
                    ],
                  ),
                );
              } else {
                return Transform.scale(
                  scale: 1.0,
                  child: AspectRatio(
                    aspectRatio: MediaQuery.of(context).size.aspectRatio,
                    child: OverflowBox(
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.fitHeight,
                        child: Container(
                          width: width,
                          height: width /
                              _cameraService.cameraController.value.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              CameraPreview(_cameraService.cameraController),
                              CustomPaint(
                                painter: FacePainter(
                                    face: faceDetected, imageSize: imageSize),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: !_bottomSheetVisible
            ? FloatingActionButton.extended(
                label: Text('Take Photo'),
                icon: Icon(Icons.camera_alt),
                // Provide an onPressed callback.
                onPressed: () async {
                  try {
                    onShot();
                  } catch (e) {
                    print(e);
                  }
                },
              )
            : Container(),
      ),
    );
  }
}

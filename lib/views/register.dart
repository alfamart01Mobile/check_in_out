import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:FaceNetAuthentication/config/constant.dart';
import 'package:FaceNetAuthentication/models/dropDown.dart';
import 'package:FaceNetAuthentication/views/home.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:FaceNetAuthentication/services/camera.service.dart';
import 'package:FaceNetAuthentication/services/facenet.service.dart';
import 'package:FaceNetAuthentication/services/ml_vision_service.dart';
import 'package:FaceNetAuthentication/widgets/FacePainter.dart';
import 'package:FaceNetAuthentication/config/session.dart' as session;

class Register extends StatefulWidget {
  final CameraDescription cameraDescription;

  const Register({Key key, @required this.cameraDescription}) : super(key: key);

  @override
  RegisterState createState() => RegisterState();
}

class RegisterState extends State<Register> {
  String imagePath;
  Face faceDetected;
  Size imageSize;

  bool _detectingFaces = false;
  bool pictureTaked = false;

  Future _initializeControllerFuture;
  bool cameraInitializated = false;

  // switchs when the user press the camera
  bool _saving = false;
  bool _bottomSheetVisible = false;

  // service injection
  MLVisionService _mlVisionService = MLVisionService();
  CameraService _cameraService = CameraService();
  FaceNetService _faceNetService = FaceNetService();

  // ignore: avoid_init_to_null
  var employeeIndex = null;

  @override
  void initState() {
    super.initState();

    /// starts the camera & start framing faces
    _start();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _cameraService.dispose();
    super.dispose();
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

  /// handles the button pressed event
  Future<void> onShot() async {
    print('onShot performed');

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

      setState(() {
        _saving = true;
        print("saving --------------- true");
      });

      await Future.delayed(Duration(milliseconds: 500));
      await _cameraService.cameraController.stopImageStream();
      await Future.delayed(Duration(milliseconds: 200));
      await _cameraService.takePicture(imagePath);

      setState(() {
        _bottomSheetVisible = true;
        pictureTaked = true;
      });

      return true;
    }
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

          if (faces.length > 0) {
            print("TEST:FACE DETECTED>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
            print(faces[0]);
            setState(() {
              faceDetected = faces[0];
            });
            print("SAVING STATUS : $_saving");
            if (_saving) {
              print("TEST:saving >>>>>>>>>>>>>>>>");
              _faceNetService.setCurrentPrediction(image, faceDetected);
              setState(() {
                _saving = false;
              });
            }
          } else {
            setState(() {
              faceDetected = null;
            });
          }

          _detectingFaces = false;
        } catch (e) {
          print(e);
          _detectingFaces = false;
        }
      }
    });
  }

  Future _signUp(context) async {
    List predictedData = _faceNetService.predictedData;
    print("predictData : ${predictedData.toString()}");
    if (predictedData != null) {
      saveRegistration(predictedData.toString());
    } else {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.ERROR,
        animType: AnimType.BOTTOMSLIDE,
        title: 'Failed!',
        desc: 'Face not detected!.',
        btnOkOnPress: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => Home()));
        },
      )..show();
    }
  }

  Future saveRegistration(faceNet) async {
    try {
      print(">>>>>>>> get employee");

      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap({
        "employeeID": employeeList[employeeIndex].id,
        "faceNet": faceNet,
        "userEmpID": session.userEmployeeID
      });
      var response = await dio.post(FR_REGISTER_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });

      if (int.parse(response.data[0]['RETURN']) >= 0) {
        this._faceNetService.setPredictedData(null);
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
          btnOkOnPress: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => Home()));
          },
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
        btnOkOnPress: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => Home()));
        },
      )..show();
      print("Connecting to server failed!.");
    }
  }

  Future _uploadImage(id) async {
    print("Image is being upload...");
    Dio dio = new Dio();
    dio.options.connectTimeout = 5000;
    dio.options.receiveTimeout = 5000;
    var formData = FormData.fromMap({
      "image": await MultipartFile.fromFile(imagePath, filename: '$id.png')
    });
    var response = await dio.post(REGISTRATION_UPLOAD_URL, data: formData,
        onSendProgress: (int sent, int total) {
      print("$sent $total");
    });

    if (response.data == null) {
      return null;
    }
    print("Upload: ${response.data}");
    return response.data;
  }

  @override
  Widget build(BuildContext context) {
    final double mirror = math.pi;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height - 300;
    return Scaffold(
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
          ),
        ),
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (pictureTaked) {
                return Padding(
                  padding: const EdgeInsets.all(10),
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
                      Padding(
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                          child: DropdownSearch<DropDown>(
                            items: employeeList,
                            itemAsString: (DropDown u) => u.name,
                            maxHeight: 300,
                            label: "Employee",
                            selectedItem: employeeIndex == null
                                ? null
                                : employeeList[employeeIndex],
                            onChanged: (e) {
                              print(e.name);
                              employeeIndex = employeeList.indexOf(e);
                              print(
                                  ">>>>>>>>>>>>>>>>>>>> EMPLOYEE: $employeeIndex");
                            },
                            showSearchBox: true,
                          )),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          new SizedBox(
                            width: 150.0,
                            height: 50,
                            child: RaisedButton(
                              color: Colors.green,
                              child: Text(
                                "SAVE",
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: () async {
                                if (employeeIndex == null) {
                                  AwesomeDialog(
                                    context: context,
                                    dialogType: DialogType.ERROR,
                                    animType: AnimType.BOTTOMSLIDE,
                                    title: 'Failed!',
                                    desc: 'Please select employee.',
                                    btnCancelText: 'Ok',
                                    btnCancelOnPress: () {},
                                  )..show();
                                } else {
                                  await _signUp(context);
                                }
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50.0),
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
                                "CANCEL",
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (BuildContext context) =>
                                            Home()));
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50.0),
                              ),
                            ),
                          ),
                        ],
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
                              ),
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
            : Container());
  }
}

import 'dart:async';
import 'dart:math';
import 'package:FaceNetAuthentication/views/in-out.dart';
import 'package:FaceNetAuthentication/views/loginView.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:FaceNetAuthentication/config/constant.dart';
import 'package:FaceNetAuthentication/views/generate.dart';
import 'package:FaceNetAuthentication/views/register.dart';
import 'package:FaceNetAuthentication/services/facenet.service.dart';
import 'package:FaceNetAuthentication/services/ml_vision_service.dart';
import 'package:FaceNetAuthentication/models/dropDown.dart';
import 'package:FaceNetAuthentication/config/session.dart' as session;
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:imei_plugin/imei_plugin.dart';
import 'package:intl/intl.dart';
import 'package:package_info/package_info.dart';
import 'package:platform_device_id/platform_device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info/package_info.dart';
import "package:http/http.dart" as http;

class Home extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomeState();
}

class HomeState extends State<Home> {
  // Services injection
  FaceNetService _faceNetService = FaceNetService();
  MLVisionService _mlVisionService = MLVisionService();

  CameraDescription cameraDescription;
  String _timeString = '';
  final _spServerUrl = TextEditingController();
  final _appServer = TextEditingController();
  int lastTap = DateTime.now().millisecondsSinceEpoch;

  String appName = "";
  String packageName = "";
  String version = "";
  String buildNumber = "";

  GoogleSignInAccount _currentUser;
  GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/contacts.readonly',
    ],
  );
  int consecutiveTaps = 0;
  @override
  void initState() {
    super.initState();
    getPackageInfo();
    _startUp();
    if (ISADMIN != 1) {
      timer();
      _getAppSettings();
    }

    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount account) {
      setState(() {
        _currentUser = account;
      });
      if (_currentUser != null) {
        print(_currentUser.email);
        print("------------ SUCCESSFULLY LOGIN EMAIL --------------");
        insertLocDeviceEmail();
      } else {
        print("------------ FAILED TO LOGIN EMAIL--------------");
      }
    });
  }

  Future<void> _handleSignIn() async {
    await _googleSignIn.signOut();
    try {
      print("START GETTING EMAIL");
      await _googleSignIn.signIn();
      print("EMAIL GETTING SUCCESSFULLY");
    } catch (error) {
      print(error);
    }
  }

  Future insertLocDeviceEmail() async {
    try {
      print("START INSERTING LOCATION DEVICE EMAIL");
      print(session.userDeviceID);
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap(
          {"androidID": session.userDeviceID, "email": _currentUser.email});
      var response = await dio.post(LOC_DEVICE_EMAIL_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });
      print(response.data);
      if (response.data.length == 0) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.ERROR,
          animType: AnimType.BOTTOMSLIDE,
          title: 'Failed!',
          desc: 'Device Initial Registration Failed!',
          dismissOnTouchOutside: false,
          btnOkText: "Close App",
          btnOkColor: Colors.red,
          btnOkOnPress: () {
            SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          },
        )..show();
      } else {
        if (int.parse(response.data[0]['RETURN']) >= 0) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.SUCCES,
            animType: AnimType.BOTTOMSLIDE,
            title: 'Successfully!',
            desc: response.data[0]['MESSAGE'],
            btnOkText: "Ok",
            btnOkOnPress: () {
              getLocDevice();
            },
          )..show();
        } else {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.ERROR,
            animType: AnimType.BOTTOMSLIDE,
            title: 'Failed!',
            desc: response.data[0]['MESSAGE'],
            btnOkText: "Ok",
            btnOkOnPress: () {},
          )..show();
        }
      }
    } catch (e) {
      print(e);
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
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        },
      )..show();
      print("Connecting to server failed!.");
    }
  }

  void getPackageInfo() {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      this.appName = packageInfo.appName;
      this.packageName = packageInfo.packageName;
      this.version = packageInfo.version;
      this.buildNumber = packageInfo.buildNumber;
      print("version >>>>>>>>>>> $version");
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getAppSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _spServerUrl.text = prefs.getString("spServerUrl") ?? '';
    _appServer.text = prefs.getString("appServer") ?? '';
    setState(() {
      if (_spServerUrl.text == '') {
        _spServerUrl.text = API_URL;
      } else {
        API_URL = _spServerUrl.text;
      }
      if (_appServer.text == '') {
        _appServer.text = APP_SERVER;
      } else {
        APP_SERVER = _appServer.text;
      }
      setValuesApi();
    });
  }

  void setValuesApi() {
    setState(() {
      PING_URL = API_URL + '/ping';
      LOC_DEVICE_URL = API_URL + '/';
      CREATE_QRCODE = API_URL + '/generate-qrcode';
      TIME_START_URL = API_URL + '/get-qrcode-timer';
      EMPLOYEE_URL = API_URL + '/get-employee-list';
      FR_IN_OUT_URL = API_URL + '/insert-update-emp-visit';
      FR_REGISTER_URL = API_URL + '/insert-fr';
      FR_REGISTERED_URL = API_URL + '/get-registered-fr';
      INOUT_UPLOAD_URL = API_URL + '/upload-image';
      REGISTRATION_UPLOAD_URL = API_URL + '/registration-upload-image';
      LOGIN_URL = API_URL + '/login';
      LOC_DEVICE_EMAIL_URL = API_URL + '/insert-loc-device-email';
    });
    if (session.userImei == null && session.locationID == null) {
      _setImei();
    }
  }

  Future<void> _setImei() async {
    String platformImei;
    String deviceId;
    try {
      deviceId = await PlatformDeviceId.getDeviceId;
      print("ANDROID ID : $deviceId");
      platformImei =
          await ImeiPlugin.getImei(shouldShowRequestPermissionRationale: false);
    } catch (e) {
      deviceId = 'Failed to get platform version.';
      print(deviceId);
    }

    if (!mounted) return;

    if (deviceId == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.ERROR,
        animType: AnimType.BOTTOMSLIDE,
        title: 'Error!',
        desc: 'Device ID not detected!. ',
        dismissOnTouchOutside: false,
        btnOkText: "Restart",
        btnOkColor: Colors.red,
        btnOkOnPress: () {
          Phoenix.rebirth(context);
        },
      )..show();
    } else {
      setState(() {
        session.userImei = platformImei;
        session.userDeviceID = deviceId;
        getLocDevice();
      });
    }
  }

  /// 1 Obtain a list of the available cameras on the device.
  /// 2 loads the face net model
  _startUp() async {
    List<CameraDescription> cameras = await availableCameras();

    /// takes the front camera
    cameraDescription = cameras.firstWhere(
      (CameraDescription camera) =>
          camera.lensDirection == CameraLensDirection.front,
    );

    // start the services
    await _faceNetService.loadModel();
    _mlVisionService.initialize();
  }

  timer() {
    const oneSec = const Duration(seconds: 1);
    new Timer.periodic(oneSec, (Timer timer) {
      if (mounted) {
        setState(
          () {
            _timeString =
                "${DateFormat('yyyy-MM-dd hh : mm : ss').format(DateTime.now())}";
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Phoenix(
      child: Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () {
                int now = DateTime.now().millisecondsSinceEpoch;
                if (now - lastTap < 500) {
                  print("Consecutive tap");
                  consecutiveTaps++;
                  print("taps = " + consecutiveTaps.toString());
                  if (consecutiveTaps == 3) {
                    print("go to login");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) => LoginPage(),
                      ),
                    );
                  }
                } else {
                  consecutiveTaps = 0;
                }
                lastTap = now;
              },
              child: Container(
                child: ISADMIN == 1
                    ? Text("${session.userFullName}")
                    : Column(
                        children: [
                          session.locationID == null
                              ? Text("CHECK IN & OUT")
                              : Text(
                                  '${session.locationCode} - ${session.location}'),
                          Text(
                            _timeString,
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
              ),
            ),
            automaticallyImplyLeading: false,
          ),
          body: Container(
            color: const Color(0xFFFFFFFF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(80.0),
                    child: Center(
                        child: ISADMIN == 1
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  new SizedBox(
                                    height: 40,
                                  ),
                                  new SizedBox(
                                    width: 300.0,
                                    height: 80,
                                    child: RaisedButton(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: <Widget>[
                                          Text(
                                            "AI FACIAL RECOGNITION",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12),
                                          ),
                                          Text(
                                            "REGISTRATION",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20),
                                          ),
                                        ],
                                      ),
                                      color: Colors.orangeAccent,
                                      onPressed: () {
                                        if (employeeList.length == 0) {
                                          getEmployee();
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (BuildContext context) =>
                                                Register(
                                              cameraDescription:
                                                  cameraDescription,
                                            ),
                                          ),
                                        );
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(50.0),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : session.locationID == null
                                ? Center(child: Text("Loading..."))
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      new SizedBox(
                                        width: 300.0,
                                        height: 80,
                                        child: RaisedButton(
                                          child: Text(
                                            "GENERATE QR",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20),
                                          ),
                                          color: Colors.green,
                                          onPressed: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        GenerateScreen()));
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(50.0),
                                          ),
                                        ),
                                      ),
                                      new SizedBox(
                                        height: 40,
                                      ),
                                      // new SizedBox(
                                      //   width: 300.0,
                                      //   height: 80,
                                      //   child: RaisedButton(
                                      //     child: Column(
                                      //       mainAxisAlignment:
                                      //           MainAxisAlignment.center,
                                      //       crossAxisAlignment:
                                      //           CrossAxisAlignment.center,
                                      //       children: <Widget>[
                                      //         Text(
                                      //           "AI FACIAL RECOGNITION",
                                      //           style: TextStyle(
                                      //               color: Colors.white,
                                      //               fontSize: 12),
                                      //         ),
                                      //         Text(
                                      //           "IN | OUT",
                                      //           style: TextStyle(
                                      //               color: Colors.white,
                                      //               fontSize: 20),
                                      //         ),
                                      //       ],
                                      //     ),
                                      //     color: Colors.purpleAccent,
                                      //     onPressed: () {
                                      //       _scan();
                                      //     },
                                      //     shape: RoundedRectangleBorder(
                                      //       borderRadius:
                                      //           BorderRadius.circular(50.0),
                                      //     ),
                                      //   ),
                                      // ),
                                    ],
                                  )),
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      "APP_VERSION : ${this.version}",
                      style: TextStyle(color: Colors.redAccent),
                    ))
              ],
            ),
          )),
    );
  }

  Future getLocDevice() async {
    try {
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap({"androidID": session.userDeviceID});
      var response = await dio.post(LOC_DEVICE_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });
      print("DEVICE ID >>> ${session.userDeviceID}");
      print(response.data.toString());
      if (response.data.length == 0) {
        _handleSignIn();
      } else {
        if (response.data[0]['MobileAppVersion'] != null) {
          if (this.version != response.data[0]['MobileAppVersion']) {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.WARNING,
              animType: AnimType.BOTTOMSLIDE,
              title: 'New Update Available',
              desc:
                  'This application current version is ${this.version} and need update to version ${response.data[0]['MobileAppVersion']}',
              dismissOnTouchOutside: false,
              dismissOnBackKeyPress: true,
              btnOkText: "Ok",
              btnOkColor: Colors.orangeAccent,
              btnOkOnPress: () {
                SystemChannels.platform
                    .invokeMethod('SystemNavigator.pop', true);
              },
            )..show();
          }
        }
        setState(() {
          session.locationID = int.parse(response.data[0]['Location_ID']);
          session.locationCode = response.data[0]['LocationCode'];
          session.location = response.data[0]['Location'];
        });
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
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        },
      )..show();
      print("Connecting to server failed!.");
    }
  }

  Future getEmployee() async {
    try {
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap({
        "employeeID": 0,
        "employeeNo": "",
        "userEmpID": session.userEmployeeID
      });

      var response = await dio.post(EMPLOYEE_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });

      for (int c = 0; c < response.data.length; c++) {
        setState(() {
          for (int c = 0; c < response.data.length; c++) {
            employeeList.add(DropDown(
                id: response.data[c]['Employee_ID'].toString(),
                name: "${response.data[c]['Employee']}"));
          }
        });
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

  Future getEmployeeByNo(employeeNo) async {
    try {
      setState(() {
        session.selectedEmployeeID = null;
        session.selectedEmployeeNo = null;
        session.selectedEmployeeName = null;
      });
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap(
          {"employeeID": 0, "employeeNo": employeeNo, "userEmpID": 0});

      var response = await dio.post(FR_REGISTERED_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });
      setState(() {
        if (response.data.length == 1) {
          session.selectedEmployeeID =
              int.parse(response.data[0]['Employee_ID']);
          session.selectedEmployeeNo = response.data[0]['EmployeeNo'];
          session.selectedEmployeeName = response.data[0]['FullName'];
          session.selectedFaceNet = response.data[0]['FaceNet'];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) => SignIn(
                cameraDescription: cameraDescription,
              ),
            ),
          );
        } else {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.ERROR,
            animType: AnimType.BOTTOMSLIDE,
            title: 'Failed!',
            desc: 'Employee not found!.',
            dismissOnTouchOutside: false,
            btnOkText: "Ok",
            btnOkColor: Colors.red,
            btnOkOnPress: () {},
          )..show();
        }
      });
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

  Future _scan() async {
    try {
      String barcode = await BarcodeScanner.scan();
      if (barcode != '' && barcode.length >= 9) {
        getEmployeeByNo(barcode.substring(0, 9));
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.ERROR,
          animType: AnimType.BOTTOMSLIDE,
          title: 'Failed!',
          desc: 'Invalid employee number!',
          dismissOnTouchOutside: true,
          btnOkText: "Close App",
          btnOkColor: Colors.red,
          btnOkOnPress: () {},
        )..show();
      }
    } catch (e) {
      print("Scanning is cancelled");
    }
  }
}

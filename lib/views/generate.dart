import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:FaceNetAuthentication/config/constant.dart';
import 'package:geolocator/geolocator.dart';
import 'package:FaceNetAuthentication/config/session.dart' as session;

class GenerateScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => GenerateScreenState();
}

class GenerateScreenState extends State<GenerateScreen> {
  bool _isLoading = true;
  GlobalKey globalKey = new GlobalKey();
  String _qrcode = "";
  String _userImei;
  int _start;
  String _lattitude = "UNKNOWN";
  String _longitude = "UNKNOWN";
  StreamSubscription<Position> _positionStreamSubscription;
  bool _isStart = false;
  @override
  void initState() {
    super.initState();

    _toggleListening();
    getTimer();
    generateQRCode();
  }

  void _toggleListening() {
    if (_positionStreamSubscription == null) {
      const LocationOptions locationOptions =
          LocationOptions(accuracy: LocationAccuracy.medium);
      final Stream<Position> positionStream =
          Geolocator().getPositionStream(locationOptions);
      _positionStreamSubscription = positionStream.listen((Position position) {
        if (mounted) {
          setState(() {
            this._lattitude = position.latitude.toString();
            this._longitude = position.longitude.toString();
            _isStart = true;
          });
        }
      });
      _positionStreamSubscription.pause();
    }

    setState(() {
      if (_positionStreamSubscription.isPaused) {
        _positionStreamSubscription.resume();
      } else {
        _positionStreamSubscription.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _contentWidget(),
    );
  }

  _contentWidget() {
    return _start == null
        ? Center(child: CircularProgressIndicator())
        : Container(
            color: const Color(0xFFFFFFFF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(80.0),
                    child: _isStart != true
                        ? Center(
                            child: Text(
                              "Identifying Location. Please wait... ",
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          )
                        : _lattitude == "UNKNOWN"
                            ? Center(
                                child: Text(
                                  "Device location not found!. Make sure device GPS is ON.",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              )
                            : Center(
                                child: _qrcode == null
                                    ? Text("No QRCode Generated")
                                    : RepaintBoundary(
                                        key: globalKey,
                                        child: QrImage(
                                          data: _qrcode,
                                        ),
                                      ),
                              ),
                  ),
                ),
                Text("lat: $_lattitude, long: $_longitude"),
                Text("Device ID: ${session.userDeviceID}"),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                      'QR Code will refresh in ${_start.toString().padLeft(2, "0")} second(s)'),
                )
              ],
            ),
          );
  }

  Future generateQRCode() async {
    try {
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap({
        "locationID": session.locationID,
        "lattitude": _lattitude,
        "longitude": _longitude
      });

      var response = await dio.post(CREATE_QRCODE, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });
      setState(() {
        print("qrcode: ${response.data}");
        _qrcode = response.data[0]['RETURN'];
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

  Future getTimer() async {
    try {
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap({"imei": session.userImei});

      var response = await dio.post(TIME_START_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });
      print("TIMER>>>>>> ${response.data}");
      print(response.data);

      _isLoading = false;
      if (mounted) {
        setState(() {
          _start = int.parse(response.data);
          TIMER_START = int.parse(response.data);
        });
      }
      const oneSec = const Duration(seconds: 1);
      new Timer.periodic(oneSec, (Timer timer) {
        if (mounted) {
          setState(
            () {
              setState(() {
                if (_start == 0) {
                  _start = TIMER_START;
                  generateQRCode();
                } else {
                  _start--;
                }
              });
            },
          );
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
}

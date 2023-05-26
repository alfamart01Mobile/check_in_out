import 'dart:async';
import 'package:FaceNetAuthentication/views/home.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:FaceNetAuthentication/config/constant.dart';
import 'package:FaceNetAuthentication/config/session.dart' as session;
import 'package:package_info/package_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery Scanner',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: LoginPage(title: "Admin Login"),
    );
  }
}

class LoginPage extends StatefulWidget {
  LoginPage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final bool _isValidUser = false;
  bool _isPasswordVisible;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _spServerUrl = TextEditingController();
  final _appServer = TextEditingController();
  int lastTap = DateTime.now().millisecondsSinceEpoch;
  int consecutiveTaps = 0;

  String appName = "";
  String packageName = "";
  String version = "";
  String buildNumber = "";

  @override
  void initState() {
    super.initState();
    getPackageInfo();
    this._usernameController.text = '';
    this._passwordController.text = '';
    _isPasswordVisible = true;
    _getAppSettings();
  }

  void getPackageInfo() {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      this.appName = packageInfo.appName;
      this.packageName = packageInfo.packageName;
      this.version = packageInfo.version;
      this.buildNumber = packageInfo.buildNumber;
      print("version >>>>>>>>>>> $version");
      getApiAppSettings();
    });
  }

  Future getApiAppSettings() async {
    try {
      print(ADMIN_VERSION_URL);
      var response = await Dio().post(
        ADMIN_VERSION_URL,
        onSendProgress: (int sent, int total) {
          print("$sent $total");
        },
      );
      print(response.data.toString());
      setState(() {
        print("app setting : ${response.data}");
        if (response.data['MobileAppVersion'] != null) {
          if (this.version != response.data['MobileAppVersion']) {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.WARNING,
              animType: AnimType.BOTTOMSLIDE,
              title: 'New Update Available',
              desc:
                  'This application current version is ${this.version} and need update to version ${response.data['MobileAppVersion']}',
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
      });
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.ERROR,
        animType: AnimType.BOTTOMSLIDE,
        title: 'Error found!',
        desc:
            'System encounter error durring request to get application version!. Please report to system administrator!. ',
        dismissOnTouchOutside: true,
        btnCancelText: "Close",
        btnCancelOnPress: () {
          SystemChannels.platform.invokeMethod('SystemNavigator.pop', true);
        },
      )..show();

      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return WillPopScope(
      onWillPop: () => _appExitConfirm(),
      child: Scaffold(
        body: Builder(builder: (BuildContext context) {
          return Center(
              child: Container(
            padding: new EdgeInsets.all(20.0),
            child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(120, 0, 120, 20),
                      child: Image.asset(
                        'assets/img/app-icon.png',
                      ),
                    ),
                    new TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: 'username'),
                      keyboardType: TextInputType.text,
                      readOnly: false,
                      maxLines: 1,
                    ),
                    new TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            }),
                      ),
                      keyboardType: TextInputType.text,
                      readOnly: false,
                      maxLines: 1,
                    ),
                    new SizedBox(
                      height: 10.0,
                    ),
                    new ButtonBar(
                      alignment: MainAxisAlignment.center,
                      children: <Widget>[
                        new RaisedButton(
                          onPressed: () {
                            if (ISADMIN == 1) {
                              _appExitConfirm();
                            } else {
                              if (ISADMIN == 0) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (BuildContext context) => Home(),
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                              ISADMIN == 1 ? "    Cancel    " : "    Back    "),
                          shape: new RoundedRectangleBorder(
                              borderRadius: new BorderRadius.circular(30.0)),
                          color: Colors.redAccent,
                        ),
                        new RaisedButton(
                            onPressed: _isValidUser
                                ? null
                                : () async {
                                    if (_usernameController.text ==
                                            adminUserName &&
                                        _passwordController.text ==
                                            adminPassword) {
                                      _appSettings();
                                    } else {
                                      await getEmployee();
                                    }
                                  },
                            child: Text("     Login     "),
                            shape: new RoundedRectangleBorder(
                                borderRadius: new BorderRadius.circular(30.0)),
                            color: Colors.red),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        '$APP_SERVER - ${this.version}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  ],
                )),
          ));
        }),
      ),
    );
  }

  Future getEmployee() async {
    try {
      Dio dio = new Dio();
      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 5000;
      var formData = FormData.fromMap({
        "employeeNo": _usernameController.text,
        "password": _passwordController.text
      });
      var response = await dio.post(LOGIN_URL, data: formData,
          onSendProgress: (int sent, int total) {
        print("$sent $total");
      });

      print("Response : ${response.headers}");
      if (response.data['apiReturn'] == 1) {
        setState(() {
          session.userEmployeeID =
              int.parse(response.data['data'][0]['Emp_ID']);
          session.userEmployeeNo = response.data['data'][0]['EmployeeNo'];
          session.userFullName = response.data['data'][0]['empl_name'];
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => Home(),
          ),
        );
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.ERROR,
          animType: AnimType.BOTTOMSLIDE,
          title: 'Opps!',
          desc: '${response.data['apiMesssage']}',
          dismissOnTouchOutside: false,
          btnOkText: "Ok",
          btnOkColor: Colors.red,
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

  Future<bool> _appExitConfirm() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Are you sure?'),
        content: Text('Do you want to close an App'),
        actions: <Widget>[
          FlatButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          FlatButton(
            onPressed: () => SystemChannels.platform
                .invokeMethod('SystemNavigator.pop', true),
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<bool> _appSettings() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('App Settings'),
        content: Container(
            width: MediaQuery.of(context).size.width,
            height: 200,
            child: Column(
              children: <Widget>[
                new TextFormField(
                  style: TextStyle(fontSize: 11),
                  controller: _appServer,
                  decoration: InputDecoration(labelText: 'Server Name'),
                  keyboardType: TextInputType.text,
                  readOnly: false,
                  maxLines: 1,
                ),
                new TextFormField(
                  style: TextStyle(fontSize: 11),
                  controller: _spServerUrl,
                  decoration: InputDecoration(labelText: 'API Url'),
                  keyboardType: TextInputType.url,
                  readOnly: false,
                  maxLines: 2,
                ),
              ],
            )),
        actions: <Widget>[
          FlatButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          FlatButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              _updateAppSettings();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
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
      ADMIN_VERSION_URL = API_URL + '/admin-app-version';
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
  }

  Future<void> _updateAppSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      prefs.setString('spServerUrl', _spServerUrl.text);
      API_URL = _spServerUrl.text;
      setValuesApi();
    });
  }
}

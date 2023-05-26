import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:FaceNetAuthentication/config/constant.dart';
import 'package:FaceNetAuthentication/services/facenet.service.dart';
import 'package:flutter/material.dart';
import 'package:FaceNetAuthentication/views/home.dart';
import 'package:FaceNetAuthentication/models/dropDown.dart';

class User {
  String user;
  String password;

  User({@required this.user, @required this.password});

  static User fromDB(String dbuser) {
    return new User(user: dbuser.split(':')[0], password: dbuser.split(':')[1]);
  }
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

class AuthActionButton extends StatefulWidget {
  AuthActionButton(this._initializeControllerFuture,
      {@required this.onPressed, @required this.isLogin});
  final Future _initializeControllerFuture;
  final Function onPressed;
  final bool isLogin;
  @override
  _AuthActionButtonState createState() => _AuthActionButtonState();
}

class _AuthActionButtonState extends State<AuthActionButton> {
  /// service injection
  final FaceNetService _faceNetService = FaceNetService();
  final TextEditingController _userTextEditingController =
      TextEditingController(text: '');
  final TextEditingController _passwordTextEditingController =
      TextEditingController(text: '');

  User predictedUser;
  Employee employee;
  // ignore: avoid_init_to_null
  var employeeIndex = null;

  Future _signUp(context) async {
    List predictedData = _faceNetService.predictedData;

    if (predictedData != null) {
      _saveSignUp(predictedData.toString());

      this._faceNetService.setPredictedData(null);
      Navigator.push(context,
          MaterialPageRoute(builder: (BuildContext context) => Home()));
    } else {
      final snackBar = SnackBar(content: Text('Face net is empty!'));
      Scaffold.of(context).showSnackBar(snackBar);
    }
  }

  Future _saveSignUp(faceNet) async {
    print(">>>>>>>> get employee");

    Dio dio = new Dio();
    var formData = FormData.fromMap({
      "employeeID": employeeList[employeeIndex].id,
      "faceNet": faceNet,
      "userEmpID": 0
    });
    var response = await dio.post(FR_REGISTER_URL, data: formData,
        onSendProgress: (int sent, int total) {
      print("$sent $total");
    });
  }

  Future _checkFace(faceNet) async {
    print(">>>>>>>> check facenet");

    Dio dio = new Dio();
    var formData =
        FormData.fromMap({"employeeID": 0, "faceNet": faceNet, "userEmpID": 0});
    var response = await dio.post(FR_IN_OUT_URL, data: formData,
        onSendProgress: (int sent, int total) {
      print("$sent $total");
    });
    print("Employee: ${response.data['fullName']}");

    return response.data;
  }

  // Future _signIn(context) async {
  //   String password = _passwordTextEditingController.text;

  //   if (this.predictedUser.password == password) {
  //     Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //             builder: (BuildContext context) => Profile(
  //                   username: this.predictedUser.user,
  //                 )));
  //   } else {
  //     print(" WRONG PASSWORD!");
  //   }
  // }

  String _predictUser() {
    String userAndPass = _faceNetService.predict();
    return userAndPass ?? null;
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      label: Text('Take Photo'),
      icon: Icon(Icons.camera_alt),
      // Provide an onPressed callback.
      onPressed: () async {
        try {
          await widget._initializeControllerFuture;
          bool faceDetected = await widget.onPressed();

          if (faceDetected) {
            if (widget.isLogin) {
              var data = _checkFace(_faceNetService.predictedData.toString());
              if (data != null) {
                this.employee = Employee.fromDB(data);
              }
            }
            Scaffold.of(context)
                .showBottomSheet((context) => signSheet(context));
          }
        } catch (e) {
          print(e);
        }
      },
    );
  }

  signSheet(context) {
    return Container(
      padding: EdgeInsets.all(20),
      height: 300,
      child: Column(
        children: [
          widget.isLogin && employee != null
              ? Container(
                  child: Text(
                    'Welcome back, ' + employee.fullName + '! 😄',
                    style: TextStyle(fontSize: 20),
                  ),
                )
              : widget.isLogin
                  ? Container(
                      child: Text(
                      'User not found 😞',
                      style: TextStyle(fontSize: 20),
                    ))
                  : Container(),
          !widget.isLogin
              ? employeeList.length == 0
                  ? Text("")
                  : Padding(
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
                      ))
              : Container(),
          widget.isLogin
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        RaisedButton(
                          child: Text('IN'),
                          onPressed: () async {
                            // _signIn(context);
                          },
                        ),
                        Spacer(),
                        RaisedButton(
                          child: Text('OUT'),
                          onPressed: () async {
                            // _signIn(context);
                          },
                        )
                      ],
                    ),
                  ),
                )
              : !widget.isLogin
                  ? RaisedButton(
                      child: Text('Submit'),
                      onPressed: () async {
                        await _signUp(context);
                      },
                    )
                  : Container(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

import 'package:FaceNetAuthentication/models/dropDown.dart';

// ignore: non_constant_identifier_names
int TIMER_START = 20;
String APP_TITLE = 'QR Generator-Scanner';
String APP_NAME = "CHECK IN & OUT";
String APP_VERSION = "1.1.1";
int ISADMIN = 0;

String APP_SERVER = "Production";
String API_URL = 'https://myhub.atp.ph/checkInOut/api/store';

// String APP_SERVER = "Development";
// String API_URL = 'http://10.245.11.47/checkInOut/api/store';

String ADMIN_VERSION_URL = API_URL + '/admin-app-version';
String PING_URL = API_URL + '/ping';
String LOC_DEVICE_URL = API_URL + '/';
String CREATE_QRCODE = API_URL + '/generate-qrcode';
String TIME_START_URL = API_URL + '/get-qrcode-timer';
String EMPLOYEE_URL = API_URL + '/get-employee-list';
String FR_IN_OUT_URL = API_URL + '/insert-update-emp-visit';
String FR_REGISTER_URL = API_URL + '/insert-fr';
String FR_REGISTERED_URL = API_URL + '/get-registered-fr';
String INOUT_UPLOAD_URL = API_URL + '/upload-image';
String REGISTRATION_UPLOAD_URL = API_URL + '/registration-upload-image';
String LOGIN_URL = API_URL + '/login';
String LOC_DEVICE_EMAIL_URL = API_URL + '/insert-loc-device-email';

String APP_KEY = 'Atp1t4m@n1l@';
String SECRET_KEY = 'my32lengthsupersecretnooneknows1';
String adminUserName = 'admin';
String adminPassword = 'ch3ck1n0ut_@dm1n';

List<DropDown> employeeList = [];

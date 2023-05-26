class QRCode
{
  final int apiReturn;
  final String qrCode;

  QRCode({this.apiReturn,this.qrCode});

  factory QRCode.fromJson(Map<String, dynamic> json)
  {
    return QRCode
      (
        apiReturn : json['apiReturn'],
        qrCode    : json['qrCode']
    );
  }

  Map toMap()
  {
    var map = new Map<String, dynamic>();
    map["apiReturn"]  = apiReturn;
    map["qrCode"]     = qrCode;
    return map;
  }

}
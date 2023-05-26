class Imei
{
  final String imei;
  final String lattitude;
  final String longitude;

  Imei({this.imei,this.lattitude,this.longitude});

  factory Imei.fromJson(Map<String, dynamic> json)
  {
    return Imei
    (
      imei       :   json['imei'],
      lattitude  :   json['lattitude'],
      longitude  :   json['longitude']
    );
  }

  Map toMap()
  {
    var map = new Map<String, dynamic>();
    map["imei"]       = imei;
    map["lattitude"]  = lattitude;
    map["longitude"]  = longitude;
    return map;
  }
}
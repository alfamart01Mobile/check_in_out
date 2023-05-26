class TimeStart
{
  final int apiReturn;
  final int timeStart;

  TimeStart({this.apiReturn,this.timeStart});

  factory TimeStart.fromJson(Map<String, dynamic> json)
  {
    return TimeStart
      (
        apiReturn : json['apiReturn'],
        timeStart    : json['timeStart']
    );
  }

  Map toMap()
  {
    var map = new Map<String, dynamic>();
    map["apiReturn"]  = apiReturn;
    map["timeStart"]     = timeStart;
    return map;
  }

}
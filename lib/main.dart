import 'dart:async';
import 'dart:io';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, Object>? _locationResult;

  StreamSubscription<Map<String, Object>>? _locationListener;

  final AMapFlutterLocation _locationPlugin = AMapFlutterLocation();

  bool _mapInitializationFailed = false;
  AMapController? _mapController;
  Set<Marker> _markers = {};

  List<LatLng> _tracePoints = []; // 存放轨迹点
  Set<Polyline> _polylines = {}; // 轨迹线

  double _nearbyRadiusMeters = 10.0;
  bool _isSimulating = false;
  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();

    /// 设置是否已经包含高德隐私政策并弹窗展示显示用户查看，如果未包含或者没有弹窗展示，高德定位SDK将不会工作
    ///
    /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy
    /// <b>必须保证在调用定位功能之前调用， 建议首次启动App时弹出《隐私政策》并取得用户同意</b>
    ///
    /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy
    ///
    /// [hasContains] 隐私声明中是否包含高德隐私政策说明
    ///
    /// [hasShow] 隐私权政策是否弹窗展示告知用户
    AMapFlutterLocation.updatePrivacyShow(true, true);

    /// 设置是否已经取得用户同意，如果未取得用户同意，高德定位SDK将不会工作
    ///
    /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy
    ///
    /// <b>必须保证在调用定位功能之前调用, 建议首次启动App时弹出《隐私政策》并取得用户同意</b>
    ///
    /// [hasAgree] 隐私权政策是否已经取得用户同意
    AMapFlutterLocation.updatePrivacyAgree(true);

    /// 动态申请定位权限
    requestPermission();

    ///设置Android和iOS的apiKey<br>
    ///key的申请请参考高德开放平台官网说明<br>
    ///Android: https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key
    ///iOS: https://lbs.amap.com/api/ios-location-sdk/guide/create-project/get-key
    AMapFlutterLocation.setApiKey("438fb8be45d2ab71ec8d0886204713d7", "3b85cb52249e3e0ab484d2434b0317d5");

    ///注册定位结果监听
    _locationListener = _locationPlugin.onLocationChanged().listen((Map<String, Object> result) {
      setState(() {
        _locationResult = result;
        // 提取经纬度
        double? latitude = double.tryParse(result["latitude"].toString());
        double? longitude = double.tryParse(result["longitude"].toString());

        if (latitude != null && longitude != null) {
          LatLng reportedPosition = LatLng(latitude, longitude);

          LatLng position;
          if (_tracePoints.isNotEmpty) {
            // 若已有上一个点，则在上一个点周围取一个随机点作为下一个点
            position = _randomPointNearby(_tracePoints.last, _nearbyRadiusMeters);
          } else {
            // 第一次使用定位结果作为起点
            position = reportedPosition;
          }

          _tracePoints.add(position);

          _polylines = {
            Polyline(
              capType: CapType.square,
              joinType: JoinType.miter,
              geodesic: true,
              points: _tracePoints,
              color: Colors.red,
              width: 5,
            ),
          };
          // 清除旧的 Marker（可选）
          _markers.clear();

          // 添加新的 Marker
          _updateMarkerAt(position);

          // 移动相机到当前位置
          _mapController?.moveCamera(
            CameraUpdate.newLatLng(position),
          );
        }
      });
    });
  }

// 随机生成上一个点 _center 周围的点，距离在 [0, radiusMeters)
  LatLng _randomPointNearby(LatLng center, double radiusMeters) {
    const R = 6371000.0; // 地球半径（米）
    final rand = math.Random();

    // 随机距离（0..radius)
    final double distance = rand.nextDouble() * radiusMeters;

    // 随机方位角 0..2π
    final double bearing = rand.nextDouble() * 2 * math.pi;

    // 将经纬度从度转为弧度
    final double lat1 = center.latitude * math.pi / 180;
    final double lon1 = center.longitude * math.pi / 180;

    final double angularDistance = distance / R;

    // 公式：球面正弦/余弦推进（常用的“根据起点、方位角和距离计算终点”公式）
    final double lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) + math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );

    final double lon2 = lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    // 转回度
    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }

  void _updateMarkerAt(LatLng position) {
    _markers = {
      Marker(
        position: position,
        draggable: false,
        infoWindow: const InfoWindow(title: "当前位置"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
  }

  @override
  void dispose() {
    _mapController?.disponse();
    super.dispose();
    _simulationTimer?.cancel();

    ///移除定位监听
    if (null != _locationListener) {
      _locationListener?.cancel();
    }

    ///销毁定位
    _locationPlugin.destroy();
  }

  ///设置定位参数
  void _setLocationOption() {
    AMapLocationOption locationOption = AMapLocationOption();

    ///是否单次定位
    locationOption.onceLocation = false;

    ///是否需要返回逆地理信息
    locationOption.needAddress = true;

    ///逆地理信息的语言类型
    locationOption.geoLanguage = GeoLanguage.DEFAULT;

    locationOption.desiredLocationAccuracyAuthorizationMode = AMapLocationAccuracyAuthorizationMode.ReduceAccuracy;

    locationOption.fullAccuracyPurposeKey = "AMapLocationScene";

    ///设置Android端连续定位的定位间隔
    locationOption.locationInterval = 2000;

    ///设置Android端的定位模式<br>
    ///可选值：<br>
    ///<li>[AMapLocationMode.Battery_Saving]</li>
    ///<li>[AMapLocationMode.Device_Sensors]</li>
    ///<li>[AMapLocationMode.Hight_Accuracy]</li>
    locationOption.locationMode = AMapLocationMode.Hight_Accuracy;

    ///设置iOS端的定位最小更新距离<br>
    locationOption.distanceFilter = -1;

    ///设置iOS端期望的定位精度
    /// 可选值：<br>
    /// <li>[DesiredAccuracy.Best] 最高精度</li>
    /// <li>[DesiredAccuracy.BestForNavigation] 适用于导航场景的高精度 </li>
    /// <li>[DesiredAccuracy.NearestTenMeters] 10米 </li>
    /// <li>[DesiredAccuracy.Kilometer] 1000米</li>
    /// <li>[DesiredAccuracy.ThreeKilometers] 3000米</li>
    locationOption.desiredAccuracy = DesiredAccuracy.Best;

    ///设置iOS端是否允许系统暂停定位
    locationOption.pausesLocationUpdatesAutomatically = false;

    ///将定位参数设置给定位插件
    _locationPlugin.setLocationOption(locationOption);
  }

  ///开始定位
  void _startLocation() {
    ///开始定位之前设置定位参数
    _setLocationOption();
    _locationPlugin.startLocation();
  }

  ///停止定位
  void _stopLocation() {
    _locationPlugin.stopLocation();
  }

  Container _createButtonContainer() {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: _startLocation,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.blue),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
                child: const Text('开始定位'),
              ),
              const SizedBox(width: 20.0),
              ElevatedButton(
                onPressed: _stopLocation,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.blue),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
                child: const Text('停止定位'),
              ),
              const SizedBox(width: 20.0),
              ElevatedButton(
                onPressed: () {
                  _stopSimulation();
                  setState(() {
                    _tracePoints = [];
                    _polylines = {};
                    _markers = {};
                  });
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
                child: const Text('清除轨迹'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("随机偏移半径：${_nearbyRadiusMeters.toStringAsFixed(1)} 米"),
          Slider(
            value: _nearbyRadiusMeters,
            min: 1,
            max: 100,
            divisions: 99,
            label: "${_nearbyRadiusMeters.toStringAsFixed(1)} m",
            onChanged: (value) {
              setState(() {
                _nearbyRadiusMeters = value;
              });
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isSimulating ? _stopSimulation : _startSimulation,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.green),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
                child: Text(_isSimulating ? '停止模拟' : '开始模拟轨迹'),
              ),
              const SizedBox(width: 20.0),
              ElevatedButton(
                onPressed: _exportTraceToFile,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.orange),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
                child: const Text('导出轨迹'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exportTraceToFile() async {
    if (_tracePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("当前没有轨迹可以导出")),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln("latitude,longitude");

    for (LatLng point in _tracePoints) {
      buffer.writeln("${point.latitude},${point.longitude}");
    }

    try {
      final directory = await Directory.systemTemp.createTemp();
      final filePath = "${directory.path}/trace_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("轨迹已导出至文件：$filePath")),
      );

      print("轨迹导出成功：$filePath");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("导出失败: $e")),
      );
      print("导出失败: $e");
    }
  }

  Widget _resultWidget(key, value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          alignment: Alignment.centerRight,
          width: 100.0,
          child: Text('$key :'),
        ),
        Container(width: 5.0),
        Flexible(child: Text('$value', softWrap: true)),
      ],
    );
  }

  void _startSimulation() {
    _stopSimulation();
    if (_tracePoints.isEmpty) {
      // 初始化一个默认起点（如北京天安门）
      LatLng startPoint = const LatLng(39.909187, 116.397451);
      _tracePoints.add(startPoint);
      _updateMarkerAt(startPoint);
      _mapController?.moveCamera(CameraUpdate.newLatLng(startPoint));
    }

    _isSimulating = true;
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        LatLng lastPoint = _tracePoints.last;
        LatLng nextPoint = _randomPointNearby(lastPoint, _nearbyRadiusMeters);

        _tracePoints.add(nextPoint);

        _polylines = {
          Polyline(
            points: _tracePoints,
            color: Colors.red,
            width: 5,
          ),
        };

        _updateMarkerAt(nextPoint);
        _mapController?.moveCamera(CameraUpdate.newLatLng(nextPoint));
      });
    });
  }

  void _stopSimulation() {
    if (_isSimulating) {
      _simulationTimer?.cancel();
      _simulationTimer = null;
      _isSimulating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = <Widget>[];
    widgets.add(_createButtonContainer());

    if (_locationResult != null) {
      print("定位结果: $_locationResult");
      _locationResult?.forEach((key, value) {
        widgets.add(_resultWidget(key, value));
      });
    }

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('高德地图+定位'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _mapInitializationFailed
                  ? _buildErrorWidget()
                  : AMapWidget(
                      // trafficEnabled: true,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      markers: _markers,
                      polylines: _polylines,
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                      },
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(39.909187, 116.397451), // 北京天安门坐标
                        zoom: 14,
                      ),
                    ),
            ),
            ...widgets,
          ],
        ),
      ),
    );
  }

  /// 动态申请定位权限
  void requestPermission() async {
    // 申请权限
    bool hasLocationPermission = await requestLocationPermission();
    if (hasLocationPermission) {
      print("定位权限申请通过");
    } else {
      print("定位权限申请不通过");
    }
  }

  /// 申请定位权限
  /// 授予定位权限返回true， 否则返回false
  Future<bool> requestLocationPermission() async {
    //获取当前的权限
    var status = await Permission.location.status;
    if (status == PermissionStatus.granted) {
      //已经授权
      return true;
    } else {
      //未授权则发起一次申请
      status = await Permission.location.request();
      if (status == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("地图初始化失败", style: TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _mapInitializationFailed = false;
                _mapController = null;
              });
            },
            child: const Text('重新加载地图'),
          ),
        ],
      ),
    );
  }
}

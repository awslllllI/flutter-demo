# Flutter集成高德地图的基本功能

一个使用 Flutter 和高德地图插件实现的实时定位并在地图上插入图钉的示例项目。

## 功能

- 获取当前位置
- 在地图上添加 Marker
- 自动移动相机到当前位置

## 目的

- 解决高德地图开放平台上flutter版本的文档几乎等于没有，插件的example、博客和AI的说法杂糅了各种版本的flutter和插件使用案例，一不小心就会原地打转转的问题。
- 记录2025/8/1时在空项目flutter集成高德地图的注意事项和步骤简化。


## 依赖插件（pubspec.yaml）

- [amap_flutter_map](https://pub.dev/packages/amap_flutter_map)2025/8/1 amap_flutter_map: ^3.0.0
- [amap_flutter_base](https://pub.dev/packages/amap_flutter_base)2025/8/1 amap_flutter_base: ^3.0.0 
- [amap_flutter_location](https://pub.dev/packages/amap_flutter_location)2025/8/1 amap_flutter_location: ^3.0.0
- [permission_handler](https://pub.dev/packages/permission_handler)2025/8/1 permission_handler: ^11.0.0

## 步骤

1. 创建新flutter项目。
2. 在`android/app/build.gradle`拿到包名`namespace`
3. 获取SHA1码，终端输入` keytool -list -v -keystore C:/Users/<你的用户>/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
4. 用包名和SHA1码在[高德开放平台](https://lbs.amap.com/?ref=https://console.amap.com/dev/index)获取key
5. [amap_flutter_location example](https://pub.dev/packages/amap_flutter_location/example)用这个代码替换main。（[amap_flutter_map](https://pub.dev/packages/amap_flutter_map)这个插件的example不可用）
6. 在` AMapFlutterLocation.setApiKey("android", "ios");`填入key
7. 在`android/app/src/main/AndroidManifest.xml`设置权限
8. 在`android/app/build.gradle`设置`compileSdkVersion 34`、`minSdkVersion 21`、`targetSdkVersion 34 `、
  ```
  dependencies {
    implementation 'com.amap.api:3dmap:8.1.0'  // 较旧但稳定的版本组合,不然3dmap和location会冲突
    implementation 'com.amap.api:location:5.6.0' //貌似是因为新版3dmap里附带了location
    implementation 'com.amap.api:search:9.5.0'

  }
  ```
9. 试运行。成功后通过AI添加`AMapWidget`展示地图和Marker相关代码

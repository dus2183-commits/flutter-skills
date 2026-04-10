// Flutter Skills 项目入口
//
// 启动命令:
//   flutter run --dart-define=USE_MOCK=true   (mock 模式)
//   flutter run                                (真实接口模式)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'core/config/app_config.dart';
import 'core/mock/mock_loader.dart';
import 'core/network/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 加载 .env (开发环境)
  await dotenv.load(fileName: '.env.dev');

  // 2. 初始化全局 GetxService
  await Get.putAsync<AppConfig>(() async => DotenvAppConfig().init());
  Get.put<MockLoader>(MockLoader());
  await Get.putAsync<ApiClient>(() async => ApiClient().init());

  runApp(const SwiftApp());
}

class SwiftApp extends StatelessWidget {
  const SwiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '{{PROJECT_NAME_PASCAL}}',
      debugShowCheckedModeBanner: false,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.cupertino,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
    );
  }
}

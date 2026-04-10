// MockInterceptor - Mock 数据拦截器
// 这是 yc141 没有的增量,我们的核心价值之一
//
// 工作机制:
// 1. 编译期开关: --dart-define=USE_MOCK=true
// 2. 启用时拦截所有请求,不发真实 HTTP
// 3. 从 assets/mock/{key}.json 加载数据
// 4. 模拟延迟 (让 loading UI 可见)
// 5. 直接构造 Response 返回

import 'package:dio/dio.dart';

import '../../mock/mock_loader.dart';

class MockInterceptor extends Interceptor {
  MockInterceptor(this.loader);

  final MockLoader loader;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!MockLoader.enabled) {
      handler.next(options);
      return;
    }

    final mockKey = options.extra['mockKey'] as String?;
    if (mockKey == null || mockKey.isEmpty) {
      // 没指定 mockKey,放行走真实接口
      handler.next(options);
      return;
    }

    try {
      // 模拟延迟
      await loader.simulateDelay();

      // 加载 mock 数据
      final mockData = await loader.load(mockKey);

      // 关键: 因为后续的 EncryptInterceptor 期望解密二进制,我们这里要伪装成已解密的状态
      // 解决: 在 extra 标记 _mocked,Encrypt 拦截器看到这个标记跳过解密
      options.extra['_mocked'] = true;
      options.extra['encrypt'] = false; // 跳过加解密

      // 直接构造 Response 终止请求链
      handler.resolve(Response(
        requestOptions: options,
        data: mockData,
        statusCode: 200,
      ));
    } catch (e) {
      // mock 失败,放行走真实接口(降级)
      handler.next(options);
    }
  }
}

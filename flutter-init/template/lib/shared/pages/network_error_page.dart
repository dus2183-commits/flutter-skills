import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/network/services/line_service.dart';

/// 网络不可达占位页
///
/// 所有线路测速失败时显示此页面。
/// 用户可点击"重试"重新测速。
///
/// 后续可自定义:
/// - 替换图片/动画
/// - 加客服联系方式
/// - 加手动选择线路入口
class NetworkErrorPage extends StatelessWidget {
  const NetworkErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 占位图标 (后续替换为自定义插图)
              Icon(
                Icons.wifi_off_rounded,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),

              Text(
                '网络连接失败',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),

              Text(
                '无法连接到服务器，请检查网络后重试',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 重试按钮
              Obx(() {
                final lineService = Get.find<LineService>();
                return FilledButton.icon(
                  onPressed: lineService.testing.value
                      ? null
                      : () async {
                          await lineService.retry();
                          // 测速成功后自动跳回首页
                          if (lineService.latency.value > 0) {
                            Get.offAllNamed('/');
                          }
                        },
                  icon: lineService.testing.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(lineService.testing.value ? '测速中...' : '重试'),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

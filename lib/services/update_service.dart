import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/tactile_button.dart';
import 'supabase_service.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  static UpdateService get instance => _instance;
  UpdateService._internal();

  String repoOwner = "maheshkumavat";
  String repoName = "fluentup";
  bool _isChecking = false;

  /// Checks GitHub releases API for a newer tag version
  Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateToast = false}) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;

      debugPrint("[UpdateService] Installed App Version: '$currentVersion+$currentBuild'");

      Map<String, dynamic> releaseData;
      if (SupabaseService.instance.isInitialized) {
        debugPrint("[UpdateService] Calling Supabase Edge Function: version-proxy");
        releaseData = await SupabaseService.instance.invokeVersionProxy();
      } else {
        final url = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest";
        debugPrint("[UpdateService] Calling GitHub API direct: $url");
        final dio = Dio();
        final response = await dio.get(
          url,
          options: Options(
            headers: {"Accept": "application/vnd.github.v3+json"},
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        releaseData = response.data as Map<String, dynamic>;
      }

      final tagName = releaseData['tag_name'] as String? ?? 'v1.0.0';
      final body = releaseData['body'] as String? ?? 'Bug fixes and performance improvements.';
      final assets = releaseData['assets'] as List? ?? [];

      String? downloadUrl;
      for (var asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      final isNewer = _isNewerVersion(tagName, currentVersion, currentBuild);
      debugPrint("[UpdateService] Comparison -> Installed: '$currentVersion+$currentBuild' | GitHub Tag: '$tagName' | isNewer: $isNewer | downloadUrl: '$downloadUrl'");

      if (isNewer && downloadUrl != null) {
        debugPrint("[UpdateService] New update detected! Showing bottom sheet update prompt.");
        final activeContext = context.mounted ? context : navigatorKey.currentContext;
        if (activeContext != null && activeContext.mounted) {
          _showUpdateBottomSheet(activeContext, tagName, body, downloadUrl);
        }
      } else if (showNoUpdateToast) {
        final activeContext = context.mounted ? context : navigatorKey.currentContext;
        if (activeContext != null && activeContext.mounted) {
          debugPrint("[UpdateService] No update required or already on latest version.");
          ScaffoldMessenger.of(activeContext).showSnackBar(
            const SnackBar(
              content: Text("You are on the latest version of FluentUp."),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("[UpdateService] Error checking for update: $e");
      if (showNoUpdateToast) {
        final activeContext = context.mounted ? context : navigatorKey.currentContext;
        if (activeContext != null && activeContext.mounted) {
          ScaffoldMessenger.of(activeContext).showSnackBar(
            SnackBar(
              content: Text("Unable to check for updates: $e"),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  bool _isNewerVersion(String tagName, String currentVersion, String currentBuild) {
    try {
      final cleanTag = tagName.replaceAll(RegExp(r'^v'), '').trim();
      final parts = cleanTag.split('+');
      final tagVersionStr = parts[0];
      final tagBuild = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final curBuild = int.tryParse(currentBuild) ?? 0;

      // 1. If build numbers exist and are valid, compare build numbers
      if (tagBuild > 0 && curBuild > 0) {
        return tagBuild > curBuild;
      }

      // 2. Semantic version comparison (major.minor.patch)
      final tagV = tagVersionStr.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final curV = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final t = i < tagV.length ? tagV[i] : 0;
        final c = i < curV.length ? curV[i] : 0;
        if (t > c) return true;
        if (t < c) return false;
      }
      return tagBuild > curBuild;
    } catch (_) {
      return false;
    }
  }

  void _showUpdateBottomSheet(BuildContext context, String tagName, String changelog, String downloadUrl) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "UPDATE AVAILABLE",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          "FluentUp $tagName",
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "What's New:",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    changelog,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("Later", style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TactileButton(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _startApkDownloadAndInstall(context, downloadUrl);
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Update Now",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _startApkDownloadAndInstall(BuildContext context, String downloadUrl) async {
    double progress = 0.0;
    StateSetter? dialogSetter;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetter = setState;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Downloading Update", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: AppTheme.surfaceContainer,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${(progress * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/FluentUp-update.apk";
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && dialogSetter != null) {
            dialogSetter!(() {
              progress = received / total;
            });
          }
        },
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final result = await OpenFilex.open(filePath);
      debugPrint("Package install result: ${result.message}");
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to download update: $e")),
        );
      }
    }
  }
}

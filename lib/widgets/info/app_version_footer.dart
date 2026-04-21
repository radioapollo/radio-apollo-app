/* App Version Footer

   Shown at the bottom of the info screen.
   Displays the developer credit and the current app version.

   The version is now read automatically from the app bundle via
   package_info_plus — no need to keep it manually in sync with
   pubspec.yaml anymore.
*/

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../theme/app_theme.dart';

class AppVersionFooter extends StatefulWidget {
  const AppVersionFooter({super.key});

  @override
  State<AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<AppVersionFooter> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    // PackageInfo.fromPlatform() reads values set by the build system
    // (ultimately from pubspec.yaml), so bumping the version in one
    // place is enough — no separate sync with a Dart constant needed.
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Center(
          child: Text(
            'App ontwikkeld door Raf Vermeylen',
            style: TextStyle(
              color: AppColors.creditText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSmall),
        Center(
          // While the version loads (briefly), show a placeholder with
          // the same height so the layout doesn't jump.
          child: Text(
            _version != null ? 'Versie $_version' : ' ',
            style: const TextStyle(color: AppColors.creditText, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

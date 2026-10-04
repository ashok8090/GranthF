import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "app_model.dart";
import "shell.dart";
import "ui.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  final app = AppModel();
  runApp(AppScope(notifier: app, child: const GranthRoot()));
  await app.boot();
}

class GranthRoot extends StatelessWidget {
  const GranthRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ग्रंथ प्रबंधन",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(seedColor: maroon, primary: maroon, surface: paper),
        fontFamily: "NotoSansDevanagari",
        splashFactory: InkSparkle.splashFactory,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const GranthApp(),
    );
  }
}

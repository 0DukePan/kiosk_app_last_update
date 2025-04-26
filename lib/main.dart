import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

import 'Pages/home_page.dart';
import 'Routes/routes.dart';
import 'Theme/style.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.landscapeRight,
  //   DeviceOrientation.landscapeLeft,
  // ]);
  runApp(Phoenix(child: HungerzKiosk()));
}

class HungerzKiosk extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
          return MaterialApp(
            theme: appTheme,
      home: HomePage(),
            routes: PageRoutes().routes(),
    );
  }
}

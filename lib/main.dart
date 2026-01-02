

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ticket/services/localnotification.dart';
import 'package:ticket/views/login.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TicketNotificationService.instance.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MaterialApp(home:LoginPage(),));
}

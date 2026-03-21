import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

void main() async {
  final _ = GoogleSignIn.instance;
  debugPrint('GoogleSignIn instance ready');
}

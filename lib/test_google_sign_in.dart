import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId:
        '406957271307-3d97h1iouperfm2p9g0hrf4pp4bt6n3h.apps.googleusercontent.com',
    serverClientId:
        '406957271307-3d97h1iouperfm2p9g0hrf4pp4bt6n3h.apps.googleusercontent.com',
    scopes: ['https://www.googleapis.com/auth/bigquery'],
  );

  print('Instantiated GoogleSignIn');
}

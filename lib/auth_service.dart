
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  static bool googleInitialized = false;

  //create account and send email verification link
  Future<void> register(String email, String password) async {
    final userCredential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await userCredential.user!.sendEmailVerification();
    await auth.signOut();
  }

  //allow login only when the email is verified.
  Future<void> login(String email, String password) async {
    final userCredential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await userCredential.user!.reload();

    if (!(auth.currentUser?.emailVerified ?? false)) {
      await auth.signOut();

      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email before logging in.',
      );
    }
  }

  //use appropriate Google login method for each platform
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      //for Chrome, mag-open og Google login popup.
      await auth.signInWithPopup(
        GoogleAuthProvider(),
      );
    } else {
      //for android, initialize first.
      if (!googleInitialized) {
        await GoogleSignIn.instance.initialize();
        googleInitialized = true;
      }

      //open the Google account picker on the Android phone.
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      //connect the selected Google account to Firebase.
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await auth.signInWithCredential(credential);
    }
  }

  //logout from Firebase and Google.
  Future<void> signOut() async {
    await auth.signOut();

    //for android only GoogleSignIn signOut.
    if (!kIsWeb && googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }
}

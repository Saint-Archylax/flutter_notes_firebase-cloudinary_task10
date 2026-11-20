import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CrudService {
  final CollectionReference<Map<String, dynamic>> items =
      FirebaseFirestore.instance.collection('items');

  String get ownerId => FirebaseAuth.instance.currentUser!.uid;

  //Save a new item under the currently logged-in user.
  Future<void> addItem(String name, int quantity, {String imageUrl = ''}) async {
    await items.add({
      'name': name,
      'quantity': quantity,
      'image_url': imageUrl,
      'ownerId': ownerId,
      'createdAt': Timestamp.now(),
      'isFavorite': false,
    });
  }

  //Read only this user's items. Automatic updates from Firebase.
  Stream<QuerySnapshot<Map<String, dynamic>>> getItems() {
    return items.where('ownerId', isEqualTo: ownerId).snapshots();
  }

  //Edit the name and quantity without changing the favorite status.
  Future<void> updateItem(String id, String name, int quantity) async {
    await items.doc(id).update({'name': name, 'quantity': quantity});
  }

  //Save the heart status in Firestore para hindi mawala after restart.
  Future<void> setFavorite(String id, bool isFavorite) async {
    await items.doc(id).update({'isFavorite': isFavorite});
  }

  //Delete the selected item.
  Future<void> deleteItem(String id) async {
    await items.doc(id).delete();
  }
}

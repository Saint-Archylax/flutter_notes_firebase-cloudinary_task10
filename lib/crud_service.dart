import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class PickedImage {
  final File file;
  final String url;

  PickedImage({required this.file, required this.url});
}

class CrudService {
  final CollectionReference<Map<String, dynamic>> items =
      FirebaseFirestore.instance.collection('items');

  String get ownerId => FirebaseAuth.instance.currentUser!.uid;

  //my cloudinary name
  static const String cloudName = 'axoafxtn';
  static const String uploadPreset = 'flutter_notes_preset';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    cloudName,
    uploadPreset,
    cache: false,
  );
  final ImagePicker _picker = ImagePicker();

  //Pumili ng picture sa gallery at i-upload ito sa Cloudinary.
  Future<PickedImage?> pickImageForAddItem() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (pickedFile == null) return null;

    final file = File(pickedFile.path);
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    return PickedImage(file: file, url: response.secureUrl);
  }

  //I-save ang item data at ang URL ng image sa Firestore.
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

  //Basahin lamang ang items ng kasalukuyang naka-login na user.
  Stream<QuerySnapshot<Map<String, dynamic>>> getItems() {
    return items.where('ownerId', isEqualTo: ownerId).snapshots();
  }

  //I-update ang item; palitan lang ang picture kapag may bagong URL.
  Future<void> updateItem(
    String id,
    String name,
    int quantity, {
    String? imageUrl,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'quantity': quantity,
    };
    if (imageUrl != null) updates['image_url'] = imageUrl;
    await items.doc(id).update(updates);
  }

  //I-save ang Favorites para hindi ito mawala after restarting.
  Future<void> setFavorite(String id, bool isFavorite) async {
    await items.doc(id).update({'isFavorite': isFavorite});
  }

  //Tanggalin ang item record sa Firestore (hindi ang Cloudinary image).
  Future<void> deleteItem(String id) async {
    await items.doc(id).delete();
  }
}

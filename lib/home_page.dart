import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'crud_service.dart';
import 'auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CrudService service = CrudService();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  bool showFavoritesOnly = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Something went wrong: $error')),
    );
  }

  //Gamit ang parehong dialog para sa Add at Edit Item.
  void openItemDialog({QueryDocumentSnapshot<Map<String, dynamic>>? item}) {
    final bool isEditing = item != null;
    final data = item?.data();
    nameCtrl.text = data?['name']?.toString() ?? '';
    qtyCtrl.text = data?['quantity']?.toString() ?? '';

    File? selectedImageFile;
    String? selectedImageUrl = data?['image_url']?.toString();
    bool uploading = false;
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Item' : 'Add Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedImageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      selectedImageFile!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (selectedImageUrl != null && selectedImageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      selectedImageUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: uploading || saving
                      ? null
                      : () async {
                          setDialogState(() => uploading = true);
                          try {
                            //I-upload agad ang napiling picture, tulad sa video.
                            final pickedImage =
                                await service.pickImageForAddItem();
                            if (pickedImage != null && dialogContext.mounted) {
                              setDialogState(() {
                                selectedImageFile = pickedImage.file;
                                selectedImageUrl = pickedImage.url;
                              });
                            }
                          } catch (error) {
                            showError(error);
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => uploading = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.upload_file),
                  label: Text(uploading ? 'Uploading...' : 'Upload Image'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading || saving
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: uploading || saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final quantity = int.tryParse(qtyCtrl.text.trim());
                      if (name.isEmpty || quantity == null || quantity <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a name and a quantity greater than zero.',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        if (isEditing) {
                          await service.updateItem(
                            item.id,
                            name,
                            quantity,
                            imageUrl: selectedImageUrl,
                          );
                        } else {
                          await service.addItem(
                            name,
                            quantity,
                            imageUrl: selectedImageUrl ?? '',
                          );
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        showError(error);
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving...' : (isEditing ? 'Edit' : 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  //Magtanong muna bago mag-delete ng item.
  void confirmDelete(String id) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await service.deleteItem(id);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                showError(error);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  //I-update ang heart status at i-save sa Firebase.
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    try {
      await service.setFavorite(id, !isFavorite);
    } catch (error) {
      showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade400,
      appBar: AppBar(
        title: const Text('Firebase Ymbol'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          //show Favorites lang pag naka select ang top heart.
          IconButton(
            tooltip: showFavoritesOnly ? 'Show all items' : 'Show favorites',
            icon: Icon(
              showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
            ),
            onPressed: () {
              setState(() => showFavoritesOnly = !showFavoritesOnly);
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await AuthService().signOut();
              } catch (error) {
                showError(error);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => openItemDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.getItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error reading items: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          //no isFavorite field
          final docs = snapshot.data!.docs.where((doc) {
            return !showFavoritesOnly || doc.data()['isFavorite'] == true;
          }).toList();

          docs.sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });

          if (docs.isEmpty) {
            return Center(
              child: Text(
                showFavoritesOnly
                    ? 'No favorite items yet.'
                    : 'No items found. Tap + to add one.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final item = docs[index];
              final data = item.data();
              final bool isFavorite = data['isFavorite'] == true;
              final String imageUrl = data['image_url']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                color: const Color(0xFFF6F2F8),
                child: ListTile(
                  //show pics if url
                  leading: imageUrl.isEmpty
                      ? null
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 45),
                          ),
                        ),
                  title: Text(data['name']?.toString() ?? 'Unnamed'),
                  subtitle: Text('Quantity: ${data['quantity'] ?? 0}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => toggleFavorite(item.id, isFavorite),
                      ),
                      IconButton(
                        tooltip: 'Edit item',
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => openItemDialog(item: item),
                      ),
                      IconButton(
                        tooltip: 'Delete item',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => confirmDelete(item.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

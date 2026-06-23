import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Handles Firebase Storage uploads for contractor verification documents.
///
/// Storage path convention:
///   contractor_docs/{contractorId}/{docKey}.jpg
///
/// Required Firebase Storage rule (add to storage.rules in Firebase Console):
///   match /contractor_docs/{contractorId}/{document=**} {
///     allow read, write: if request.auth != null;
///   }
class StorageService {
  StorageService._();
  static final instance = StorageService._();

  final _storage = FirebaseStorage.instance;

  /// Uploads a verification document image and returns the HTTPS download URL.
  ///
  /// [contractorId] — Firestore document ID of the contractor.
  /// [docKey]       — Short identifier used as the filename, e.g. 'driving_licence'.
  /// [file]         — XFile selected via image_picker.
  Future<String> uploadVerificationDoc({
    required String contractorId,
    required String docKey,
    required XFile file,
  }) async {
    final ref = _storage
        .ref()
        .child('contractor_docs')
        .child(contractorId)
        .child('$docKey.jpg');

    final bytes = await file.readAsBytes();
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  /// Uploads a profile selfie and returns the HTTPS download URL.
  ///
  /// Stored at `profile_pictures/{contractorId}.jpg` — filename matches
  /// the UID so Firebase Storage security rules can scope access.
  Future<String> uploadProfilePhoto({
    required String contractorId,
    required XFile file,
  }) async {
    final ref = _storage
        .ref()
        .child('profile_pictures')
        .child('$contractorId.jpg');

    final bytes = await file.readAsBytes();
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }
}

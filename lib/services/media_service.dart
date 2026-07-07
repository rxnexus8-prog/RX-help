import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MediaService {
  static final _supabase = Supabase.instance.client;
  static const _bucket = 'chat-media';
  static const _uuid = Uuid();

  static Future<Map<String, dynamic>?> pickAndUploadImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile == null) return null;
    return _upload(File(xfile.path), 'image');
  }

  static Future<Map<String, dynamic>?> pickAndUploadVideo() async {
    final picker = ImagePicker();
    final xfile = await picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return null;
    return _upload(File(xfile.path), 'video');
  }

  static Future<Map<String, dynamic>?> pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return null;
    final pf = result.files.first;
    if (pf.path == null) return null;
    final mime = lookupMimeType(pf.path!) ?? 'application/octet-stream';
    String type = 'file';
    if (mime.startsWith('audio')) type = 'audio';
    else if (mime.startsWith('image')) type = 'image';
    else if (mime.startsWith('video')) type = 'video';
    return _upload(File(pf.path!), type, name: pf.name);
  }

  static Future<Map<String, dynamic>?> _upload(File file, String type, {String? name}) async {
    try {
      final ext = p.extension(file.path);
      final fileName = '${_uuid.v4()}$ext';
      final path = '$type/$fileName';
      await _supabase.storage.from(_bucket).upload(path, file,
        fileOptions: const FileOptions(upsert: false));
      final url = _supabase.storage.from(_bucket).getPublicUrl(path);
      return {
        'url': url,
        'type': type,
        'name': name ?? fileName,
        'size': await file.length(),
      };
    } catch (e) {
      return null;
    }
  }
}

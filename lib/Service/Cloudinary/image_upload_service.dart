import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

Future<String?> imageUploadService(File imageFile) async {
  const cloudName = 'dakeunntm';
  const uploadPreset = 'flutter_unsigned_upload';

  final url = Uri.parse(
    "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
  );

  final request = http.MultipartRequest('POST', url)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

  final response = await request.send();

  if (response.statusCode == 200) {
    final resStr = await response.stream.bytesToString();
    final data = json.decode(resStr);
    return data['secure_url']; // URL segura de la imagen
  } else {
    debugPrint('Error al subir imagen: ${response.statusCode}');
    return null;
  }
}

String getOptimizedCloudinaryUrl(
  String originalUrl, {
  int? width,
  int? height,
}) {
  final uploadIndex = originalUrl.indexOf('/upload/');
  if (uploadIndex == -1) return originalUrl;

  final prefix = originalUrl.substring(0, uploadIndex + 8);
  final suffix = originalUrl.substring(uploadIndex + 8);

  final transformations = [
    if (width != null) 'w_$width',
    if (height != null) 'h_$height',
    'c_fill',
    'f_auto',
    'c_limit',
    'q_auto',
  ].join(',');

  return '$prefix$transformations/$suffix';
}

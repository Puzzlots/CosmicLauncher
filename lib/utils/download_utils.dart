import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../main.dart';

Future<void> downloadFile(String url, String savePath) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes);
    if (kDebugMode || verbose) {
      print('File downloaded to $savePath');
    }
  } else {
    if (kDebugMode || verbose) {
      print('Failed to download file: ${response.statusCode}');
    }
  }
}

Future<void> downloadFiles(Map<String, List<String>> files) async {
  for (final entry in files.entries) {
    final savePath = entry.key;
    final urls = entry.value;

    for (final url in urls) {
      await downloadFile(url, savePath);
    }
  }
}

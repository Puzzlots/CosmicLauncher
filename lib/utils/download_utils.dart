import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> downloadFile(String url, String savePath) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes);
    print('File downloaded to $savePath');
  } else {
    print('Failed to download file: ${response.statusCode}');
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

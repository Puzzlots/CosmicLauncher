import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'logger.dart';

Logger downloadLogger = Logger.logger("Downloader");

Future<void> downloadFile(String url, String savePath) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes);
    downloadLogger.log('File downloaded to $savePath');
  } else {
    downloadLogger.log('Failed to download file: ${response.statusCode}');
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

import 'package:flutter/foundation.dart';

class CrmmProject {
  final String id;
  final String slug;
  final String name;
  final String summary;

  /// mod / shader / resourcepack / datapack
  final String projectType;

  final Uri? iconUrl;
  final Uri? featuredGalleryUrl;

  final int downloads;
  final int followers;

  final DateTime dateUpdated;
  final DateTime datePublished;

  final List<String> categories;
  final List<String> featuredCategories;
  final List<String> gameVersions;
  final List<Loader> loaders;

  final String author;

  const CrmmProject({
    required this.id,
    required this.slug,
    required this.name,
    required this.summary,
    required this.projectType,
    required this.iconUrl,
    required this.featuredGalleryUrl,
    required this.downloads,
    required this.followers,
    required this.dateUpdated,
    required this.datePublished,
    required this.categories,
    required this.featuredCategories,
    required this.gameVersions,
    required this.loaders,
    required this.author,
  });

  factory CrmmProject.fromJson(Map<String, dynamic> json) {
    CrmmProject project = CrmmProject(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      projectType: (json['type'] as List<dynamic>?)?.isNotEmpty == true
          ? (json['type'] as List<dynamic>)[0] as String
          : 'unknown',
      iconUrl: json['icon'] != null ? Uri.parse(json['icon'] as String) : null,
      featuredGalleryUrl: json['featured_gallery'] != null
          ? Uri.parse(json['featured_gallery'] as String)
          : null,
      downloads: json['downloads'] as int? ?? 0,
      followers: json['followers'] as int? ?? 0,
      dateUpdated: json['date_updated'] != null
          ? DateTime.parse(json['date_updated'] as String)
          : DateTime.now(),
      datePublished: json['date_published'] != null
          ? DateTime.parse(json['date_published'] as String)
          : DateTime.now(),
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
          [],
      featuredCategories: (json['featured_categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
          [],
      gameVersions: (json['game_versions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
          [],
      loaders: (json['loaders'] as List<dynamic>? ?? [])
          .map<Loader>((e) => _loaderFromString(e as String))
          .toList(),
    );
    if (kDebugMode) {
      print("Found ${project.name} by ${project.author}");
    }
    return project;
  }
}

enum Loader {
  fabric,
  quilt,
  puzzle,
}

Loader _loaderFromString(String value) {
  switch (value.toLowerCase()) {
    case 'fabric':
      return Loader.fabric;
    case 'quilt':
      return Loader.quilt;
    case 'puzzle_loader':
      return Loader.puzzle;
    default:
      throw ArgumentError('Unknown loader: $value');
  }
}

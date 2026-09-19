import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:polaris/utils/general_utils.dart';
import 'package:polaris/utils/version_cache.dart';

import '../main.dart';
import '../utils/cache_utils.dart';
import '../utils/crmm/crmm_project.dart';
import '../utils/crmm/crmm_service.dart';
import '../utils/instance_utils.dart';
import '../utils/widgets/stateless_widgets.dart';

class AddContentTab extends StatefulWidget {
  final Map<String, dynamic> instance;
  final VoidCallback onBack;

  const AddContentTab({
    super.key,
    required this.instance,
    required this.onBack,
  });

  @override
  State<AddContentTab> createState() => _AddContentTabState();
}

class _AddContentTabState extends State<AddContentTab> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String query = '';
  String selectedProjectType = 'mod';
  String sortBy = 'relevance';
  final List<String> projectTypes = ['Mod','Shader','Resource Pack','Datamod'];

  bool locked = true;
  ReleaseChannel releaseChannel = ReleaseChannel.alpha;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.extension,
              size: 48,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.instance['name'] as String,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${widget.instance['loader']} ${widget.instance['version']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            const Spacer(),

            TextButton.icon(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              label: const Text(
                'Back to instances',
                style: TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                  backgroundColor: backgroundColour,
                  overlayColor: Colors.white.withAlpha(50)
              ),
              onPressed: widget.onBack,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: Color(0xFF1E1E1E)),
        const SizedBox(height: 12),
        Text(
          "Install Content to ${widget.instance['name']}",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: projectTypes.length,
            itemBuilder: (context, index) {
              final type = projectTypes[index];
              final normalized = type.toLowerCase().replaceAll(' ', '-');
              final isSelected = selectedProjectType == normalized;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedProjectType = normalized;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.withValues(alpha: 0.2) : Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.withValues(alpha: 0),
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? Colors.green : Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              query = value;
            });
          },
          decoration: InputDecoration(
            hintText: "Search ${selectedProjectType.replaceAll('-', ' ').replaceAll(' ', '')}s…",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: DefaultSelectionStyle.defaultColor)
            ),
            fillColor: backgroundColour,
            filled: true,
          ),
        ),

        const SizedBox(height: 5),


        Row(children: [
          SizedBox(
            width: 250, // limits width
            child: DropdownButtonFormField<String>(
              initialValue: sortBy,
              items: CrmmService.sortBy
                  .map((v) => DropdownMenuItem(
                value: v,
                child: Text("Sort: ${v.replaceAll('_', ' ').capitalize()}",
                ),
              ),)
                  .toList(),
              onChanged: (value) {
                setState(() {
                  sortBy = value ?? sortBy;
                });
              },
              borderRadius: BorderRadius.circular(12),
              dropdownColor: backgroundColour,
              decoration: InputDecoration(
                labelText: 'Sort by',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                filled: true,
                fillColor: backgroundColour,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 250, // limits width
            child: DropdownButtonFormField<String>(
              initialValue: releaseChannel.name.capitalize(),
              items:
              ReleaseChannel.values
                  .map((v) => DropdownMenuItem(
                value: v.name.capitalize(),
                child: Text("Channel: ${v.name.capitalize()}",),
              ),
              ).toList(),

              onChanged: (value) {
                setState(() {
                  releaseChannel = releaseChannelFromString(value??'');
                });
              },
              borderRadius: BorderRadius.circular(12),
              dropdownColor: backgroundColour,
              decoration: InputDecoration(
                labelText: 'Release channel',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                filled: true,
                fillColor: backgroundColour,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          IconCheckbox(
            value: locked,
            label: resolveLatest("Vanilla", "Client", widget.instance['version'] as String),
            backgroundColour: backgroundColour,
            onChanged: (v) => setState(() => locked = v),
          )]
        ),

        const SizedBox(height: 12),

        // Results
        Expanded(
          child: _CrmmSearchResults(
            instance: widget.instance,
            query: query,
            selectedProjectType: selectedProjectType,
            sortBy: sortBy,
            versionLocked: locked,
            releaseChannel: releaseChannel,
          ),
        ),
      ],
    );
  }
}

class _CrmmSearchResults extends StatefulWidget {
  final Map<String, dynamic> instance;
  final String query;
  final String selectedProjectType;
  final String sortBy;
  final bool versionLocked;
  final ReleaseChannel releaseChannel;

  const _CrmmSearchResults({
    required this.instance,
    required this.query,
    required this.selectedProjectType,
    required this.sortBy,
    required this.versionLocked,
    required this.releaseChannel
  });

  @override
  State<_CrmmSearchResults> createState() => _CrmmSearchResultsState();
}

class _CrmmSearchResultsState extends State<_CrmmSearchResults> {
  bool loading = false;
  List<CrmmProject> results = [];
  Map<CrmmProject, bool> downloadingList = {};

  @override
  void initState() {
    super.initState();
    search('', 'mod', 'relevance', true, ReleaseChannel.beta);
  }

  @override
  void didUpdateWidget(covariant _CrmmSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.selectedProjectType != widget.selectedProjectType || oldWidget.sortBy != widget.sortBy || oldWidget.versionLocked != widget.versionLocked || oldWidget.releaseChannel != widget.releaseChannel) {
      search(widget.query, widget.selectedProjectType, widget.sortBy, widget.versionLocked, widget.releaseChannel);
    }
  }


  Future<void> search(String query, String projectType, String sortBy, bool versionLocked, ReleaseChannel releaseChannel) async {
    setState(() => loading = true);

    try {
      final res = await CrmmService.searchProjects(query, projectType, (resolveLatest("Vanilla", "Client", widget.instance['version'] as String).split('-').first), sortBy, versionLocked, releaseChannel);
      setState(() {
        results = res;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    var quotes =
    ["Nothing but dust...", "Well this is awkward...", "Nothing here captain...", "Keep searching...", "We searched far and wide...", "You did want to find projects right?", "Uhh, try again...",
      "**whistling**", "What were you even trying to find...", "Hello there fellow searcher", "It's just an empty void...", "Next time try searching for something that actually exists...", "No luck here...",
      "Maybe in the back aisle?", "You're going to need a wizard to find that...", "**sighs** nope...", "Not on CRMM today...", "Try again tomorrow...", "**crickets**", "Is that a tumbleweed?"];

    if (results.isEmpty) {
      return Center(
        child: Text(quotes[Random().nextInt(quotes.length)]),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      itemBuilder: (context, index) {
        final project = results[index];
        downloadingList.putIfAbsent(project, () => false);

        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CardBorderSpinner(
            active: downloadingList[project] ?? false,
            child: Card(
              margin: EdgeInsets.zero,
              color: backgroundColour,
              child: ListTile(
                title: Text(project.name),
                subtitle: Text(
                  project.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: widget.instance["mods"]?[project.slug] != null ? (widget.instance["mods"]?[project.slug]["version"] == project.latestVersionSlug || project.latestVersionSlug == '' /* <- Prevents projects which have no versions for the selected search showing as update available (P.S. not sure how this is possible)*/) ? Icon(Icons.check_circle, color: Colors.green) : Icon(Icons.update): Icon(Icons.download, color: downloadingList[project] ?? false ? Colors.blue : Colors.white),
                  onPressed: () async {
                    if (downloadingList[project] == true || widget.instance["mods"]?[project.slug] != null) return;
                    setState(() {downloadingList[project] = true;});
                    final downloaded = await CrmmService.downloadLatestProject(project.slug, widget.selectedProjectType, widget.versionLocked, p.join(getPersistentCacheDir().path, "instances", widget.instance['uuid'] as String), (resolveLatest("Vanilla", "Client", widget.instance['version'] as String).split('-').first));
                    if (!mounted) return;
                    setState(() {downloadingList[project] = false;});
                    if (!downloaded) return;
                    final Map<String, dynamic> mods = (widget.instance["mods"] ??= <String, dynamic>{} ) as Map<String,dynamic>;
                    mods[project.slug] = {
                      "version": project.latestVersionSlug,
                      "enabled": true,
                      "type": project.projectType,
                      "path": project.latestVersionPrimaryFileName,
                      "sha512": project.latestVersionPrimaryFileHash
                    };
                    setState(() {});
                    await InstanceManager().saveInstance(widget.instance['uuid'] as String, widget.instance);
                  },
                ),
              ),
            )
        )
        );
      },
    );
  }
}

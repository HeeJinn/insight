import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_theme.dart';
import '../models/flavor_profile.dart';
import '../providers/flavor_profiles_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

class FlavorStudioScreen extends ConsumerWidget {
  const FlavorStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(flavorProfilesProvider);
    final enabledCount = profiles.where((profile) => profile.enabled).length;
    final compact = AppBreakpoints.isCompact(MediaQuery.sizeOf(context).width);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Flavor Studio'),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(flavorProfilesProvider.notifier).resetAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Flavor defaults restored')),
              );
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset all'),
          ),
        ],
      ),
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final wide = width >= 1080;
            final contentWidth = AppBreakpoints.contentWidth(width);
            final padding = AppBreakpoints.pagePadding(width);

            return SafeArea(
              child: SingleChildScrollView(
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppPanel(
                          child: AppSectionHeading(
                            eyebrow: 'Admin customization',
                            title: 'Vessel and Scoop',
                            subtitle:
                                'Edit the copy, visual tone, and visibility of your two workspace flavors so the experience fits your team.',
                            compact: compact,
                            trailing: Badge.count(
                              count: enabledCount,
                              child: FilledButton.tonalIcon(
                                onPressed: () => context.go('/admin'),
                                icon: const Icon(
                                  Icons.dashboard_customize_outlined,
                                ),
                                label: const Text('Admin dashboard'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _FlavorOverviewCard(
                                  title: 'Live flavors',
                                  value: '$enabledCount / ${profiles.length}',
                                  subtitle:
                                      'Available to the admin workspace right now.',
                                  color: AppTheme.accentDark,
                                  icon: Icons.tune_outlined,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _FlavorOverviewCard(
                                  title: 'Primary presets',
                                  value: 'Vessel + Scoop',
                                  subtitle:
                                      'Both presets can be renamed, recolored, and paused.',
                                  color: AppTheme.blue,
                                  icon: Icons.palette_outlined,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _FlavorOverviewCard(
                            title: 'Live flavors',
                            value: '$enabledCount / ${profiles.length}',
                            subtitle:
                                'Available to the admin workspace right now.',
                            color: AppTheme.accentDark,
                            icon: Icons.tune_outlined,
                          ),
                          const SizedBox(height: 12),
                          const _FlavorOverviewCard(
                            title: 'Primary presets',
                            value: 'Vessel + Scoop',
                            subtitle:
                                'Both presets can be renamed, recolored, and paused.',
                            color: AppTheme.blue,
                            icon: Icons.palette_outlined,
                          ),
                        ],
                        const SizedBox(height: 18),
                        ...profiles.map(
                          (profile) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _FlavorCard(profile: profile),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FlavorOverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _FlavorOverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlavorCard extends ConsumerWidget {
  final FlavorProfile profile;

  const _FlavorCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toneColor = AppTheme.flavorToneColor(profile.tone);
    final toneSoft = AppTheme.flavorToneSoft(profile.tone);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.flavorToneGradient(profile.tone),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_flavorIcon(profile.id), color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.tagline,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: profile.enabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.4),
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  onChanged: (value) {
                    ref
                        .read(flavorProfilesProvider.notifier)
                        .upsertFlavor(profile.copyWith(enabled: value));
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Text(
              profile.note,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(
                  avatar: Icon(
                    profile.enabled
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: toneColor,
                  ),
                  label: Text(profile.enabled ? 'Visible to admin' : 'Paused'),
                  backgroundColor: toneSoft,
                ),
                Chip(
                  avatar: Icon(
                    Icons.color_lens_outlined,
                    size: 18,
                    color: toneColor,
                  ),
                  label: Text(_toneLabel(profile.tone)),
                  backgroundColor: toneSoft,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OverflowBar(
              alignment: MainAxisAlignment.start,
              spacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (context) => _FlavorEditorSheet(profile: profile),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Customize'),
                ),
                TextButton.icon(
                  onPressed: () {
                    ref
                        .read(flavorProfilesProvider.notifier)
                        .resetFlavor(profile.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${profile.name} restored to defaults'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlavorEditorSheet extends ConsumerStatefulWidget {
  final FlavorProfile profile;

  const _FlavorEditorSheet({required this.profile});

  @override
  ConsumerState<_FlavorEditorSheet> createState() => _FlavorEditorSheetState();
}

class _FlavorEditorSheetState extends ConsumerState<_FlavorEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;
  late final TextEditingController _noteController;
  late FlavorTone _tone;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _taglineController = TextEditingController(text: widget.profile.tagline);
    _noteController = TextEditingController(text: widget.profile.note);
    _tone = widget.profile.tone;
    _enabled = widget.profile.enabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 6, 18, bottomInset + 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customize ${widget.profile.name}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Update the admin-facing copy and tone for this flavor preset.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'Enter flavor name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineController,
              decoration: const InputDecoration(
                labelText: 'Tagline',
                hintText: 'Short summary',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Admin note',
                hintText: 'Describe where this flavor fits best',
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              subtitle: const Text(
                'Show this flavor in the admin workspace and home overview.',
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 8),
            Text('Visual tone', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<FlavorTone>(
                segments: const [
                  ButtonSegment(
                    value: FlavorTone.mint,
                    icon: Icon(Icons.eco_outlined),
                    label: Text('Mint'),
                  ),
                  ButtonSegment(
                    value: FlavorTone.sky,
                    icon: Icon(Icons.waves_outlined),
                    label: Text('Sky'),
                  ),
                  ButtonSegment(
                    value: FlavorTone.peach,
                    icon: Icon(Icons.wb_sunny_outlined),
                    label: Text('Peach'),
                  ),
                  ButtonSegment(
                    value: FlavorTone.lilac,
                    icon: Icon(Icons.brightness_7_outlined),
                    label: Text('Lilac'),
                  ),
                ],
                selected: {_tone},
                onSelectionChanged: (selection) {
                  setState(() => _tone = selection.first);
                },
              ),
            ),
            const SizedBox(height: 18),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    final tagline = _taglineController.text.trim();
                    final note = _noteController.text.trim();
                    if (name.isEmpty || tagline.isEmpty || note.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please complete all flavor fields'),
                        ),
                      );
                      return;
                    }

                    await ref
                        .read(flavorProfilesProvider.notifier)
                        .upsertFlavor(
                          widget.profile.copyWith(
                            name: name,
                            tagline: tagline,
                            note: note,
                            enabled: _enabled,
                            tone: _tone,
                          ),
                        );
                    if (!mounted) {
                      return;
                    }
                    Navigator.of(this.context).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('$name updated successfully')),
                    );
                  },
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _flavorIcon(String id) {
  return switch (id) {
    'vessel' => Icons.layers_outlined,
    'scoop' => Icons.auto_awesome_mosaic_outlined,
    _ => Icons.palette_outlined,
  };
}

String _toneLabel(FlavorTone tone) {
  return switch (tone) {
    FlavorTone.mint => 'Mint tone',
    FlavorTone.sky => 'Sky tone',
    FlavorTone.peach => 'Peach tone',
    FlavorTone.lilac => 'Lilac tone',
  };
}

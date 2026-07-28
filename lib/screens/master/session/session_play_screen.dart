import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/component.dart';
import '../../../models/session_screen.dart';
import '../../../providers/campaign_provider.dart';
import 'components/component_view.dart';

class SessionPlayScreen extends ConsumerStatefulWidget {
  final String screenId;
  final String chapterId;
  final String campaignId;

  const SessionPlayScreen({
    super.key,
    required this.screenId,
    required this.chapterId,
    required this.campaignId,
  });

  @override
  ConsumerState<SessionPlayScreen> createState() => _SessionPlayScreenState();
}

class _SessionPlayScreenState extends ConsumerState<SessionPlayScreen> {
  /// The current page index into the ordered screen list. `null` until the
  /// list first loads, at which point it's seeded from `widget.screenId`.
  /// Only this index — not the screen list itself — is local UI state; the
  /// ordered list comes from [screenListProvider] on every build.
  int? _screenIndex;
  bool _hideHeader = false;

  void _goTo(int index, int screenCount) {
    if (index < 0 || index >= screenCount) return;
    setState(() => _screenIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screensAsync = ref.watch(screenListProvider(widget.chapterId));

    return screensAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
      data: (allScreens) {
        if (allScreens.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Nessuna scena', style: TextStyle(color: AppTheme.onSurfaceMuted)),
            ),
          );
        }

        if (_screenIndex == null) {
          final idx = allScreens.indexWhere((s) => s.id == widget.screenId);
          _screenIndex = idx >= 0 ? idx : 0;
        }
        final screenIndex = _screenIndex!.clamp(0, allScreens.length - 1);
        final screen = allScreens[screenIndex];

        return _buildScaffold(context, screen, allScreens, screenIndex);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    SessionScreen screen,
    List<SessionScreen> allScreens,
    int screenIndex,
  ) {
    final components = ref.watch(componentListProvider(screen.id));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation bar
            if (!_hideHeader)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: AppTheme.primary,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.accent),
                      onPressed: () => context.go('/campaigns/${widget.campaignId}/chapters/${widget.chapterId}'),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: screenIndex > 0 ? AppTheme.accent : AppTheme.onSurfaceMuted, size: 18),
                      onPressed: screenIndex > 0 ? () => _goTo(screenIndex - 1, allScreens.length) : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(screen.title, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            '${screenIndex + 1} / ${allScreens.length}',
                            style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward_ios, color: screenIndex < allScreens.length - 1 ? AppTheme.accent : AppTheme.onSurfaceMuted, size: 18),
                      onPressed: screenIndex < allScreens.length - 1 ? () => _goTo(screenIndex + 1, allScreens.length) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen, color: AppTheme.accent),
                      onPressed: () => setState(() => _hideHeader = true),
                      tooltip: 'Schermo intero',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.accent),
                      onPressed: () => context.go('/campaigns/${widget.campaignId}/chapters/${widget.chapterId}/screens/${screen.id}/edit'),
                      tooltip: 'Modifica',
                    ),
                  ],
                ),
              )
            else
              GestureDetector(
                onTap: () => setState(() => _hideHeader = false),
                child: Container(
                  height: 4,
                  color: AppTheme.accent.withOpacity(0.5),
                ),
              ),
            // Content
            Expanded(
              child: components.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Errore: $e')),
                data: (list) => list.isEmpty
                    ? const Center(
                        child: Text('Scena vuota', style: TextStyle(color: AppTheme.onSurfaceMuted)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, i) => _PlayComponent(
                          component: list[i],
                          onUpdate: (updated) => ref.read(componentListProvider(screen.id).notifier).save(updated),
                        ),
                      ),
              ),
            ),
            // Bottom navigation
            if (!_hideHeader && allScreens.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: screenIndex > 0 ? () => _goTo(screenIndex - 1, allScreens.length) : null,
                      icon: const Icon(Icons.arrow_back_ios, size: 14),
                      label: Text(
                        screenIndex > 0 ? allScreens[screenIndex - 1].title : '',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: screenIndex < allScreens.length - 1 ? () => _goTo(screenIndex + 1, allScreens.length) : null,
                      icon: Text(
                        screenIndex < allScreens.length - 1 ? allScreens[screenIndex + 1].title : '',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      label: const Icon(Icons.arrow_forward_ios, size: 14),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayComponent extends StatelessWidget {
  final SessionComponent component;
  final Future<void> Function(SessionComponent) onUpdate;

  const _PlayComponent({required this.component, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return ComponentView(component: component, isEditMode: false, onUpdate: onUpdate);
  }
}

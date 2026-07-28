import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/pg/character_list_screen.dart';
import 'screens/pg/character_sheet_screen.dart';
import 'screens/master/campaign_list_screen.dart';
import 'screens/master/campaign_screen.dart';
import 'screens/master/chapter_screen.dart';
import 'screens/master/session/session_edit_screen.dart';
import 'screens/master/session/session_play_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
    ),
    // ── PG Mode ───────────────────────────────────────────────────────────────
    GoRoute(
      path: '/characters',
      builder: (_, __) => const CharacterListScreen(),
    ),
    GoRoute(
      path: '/characters/:characterId',
      builder: (_, state) => CharacterSheetScreen(
        characterId: state.pathParameters['characterId']!,
      ),
    ),
    // ── Master Mode ───────────────────────────────────────────────────────────
    GoRoute(
      path: '/campaigns',
      builder: (_, __) => const CampaignListScreen(),
    ),
    GoRoute(
      path: '/campaigns/:campaignId',
      builder: (_, state) => CampaignScreen(
        campaignId: state.pathParameters['campaignId']!,
      ),
    ),
    GoRoute(
      path: '/campaigns/:campaignId/chapters/:chapterId',
      builder: (_, state) => ChapterScreen(
        campaignId: state.pathParameters['campaignId']!,
        chapterId: state.pathParameters['chapterId']!,
      ),
    ),
    GoRoute(
      path: '/campaigns/:campaignId/chapters/:chapterId/screens/:screenId/edit',
      builder: (_, state) => SessionEditScreen(
        campaignId: state.pathParameters['campaignId']!,
        chapterId: state.pathParameters['chapterId']!,
        screenId: state.pathParameters['screenId']!,
      ),
    ),
    GoRoute(
      path: '/campaigns/:campaignId/chapters/:chapterId/screens/:screenId/play',
      builder: (_, state) => SessionPlayScreen(
        campaignId: state.pathParameters['campaignId']!,
        chapterId: state.pathParameters['chapterId']!,
        screenId: state.pathParameters['screenId']!,
      ),
    ),
  ],
);

class RpBoardApp extends StatelessWidget {
  const RpBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RPBoard',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

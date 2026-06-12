import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'core/navigation/router.dart';
import 'core/theme/neumorphic_theme.dart';
import 'features/shared/frame_wrapper.dart';
import 'services/database_service.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseNotifier.init();

  audioHandler = await AudioService.init(
    builder: () => BeatFlowAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.beatflow.beatflow.channel.audio',
      androidNotificationChannelName: 'BeatFlow Music Playback',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    ),
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(databaseProvider.select((s) => s.theme));
    AppTheme.setTheme(themeMode);

    return MaterialApp.router(
      title: 'BeatFlow Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      routerConfig: goRouter,
      builder: (context, child) {
        return FrameWrapper(child: child!);
      },
    );
  }
}

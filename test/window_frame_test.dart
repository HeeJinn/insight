import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/ui/insight_ui.dart';
import 'package:window_manager/window_manager.dart';

/// Records calls to the window_manager plugin; answers isMaximized.
List<String> fakeWindowChannel({bool maximized = false}) {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('window_manager'), (
        call,
      ) async {
        calls.add(call.method);
        return call.method == 'isMaximized' ? maximized : null;
      });
  return calls;
}

Widget framed() => CupertinoApp(
  builder: (context, child) => DesktopWindowFrame(child: child!),
  home: Builder(
    builder: (context) => CupertinoPageScaffold(
      child: Center(
        child: Text('top ${MediaQuery.paddingOf(context).top.round()}'),
      ),
    ),
  ),
);

void main() {
  testWidgets('Windows: caption buttons control the window', (tester) async {
    final calls = fakeWindowChannel();
    await tester.pumpWidget(framed());
    await tester.pump();

    // Content starts below the 32pt bar.
    expect(find.text('top 32'), findsOneWidget);
    expect(find.byType(WindowCaptionButton), findsNWidgets(3));

    await tester.tap(find.byType(WindowCaptionButton).at(0));
    await tester.tap(find.byType(WindowCaptionButton).at(1));
    await tester.tap(find.byType(WindowCaptionButton).at(2));
    expect(calls, containsAllInOrder(['minimize', 'maximize', 'close']));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows: maximized shows the restore button', (tester) async {
    final calls = fakeWindowChannel(maximized: true);
    await tester.pumpWidget(framed());
    await tester.pump();
    await tester.tap(find.byType(WindowCaptionButton).at(1));
    expect(calls, contains('unmaximize'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Mac: no drawn buttons; the system traffic lights stay', (
    tester,
  ) async {
    fakeWindowChannel();
    await tester.pumpWidget(framed());
    await tester.pump();
    expect(find.byType(WindowCaptionButton), findsNothing);
    expect(find.text('top 28'), findsOneWidget);
    expect(find.byType(DragToMoveArea), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('phones get no title bar at all', (tester) async {
    await tester.pumpWidget(framed());
    expect(find.byType(DragToMoveArea), findsNothing);
    expect(find.text('top 0'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

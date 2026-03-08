import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yunxintong_im/app/app_state.dart';
import 'package:yunxintong_im/main.dart';

void main() {
  testWidgets('App should show login page initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const YunXinTongApp(),
      ),
    );

    expect(find.text('云信通'), findsOneWidget);
  });
}

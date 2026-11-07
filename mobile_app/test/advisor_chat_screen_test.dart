import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/advisor/application/advisor_service.dart';
import 'package:mobile_app/features/advisor/domain/advisor_chat_model.dart';
import 'package:mobile_app/features/advisor/presentation/advisor_chat_screen.dart';
import 'package:mobile_app/features/advisor/presentation/widgets/quick_prompt_carousel.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

/// Fake test implementation of AdvisorService that intercepts askAdvisor
class FakeAdvisorService extends AdvisorService {
  final Future<ChatMessage> Function(
    String userMessage, {
    ProductAdvisorContext? productContext,
    UserProfileModel? userProfile,
  }) onAskAdvisor;

  FakeAdvisorService(this.onAskAdvisor);

  @override
  Future<ChatMessage> askAdvisor({
    required String userMessage,
    ProductAdvisorContext? productContext,
    UserProfileModel? userProfile,
  }) {
    return onAskAdvisor(
      userMessage,
      productContext: productContext,
      userProfile: userProfile,
    );
  }
}

void main() {
  final testProfile = UserProfileModel.defaults('test_user_advisor');

  const testProductContext = ProductAdvisorContext(
    productName: 'Crunchy Hazelnut Cookies',
    barcode: '8901030999999',
    healthScore: 38,
    additives: [
      {'ins_code': '102', 'name': 'Tartrazine', 'risk_tier': 'RED'},
    ],
    nutrition: {'sugars_100g': 28.5},
  );

  testWidgets('AdvisorChatScreen renders header, status pill, welcome bubble, and quick prompt carousel', (tester) async {
    final fakeService = FakeAdvisorService((msg, {productContext, userProfile}) async {
      return ChatMessage.advisor(text: 'Test answer');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AdvisorChatScreen(
          userProfile: testProfile,
          advisorService: fakeService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify top header
    expect(find.text('VeriBite AI Advisor'), findsAtLeastNWidgets(1));
    expect(find.text('Gemini 3.5 Flash • Live AI'), findsAtLeastNWidgets(1));

    // Verify initial welcome message from advisor
    expect(find.textContaining('Hello! I am your VeriBite Personal AI Advisor'), findsOneWidget);

    // Verify quick prompt carousel
    expect(find.byType(QuickPromptCarousel), findsOneWidget);
    expect(find.text('Is maltodextrin safe for daily consumption?'), findsOneWidget);
    expect(find.text('How does WHO calculate free sugar limits?'), findsOneWidget);

    // Verify input bar and send button
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('AdvisorChatScreen displays active product capsule when initial context is provided and allows dismissal', (tester) async {
    final fakeService = FakeAdvisorService((msg, {productContext, userProfile}) async {
      return ChatMessage.advisor(text: 'Analysis completed');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AdvisorChatScreen(
          userProfile: testProfile,
          initialProductContext: testProductContext,
          advisorService: fakeService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify active product capsule is visible
    expect(find.textContaining('Discussing: Crunchy Hazelnut Cookies'), findsOneWidget);

    // Tap dismiss (close) button on product capsule
    final closeButtonFinder = find.byIcon(Icons.close_rounded);
    expect(closeButtonFinder, findsOneWidget);
    await tester.tap(closeButtonFinder);
    await tester.pumpAndSettle();

    // Capsule should now be dismissed
    expect(find.textContaining('Discussing: Crunchy Hazelnut Cookies'), findsNothing);
  });

  testWidgets('AdvisorChatScreen sends prompt via quick prompt carousel and displays AI response with citations and safe portion card', (tester) async {
    final fakeService = FakeAdvisorService((msg, {productContext, userProfile}) async {
      return ChatMessage.advisor(
        text: 'Tartrazine (INS 102) has been linked to hyperactivity in children under the Southampton study.',
        source: 'gemini_2.5_flash',
        safePortionGrams: 10,
        frequencySchedule: 'Max 1x per week',
        citations: [
          'EFSA: Scientific Opinion on the re-evaluation of Tartrazine (E 102) (2009)',
        ],
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AdvisorChatScreen(
          userProfile: testProfile,
          advisorService: fakeService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on the quick prompt
    final quickPromptFinder = find.text('Is maltodextrin safe for daily consumption?');
    expect(quickPromptFinder, findsOneWidget);
    await tester.tap(quickPromptFinder);
    await tester.pumpAndSettle();

    // Verify user message bubble was inserted (appears in user bubble + carousel chip)
    expect(find.text('Is maltodextrin safe for daily consumption?'), findsNWidgets(2));

    // Verify AI response bubble rendered
    expect(find.textContaining('Tartrazine (INS 102) has been linked to hyperactivity'), findsOneWidget);
    expect(find.text('Gemini 3.5 Flash • Live AI'), findsAtLeastNWidgets(1));

    // Verify safe portion card in bubble
    expect(find.textContaining('Prescribed Safe Portion: 10g'), findsOneWidget);
    expect(find.text('Schedule: Max 1x per week'), findsOneWidget);

    // Verify citation chip
    expect(find.textContaining('EFSA: Scientific Opinion on the re-evaluation of Tartrazine (E 102) (2009)'), findsOneWidget);
  });

  testWidgets('AdvisorChatScreen typing message and pressing send adds message to conversation', (tester) async {
    String? receivedPrompt;
    final fakeService = FakeAdvisorService((msg, {productContext, userProfile}) async {
      receivedPrompt = msg;
      return ChatMessage.advisor(
        text: 'WHO strongly recommends limiting free sugar intake to less than 10% of total energy intake.',
        source: 'local_offline',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AdvisorChatScreen(
          userProfile: testProfile,
          advisorService: fakeService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter text in text field
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'How much sugar can I eat?');
    await tester.pumpAndSettle();

    // Tap send icon button
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(receivedPrompt, 'How much sugar can I eat?');
    expect(find.text('How much sugar can I eat?'), findsOneWidget);
    expect(find.textContaining('WHO strongly recommends limiting free sugar intake'), findsOneWidget);
    expect(find.text('Offline Scientific Engine'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import '../l10n/ui_strings.dart';

/// Static, deliberately shared material. No user content or model calls.
class TemplateExample extends StatelessWidget {
  const TemplateExample(this.id, {super.key});
  final String id;
  static const sourceZh =
      '工作坊讨论通知功能。林说：“通知太多会打断工作。”讲师解释批量通知：把多条消息合成一次提醒，例如每天一封邮件。大家决定先试每天汇总；小周负责制作原型，期限未定，尚未完成。短信是备选方向，仍需验证接受度。复习重点是批量与即时通知的区别。';
  static const sourceEn =
      'A workshop discussed notifications. Lin said, “Too many notifications interrupt work.” The instructor defined batching as combining messages into one alert, such as one daily email. The group decided to try daily digests. Zhou will make a prototype; no deadline was set and it is not finished. SMS remains an alternative whose acceptance needs testing. The stated review point is the difference between batched and instant alerts.';
  static const examples = {
    'teno:meeting': [
      '概览：讨论减少通知干扰。\n议题：批量通知。\n决策：先试每天汇总。\n行动项：小周制作原型，期限未定。\n未决问题：短信接受度。',
      'Overview: Reduce notification interruptions.\nTopic: Batching.\nDecision: Try daily digests.\nAction: Zhou makes a prototype; no deadline stated.\nOpen question: Acceptance of SMS.',
    ],
    'teno:interview': [
      '主题：通知干扰。\n回答：林认为通知太多会打断工作。\n引述：“通知太多会打断工作。”\n发现：林对过多通知有顾虑。\n待追问：短信接受度待验证。',
      'Theme: Notification interruptions.\nAnswer: Lin finds excessive alerts disruptive.\nQuote: “Too many notifications interrupt work.”\nFinding: Lin is concerned about excessive alerts.\nFollow-up: SMS acceptance remains unverified.',
    ],
    'teno:lecture': [
      '主题：通知方式。\n概念：批量通知合并多条消息。\n知识层级：通知 → 批量／即时。\n例子：每天一封邮件。\n原文提及的复习重点：批量与即时通知的区别。',
      'Topic: Notification delivery.\nConcept: Batching combines messages.\nHierarchy: Notifications → batched / instant.\nExample: One daily email.\nStated review point: Batched versus instant alerts.',
    ],
    'teno:inspiration': [
      '想法：每天汇总通知。\n场景：减少工作时的打扰。\n背景：林反馈通知过多。\n备选方向：短信。\n待验证问题：短信接受度。',
      'Idea: A daily notification digest.\nScenario: Fewer work interruptions.\nBackground: Lin reports excessive alerts.\nAlternative: SMS.\nQuestion to validate: Acceptance of SMS.',
    ],
    'teno:actions': [
      '任务：制作原型。\n负责人：小周。\n期限：原文未明确。\n状态：已安排，尚未完成。\n来源：“小周负责制作原型，期限未定，尚未完成。”',
      'Task: Make a prototype.\nOwner: Zhou.\nDeadline: Not stated.\nStatus: Assigned, not finished.\nSource: “Zhou will make a prototype; no deadline was set and it is not finished.”',
    ],
  };
  @override
  Widget build(BuildContext context) {
    final values = examples[id];
    if (values == null) return const SizedBox.shrink();
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const UiText(
          'Example source',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          zh ? sourceZh : sourceEn,
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 12),
        const UiText(
          'Example result',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          values[zh ? 0 : 1],
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
      ],
    );
  }
}

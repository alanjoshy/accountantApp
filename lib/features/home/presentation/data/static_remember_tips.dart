// Static demo tips for Home “Things to remember”.

enum RememberTone { info, warning, success }

class StaticRememberTip {
  const StaticRememberTip({
    required this.id,
    required this.title,
    required this.body,
    required this.tone,
    this.hrefLabel,
  });

  final String id;
  final String title;
  final String body;
  final RememberTone tone;
  final String? hrefLabel;
}

const staticRememberTips = <StaticRememberTip>[
  StaticRememberTip(
    id: 'daily-avg',
    title: 'Average daily spend',
    body:
        "You're averaging ₹1,250 per day across this cycle (12 days).",
    tone: RememberTone.info,
  ),
  StaticRememberTip(
    id: 'rent-due',
    title: 'Rent send coming up',
    body: 'Scheduled payment for Rent is due in 3 days. Keep ₹15,000 ready.',
    tone: RememberTone.warning,
    hrefLabel: 'Tap to open',
  ),
  StaticRememberTip(
    id: 'healthy',
    title: 'Spending looks steady',
    body:
        'Expenses are well under income this period. Nice buffer to keep going.',
    tone: RememberTone.success,
  ),
];

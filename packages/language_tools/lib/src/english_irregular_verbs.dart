/// Three principal forms of an English irregular verb.
class IrregularVerbForms {
  const IrregularVerbForms({
    required this.base,
    required this.pastSimple,
    required this.pastParticiple,
  });

  final String base;
  final List<String> pastSimple;
  final List<String> pastParticiple;

  String get pastSimpleLabel => pastSimple.join('/');
  String get pastParticipleLabel => pastParticiple.join('/');
}

/// Returns irregular verb forms for an English verb or verb phrase.
///
/// The lookup accepts base, past-simple, and past-participle forms. For
/// multiword expressions it searches tokens from left to right, which covers
/// phrasal verbs such as "taken off" -> "take / took / taken".
IrregularVerbForms? findEnglishIrregularVerbForms(String value) {
  final whole = _normalizeToken(value);
  if (whole != null) {
    final forms = _formsByToken[whole];
    if (forms != null) return forms;
  }

  for (final token in _tokenPattern.allMatches(value)) {
    final normalized = _normalizeToken(token.group(0));
    if (normalized == null) continue;
    final forms = _formsByToken[normalized];
    if (forms != null) return forms;
  }
  return null;
}

bool looksLikeVerbPartOfSpeech(String? value) {
  final normalized = value?.trim().toLowerCase().replaceAll('_', ' ') ?? '';
  return normalized == 'verb' ||
      normalized.contains(' verb') ||
      normalized.contains('verb ');
}

final _tokenPattern = RegExp(r"[A-Za-z']+");

String? _normalizeToken(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  final tokens = _tokenPattern
      .allMatches(normalized)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  if (tokens.isEmpty) return null;
  return tokens.join(' ');
}

final _formsByToken = <String, IrregularVerbForms>{
  for (final forms in _irregularVerbForms)
    for (final value in [
      forms.base,
      ...forms.pastSimple,
      ...forms.pastParticiple,
    ])
      _normalizeToken(value)!: forms,
};

const _irregularVerbForms = <IrregularVerbForms>[
  IrregularVerbForms(
    base: 'be',
    pastSimple: ['was', 'were'],
    pastParticiple: ['been'],
  ),
  IrregularVerbForms(
    base: 'become',
    pastSimple: ['became'],
    pastParticiple: ['become'],
  ),
  IrregularVerbForms(
    base: 'begin',
    pastSimple: ['began'],
    pastParticiple: ['begun'],
  ),
  IrregularVerbForms(
    base: 'break',
    pastSimple: ['broke'],
    pastParticiple: ['broken'],
  ),
  IrregularVerbForms(
    base: 'bring',
    pastSimple: ['brought'],
    pastParticiple: ['brought'],
  ),
  IrregularVerbForms(
    base: 'build',
    pastSimple: ['built'],
    pastParticiple: ['built'],
  ),
  IrregularVerbForms(
    base: 'buy',
    pastSimple: ['bought'],
    pastParticiple: ['bought'],
  ),
  IrregularVerbForms(
    base: 'catch',
    pastSimple: ['caught'],
    pastParticiple: ['caught'],
  ),
  IrregularVerbForms(
    base: 'choose',
    pastSimple: ['chose'],
    pastParticiple: ['chosen'],
  ),
  IrregularVerbForms(
    base: 'come',
    pastSimple: ['came'],
    pastParticiple: ['come'],
  ),
  IrregularVerbForms(base: 'cut', pastSimple: ['cut'], pastParticiple: ['cut']),
  IrregularVerbForms(base: 'do', pastSimple: ['did'], pastParticiple: ['done']),
  IrregularVerbForms(
    base: 'draw',
    pastSimple: ['drew'],
    pastParticiple: ['drawn'],
  ),
  IrregularVerbForms(
    base: 'drink',
    pastSimple: ['drank'],
    pastParticiple: ['drunk'],
  ),
  IrregularVerbForms(
    base: 'drive',
    pastSimple: ['drove'],
    pastParticiple: ['driven'],
  ),
  IrregularVerbForms(
    base: 'eat',
    pastSimple: ['ate'],
    pastParticiple: ['eaten'],
  ),
  IrregularVerbForms(
    base: 'fall',
    pastSimple: ['fell'],
    pastParticiple: ['fallen'],
  ),
  IrregularVerbForms(
    base: 'feel',
    pastSimple: ['felt'],
    pastParticiple: ['felt'],
  ),
  IrregularVerbForms(
    base: 'fight',
    pastSimple: ['fought'],
    pastParticiple: ['fought'],
  ),
  IrregularVerbForms(
    base: 'find',
    pastSimple: ['found'],
    pastParticiple: ['found'],
  ),
  IrregularVerbForms(
    base: 'fly',
    pastSimple: ['flew'],
    pastParticiple: ['flown'],
  ),
  IrregularVerbForms(
    base: 'forget',
    pastSimple: ['forgot'],
    pastParticiple: ['forgotten', 'forgot'],
  ),
  IrregularVerbForms(
    base: 'get',
    pastSimple: ['got'],
    pastParticiple: ['gotten', 'got'],
  ),
  IrregularVerbForms(
    base: 'give',
    pastSimple: ['gave'],
    pastParticiple: ['given'],
  ),
  IrregularVerbForms(
    base: 'go',
    pastSimple: ['went'],
    pastParticiple: ['gone'],
  ),
  IrregularVerbForms(
    base: 'grow',
    pastSimple: ['grew'],
    pastParticiple: ['grown'],
  ),
  IrregularVerbForms(
    base: 'have',
    pastSimple: ['had'],
    pastParticiple: ['had'],
  ),
  IrregularVerbForms(
    base: 'hear',
    pastSimple: ['heard'],
    pastParticiple: ['heard'],
  ),
  IrregularVerbForms(
    base: 'hold',
    pastSimple: ['held'],
    pastParticiple: ['held'],
  ),
  IrregularVerbForms(
    base: 'keep',
    pastSimple: ['kept'],
    pastParticiple: ['kept'],
  ),
  IrregularVerbForms(
    base: 'know',
    pastSimple: ['knew'],
    pastParticiple: ['known'],
  ),
  IrregularVerbForms(
    base: 'leave',
    pastSimple: ['left'],
    pastParticiple: ['left'],
  ),
  IrregularVerbForms(
    base: 'lend',
    pastSimple: ['lent'],
    pastParticiple: ['lent'],
  ),
  IrregularVerbForms(base: 'let', pastSimple: ['let'], pastParticiple: ['let']),
  IrregularVerbForms(
    base: 'lose',
    pastSimple: ['lost'],
    pastParticiple: ['lost'],
  ),
  IrregularVerbForms(
    base: 'make',
    pastSimple: ['made'],
    pastParticiple: ['made'],
  ),
  IrregularVerbForms(
    base: 'mean',
    pastSimple: ['meant'],
    pastParticiple: ['meant'],
  ),
  IrregularVerbForms(
    base: 'meet',
    pastSimple: ['met'],
    pastParticiple: ['met'],
  ),
  IrregularVerbForms(
    base: 'pay',
    pastSimple: ['paid'],
    pastParticiple: ['paid'],
  ),
  IrregularVerbForms(base: 'put', pastSimple: ['put'], pastParticiple: ['put']),
  IrregularVerbForms(
    base: 'read',
    pastSimple: ['read'],
    pastParticiple: ['read'],
  ),
  IrregularVerbForms(
    base: 'ride',
    pastSimple: ['rode'],
    pastParticiple: ['ridden'],
  ),
  IrregularVerbForms(
    base: 'ring',
    pastSimple: ['rang'],
    pastParticiple: ['rung'],
  ),
  IrregularVerbForms(
    base: 'rise',
    pastSimple: ['rose'],
    pastParticiple: ['risen'],
  ),
  IrregularVerbForms(base: 'run', pastSimple: ['ran'], pastParticiple: ['run']),
  IrregularVerbForms(
    base: 'say',
    pastSimple: ['said'],
    pastParticiple: ['said'],
  ),
  IrregularVerbForms(
    base: 'see',
    pastSimple: ['saw'],
    pastParticiple: ['seen'],
  ),
  IrregularVerbForms(
    base: 'sell',
    pastSimple: ['sold'],
    pastParticiple: ['sold'],
  ),
  IrregularVerbForms(
    base: 'send',
    pastSimple: ['sent'],
    pastParticiple: ['sent'],
  ),
  IrregularVerbForms(base: 'set', pastSimple: ['set'], pastParticiple: ['set']),
  IrregularVerbForms(
    base: 'shake',
    pastSimple: ['shook'],
    pastParticiple: ['shaken'],
  ),
  IrregularVerbForms(
    base: 'show',
    pastSimple: ['showed'],
    pastParticiple: ['shown', 'showed'],
  ),
  IrregularVerbForms(
    base: 'shut',
    pastSimple: ['shut'],
    pastParticiple: ['shut'],
  ),
  IrregularVerbForms(
    base: 'sing',
    pastSimple: ['sang'],
    pastParticiple: ['sung'],
  ),
  IrregularVerbForms(base: 'sit', pastSimple: ['sat'], pastParticiple: ['sat']),
  IrregularVerbForms(
    base: 'sleep',
    pastSimple: ['slept'],
    pastParticiple: ['slept'],
  ),
  IrregularVerbForms(
    base: 'speak',
    pastSimple: ['spoke'],
    pastParticiple: ['spoken'],
  ),
  IrregularVerbForms(
    base: 'spend',
    pastSimple: ['spent'],
    pastParticiple: ['spent'],
  ),
  IrregularVerbForms(
    base: 'stand',
    pastSimple: ['stood'],
    pastParticiple: ['stood'],
  ),
  IrregularVerbForms(
    base: 'steal',
    pastSimple: ['stole'],
    pastParticiple: ['stolen'],
  ),
  IrregularVerbForms(
    base: 'swim',
    pastSimple: ['swam'],
    pastParticiple: ['swum'],
  ),
  IrregularVerbForms(
    base: 'take',
    pastSimple: ['took'],
    pastParticiple: ['taken'],
  ),
  IrregularVerbForms(
    base: 'teach',
    pastSimple: ['taught'],
    pastParticiple: ['taught'],
  ),
  IrregularVerbForms(
    base: 'tell',
    pastSimple: ['told'],
    pastParticiple: ['told'],
  ),
  IrregularVerbForms(
    base: 'think',
    pastSimple: ['thought'],
    pastParticiple: ['thought'],
  ),
  IrregularVerbForms(
    base: 'throw',
    pastSimple: ['threw'],
    pastParticiple: ['thrown'],
  ),
  IrregularVerbForms(
    base: 'understand',
    pastSimple: ['understood'],
    pastParticiple: ['understood'],
  ),
  IrregularVerbForms(
    base: 'wear',
    pastSimple: ['wore'],
    pastParticiple: ['worn'],
  ),
  IrregularVerbForms(base: 'win', pastSimple: ['won'], pastParticiple: ['won']),
  IrregularVerbForms(
    base: 'write',
    pastSimple: ['wrote'],
    pastParticiple: ['written'],
  ),
];

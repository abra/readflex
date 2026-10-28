import 'package:flutter_test/flutter_test.dart';
import 'package:vellum/vellum.dart';

void main() {
  final doc = ContentDocument.parseXml('''
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-GB">
<body class="book">
  <section id="ch1" class="chapter first" epub:type="chapter" xmlns:epub="http://www.idpf.org/2007/ops">
    <h1>Title</h1>
    <p class="first-para">one</p>
    <p>two <em>em</em> <a href="https://x.org/a.html">link</a></p>
    <p lang="fr">trois</p>
    <div><p>nested</p><img src="a.png" alt=""/></div>
    <blockquote></blockquote>
  </section>
</body>
</html>''');

  /// The elements matching [selector], by a short description.
  List<String> matching(String selector) {
    final list = CssSelectorList.parseText(selector);
    if (list == null) return ['<invalid>'];
    final out = <String>[];
    for (final n in doc.descendantsOf(ContentDocument.rootIndex)) {
      if (!doc.isElement(n)) continue;
      if (list.selectors.any((s) => s.matches(doc, n))) {
        final id = doc.idOf(n);
        final text = doc.textContentOf(n).trim();
        out.add(
          '${doc.localNameOf(n)}${id == null ? '' : '#$id'}'
          '${text.isEmpty || text.length > 6 ? '' : ':$text'}',
        );
      }
    }
    return out;
  }

  test('type, universal, class, id and attribute selectors', () {
    expect(matching('h1'), ['h1:Title']);
    expect(matching('P'), ['p:one', 'p', 'p:trois', 'p:nested']);
    expect(matching('*'), hasLength(13));
    expect(matching('.first'), ['section#ch1']);
    expect(matching('.chapter.first'), ['section#ch1']);
    expect(matching('.chapte'), isEmpty);
    expect(matching('#ch1'), ['section#ch1']);
    expect(matching('section#ch1.chapter'), ['section#ch1']);
    expect(matching('[href]'), ['a:link']);
    expect(matching('[epub\\:type="chapter"]'), ['section#ch1']);
    expect(matching('[class~="first"]'), ['section#ch1']);
    expect(matching('[class~=first-para]'), ['p:one']);
    expect(matching('[lang|="fr"]'), ['p:trois']);
    expect(matching('[href^="https"]'), ['a:link']);
    expect(matching(r'[href$=".html"]'), ['a:link']);
    expect(matching('[href*="x.org"]'), ['a:link']);
    expect(matching('[alt=""]'), ['img']);
    expect(matching('[alt~=""]'), isEmpty);
  });

  test('combinators', () {
    expect(matching('section p'), ['p:one', 'p', 'p:trois', 'p:nested']);
    expect(matching('section > p'), ['p:one', 'p', 'p:trois']);
    expect(matching('body > p'), isEmpty);
    expect(matching('h1 + p'), ['p:one']);
    expect(matching('h1 ~ p'), ['p:one', 'p', 'p:trois']);
    expect(matching('p + p'), ['p', 'p:trois']);
    expect(matching('html body section div > p'), ['p:nested']);
    expect(matching('p em'), ['em:em']);
    expect(matching('p > a'), ['a:link']);
  });

  test('structural pseudo-classes', () {
    expect(matching(':root'), ['html']);
    expect(matching('p:first-child'), ['p:nested']);
    expect(matching('section :first-child'), ['h1:Title', 'em:em', 'p:nested']);
    expect(matching('section > :last-child'), ['blockquote']);
    expect(matching('p:only-child'), isEmpty);
    expect(matching('h1:only-child'), isEmpty);
    expect(matching('section > :nth-child(2)'), ['p:one']);
    expect(matching('section > :nth-child(odd)'), [
      'h1:Title',
      'p',
      'div:nested',
    ]);
    expect(matching('section > :nth-child(2n)'), [
      'p:one',
      'p:trois',
      'blockquote',
    ]);
    expect(matching('section > :nth-child(-n+2)'), ['h1:Title', 'p:one']);
    expect(matching('section > :nth-last-child(1)'), ['blockquote']);
    expect(matching('p:first-of-type'), ['p:one', 'p:nested']);
    expect(matching('section > p:last-of-type'), ['p:trois']);
    expect(matching(':empty'), ['img', 'blockquote']);
    expect(matching(':not(p)'), isNot(contains('p:one')));
    expect(matching('p:not(.first-para)'), ['p', 'p:trois', 'p:nested']);
    expect(matching(':lang(fr)'), ['p:trois']);
    expect(matching('p:lang(en)'), ['p:one', 'p', 'p:nested']);
    expect(matching(':lang("en-gb")'), hasLength(12));
  });

  test('pseudo-elements and dynamic pseudo-classes parse and never match', () {
    expect(matching('p::first-letter'), isEmpty);
    expect(matching('p:first-line'), isEmpty);
    expect(matching('a:hover'), isEmpty);
    expect(matching('a:link, h1'), ['h1:Title'], reason: 'the list survives');
  });

  test('invalid selectors drop the whole list', () {
    for (final selector in [
      '',
      'p,',
      'p >',
      '> p',
      'p.',
      'p#1a',
      'p:unknown',
      'p:nth-child(x)',
      'p[',
      'p[a=]',
      'p[a=b c]',
      ':not(p > a)',
      'p %',
      'ns|p',
      'p::',
    ]) {
      expect(matching(selector), ['<invalid>'], reason: selector);
    }
  });

  test('specificity', () {
    int specificity(String s) =>
        CssSelectorList.parseText(s)!.selectors.single.specificity;
    expect(specificity('*'), 0);
    expect(specificity('p'), 1);
    expect(specificity('p em'), 2);
    expect(specificity('.a'), 1000);
    expect(specificity('p.a.b'), 2001);
    expect(specificity('#x'), 1000000);
    expect(specificity('#x .a p > em:first-child'), 1002002);
    expect(specificity('[href]'), 1000);
    expect(specificity(':not(.a)'), 1000);
    expect(specificity(':not(p)'), 1);
    expect(specificity('p::before'), 2);
    expect(specificity('a:hover'), 1001);
    expect(specificity(':nth-child(2n)'), 1000);
  });

  test('prints back', () {
    const text =
        'html > body.book section#ch1 p + em ~ a[href^="x"]:first-child:nth-child(2n+1):not(.x)::before, *';
    expect(CssSelectorList.parseText(text).toString(), text);
  });
}

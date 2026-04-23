import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

/// Inserts a handful of sample dictionary entries (plus matching FSRS
/// review items) into the local DB on first run, so UI development has
/// content to render. No-ops if the dictionary table already has any
/// rows. Called from composition only behind a dev flag; safe to remove
/// once the real import flow fully replaces manual seeding.
Future<void> seedDictionary({
  required DictionaryRepository dictionaryRepository,
  required FsrsRepository fsrsRepository,
}) async {
  final existing = await dictionaryRepository.getEntries();
  if (existing.isNotEmpty) return;

  final now = DateTime.now();

  const seeds = [
    (
      w: 'Tranquility',
      t: 'The quality or state of being calm and peaceful.',
      p: '/træŋˈkwɪl.ɪ.ti/',
      pos: 'noun',
      src: 'Meditations',
      ex: '"I affirm that tranquility is nothing else than the good ordering of the mind."',
      d: 14,
      m: true,
    ),
    (
      w: 'Ephemeral',
      t: 'Lasting for a very short time.',
      p: '/ɪˈfem.ər.əl/',
      pos: 'adjective',
      src: 'Meditations',
      ex: '"All things are ephemeral, both memory and the object of memory."',
      d: 12,
      m: false,
    ),
    (
      w: 'Equanimity',
      t: 'Mental calmness and composure, especially in difficult situations.',
      p: '/ˌek.wəˈnɪm.ə.ti/',
      pos: 'noun',
      src: 'Meditations',
      ex: '"Accept the things to which fate binds you with equanimity."',
      d: 10,
      m: true,
    ),
    (
      w: 'Solitude',
      t: 'The state of being alone, often by choice.',
      p: '/ˈsɒl.ɪ.tjuːd/',
      pos: 'noun',
      src: 'The Art of Stillness',
      ex: '"The greatest thing in the world is to know how to belong to oneself."',
      d: 8,
      m: false,
    ),
    (
      w: 'Contemplation',
      t: 'Deep reflective thought or the action of looking thoughtfully at something.',
      p: '/ˌkɒn.tɛmˈpleɪ.ʃən/',
      pos: 'noun',
      src: 'Deep Work',
      ex: '"In contemplation, we find the truest form of understanding."',
      d: 6,
      m: true,
    ),
    (
      w: 'Fortitude',
      t: 'Courage in pain or adversity.',
      p: '/ˈfɔːr.tɪ.tjuːd/',
      pos: 'noun',
      src: 'Meditations',
      ex: '"He showed real fortitude in dealing with his illness."',
      d: 5,
      m: false,
    ),
    (
      w: 'Sagacious',
      t: 'Having or showing keen mental discernment and good judgment.',
      p: '/səˈɡeɪ.ʃəs/',
      pos: 'adjective',
      src: 'Thinking, Fast and Slow',
      ex: '"A sagacious leader anticipates future problems."',
      d: 4,
      m: false,
    ),
    (
      w: 'Melancholy',
      t: 'A deep, persistent sadness or pensive mood.',
      p: '/ˈmel.ən.kɒl.i/',
      pos: 'noun',
      src: 'Four Thousand Weeks',
      ex: '"There is a certain melancholy in the beauty of autumn."',
      d: 3,
      m: true,
    ),
    (
      w: 'Resilience',
      t: 'The capacity to withstand or recover quickly from difficulties.',
      p: '/rɪˈzɪl.i.əns/',
      pos: 'noun',
      src: 'Atomic Habits',
      ex: '"Resilience is not about bouncing back; it is about growing forward."',
      d: 2,
      m: false,
    ),
    (
      w: 'Serendipity',
      t: 'The occurrence of events by chance in a happy or beneficial way.',
      p: '/ˌser.ənˈdɪp.ɪ.ti/',
      pos: 'noun',
      src: 'How to Do Nothing',
      ex: '"Many of the greatest discoveries came about through serendipity."',
      d: 1,
      m: false,
    ),
  ];

  for (final s in seeds) {
    final entry = await dictionaryRepository.addEntry(
      word: s.w,
      translation: s.t,
      pronunciation: s.p,
      partOfSpeech: s.pos,
      sourceId: s.src,
      usageExamples: [s.ex],
      addedAt: now.subtract(Duration(days: s.d)),
    );

    await fsrsRepository.createReviewItem(
      itemId: entry.id,
      itemType: ReviewableType.dictionary,
      sourceId: s.src,
    );

    // Simulate reviews for mastered entries.
    if (s.m) {
      for (final rating in [Rating.good, Rating.good, Rating.easy]) {
        await fsrsRepository.recordReview(
          itemId: entry.id,
          itemType: ReviewableType.dictionary,
          rating: rating,
        );
      }
    }
  }
}

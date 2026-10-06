import 'package:flutter_test/flutter_test.dart';
import 'package:katsklub_flutter/models/post.dart';

Map<String, dynamic> _discussionJson({
  String titleKey = 'discussionTitle',
  String aboutKey = 'discussionAbout',
  String coverKey = 'discussionCoverUrl',
  String sourceKey = 'discussionCoverSource',
}) {
  return <String, dynamic>{
    'id': '101',
    'text': 'Full body of the discussion.',
    'isDiscussion': true,
    titleKey: 'Bagyo Update sa Manila',
    aboutKey: 'Short news-style summary about the storm.',
    coverKey: 'https://media.katsklub.top/attachments/cover.webp',
    sourceKey: 'Photo: KatsKlub Weather Team',
    'authorFullName': 'Test Persona',
    'authorUsername': 'test.persona',
    'createdAt': '2026-10-06T00:00:00.000Z',
  };
}

void main() {
  group('Discussion news fields', () {
    test('fromJson parses camelCase about and cover source', () {
      final post = Post.fromJson(_discussionJson());

      expect(post.isDiscussion, isTrue);
      expect(post.discussionTitle, 'Bagyo Update sa Manila');
      expect(post.discussionAbout, 'Short news-style summary about the storm.');
      expect(post.discussionCoverUrl,
          'https://media.katsklub.top/attachments/cover.webp');
      expect(post.discussionCoverSource, 'Photo: KatsKlub Weather Team');
      expect(post.displayTitle, 'Bagyo Update sa Manila');
    });

    test('fromJson parses snake_case about and cover source', () {
      final post = Post.fromJson(_discussionJson(
        titleKey: 'discussion_title',
        aboutKey: 'discussion_about',
        coverKey: 'discussion_cover_url',
        sourceKey: 'discussion_cover_source',
      ));

      expect(post.discussionAbout, 'Short news-style summary about the storm.');
      expect(post.discussionCoverSource, 'Photo: KatsKlub Weather Team');
    });

    test('missing news fields default to empty strings', () {
      final post = Post.fromJson(<String, dynamic>{
        'id': '102',
        'text': 'Plain post.',
      });

      expect(post.isDiscussion, isFalse);
      expect(post.discussionAbout, '');
      expect(post.discussionCoverSource, '');
    });

    test('toJson round-trips news fields', () {
      final post = Post.fromJson(_discussionJson());
      final json = post.toJson();

      expect(json['discussionAbout'], 'Short news-style summary about the storm.');
      expect(json['discussionCoverSource'], 'Photo: KatsKlub Weather Team');

      final reparsed = Post.fromJson(json);
      expect(reparsed.discussionAbout, post.discussionAbout);
      expect(reparsed.discussionCoverSource, post.discussionCoverSource);
    });

    test('copyWith preserves news fields', () {
      final post = Post.fromJson(_discussionJson());
      final copied = post.copyWith(likeCount: 5);

      expect(copied.likeCount, 5);
      expect(copied.discussionAbout, post.discussionAbout);
      expect(copied.discussionCoverSource, post.discussionCoverSource);
    });
  });
}

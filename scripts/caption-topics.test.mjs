import test from 'node:test'
import assert from 'node:assert/strict'
import { matchesCaptionTopic } from '../src/utils/caption-topics.ts'

test('topics recognize related words, capitalization, and punctuation', () => {
  assert.equal(matchesCaptionTopic('FINALs: three exams tomorrow!', 'academics'), true)
  assert.equal(matchesCaptionTopic('My bestie is texting her crush.', 'relationships'), true)
  assert.equal(matchesCaptionTopic('No dining points left for dinner.', 'food'), true)
  assert.equal(matchesCaptionTopic('Rejected after my internship interview.', 'career'), true)
  assert.equal(matchesCaptionTopic('Another night at Butler library.', 'campus'), true)
})

test('word boundaries avoid unrelated substring matches', () => {
  assert.equal(matchesCaptionTopic('Finally finished.', 'academics'), false)
  assert.equal(matchesCaptionTopic('An updated file.', 'relationships'), false)
  assert.equal(matchesCaptionTopic('A great feature.', 'food'), false)
  assert.equal(matchesCaptionTopic('A good offer.', 'academics'), false)
})

test('topics can overlap and all topics includes unclassified captions', () => {
  const caption = 'Coffee with my friend before finals.'
  for (const topic of ['food', 'relationships', 'academics']) {
    assert.equal(matchesCaptionTopic(caption, topic), true)
  }
  assert.equal(matchesCaptionTopic('Just vibing.', 'all'), true)
  assert.equal(matchesCaptionTopic('', 'all'), true)
  assert.equal(matchesCaptionTopic('', 'food'), false)
})

import test from 'node:test'
import assert from 'node:assert/strict'
import { searchCaptions } from '../src/utils/caption-search.ts'

const feed = [
  { id: 'bestie', content: 'My bestie brought coffee to the library.' },
  { id: 'literal', content: 'Friendship survives finals.' },
  { id: 'dating', content: 'Another date with my crush.' },
  { id: 'friends', content: 'Friends studying in libraries.' },
]
const ids = query => searchCaptions(feed, query).map(item => item.id)

test('short queries and search introductions find related caption words', () => {
  for (const query of ['friendship', 'captions about friendship', 'memes about friendship',
    'Give me the captions about friendship', 'Please show me memes about friendship',
    'Can you find me captions about FRIENDSHIP?!']) {
    assert.deepEqual(ids(query), ['literal', 'bestie', 'friends'])
  }
  assert.deepEqual(ids('captions about friendship at the library'), ['bestie', 'friends'])
})

test('all meaningful terms must match; topic neighbors are not synonyms', () => {
  assert.deepEqual(ids('friends library'), ['bestie', 'friends'])
  assert.deepEqual(ids('friendship pizza'), [])
  assert.deepEqual(ids('not friendship'), [])
  assert.deepEqual(searchCaptions([{ content: 'Finally updated the file.' }], 'finals'), [])
})

test('empty query preserves browsing, empty subjects do not match everything', () => {
  assert.equal(searchCaptions(feed, '  '), feed)
  for (const query of ['captions about', '!!!', 'memes']) assert.deepEqual(ids(query), [])
  assert.deepEqual(searchCaptions([], 'friendship'), [])
})

test('punctuation, Unicode, and relevance ties are handled consistently', () => {
  assert.deepEqual(searchCaptions([{ content: 'Café friends!' }], 'café').length, 1)
  const tied = [{ content: 'A friend arrived.' }, { content: 'My bestie called.' }]
  assert.deepEqual(searchCaptions(tied, 'friendship'), tied)
  assert.deepEqual(ids('friendship friendship'), ids('friendship'))
})

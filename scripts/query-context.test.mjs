import test from 'node:test'
import assert from 'node:assert/strict'
import { createQueryInterpreter } from '../src/utils/query-context.ts'
import { searchCaptionsWithContext } from '../src/utils/caption-search.ts'

const success = queries => Response.json({ choices: [{ message: {
  content: JSON.stringify({ queries }),
} }] })

test('Groq receives only query text, server credentials and a strict output schema', async () => {
  const interpret = createQueryInterpreter()
  const result = await interpret('stressed before finals', 'test-key', async (url, options) => {
    assert.equal(url, 'https://api.groq.com/openai/v1/chat/completions')
    assert.equal(options.headers.Authorization, 'Bearer test-key')
    const body = JSON.parse(options.body)
    assert.equal(body.messages[1].content, 'stressed before finals')
    assert.equal(body.response_format.json_schema.strict, true)
    assert.ok(options.signal)
    return success(['exam anxiety', 'finals stress'])
  })
  assert.deepEqual(result, { queries: ['exam anxiety', 'finals stress'], mode: 'context' })
  assert.ok(!JSON.stringify(result).includes('test-key'))
})

test('repeated and concurrent queries reuse cached interpretations', async () => {
  const interpret = createQueryInterpreter()
  let calls = 0
  const request = async () => { calls++; return success(['friends']) }
  await Promise.all([interpret('Friendship', 'key', request),
    interpret('friendship', 'key', request)])
  await interpret(' friendship ', 'key', request)
  assert.equal(calls, 1)
})

test('missing key, provider errors, timeout and malformed output keep keyword search', async () => {
  const never = async () => { throw new Error('should not call') }
  assert.equal((await createQueryInterpreter()('friends', undefined, never)).mode, 'keywords')
  for (const request of [async () => new Response('', { status: 429 }),
    async () => new Response('', { status: 401 }),
    async () => { throw new DOMException('Timeout', 'TimeoutError') },
    async () => Response.json({ choices: [] }),
    async () => success([123]), async () => success(Array(5).fill('friends'))]) {
    assert.deepEqual(await createQueryInterpreter()('friends', 'key', request),
      { queries: [], mode: 'keywords' })
  }
})

test('request cap and provider cooldown prevent repeated upstream calls', async () => {
  const interpret = createQueryInterpreter()
  let calls = 0
  const request = async () => { calls++; return success(['friends']) }
  for (let i = 0; i < 11; i++) await interpret(`query ${i}`, 'key', request, 100000)
  assert.equal(calls, 10)
  const limited = createQueryInterpreter()
  await limited('friends', 'key', async () => new Response('', { status: 429 }), 100000)
  assert.equal((await limited('exams', 'key', request, 100001)).mode, 'keywords')
  assert.equal(calls, 10)
})

test('rewrites preserve direct ranking, deduplicate, and avoid negation expansion', () => {
  const captions = [{ content: 'Exam anxiety is real.' },
    { content: 'Stressed before finals again.' }, { content: 'Dinner time.' }]
  assert.deepEqual(searchCaptionsWithContext(captions, 'stressed before finals',
    ['exam anxiety', 'exam anxiety']), [captions[1], captions[0]])
  assert.deepEqual(searchCaptionsWithContext(captions, '', ['dinner']), captions)
  assert.deepEqual(searchCaptionsWithContext(captions, 'without exams', ['exams']), [])
})

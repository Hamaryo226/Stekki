const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createOperationQueue, isTradeURL } = require('../src/receive-queue.cjs');

test('an incoming trade waits until the editor closes', async () => {
  const enqueue = createOperationQueue();
  const events = [];
  let close;
  const editor = enqueue(async () => {
    events.push('editor');
    await new Promise(resolve => { close = resolve; });
    events.push('closed');
  });
  const trade = enqueue(async () => { events.push('trade'); });
  await Promise.resolve();
  assert.deepEqual(events, ['editor']);
  close();
  await Promise.all([editor, trade]);
  assert.deepEqual(events, ['editor', 'closed', 'trade']);
});

test('a rejected operation does not block subsequent files', async () => {
  const enqueue = createOperationQueue();
  const failed = enqueue(async () => { throw Error('invalid archive'); });
  const next = enqueue(async () => 'received');
  await assert.rejects(failed, /invalid archive/);
  assert.equal(await next, 'received');
});

test('only local stickertrade URLs enter the receive queue', () => {
  for (const url of ['file:///tmp/test.stickertrade', 'file:///tmp/%E3%82%B7%E3%83%BC%E3%83%AB.STICKERTRADE']) {
    assert.equal(isTradeURL(url), true);
  }
  for (const url of ['https://example.com/test.stickertrade', 'stekki://test.stickertrade',
    'file:///tmp/test.png', 'file:///tmp/test.stickertrade.exe', 'file:///tmp/%ZZ.stickertrade', 'invalid']) {
    assert.equal(isTradeURL(url), false);
  }
});

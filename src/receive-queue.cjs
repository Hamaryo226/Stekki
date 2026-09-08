// Serialize native presentations; an AirDrop arriving over the editor waits for it to close.
function createOperationQueue() {
  let tail = Promise.resolve();
  return function enqueue(operation) {
    const result = tail.then(operation);
    tail = result.catch(() => undefined);
    return result;
  };
}
function isTradeURL(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'file:' && decodeURIComponent(url.pathname).toLowerCase().endsWith('.stickertrade');
  } catch { return false; }
}
module.exports = { createOperationQueue, isTradeURL };

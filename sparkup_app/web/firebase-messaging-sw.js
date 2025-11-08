// Minimal, resilient service worker for FCM background notifications.
// Note: avoid importing firebase scripts here to ensure the worker registers
// in local dev environments where importScripts may fail. This SW listens
// for raw 'push' events and displays a notification using the payload
// provided by the push service.

self.addEventListener('push', function(event) {
  let payload = {};
  try {
    if (event.data) payload = event.data.json();
  } catch (e) {
    // If payload isn't JSON, try to use text
    try { payload = { notification: { body: event.data.text() } }; } catch (_) { payload = {}; }
  }

  const notification = (payload && payload.notification) || {};
  const title = notification.title || 'SparkUp';
  const options = {
    body: notification.body || '',
    icon: notification.icon || '/icons/Icon-192.png',
    data: payload.data || {}
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = event.notification.data?.url || '/';
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
    for (const client of clientList) {
      if (client.url === url && 'focus' in client) return client.focus();
    }
    if (clients.openWindow) return clients.openWindow(url);
  }));
});

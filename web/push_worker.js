// Minimal push-only service worker for Club Sandwich. Deliberately does
// not do offline asset caching — its only job is to turn a push message
// into a device notification and to focus/open the app when tapped.

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', (event) => {
  let payload = { title: 'Club Sandwich', body: '' };
  try {
    if (event.data) payload = event.data.json();
  } catch (error) {
    payload.body = event.data ? event.data.text() : '';
  }

  const url = payload.concertId
    ? `/#/maraudes/${payload.concertId}`
    : '/#/dashboard';

  event.waitUntil(
    self.registration.showNotification(payload.title || 'Club Sandwich', {
      body: payload.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: { url },
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification.data && event.notification.data.url
    ? event.notification.data.url
    : '/#/dashboard';

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ('focus' in client) {
            client.focus();
            if ('navigate' in client) client.navigate(targetUrl);
            return;
          }
        }
        if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
      })
  );
});

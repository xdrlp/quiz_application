importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
    apiKey: 'AIzaSyC6h-ELrDC9iAGOZjJ4-6sa5wlDHy9IRPg',
    appId: '1:1033751174368:web:d43edc44db0776a3018485',
    messagingSenderId: '1033751174368',
    projectId: 'quiz-application-66822',
    authDomain: 'quiz-application-66822.firebaseapp.com',
    storageBucket: 'quiz-application-66822.firebasestorage.app',
    measurementId: 'G-BWZY9594X1',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

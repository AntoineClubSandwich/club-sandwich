{{flutter_js}}
{{flutter_build_config}}

const loadingElement = document.querySelector('#app-loading');

const loadApplication = () => _flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    loadingElement?.remove();
  },
}).catch((error) => {
  if (loadingElement) {
    loadingElement.textContent =
      'Le chargement a échoué. Rechargez la page pour réessayer.';
  }
  throw error;
});

if ('serviceWorker' in navigator) {
  navigator.serviceWorker
    .getRegistrations()
    .then((registrations) =>
      Promise.all(registrations.map((registration) => registration.unregister()))
    )
    .then(loadApplication, loadApplication);
} else {
  loadApplication();
}

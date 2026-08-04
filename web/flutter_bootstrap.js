{{flutter_js}}
{{flutter_build_config}}

const loadApplication = () => _flutter.loader.load();

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

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}}).catch(function () {
  document.getElementById('startup-message').textContent = 'Chưa mở được ứng dụng. Hãy tải lại trang.';
  document.getElementById('startup-retry').hidden = false;
});

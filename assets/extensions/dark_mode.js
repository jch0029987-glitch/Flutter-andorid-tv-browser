(function() {
  if (document.getElementById('custom-dark-mode-style')) return;
  var style = document.createElement('style');
  style.id = 'custom-dark-mode-style';
  style.innerHTML = 'body, html { background-color: #121212 !important; color: #e0e0e0 !important; }';
  document.head.appendChild(style);
})();

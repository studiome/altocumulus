// Turbo Drive replaces <body> and merges <head> on a visit, but on <html> it only
// syncs `lang` and `dir`. The theme lives on <html data-app-theme> (for the CSS), so
// without this it would stay stale after an admin saves a new theme until a hard
// reload. The layout repeats the value on <body>; copy it over before each render.
document.addEventListener("turbo:before-render", (event) => {
  const theme = event.detail.newBody?.dataset.appTheme
  if (theme) document.documentElement.dataset.appTheme = theme
})

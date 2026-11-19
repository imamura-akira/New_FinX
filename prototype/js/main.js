'use strict';
Store.load();
applyPrefs();
document.body.classList.toggle('hide-tags', !Store.ui.showTags);
Router.render();

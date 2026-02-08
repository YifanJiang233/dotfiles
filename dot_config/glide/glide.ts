// Config docs:
//
//   https://glide-browser.app/config
//
// API reference:
//
//   https://glide-browser.app/api
//
// Default config files can be found here:
//
//   https://github.com/glide-browser/glide/tree/main/src/glide/browser/base/content/plugins
//
// Most default keymappings are defined here:
//
//   https://github.com/glide-browser/glide/blob/main/src/glide/browser/base/content/plugins/keymaps.mts
//
// Try typing `glide.` and see what you can do!

// scroll half of the page
glide.prefs.set("toolkit.scrollbox.pagescroll.maxOverlapLines", 9999999999);
glide.prefs.set("toolkit.scrollbox.pagescroll.maxOverlapPercent", 50);

// keybindings
glide.keymaps.set("normal", "x", "tab_close");
glide.keymaps.set("normal", "X", () => {
  glide.keys.send("<S-D-t>");
});
glide.keymaps.set(
  "normal",
  "O",
  async () => {
    await glide.keys.send("<D-t>");
  },
  { description: "Go to address bar and open in a new tab" },
);
glide.keymaps.set("command", "<c-j>", "commandline_focus_next");
glide.keymaps.set("command", "<c-k>", "commandline_focus_back");

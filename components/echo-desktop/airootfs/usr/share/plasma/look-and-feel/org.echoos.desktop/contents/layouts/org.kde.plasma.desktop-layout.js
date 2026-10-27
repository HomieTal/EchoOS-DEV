// Echo OS default panel layout.
// The panel itself comes from Plasma's shipped defaultPanel template
// (application launcher, task manager, system tray, clock, show desktop).
// Pin the desktop containment to the image wallpaper plugin and write the
// Echo OS wallpaper package explicitly: the [Wallpaper] Image default alone
// is not applied reliably on a first login.
loadTemplate("org.kde.plasma.desktop.defaultPanel")

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = 'org.kde.image';
    desktopsArray[j].currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    desktopsArray[j].writeConfig('Image', 'file:///usr/share/wallpapers/EchoOS');
}

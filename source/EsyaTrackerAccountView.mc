import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Kept for compile compatibility; settings entry uses EsyaTrackerPairView (Online status).
class EsyaTrackerAccountView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x142016, Graphics.COLOR_BLACK);
        dc.clear();
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(0xF4EFE4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            h / 2,
            Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.OnlineTitle) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

class EsyaTrackerAccountDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view as EsyaTrackerAccountView;

    function initialize(view as EsyaTrackerAccountView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        return false;
    }
}

import Toybox.Lang;
import Toybox.WatchUi;

class EsyaTrackerPairDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view as EsyaTrackerPairView;
    hidden var _isPushed as Boolean;

    function initialize(view as EsyaTrackerPairView, isPushed as Boolean) {
        BehaviorDelegate.initialize();
        _view = view;
        _isPushed = isPushed;
    }

    function onBack() as Boolean {
        if (_isPushed) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onSelect() as Boolean {
        _view.retry();
        return true;
    }

    function onTap(evt as ClickEvent) as Boolean {
        _view.retry();
        return true;
    }

    function onMenu() as Boolean {
        _view.retry();
        return true;
    }
}

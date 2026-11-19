import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Online/offline status + bind code (settings only). Replaces OAuth pair start/poll.
class EsyaTrackerPairView extends WatchUi.View {

    hidden var _uiTimer as Timer.Timer?;
    hidden var _status as String = "";

    function initialize() {
        View.initialize();
        _status = "";
    }

    function onShow() as Void {
        startUiTimer();
        refreshSession();
    }

    function onHide() as Void {
        stopUiTimer();
    }

    function retry() as Void {
        refreshSession();
        WatchUi.requestUpdate();
    }

    function refreshSession() as Void {
        if (!EsyaTrackerAuth.isOnlineMode()) {
            _status = WatchUi.loadResource(Rez.Strings.OnlineOffHint) as String;
            return;
        }
        _status = WatchUi.loadResource(Rez.Strings.OnlineConnecting) as String;
        EsyaTrackerAuth.refreshOnlineStatus();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x142016, Graphics.COLOR_BLACK);
        dc.clear();
        dc.fillRectangle(0, 0, w, h);

        var pad = 14;
        var y = pad;
        var hintFont = Graphics.FONT_TINY;
        var bodyFont = Graphics.FONT_SMALL;
        var titleFont = Graphics.FONT_MEDIUM;
        var codeFont = Graphics.FONT_NUMBER_MEDIUM;

        var online = EsyaTrackerAuth.isOnlineMode();
        dc.setColor(0xB7C4B8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            pad,
            y,
            hintFont,
            WatchUi.loadResource(Rez.Strings.OnlineTitle) as String,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        y += dc.getFontHeight(hintFont) + 8;

        if (!online) {
            dc.setColor(0xF4EFE4, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                pad,
                y,
                titleFont,
                WatchUi.loadResource(Rez.Strings.OnlineOffTitle) as String,
                Graphics.TEXT_JUSTIFY_LEFT
            );
            y += dc.getFontHeight(titleFont) + 10;
            dc.setColor(0xD8D0C2, Graphics.COLOR_TRANSPARENT);
            drawWrapped(dc, pad, y, w - pad * 2, hintFont, WatchUi.loadResource(Rez.Strings.OnlineOffHint) as String);
            return;
        }

        var hasToken = EsyaTrackerAuth.hasToken();
        var bound = EsyaTrackerAuth.isBound();
        var bindCode = EsyaTrackerAuth.readBindCode();
        var name = EsyaTrackerAuth.readDeviceName();

        if (!hasToken) {
            dc.setColor(0xC9A227, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                pad,
                y,
                bodyFont,
                EsyaTrackerAuth.isSessionBusy()
                    ? (WatchUi.loadResource(Rez.Strings.OnlineConnecting) as String)
                    : (WatchUi.loadResource(Rez.Strings.OnlineNeedToken) as String),
                Graphics.TEXT_JUSTIFY_LEFT
            );
            y += dc.getFontHeight(bodyFont) + 10;
            dc.setColor(0xD8D0C2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pad, y, hintFont, WatchUi.loadResource(Rez.Strings.OnlineTapRefresh) as String, Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        if (bound) {
            dc.setColor(0xF4EFE4, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                pad,
                y,
                titleFont,
                WatchUi.loadResource(Rez.Strings.OnlineBoundTitle) as String,
                Graphics.TEXT_JUSTIFY_LEFT
            );
            y += dc.getFontHeight(titleFont) + 8;
            if (name.length() > 0) {
                dc.setColor(0xC9A227, Graphics.COLOR_TRANSPARENT);
                dc.drawText(pad, y, bodyFont, name, Graphics.TEXT_JUSTIFY_LEFT);
                y += dc.getFontHeight(bodyFont) + 8;
            }
            dc.setColor(0xD8D0C2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pad, y, hintFont, WatchUi.loadResource(Rez.Strings.OnlineTapRefresh) as String, Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        dc.setColor(0xF4EFE4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            pad,
            y,
            bodyFont,
            WatchUi.loadResource(Rez.Strings.OnlineBindHint) as String,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        y += dc.getFontHeight(bodyFont) + 10;

        if (bindCode.length() > 0) {
            dc.setColor(0xC9A227, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, codeFont, bindCode, Graphics.TEXT_JUSTIFY_CENTER);
            y += dc.getFontHeight(codeFont) + 8;
        } else {
            dc.setColor(0xC9A227, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pad, y, bodyFont, WatchUi.loadResource(Rez.Strings.OnlineConnecting) as String, Graphics.TEXT_JUSTIFY_LEFT);
            y += dc.getFontHeight(bodyFont) + 8;
        }

        dc.setColor(0xB7C4B8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(pad, y, hintFont, "esya.ru/pair", Graphics.TEXT_JUSTIFY_LEFT);
        y += dc.getFontHeight(hintFont) + 8;
        if (name.length() > 0) {
            dc.setColor(0xD8D0C2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pad, y, hintFont, name, Graphics.TEXT_JUSTIFY_LEFT);
            y += dc.getFontHeight(hintFont) + 6;
        }
        dc.setColor(0xD8D0C2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(pad, y, hintFont, WatchUi.loadResource(Rez.Strings.OnlineTapRefresh) as String, Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function drawWrapped(
        dc as Dc,
        x as Number,
        y as Number,
        maxW as Number,
        font as FontDefinition,
        text as String
    ) as Void {
        // Simple single-block draw; long text may clip on tiny screens.
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function startUiTimer() as Void {
        stopUiTimer();
        try {
            _uiTimer = new Timer.Timer();
            _uiTimer.start(method(:onUiTick), 1000, true);
        } catch (ex) {
            _uiTimer = null;
        }
    }

    hidden function stopUiTimer() as Void {
        if (_uiTimer != null) {
            try {
                _uiTimer.stop();
            } catch (ex) {
            }
            _uiTimer = null;
        }
    }

    function onUiTick() as Void {
        if (EsyaTrackerAuth.isOnlineMode() && (!EsyaTrackerAuth.hasToken() || (!EsyaTrackerAuth.isBound() && EsyaTrackerAuth.readBindCode().length() == 0))) {
            if (!EsyaTrackerAuth.isSessionBusy()) {
                EsyaTrackerAuth.refreshOnlineStatus();
            }
        }
        WatchUi.requestUpdate();
    }
}

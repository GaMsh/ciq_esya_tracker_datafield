import Toybox.Activity;
import Toybox.Application;
import Toybox.Attention;
import Toybox.Communications;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class EsyaTrackerView extends WatchUi.DataField {

    const TX_FAIL_RECORD_ID = 1;
    const PRESSURE_FIELD_ID = 4;
    const BATTERY_FIELD_ID = 5;
    const GPS_FIELD_ID = 6;
    const VIEWERS_FIELD_ID = 7;
    const TEMP_FIELD_ID = 8;
    const WEATHER_TEMP_DELTA_FIELD_ID = 9;
    const WIND_TYPE_FIELD_ID = 10;
    const WIND_SPEED_FIELD_ID = 11;
    const TONE_DEFAULT = 0;
    const TONE_OK = 1;
    const TONE_WAIT = 2;
    const TONE_ERROR = 3;
    const STALE_WARN_SEC = 15;
    const STALE_FAIL_SEC = 45;
    (:other_token)
    const FALLBACK_TOKEN = "zHd5rsY3vOCYhXzYk0k165SNgLtBgb_lSypDTSCdnV";
    (:other_token)
    const STALE_TOKEN = "cp4N8wcw9OrucMm0gB6tQPU2jE2kqFy5cun9SQBgWJ";
    (:edge1050)
    const FALLBACK_TOKEN = "cp4N8wcw9OrucMm0gB6tQPU2jE2kqFy5cun9SQBgWJ";
    (:edge1050)
    const STALE_TOKEN = "zHd5rsY3vOCYhXzYk0k165SNgLtBgb_lSypDTSCdnV";
    const CODE_SEND_CRASH = -9001;
    const CODE_COMPUTE_CRASH = -9002;
    const BEEP_EVERY_POINTS = 4200;
    const COLOR_EVERY_POINTS = 3600;
    const MAX_SPEED_MPS = 278.0;
    const PAUSE_SEND_INTERVAL_SEC = 60;
    const FORBIDDEN_CLEAR_COUNT = 15;
    const WIND_ALIGN_DEG = 30;
    const WIND_QUARTER_DEG = 75;
    // Below this ground speed (m/s), course is unreliable — show wind compass, not head/tail.
    const WIND_CARDINAL_MAX_SPEED_MPS = 8.0 / 3.6;
    const WIND_CALM_MAX_MPS = 0.5;
    const WIND_TYPE_NONE = 99;
    const WIND_TYPE_HEAD = -2;
    const WIND_TYPE_QUARTER_HEAD = -1;
    const WIND_TYPE_CROSS = 0;
    const WIND_TYPE_QUARTER_TAIL = 1;
    const WIND_TYPE_TAIL = 2;
    // createField IDs are per activity; re-add mid-ride fatals if called again.
    const FIT_SESSION_KEY = "esya_fit_session";
    const FIT_ONLINE_KEY = "esya_fit_online";
    const UNITS_METRIC = 0;
    const UNITS_NAUTICAL = 1;
    const MPS_TO_KN = 3600.0 / 1852.0;
    const M_TO_FT = 3.28084;
    const HPA_TO_MMHG = 0.750061683;
    const WIND_COLOR_PINK = 0xFF6B9D;
    const VERSION_URL = "https://esya.ru/osmo/ciq-version.json";
    const VERSION_CHECK_INTERVAL_SEC = 6 * 3600;
    const VERSION_STORAGE_KEY = "esya_ciq_latest";
    const VERSION_CHECKED_KEY = "esya_ciq_checked_at";
    const VERSION_PENDING_KEY = "esya_ciq_update_pending";
    // Soft attention fill when idle (not alarm red/orange).
    const UPDATE_IDLE_BG = 0x2C3848;
    const UPDATE_IDLE_FG = 0xE8D5A3;

    hidden var txOk as Number = 0;
    hidden var txFail as Number = 0;
    hidden var forbidden403Count as Number = 0;
    hidden var lastCode as Number = 0;
    hidden var busy as Boolean = false;
    hidden var pending as Dictionary?;
    hidden var hasDistance as Boolean = false;
    hidden var timerOn as Boolean = false;
    hidden var timerPaused as Boolean = false;
    hidden var lastElapsedDistance as Float?;
    hidden var lastElapsedAt as Number?;
    hidden var lastOkAt as Number?;
    hidden var lastPauseSendAt as Number?;
    hidden var derivedSpeed as Float?;
    // Detect new activity when the DF View instance is reused (Edge/FR).
    hidden var lastSeenStartTime as Number?;

    hidden var txFailRecord as FitContributor.Field?;
    hidden var pressureField as FitContributor.Field?;
    hidden var batteryField as FitContributor.Field?;
    hidden var gpsField as FitContributor.Field?;
    hidden var viewersField as FitContributor.Field?;
    hidden var tempField as FitContributor.Field?;
    hidden var weatherTempDeltaField as FitContributor.Field?;
    hidden var windTypeField as FitContributor.Field?;
    hidden var windSpeedField as FitContributor.Field?;
    hidden var viewersCount as Number?;
    hidden var fitReady as Boolean = false;
    hidden var fitTried as Boolean = false;
    hidden var fitSkippedReadd as Boolean = false;
    hidden var tempText as String = "--";
    hidden var presText as String = "--";
    hidden var speedText as String = "--";
    hidden var windText as String = "";
    hidden var viewersText as String = "";
    hidden var sensorTop2 as String = "";
    hidden var sensorBot2 as String = "";
    hidden var cacheTemp as Float?;
    hidden var cacheHasWxDelta as Boolean = false;
    hidden var cacheWxDelta as Float = 0.0;
    hidden var cachePres as Float?;
    hidden var cacheAlt as Float?;
    hidden var cacheSpeed as Float?;
    hidden var cacheWindTypeUi as Number = WIND_TYPE_NONE;
    hidden var cacheWindSpeedMps as Float?;
    hidden var cacheWindCalm as Boolean = false;
    hidden var cacheWindDirLabel as String = "";
    hidden var cacheWindDirCompact as String = "";
    hidden var cacheViewersCount as Number = 0;
    hidden var cacheGpsQuality as Number?;
    // Bad GPS background ramp: quality ≤3 accumulates; ≤2 uses a separate red ramp.
    hidden var gpsBadAccumSec as Number = 0;
    hidden var gpsSevereAccumSec as Number = 0;
    hidden var gpsBadTickAt as Number?;
    hidden var updateAvailable as Boolean = false;
    hidden var versionCheckBusy as Boolean = false;
    hidden var lastTempBgEnsure as Number = 0;

    function initialize() {
        DataField.initialize();
    }

    function onTimerStart() as Void {
        try {
            ensureFitFields();
        } catch (ex) {
        }
    }

    function onTimerReset() as Void {
        // Activity saved/discarded — DF instance often survives; clear per-ride state.
        resetActivitySessionState();
        lastSeenStartTime = null;
    }

    function compute(info as Activity.Info) as Void {
        try {
            reconcileActivitySession(info);
            timerOn = isTimerOn(info);
            timerPaused = isTimerPaused(info);
            hasDistance = info has :elapsedDistance && info.elapsedDistance != null && info.elapsedDistance > 0;
            try {
                (Application.getApp() as EsyaTrackerApp).syncSettingsDisplayOnce();
            } catch (exSync) {
            }
            try {
                var nowBg = Time.now().value();
                if (lastTempBgEnsure == 0 || (nowBg - lastTempBgEnsure) >= 30) {
                    lastTempBgEnsure = nowBg;
                    (Application.getApp() as EsyaTrackerApp).ensureTempBackground();
                }
            } catch (exBg) {
            }
            // Reconcile pending flag every tick (clears after the user installs the update).
            reconcileUpdateFlag();
            // Poll remote version only on warm-up; never during a running/paused activity.
            if (!timerOn && !timerPaused) {
                maybeCheckForUpdate();
            }

            // createField only while recording — calling it before Start can fatal-crash.
            if (timerOn || timerPaused) {
                ensureFitFields();
            }

            if (timerOn) {
                lastPauseSendAt = null;
                sampleElapsedSpeed(info);
                updateSensorState(info);
                writeFit();

                if (EsyaTrackerAuth.isOnlineMode()) {
                    EsyaTrackerAuth.ensureOnlineSession();
                }
                if (canSendNow()) {
                    var point = buildPoint(info);
                    if (point != null) {
                        pending = point;
                    }
                    if (!busy) {
                        trySend();
                    }
                } else {
                    pending = null;
                }
                return;
            }

            lastElapsedDistance = null;
            lastElapsedAt = null;
            derivedSpeed = null;
            updateSensorState(info);
            writeFit();

            if (EsyaTrackerAuth.isOnlineMode() && !timerOn) {
                EsyaTrackerAuth.ensureOnlineSession();
            }
            if (timerPaused && canSendNow()) {
                maybeQueuePauseSend(info);
                if (!busy) {
                    trySend();
                }
                return;
            }

            pending = null;
            lastPauseSendAt = null;
        } catch (ex) {
            lastCode = CODE_COMPUTE_CRASH;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        try {
            var width = dc.getWidth();
            var height = dc.getHeight();
            var round = useRoundLayout(width, height);

            // Idle: full-field soft banner. Does not block compute/send.
            if (updateAvailable && isPreActivity()) {
                drawUpdateSplash(dc, width, height, round);
                return;
            }

            var theme = getBackgroundColor();
            var bg = fieldBackground(theme);
            var fg = fieldForeground(theme);
            dc.setColor(fg, bg);
            dc.clear();
            var compact = round || height < 160 || width < 200;
            var micro = height < 100 || (round && height < 140);
            var spacious = isSpaciousLayout(width, height, round);
            rebuildSensorDisplay(round, spacious, compact, micro);
            var pad = layoutPad(width, height, round, spacious);
            var sensorFont = sensorFontFor(dc, width, height, round, spacious, pad);
            var fh = dc.getFontHeight(sensorFont);
            var topLines = countSensorTopLines(micro);
            var botLines = countSensorBotLines(micro, isOfflineMode());
            var bandTop = round ? (pad + (topLines * fh)) : (pad + fh);
            var bandBot = round ? (pad + (botLines * fh)) : (pad + fh);
            if (spacious && !round) {
                bandTop = pad + fh + (fh / 3);
                bandBot = bandTop;
            }
            if (micro) {
                bandTop = pad;
                bandBot = pad + ((botLines > 0) ? fh : 0);
            }
            var midHeight = height - bandTop - bandBot;
            if (midHeight < 1) {
                midHeight = height;
                bandTop = 0;
                bandBot = 0;
            }
            var value = statusValue(compact);
            var showPaused = isPausedDisplay();
            var statusMaxW = lineMaxWidth(width, height, height / 2, pad, round);
            var font = statusFont(dc, width, midHeight, value, spacious, round, statusMaxW);
            var sensorFg = sensorColor(theme);
            var countColor = txOkColor(theme);
            var offline = isOfflineMode();
            var showOfflineActive = offline && (timerOn || timerPaused);

            dc.setColor(sensorFg, Graphics.COLOR_TRANSPARENT);
            if (round || compact) {
                drawRoundSensorBands(dc, width, height, sensorFont, pad, offline, theme, micro);
            } else {
                dc.drawText(pad, pad, sensorFont, tempText, Graphics.TEXT_JUSTIFY_LEFT);
                dc.drawText(width - pad, pad, sensorFont, presText, Graphics.TEXT_JUSTIFY_RIGHT);

                var bottomY = height - pad - fh;
                drawSpeedWithWind(dc, pad, bottomY, sensorFont, theme, sensorFg);
                if (!offline && viewersText.length() > 0) {
                    dc.setColor(sensorFg, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(width - pad, bottomY, sensorFont, viewersText, Graphics.TEXT_JUSTIFY_RIGHT);
                }
            }

            var gpsWarn = gpsStatusLabel(compact);
            if (showPaused || gpsWarn != null) {
                var mainValue = showPaused ? value : (gpsWarn as String);
                mainValue = fitLineToWidth(dc, mainValue, Graphics.FONT_TINY, statusMaxW);
                var pauseFont = pickFittingFont(dc, mainValue, statusMaxW, [
                    Graphics.FONT_MEDIUM,
                    Graphics.FONT_SMALL,
                    Graphics.FONT_TINY,
                    Graphics.FONT_XTINY
                ] as Array<Graphics.FontDefinition>);
                var countFont = Graphics.FONT_XTINY;
                var pauseH = dc.getFontHeight(pauseFont);
                var countH = dc.getFontHeight(countFont);
                var gap = 2;
                var blockH = pauseH + gap + countH;
                var blockTop = bandTop + (midHeight - blockH) / 2;
                if (blockTop < bandTop) {
                    blockTop = bandTop;
                }
                dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
                dc.drawText(width / 2, blockTop, pauseFont, mainValue, Graphics.TEXT_JUSTIFY_CENTER);
                if (offline) {
                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(
                        width / 2,
                        blockTop + pauseH + gap,
                        countFont,
                        statusText(Rez.Strings.OfflineMode),
                        Graphics.TEXT_JUSTIFY_CENTER
                    );
                } else if (needsOnlineFitRestart()) {
                    var restartHint = fitLineToWidth(
                        dc,
                        statusText(Rez.Strings.RestartActivityCompact),
                        countFont,
                        statusMaxW
                    );
                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(
                        width / 2,
                        blockTop + pauseH + gap,
                        countFont,
                        restartHint,
                        Graphics.TEXT_JUSTIFY_CENTER
                    );
                } else {
                    dc.setColor(countColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(
                        width / 2,
                        blockTop + pauseH + gap,
                        countFont,
                        txOk.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER
                    );
                }
            } else {
                if (isPreActivity() && value.equals(statusText(Rez.Strings.Start)) && consumeVersionOnStart()) {
                    var startFont = pickFittingFont(dc, value, statusMaxW, [
                        Graphics.FONT_MEDIUM,
                        Graphics.FONT_SMALL,
                        Graphics.FONT_TINY
                    ] as Array<Graphics.FontDefinition>);
                    var verFont = Graphics.FONT_XTINY;
                    var startH = dc.getFontHeight(startFont);
                    var gap2 = 2;
                    var blockH2 = startH + gap2 + dc.getFontHeight(verFont);
                    var blockTop2 = bandTop + (midHeight - blockH2) / 2;
                    if (blockTop2 < bandTop) {
                        blockTop2 = bandTop;
                    }
                    dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(width / 2, blockTop2, startFont, value, Graphics.TEXT_JUSTIFY_CENTER);
                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(
                        width / 2,
                        blockTop2 + startH + gap2,
                        verFont,
                        statusText(Rez.Strings.Version),
                        Graphics.TEXT_JUSTIFY_CENTER
                    );
                } else {
                    var valueY = bandTop + midHeight / 2;
                    var valueColor = fg;
                    var drawValue = value;
                    if (showOfflineActive) {
                        valueColor = Graphics.COLOR_LT_GRAY;
                        drawValue = statusText(Rez.Strings.OfflineMode);
                    } else if (looksLikeNumber(value)) {
                        valueColor = countColor;
                    }
                    font = statusFont(dc, width, midHeight, drawValue, spacious, round, statusMaxW);
                    drawValue = fitLineToWidth(dc, drawValue, font, statusMaxW);
                    dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(width / 2, valueY, font, drawValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        } catch (ex) {
        }
    }

    hidden function drawUpdateSplash(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        round as Boolean
    ) as Void {
        dc.setColor(UPDATE_IDLE_FG, UPDATE_IDLE_BG);
        dc.clear();
        dc.setColor(UPDATE_IDLE_BG, UPDATE_IDLE_BG);
        dc.fillRectangle(0, 0, width, height);
        var msg = statusText(Rez.Strings.UpdateField);
        var pad = layoutPad(width, height, round, false);
        var maxW = lineMaxWidth(width, height, height / 2, pad, round);
        var font = pickFittingFont(dc, msg, maxW, [
            Graphics.FONT_LARGE,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
            Graphics.FONT_TINY
        ] as Array<Graphics.FontDefinition>);
        msg = fitLineToWidth(dc, msg, font, maxW);
        dc.setColor(UPDATE_IDLE_FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 2, font, msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Pending flag in Storage stays until installed version >= stored remote.
    hidden function reconcileUpdateFlag() as Void {
        var local = statusText(Rez.Strings.Version);
        var remote = "";
        try {
            var stored = Application.Storage.getValue(VERSION_STORAGE_KEY);
            if (stored instanceof String) {
                remote = stored as String;
            }
        } catch (ex) {
        }

        if (remote.length() > 0 && isNewerVersion(remote, local)) {
            updateAvailable = true;
            setUpdatePending(true);
            return;
        }

        // Updated (or no remote yet): clear pending and allow polls again.
        if (updateAvailable || isUpdatePending()) {
            clearUpdatePending();
        }
        updateAvailable = false;
    }

    hidden function maybeCheckForUpdate() as Void {
        // Caller must ensure pre-activity; double-guard against mid-ride network noise.
        if (timerOn || timerPaused || versionCheckBusy || busy) {
            return;
        }
        // While a pending update is already known, keep the flag — no need to poll again.
        if (updateAvailable) {
            return;
        }
        var now = Time.now().value();
        try {
            var last = Application.Storage.getValue(VERSION_CHECKED_KEY);
            if (last instanceof Number) {
                if ((now - (last as Number)) < VERSION_CHECK_INTERVAL_SEC) {
                    return;
                }
            }
        } catch (ex) {
        }
        versionCheckBusy = true;
        try {
            Application.Storage.setValue(VERSION_CHECKED_KEY, now);
        } catch (ex2) {
        }
        try {
            Communications.makeWebRequest(
                VERSION_URL,
                null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:onVersionReceive)
            );
        } catch (ex3) {
            versionCheckBusy = false;
        }
    }

    function onVersionReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        versionCheckBusy = false;
        try {
            if (responseCode != 200) {
                return;
            }
            var remote = "";
            if (data instanceof Dictionary) {
                remote = asVersionText((data as Dictionary).get("version"));
            } else if (data instanceof String) {
                remote = asVersionText(data);
            }
            if (remote.length() == 0) {
                return;
            }
            try {
                Application.Storage.setValue(VERSION_STORAGE_KEY, remote);
            } catch (ex) {
            }
            reconcileUpdateFlag();
            WatchUi.requestUpdate();
        } catch (ex2) {
        }
    }

    hidden function isUpdatePending() as Boolean {
        try {
            var flag = Application.Storage.getValue(VERSION_PENDING_KEY);
            if (flag instanceof Boolean) {
                return flag as Boolean;
            }
            if (flag instanceof Number) {
                return (flag as Number) != 0;
            }
        } catch (ex) {
        }
        return false;
    }

    hidden function setUpdatePending(pending as Boolean) as Void {
        try {
            Application.Storage.setValue(VERSION_PENDING_KEY, pending);
        } catch (ex) {
        }
    }

    hidden function clearUpdatePending() as Void {
        try {
            Application.Storage.setValue(VERSION_PENDING_KEY, false);
        } catch (ex) {
        }
        try {
            Application.Storage.deleteValue(VERSION_PENDING_KEY);
        } catch (ex2) {
        }
    }

    hidden function isNewerVersion(remote as String, local as String) as Boolean {
        var ri = 0;
        var li = 0;
        var part = 0;
        while (part < 4) {
            var rn = 0;
            var ln = 0;
            var rDig = false;
            var lDig = false;
            while (ri < remote.length()) {
                var rc = remote.substring(ri, ri + 1);
                if (rc == null || (rc as String).equals(".")) {
                    if (rc != null) {
                        ri += 1;
                    }
                    break;
                }
                var rd = (rc as String).toNumber();
                if (rd == null) {
                    ri += 1;
                    break;
                }
                rn = rn * 10 + (rd as Number);
                rDig = true;
                ri += 1;
            }
            while (li < local.length()) {
                var lc = local.substring(li, li + 1);
                if (lc == null || (lc as String).equals(".")) {
                    if (lc != null) {
                        li += 1;
                    }
                    break;
                }
                var ld = (lc as String).toNumber();
                if (ld == null) {
                    li += 1;
                    break;
                }
                ln = ln * 10 + (ld as Number);
                lDig = true;
                li += 1;
            }
            if (!rDig && !lDig) {
                return false;
            }
            if (rn > ln) {
                return true;
            }
            if (rn < ln) {
                return false;
            }
            part += 1;
        }
        return false;
    }

    hidden function asVersionText(value as Object?) as String {
        if (value instanceof String) {
            return value as String;
        }
        if (value instanceof Number) {
            return (value as Number).toString();
        }
        if (value instanceof Float) {
            return (value as Float).format("%.2f");
        }
        return "";
    }

    hidden function ensureFitFields() as Void {
        if (fitReady) {
            return;
        }

        fitTried = true;

        // Re-adding the data field mid-activity creates a new instance that would
        // call createField with the same IDs again — uncatchable fatal (IQ icon).
        if (fitFieldsAlreadyCreatedForSession()) {
            fitSkippedReadd = true;
            return;
        }

        // Mark before createField so a partial/fatal first attempt still blocks re-add.
        markFitSessionCreated();

        // Data-field RECORD FitContributor budget ≈ 32 bytes.
        // Online-only: tx fail + viewers (no network /osmo in offline).
        var onlineFit = EsyaTrackerAuth.isOnlineMode();
        markFitOnlineCreated(onlineFit);
        try {
            if (onlineFit && hasToken()) {
                txFailRecord = createFitField(
                    "esya_tx_fail",
                    TX_FAIL_RECORD_ID,
                    FitContributor.DATA_TYPE_FLOAT,
                    "n"
                );
            }
            pressureField = createFitField(
                "esya_ambient_pressure",
                PRESSURE_FIELD_ID,
                FitContributor.DATA_TYPE_FLOAT,
                "hPa"
            );
            batteryField = createFitField(
                "esya_device_battery",
                BATTERY_FIELD_ID,
                FitContributor.DATA_TYPE_UINT8,
                "%"
            );
            gpsField = createFitField(
                "esya_gps_quality",
                GPS_FIELD_ID,
                FitContributor.DATA_TYPE_UINT8,
                "0-4"
            );
            if (onlineFit) {
                viewersField = createFitField(
                    "esya_viewers",
                    VIEWERS_FIELD_ID,
                    FitContributor.DATA_TYPE_UINT16,
                    "n"
                );
            }
            tempField = createFitField(
                "esya_temp_c",
                TEMP_FIELD_ID,
                FitContributor.DATA_TYPE_FLOAT,
                "C"
            );
            weatherTempDeltaField = createFitField(
                "esya_weather_temp_delta_c",
                WEATHER_TEMP_DELTA_FIELD_ID,
                FitContributor.DATA_TYPE_FLOAT,
                "C"
            );
            windTypeField = createFitField(
                "esya_wind_type",
                WIND_TYPE_FIELD_ID,
                FitContributor.DATA_TYPE_SINT8,
                "code"
            );
            windSpeedField = createFitField(
                "esya_wind_speed",
                WIND_SPEED_FIELD_ID,
                FitContributor.DATA_TYPE_FLOAT,
                "m/s"
            );
            if (txFailRecord != null) {
                setFit(txFailRecord, 0);
            }
            setFitNum(batteryField, 0);
            setFitNum(gpsField, 0);
            if (viewersField != null) {
                setFitNum(viewersField, 0);
            }
            setFitNum(windTypeField, 0);
            setFitFloat(pressureField, 0.0);
            setFitFloat(windSpeedField, 0.0);
        } catch (ex) {
        }
        fitReady = tempField != null && pressureField != null;
    }

    hidden function createFitField(
        name as String,
        fieldId as Number,
        dataType as FitContributor.DataType,
        units as String
    ) as FitContributor.Field? {
        try {
            return createField(
                name,
                fieldId,
                dataType,
                {
                    :mesgType => FitContributor.MESG_TYPE_RECORD,
                    :units => units
                }
            );
        } catch (ex) {
        }
        return null;
    }

    hidden function currentFitSessionId() as Number {
        try {
            var info = Activity.getActivityInfo();
            if (info != null && info has :startTime && info.startTime != null) {
                return (info.startTime as Time.Moment).value();
            }
        } catch (ex) {
        }
        return 0;
    }

    hidden function readActivityStartTime(info as Activity.Info) as Number? {
        try {
            if (info has :startTime && info.startTime != null) {
                return (info.startTime as Time.Moment).value();
            }
        } catch (ex) {
        }
        return null;
    }

    // Edge/FR keep the same DataField across Save→next ride; reset counters/FIT hooks.
    // Do not hook onTimerStart alone — Stop→Start mid-ride would wipe the counter.
    hidden function reconcileActivitySession(info as Activity.Info) as Void {
        var start = readActivityStartTime(info);
        if (start == null) {
            if (lastSeenStartTime != null) {
                resetActivitySessionState();
                lastSeenStartTime = null;
            }
            return;
        }
        if (lastSeenStartTime != null && (lastSeenStartTime as Number) != start) {
            resetActivitySessionState();
        }
        lastSeenStartTime = start;
    }

    hidden function resetActivitySessionState() as Void {
        txOk = 0;
        txFail = 0;
        forbidden403Count = 0;
        lastCode = 0;
        busy = false;
        pending = null;
        lastOkAt = null;
        lastPauseSendAt = null;
        lastElapsedDistance = null;
        lastElapsedAt = null;
        derivedSpeed = null;
        viewersCount = null;
        cacheViewersCount = 0;
        viewersText = "";
        resetGpsBadTimer();
        clearFitSessionMark();
        fitReady = false;
        fitTried = false;
        fitSkippedReadd = false;
        txFailRecord = null;
        pressureField = null;
        batteryField = null;
        gpsField = null;
        viewersField = null;
        tempField = null;
        weatherTempDeltaField = null;
        windTypeField = null;
        windSpeedField = null;
    }

    hidden function fitFieldsAlreadyCreatedForSession() as Boolean {
        var session = currentFitSessionId();
        if (session == 0) {
            return false;
        }
        try {
            var prev = Application.Storage.getValue(FIT_SESSION_KEY);
            if (prev instanceof Number && (prev as Number) == session) {
                return true;
            }
        } catch (ex) {
        }
        return false;
    }

    hidden function markFitSessionCreated() as Void {
        var session = currentFitSessionId();
        if (session == 0) {
            return;
        }
        try {
            Application.Storage.setValue(FIT_SESSION_KEY, session);
        } catch (ex) {
        }
    }

    hidden function markFitOnlineCreated(onlineFit as Boolean) as Void {
        try {
            Application.Storage.setValue(FIT_ONLINE_KEY, onlineFit);
        } catch (ex) {
        }
    }

    // Online toggled on after FIT fields were created offline — viewers/tx_fail missing.
    hidden function needsOnlineFitRestart() as Boolean {
        if (!EsyaTrackerAuth.isOnlineMode()) {
            return false;
        }
        if (!timerOn && !timerPaused) {
            return false;
        }
        if (!fitTried) {
            return false;
        }
        try {
            var value = Application.Storage.getValue(FIT_ONLINE_KEY);
            if (value instanceof Boolean) {
                return !(value as Boolean);
            }
        } catch (ex) {
        }
        return false;
    }

    hidden function clearFitSessionMark() as Void {
        try {
            Application.Storage.deleteValue(FIT_SESSION_KEY);
        } catch (ex) {
        }
        try {
            Application.Storage.deleteValue(FIT_ONLINE_KEY);
        } catch (ex) {
        }
    }

    hidden function writeFit() as Void {
        if (txFailRecord != null && EsyaTrackerAuth.isOnlineMode() && hasToken()) {
            setFit(txFailRecord, txFail);
        }
        if (viewersField != null && viewersCount != null) {
            setFitNum(viewersField, viewersCount);
        }
    }

    hidden function setFit(field as FitContributor.Field?, value as Number) as Void {
        setFitFloat(field, value.toFloat());
    }

    hidden function setFitNum(field as FitContributor.Field?, value as Number) as Void {
        if (field != null) {
            field.setData(value);
        }
    }

    hidden function setFitFloat(field as FitContributor.Field?, value as Float) as Void {
        if (field != null) {
            field.setData(value);
        }
    }

    hidden function updateSensorState(info as Activity.Info) as Void {
        cacheTemp = null;
        cacheHasWxDelta = false;
        cacheWxDelta = 0.0;
        cachePres = null;
        cacheAlt = null;
        cacheSpeed = null;
        cacheWindTypeUi = WIND_TYPE_NONE;
        cacheWindSpeedMps = null;
        cacheWindCalm = false;
        cacheWindDirLabel = "";
        cacheWindDirCompact = "";
        cacheGpsQuality = null;

        var temp = null as Float?;
        if (recordTemperature()) {
            temp = readTemperature(info);
        }
        if (temp != null) {
            cacheTemp = temp;
            setFitFloat(tempField, temp);
        }
        var wxTemp = readWeatherTemperature();
        if (temp != null && wxTemp != null) {
            var delta = temp - wxTemp;
            cacheHasWxDelta = true;
            cacheWxDelta = delta;
            // T_weather = esya_temp_c - esya_weather_temp_delta_c
            setFitFloat(weatherTempDeltaField, delta);
        }

        var pres = readPressureHpa(info);
        if (pres != null) {
            cachePres = pres;
            setFitFloat(pressureField, pres);
        }
        cacheAlt = readAltitude(info);

        var speed = readSpeed(info);
        if (timerOn && speed != null) {
            cacheSpeed = speed;
        }
        formatWindLabel(info);

        try {
            var stats = System.getSystemStats();
            if (stats != null) {
                setFitNum(batteryField, Math.round(stats.battery).toNumber());
            }
        } catch (ex) {
        }

        var gps = readGpsQuality(info);
        if (gps != null) {
            cacheGpsQuality = gps;
            setFitNum(gpsField, gps);
        }
        tickGpsBadTimer();
    }

    hidden function readGpsQuality(info as Activity.Info) as Number? {
        try {
            if (info has :currentLocationAccuracy && info.currentLocationAccuracy != null) {
                if (info.currentLocationAccuracy instanceof Number) {
                    return info.currentLocationAccuracy as Number;
                }
            }
        } catch (ex) {
        }
        try {
            var live = Activity.getActivityInfo();
            if (live != null && live has :currentLocationAccuracy && live.currentLocationAccuracy != null) {
                if (live.currentLocationAccuracy instanceof Number) {
                    return live.currentLocationAccuracy as Number;
                }
            }
        } catch (ex) {
        }
        return null;
    }

    hidden function buildPoint(info as Activity.Info) as Dictionary? {
        var location = readLocation(info);
        if (location == null) {
            return null;
        }

        var degrees = location.toDegrees();
        if (degrees == null || degrees.size() < 2) {
            return null;
        }

        var lat = toRequestFloat(degrees[0]);
        var lon = toRequestFloat(degrees[1]);
        if (lat == null || lon == null) {
            return null;
        }

        var body = {
            "lat" => lat,
            "lon" => lon,
            "tst" => Time.now().value().toString()
        } as Dictionary;

        if (recordTemperature()) {
            var temp = readTemperature(info);
            if (temp != null) {
                body.put("temp", temp.format("%.1f"));
            }
        }

        var pres = readPressureHpa(info);
        if (pres != null) {
            body.put("pres", pres.format("%.1f"));
        }

        var acc = readAccuracyMeters(info);
        if (acc != null) {
            body.put("acc", acc.toString());
        }

        var alt = readAltitude(info);
        if (alt != null) {
            body.put("alt", Math.round(alt).toNumber().toString());
        }

        var speed = readSpeed(info);
        if (speed != null) {
            body.put("vel", speed.format("%.2f"));
        }

        var headingRaw = readNumberField(info, :currentHeading);
        if (headingRaw == null && lastGps() != null) {
            headingRaw = toRequestFloat(lastGps().heading);
        }
        if (headingRaw != null) {
            var heading = headingRaw * 180.0 / Math.PI;
            if (heading < 0) {
                heading += 360.0;
            }
            body.put("bear", Math.round(heading).toNumber().toString());
        }

        try {
            var stats = System.getSystemStats();
            if (stats != null) {
                body.put("batt", Math.round(stats.battery).toNumber().toString());
                if (stats has :charging && stats.charging) {
                    body.put("bs", "2");
                }
            }
        } catch (ex) {
        }

        return body;
    }

    hidden function readLocation(info as Activity.Info) as Position.Location? {
        if (!hasLiveFix(info)) {
            return null;
        }

        if (info.currentLocation != null) {
            return info.currentLocation;
        }

        try {
            var live = Activity.getActivityInfo();
            if (live != null && live.currentLocation != null) {
                return live.currentLocation;
            }
        } catch (ex) {
        }

        var gps = lastGps();
        if (gps != null && gps.position != null) {
            return gps.position;
        }

        return null;
    }

    hidden function hasLiveFix(info as Activity.Info) as Boolean {
        if (info has :currentLocationAccuracy && info.currentLocationAccuracy != null) {
            return info.currentLocationAccuracy >= Position.QUALITY_POOR;
        }

        var gps = lastGps();
        if (gps != null && gps.accuracy != null) {
            return gps.accuracy >= Position.QUALITY_POOR;
        }

        return false;
    }

    hidden function readAccuracyMeters(info as Activity.Info) as Number? {
        var quality = null as Number?;
        try {
            if (info has :currentLocationAccuracy && info.currentLocationAccuracy != null) {
                quality = info.currentLocationAccuracy;
            }
        } catch (ex) {
        }
        if (quality == null) {
            try {
                var live = Activity.getActivityInfo();
                if (live != null && live has :currentLocationAccuracy && live.currentLocationAccuracy != null) {
                    quality = live.currentLocationAccuracy;
                }
            } catch (ex) {
            }
        }
        if (quality == null) {
            var gps = lastGps();
            if (gps != null && gps.accuracy != null) {
                quality = gps.accuracy;
            }
        }
        if (quality == null) {
            return null;
        }
        if (quality >= Position.QUALITY_GOOD) {
            return 5;
        }
        if (quality >= Position.QUALITY_USABLE) {
            return 15;
        }
        if (quality >= Position.QUALITY_POOR) {
            return 30;
        }
        if (quality >= Position.QUALITY_LAST_KNOWN) {
            return 50;
        }
        return null;
    }

    hidden function lastGps() as Position.Info? {
        try {
            return Position.getInfo();
        } catch (ex) {
            return null;
        }
    }

    hidden function readSpeed(info as Activity.Info) as Float? {
        var activitySpeed = sanitizeSpeed(readNumberField(info, :currentSpeed));
        var liveSpeed = null as Float?;
        try {
            var live = Activity.getActivityInfo();
            if (live != null) {
                liveSpeed = sanitizeSpeed(toRequestFloat(live.currentSpeed));
            }
        } catch (ex) {
        }

        var gpsSpeed = null as Float?;
        var gps = lastGps();
        if (gps != null) {
            gpsSpeed = sanitizeSpeed(toRequestFloat(gps.speed));
        }

        var best = maxSpeed(maxSpeed(activitySpeed, liveSpeed), gpsSpeed);
        if (isMovingSpeed(best)) {
            return best;
        }
        var derived = sanitizeSpeed(derivedSpeed);
        if (isMovingSpeed(derived)) {
            return derived;
        }
        if (best != null) {
            return best;
        }
        return derived;
    }

    hidden function sanitizeSpeed(speed as Float?) as Float? {
        if (speed == null) {
            return null;
        }
        if (speed < 0.0 || speed > MAX_SPEED_MPS) {
            return null;
        }
        return speed;
    }

    hidden function sampleElapsedSpeed(info as Activity.Info) as Void {
        var dist = readNumberField(info, :elapsedDistance);
        var now = Time.now().value();
        if (dist == null) {
            derivedSpeed = null;
            return;
        }

        var prevDist = lastElapsedDistance;
        var prevAt = lastElapsedAt;
        lastElapsedDistance = dist;
        lastElapsedAt = now;

        if (prevDist == null || prevAt == null) {
            derivedSpeed = null;
            return;
        }

        var dt = now - prevAt;
        var dd = dist - prevDist;
        if (dt <= 0 || dd < 0) {
            derivedSpeed = null;
            return;
        }

        derivedSpeed = sanitizeSpeed(dd / dt.toFloat());
    }

    hidden function maxSpeed(a as Float?, b as Float?) as Float? {
        if (a == null) {
            return b;
        }
        if (b == null) {
            return a;
        }
        return a > b ? a : b;
    }

    hidden function isMovingSpeed(speed as Float?) as Boolean {
        return speed != null && speed > 0.3;
    }

    // 10 Oct path: Storage, then Activity.Info, then Activity.getActivityInfo().
    // Do not call Sensor.getInfo() here — that fatals Edge data fields.
    hidden function readTemperature(info as Activity.Info) as Float? {
        var temp = readStoredTemperature();
        if (temp == null) {
            temp = readNumberField(info, :temperature);
        }
        if (temp == null) {
            temp = readLiveNumberField(:temperature);
        }
        if (temp == null || temp < -40.0 || temp > 80.0) {
            return null;
        }
        return temp;
    }

    hidden function readStoredTemperature() as Float? {
        try {
            var value = toRequestFloat(Application.Storage.getValue("esya_temp_c"));
            if (value == null) {
                return null;
            }
            if (value <= -998.0 || value < -40.0 || value > 80.0) {
                return null;
            }
            return value;
        } catch (ex) {
        }
        return null;
    }

    hidden function formatSignedDelta(deltaC as Float) as String {
        var delta = useNauticalUnits() ? (deltaC * 9.0 / 5.0) : deltaC;
        if (delta >= 0.0) {
            return "+" + delta.format("%.1f");
        }
        return delta.format("%.1f");
    }

    hidden function readWeatherTemperature() as Float? {
        try {
            if (!(Toybox has :Weather)) {
                return null;
            }
            var cc = Toybox.Weather.getCurrentConditions();
            if (cc != null && cc has :temperature && cc.temperature != null) {
                var wx = toRequestFloat(cc.temperature);
                if (wx != null && wx >= -80.0 && wx <= 60.0) {
                    return wx;
                }
            }
        } catch (ex) {
        }
        return null;
    }

    hidden function readHeadingDegrees(info as Activity.Info) as Float? {
        var headingRaw = readNumberField(info, :currentHeading);
        if (headingRaw == null) {
            var gps = lastGps();
            if (gps != null) {
                headingRaw = toRequestFloat(gps.heading);
            }
        }
        if (headingRaw == null) {
            return null;
        }
        return normalizeDegrees(headingRaw * 180.0 / Math.PI);
    }

    hidden function normalizeDegrees(value as Float) as Float {
        var deg = Math.round(value).toNumber() % 360;
        if (deg < 0) {
            deg += 360;
        }
        return deg.toFloat();
    }

    hidden function shortestAngleDiff(a as Float, b as Float) as Float {
        var diff = (Math.round(a).toNumber() - Math.round(b).toNumber()) % 360;
        if (diff < 0) {
            diff += 360;
        }
        if (diff > 180) {
            diff = 360 - diff;
        }
        return diff.toFloat();
    }

    hidden function classifyWind(headingDeg as Float, windFromDeg as Float) as Number {
        var diff = shortestAngleDiff(headingDeg, windFromDeg);
        if (diff <= WIND_ALIGN_DEG) {
            return WIND_TYPE_HEAD;
        }
        if (diff <= WIND_QUARTER_DEG) {
            return WIND_TYPE_QUARTER_HEAD;
        }
        if (diff >= (180 - WIND_ALIGN_DEG)) {
            return WIND_TYPE_TAIL;
        }
        if (diff >= (180 - WIND_QUARTER_DEG)) {
            return WIND_TYPE_QUARTER_TAIL;
        }
        return WIND_TYPE_CROSS;
    }

    hidden function windTypeShortLabel(windType as Number) as String {
        if (windType == WIND_TYPE_HEAD) {
            return statusText(Rez.Strings.WindHeadShort);
        }
        if (windType == WIND_TYPE_TAIL) {
            return statusText(Rez.Strings.WindTailShort);
        }
        if (windType == WIND_TYPE_CROSS) {
            return statusText(Rez.Strings.WindCrossShort);
        }
        if (windType == WIND_TYPE_QUARTER_HEAD) {
            return statusText(Rez.Strings.WindQuarterHeadShort);
        }
        if (windType == WIND_TYPE_QUARTER_TAIL) {
            return statusText(Rez.Strings.WindQuarterTailShort);
        }
        return "";
    }

    hidden function formatWindLabel(info as Activity.Info) as String? {
        var windSpeed = null as Float?;
        var windFrom = null as Float?;

        try {
            if (Toybox has :Weather) {
                var cc = Toybox.Weather.getCurrentConditions();
                if (cc != null) {
                    if (cc has :windSpeed && cc.windSpeed != null) {
                        var speed = toRequestFloat(cc.windSpeed);
                        if (speed != null && speed >= 0.0 && speed <= 80.0) {
                            windSpeed = speed;
                        }
                    }
                    if (cc has :windBearing && cc.windBearing != null) {
                        var bearing = toRequestFloat(cc.windBearing);
                        if (bearing != null) {
                            windFrom = normalizeDegrees(bearing);
                        }
                    }
                }
            }
        } catch (ex) {
        }

        var windType = WIND_TYPE_NONE;
        var heading = readHeadingDegrees(info);
        var moveSpeed = readSpeed(info);
        var slowMove = moveSpeed == null || moveSpeed < WIND_CARDINAL_MAX_SPEED_MPS;
        var useCardinal = isPreActivity() || heading == null || slowMove;
        var calm = windSpeed != null && windSpeed < WIND_CALM_MAX_MPS;

        if (calm) {
            cacheWindDirLabel = "";
            cacheWindDirCompact = "";
        } else if (useCardinal && windFrom != null) {
            cacheWindDirLabel = windDirectionCompact(windFrom);
            cacheWindDirCompact = cacheWindDirLabel;
        } else if (heading != null && windFrom != null) {
            windType = classifyWind(heading, windFrom);
            if (windTypeField != null) {
                setFitNum(windTypeField, windType);
            }
            cacheWindDirLabel = windTypeShortLabel(windType);
            cacheWindDirCompact = cacheWindDirLabel;
        }

        if (windSpeed != null && windSpeedField != null) {
            setFitFloat(windSpeedField, windSpeed);
        }

        cacheWindTypeUi = windType;
        cacheWindSpeedMps = windSpeed;
        cacheWindCalm = calm;

        if (windSpeed == null) {
            return null;
        }
        if (calm) {
            return statusText(Rez.Strings.WindCalm);
        }
        var windSpeedText = formatSpeedNumber(windSpeed);
        if (cacheWindDirLabel.length() > 0) {
            return cacheWindDirLabel + " " + windSpeedText;
        }
        return windSpeedText;
    }

    hidden function isPreActivity() as Boolean {
        return !timerOn && !timerPaused;
    }

    hidden function consumeVersionOnStart() as Boolean {
        try {
            var app = Application.getApp() as EsyaTrackerApp;
            return app.consumeVersionOnStart();
        } catch (ex) {
        }
        return false;
    }

    hidden function windDirectionIndex(degrees as Float) as Number {
        var deg = normalizeDegrees(degrees);
        var idx = Math.floor((deg + 22.5) / 45.0).toNumber() % 8;
        if (idx < 0) {
            idx += 8;
        }
        return idx;
    }

    hidden function windDirectionCompact(degrees as Float) as String {
        var idx = windDirectionIndex(degrees);
        if (idx == 0) {
            return statusText(Rez.Strings.WindDirCompactN);
        }
        if (idx == 1) {
            return statusText(Rez.Strings.WindDirCompactNE);
        }
        if (idx == 2) {
            return statusText(Rez.Strings.WindDirCompactE);
        }
        if (idx == 3) {
            return statusText(Rez.Strings.WindDirCompactSE);
        }
        if (idx == 4) {
            return statusText(Rez.Strings.WindDirCompactS);
        }
        if (idx == 5) {
            return statusText(Rez.Strings.WindDirCompactSW);
        }
        if (idx == 6) {
            return statusText(Rez.Strings.WindDirCompactW);
        }
        return statusText(Rez.Strings.WindDirCompactNW);
    }

    hidden function rebuildSensorDisplay(
        round as Boolean,
        spacious as Boolean,
        compact as Boolean,
        micro as Boolean
    ) as Void {
        sensorTop2 = "";
        sensorBot2 = "";
        windText = "";
        viewersText = formatViewersLabel();

        if (round || compact) {
            if (cacheTemp != null) {
                tempText = formatTemperature(cacheTemp, true);
                if (cacheHasWxDelta && !micro) {
                    tempText = tempText + " " + formatSignedDelta(cacheWxDelta);
                }
            } else {
                tempText = missingTempText(true);
            }

            if (cachePres != null) {
                var pres = formatPressure(cachePres, true);
                if (cacheAlt != null && !micro) {
                    pres = pres + " (" + formatAltitude(cacheAlt, true) + ")";
                }
                if (micro) {
                    // One top line: temp (if Tempe) + pressure.
                    if (tempText.length() > 0) {
                        tempText = tempText + " " + pres;
                    } else {
                        tempText = pres;
                    }
                    sensorTop2 = "";
                } else {
                    sensorTop2 = pres;
                }
            } else if (!micro) {
                sensorTop2 = "--";
            }
            presText = "";

            if (cacheSpeed != null) {
                speedText = formatSpeed(cacheSpeed, true);
            } else {
                speedText = "--";
            }

            if (micro) {
                // Keep wind on the speed line (short).
                var w = buildWindText(true);
                if (w.length() > 0) {
                    speedText = speedText + " " + w;
                }
                windText = "";
                sensorBot2 = "";
            } else {
                windText = buildWindText(true);
                if (cacheViewersCount > 0) {
                    sensorBot2 = formatViewersLabel();
                }
            }
            return;
        }

        if (cacheTemp != null) {
            tempText = formatTemperature(cacheTemp, false);
            if (cacheHasWxDelta) {
                if (spacious) {
                    tempText = tempText + " (" + formatSignedDelta(cacheWxDelta) + "°)";
                } else {
                    tempText = tempText + " (" + formatSignedDelta(cacheWxDelta) + "° "
                        + statusText(Rez.Strings.WeatherDeltaSuffix) + ")";
                }
            }
        } else {
            tempText = missingTempText(false);
        }

        if (cachePres != null) {
            presText = formatPressure(cachePres, false);
            if (cacheAlt != null) {
                presText = presText + " (" + formatAltitude(cacheAlt, spacious) + ")";
            }
        } else {
            presText = useNauticalUnits() ? "-- hPa" : "-- mmHg";
        }

        if (cacheSpeed != null) {
            speedText = formatSpeed(cacheSpeed, false);
        } else {
            speedText = "-- " + speedUnitLabel(false);
        }
        windText = buildWindText(false);
    }

    hidden function countSensorTopLines(micro as Boolean) as Number {
        if (micro) {
            return (tempText.length() > 0) ? 1 : 0;
        }
        var n = 0;
        if (tempText.length() > 0) {
            n += 1;
        }
        if (sensorTop2.length() > 0) {
            n += 1;
        }
        return n;
    }

    hidden function countSensorBotLines(micro as Boolean, offline as Boolean) as Number {
        if (micro) {
            return (speedText.length() > 0) ? 1 : 0;
        }
        var n = 0;
        if (speedText.length() > 0) {
            n += 1;
        }
        if (!offline && windText.length() > 0) {
            n += 1;
        }
        if (!offline && sensorBot2.length() > 0) {
            n += 1;
        }
        return n;
    }

    hidden function buildWindText(tight as Boolean) as String {
        if (cacheWindCalm) {
            return statusText(Rez.Strings.WindCalm);
        }
        if (cacheWindSpeedMps == null) {
            return "";
        }
        var windSpeedPart = formatSpeedNumber(cacheWindSpeedMps);
        if (tight) {
            if (cacheWindDirCompact.length() > 0) {
                return cacheWindDirCompact + windSpeedPart;
            }
            if (cacheWindDirLabel.length() > 0) {
                return cacheWindDirLabel + " " + windSpeedPart;
            }
            return "W" + windSpeedPart;
        }
        if (cacheWindDirLabel.length() > 0) {
            return cacheWindDirLabel + " " + windSpeedPart;
        }
        return windSpeedPart;
    }

    hidden function windLabelColor(theme as Number) as Number {
        if (cacheWindCalm) {
            return Graphics.COLOR_LT_GRAY;
        }
        if (cacheWindTypeUi == WIND_TYPE_TAIL) {
            return Graphics.COLOR_GREEN;
        }
        if (cacheWindTypeUi == WIND_TYPE_QUARTER_TAIL) {
            return Graphics.COLOR_YELLOW;
        }
        if (cacheWindTypeUi == WIND_TYPE_QUARTER_HEAD) {
            return WIND_COLOR_PINK;
        }
        if (cacheWindTypeUi == WIND_TYPE_HEAD) {
            return Graphics.COLOR_RED;
        }
        if (cacheWindTypeUi == WIND_TYPE_CROSS) {
            return Graphics.COLOR_ORANGE;
        }
        return sensorColor(theme);
    }

    hidden function drawSpeedWithWind(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        font as Graphics.FontDefinition,
        theme as Number,
        speedColor as Number
    ) as Void {
        dc.setColor(speedColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, speedText, Graphics.TEXT_JUSTIFY_LEFT);
        if (windText.length() == 0) {
            return;
        }
        var gap = dc.getTextWidthInPixels(speedText + " ", font);
        dc.setColor(windLabelColor(theme), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + gap, y, font, "(" + windText + ")", Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Tap / Select on the data field (Edge and touch-capable watches).
    function toggleDisplayUnits() as Void {
        try {
            var next = useNauticalUnits() ? UNITS_METRIC : UNITS_NAUTICAL;
            Application.Properties.setValue("displayUnits", next);
        } catch (ex) {
        }
        try {
            WatchUi.requestUpdate();
        } catch (ex2) {
        }
    }

    hidden function useNauticalUnits() as Boolean {
        try {
            var value = Application.Properties.getValue("displayUnits");
            if (value instanceof Number) {
                return (value as Number) == UNITS_NAUTICAL;
            }
        } catch (ex) {
        }
        return false;
    }

    hidden function recordTemperature() as Boolean {
        try {
            var value = Application.Properties.getValue("recordTemp");
            if (value instanceof Boolean) {
                return value as Boolean;
            }
        } catch (ex) {
        }
        return true;
    }

    hidden function celsiusToDisplay(tempC as Float) as Float {
        if (useNauticalUnits()) {
            return (tempC * 9.0 / 5.0) + 32.0;
        }
        return tempC;
    }

    hidden function tempUnitSuffix(compact as Boolean) as String {
        if (useNauticalUnits()) {
            return compact ? "°" : "°F";
        }
        return compact ? "°" : "°C";
    }

    hidden function formatTemperature(tempC as Float, compact as Boolean) as String {
        return celsiusToDisplay(tempC).format("%.1f") + tempUnitSuffix(compact);
    }

    hidden function missingTempText(compact as Boolean) as String {
        return "--" + tempUnitSuffix(compact);
    }

    hidden function formatSpeedNumber(mps as Float) as String {
        if (useNauticalUnits()) {
            return (mps * MPS_TO_KN).format("%.1f");
        }
        return mps.format("%.1f");
    }

    hidden function speedUnitLabel(compact as Boolean) as String {
        if (useNauticalUnits()) {
            return "kn";
        }
        return compact ? "m/s" : "m/s";
    }

    hidden function formatSpeed(mps as Float, compact as Boolean) as String {
        var num = formatSpeedNumber(mps);
        var unit = speedUnitLabel(compact);
        if (compact) {
            return num + unit;
        }
        return num + " " + unit;
    }

    hidden function formatAltitude(meters as Float, compact as Boolean) as String {
        if (useNauticalUnits()) {
            var ft = Math.round(meters * M_TO_FT).toNumber();
            if (compact) {
                return ft.toString() + "ft";
            }
            return ft.toString() + " ft";
        }
        var m = Math.round(meters).toNumber();
        if (compact) {
            return m.toString() + "m";
        }
        return m.toString() + " m";
    }

    // Metric → mmHg; nautical/feet → hPa. FIT/osmo stay in hPa.
    hidden function formatPressure(hpa as Float, compact as Boolean) as String {
        if (useNauticalUnits()) {
            var n = Math.round(hpa).toNumber();
            if (compact) {
                return n.toString() + "hPa";
            }
            return n.toString() + " hPa";
        }
        var mm = Math.round(hpa * HPA_TO_MMHG).toNumber();
        if (compact) {
            return mm.toString() + "mm";
        }
        return mm.toString() + " mmHg";
    }

    hidden function formatViewersLabel() as String {
        if (cacheViewersCount <= 0) {
            return "";
        }
        return cacheViewersCount.toString() + statusText(Rez.Strings.ViewersCompactSuffix);
    }

    // 0 = ok, 1 = degraded (quality 3), 2 = poor/none (≤2). Only while recording/paused.
    hidden function gpsWarnLevel() as Number {
        if ((!timerOn && !timerPaused) || cacheGpsQuality == null || cacheGpsQuality >= 4) {
            return 0;
        }
        if (cacheGpsQuality == 3) {
            return 1;
        }
        return 2;
    }

    hidden function gpsStatusLabel(compact as Boolean) as String? {
        var level = gpsWarnLevel();
        if (level == 0 || !timerOn) {
            return null;
        }
        if (cacheGpsQuality == 3) {
            return statusText(Rez.Strings.GpsDegraded);
        }
        if (cacheGpsQuality == 2) {
            return statusText(Rez.Strings.GpsJammed);
        }
        return statusText(Rez.Strings.GpsNoData);
    }

    hidden function drawRoundSensorBands(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        font as Graphics.FontDefinition,
        pad as Number,
        offline as Boolean,
        theme as Number,
        micro as Boolean
    ) as Void {
        var fh = dc.getFontHeight(font);
        var y = pad;
        var justify = Graphics.TEXT_JUSTIFY_CENTER;
        var sensorFg = sensorColor(theme);
        var round = true;
        dc.setColor(sensorFg, Graphics.COLOR_TRANSPARENT);
        if (tempText.length() > 0) {
            var t = fitLineToWidth(dc, tempText, font, lineMaxWidth(width, height, y + fh / 2, pad, round));
            dc.drawText(width / 2, y, font, t, justify);
            y += fh;
        }
        if (!micro && sensorTop2.length() > 0) {
            var p = fitLineToWidth(dc, sensorTop2, font, lineMaxWidth(width, height, y + fh / 2, pad, round));
            dc.drawText(width / 2, y, font, p, justify);
        }

        var yBot = height - pad - fh;
        if (!micro && !offline && sensorBot2.length() > 0) {
            dc.setColor(sensorFg, Graphics.COLOR_TRANSPARENT);
            var v = fitLineToWidth(dc, sensorBot2, font, lineMaxWidth(width, height, yBot + fh / 2, pad, round));
            dc.drawText(width / 2, yBot, font, v, justify);
            yBot -= fh;
        }
        if (!micro && !offline && windText.length() > 0) {
            dc.setColor(windLabelColor(theme), Graphics.COLOR_TRANSPARENT);
            var w = fitLineToWidth(dc, windText, font, lineMaxWidth(width, height, yBot + fh / 2, pad, round));
            dc.drawText(width / 2, yBot, font, w, justify);
            yBot -= fh;
        }
        if (speedText.length() > 0) {
            dc.setColor(sensorFg, Graphics.COLOR_TRANSPARENT);
            var s = fitLineToWidth(dc, speedText, font, lineMaxWidth(width, height, yBot + fh / 2, pad, round));
            dc.drawText(width / 2, yBot, font, s, justify);
        }
    }

    hidden function fitLineToWidth(
        dc as Graphics.Dc,
        text as String,
        font as Graphics.FontDefinition,
        maxW as Number
    ) as String {
        if (maxW < 8 || text.length() == 0) {
            return text;
        }
        if (dc.getTextWidthInPixels(text, font) <= maxW) {
            return text;
        }
        var out = text;
        var dots = "..";
        while (out.length() > 1 && dc.getTextWidthInPixels(out + dots, font) > maxW) {
            out = out.substring(0, out.length() - 1);
            if (out == null) {
                return dots;
            }
        }
        return (out as String) + dots;
    }

    hidden function isRoundDevice() as Boolean {
        try {
            var settings = System.getDeviceSettings();
            if (settings has :screenShape) {
                return settings.screenShape == System.SCREEN_SHAPE_ROUND;
            }
        } catch (ex) {
        }
        return false;
    }

    hidden function isNearlySquareField(width as Number, height as Number) as Boolean {
        var minSide = width < height ? width : height;
        var maxSide = width > height ? width : height;
        return (maxSide - minSide) <= 16;
    }

    hidden function useRoundLayout(width as Number, height as Number) as Boolean {
        if (isRoundDevice()) {
            return true;
        }
        // Square-ish field on unknown/sim devices.
        return isNearlySquareField(width, height) && (width <= 480);
    }

    hidden function isSpaciousLayout(width as Number, height as Number, round as Boolean) as Boolean {
        if (round) {
            return false;
        }
        // Full-screen Edge 1050 (~480x800) and similar large rectangular fields.
        return width >= 360 || height >= 360;
    }

    hidden function layoutPad(width as Number, height as Number, round as Boolean, spacious as Boolean) as Number {
        if (round) {
            // Wider inset: data-field bands near the bezel have a short chord.
            var p = width / 7;
            if (height * 2 < width) {
                p = width / 5;
            }
            if (p < 14) {
                p = 14;
            }
            if (p > 40) {
                p = 40;
            }
            return p;
        }
        if (spacious) {
            var p2 = height / 28;
            if (p2 < 14) {
                p2 = 14;
            }
            if (p2 > 36) {
                p2 = 36;
            }
            return p2;
        }
        return 4;
    }

    hidden function lineMaxWidth(
        width as Number,
        height as Number,
        y as Number,
        pad as Number,
        round as Boolean
    ) as Number {
        if (round) {
            if (isNearlySquareField(width, height)) {
                var chord = safeChordWidth(width, height, y);
                if (chord > 24) {
                    return chord;
                }
            }
            // Horizontal band on a round watch: keep ~62–70% of field width.
            var frac = (height * 2 < width) ? 62 : 70;
            var usable = (width * frac) / 100;
            if (usable > width - (2 * pad)) {
                usable = width - (2 * pad);
            }
            if (usable < 20) {
                usable = 20;
            }
            return usable;
        }
        var maxW = width - (2 * pad);
        if (maxW < 16) {
            maxW = width - 8;
        }
        return maxW;
    }

    hidden function chordWidthAtY(width as Number, height as Number, y as Number) as Number {
        var r = (width < height ? width : height) / 2.0;
        if (r <= 0.0) {
            return width;
        }
        var cy = height / 2.0;
        var dy = y - cy;
        if (dy < 0.0) {
            dy = -dy;
        }
        if (dy >= r) {
            return 0;
        }
        var half = Math.sqrt(r * r - dy * dy);
        return (2.0 * half).toNumber();
    }

    hidden function safeChordWidth(width as Number, height as Number, y as Number) as Number {
        var chord = chordWidthAtY(width, height, y);
        if (chord < 1) {
            chord = (width * 70) / 100;
        }
        // Keep clear of the round bezel / clipped corners.
        var usable = (chord * 72) / 100;
        var inset = width / 6;
        if (usable > width - inset) {
            usable = width - inset;
        }
        if (usable < 16) {
            usable = 16;
        }
        return usable;
    }

    hidden function maxTextWidth(dc as Graphics.Dc, font as Graphics.FontDefinition, lines as Array<String>) as Number {
        var maxW = 0;
        var i = 0;
        while (i < lines.size()) {
            var line = lines[i] as String;
            if (line != null && line.length() > 0) {
                var w = dc.getTextWidthInPixels(line, font);
                if (w > maxW) {
                    maxW = w;
                }
            }
            i += 1;
        }
        return maxW;
    }

    hidden function updateViewers(data as Dictionary or String or Null) as Void {
        var count = extractViewersCount(data);
        if (count == null) {
            return;
        }
        viewersCount = count;
        cacheViewersCount = count;
        viewersText = formatViewersLabel();
        setFitNum(viewersField, count);
    }

    // null = response had no usable viewers field — keep the last count.
    hidden function extractViewersCount(data as Dictionary or String or Null) as Number? {
        try {
            if (data instanceof Dictionary) {
                var raw = (data as Dictionary).get("viewers");
                if (raw == null) {
                    return null;
                }
                var parsed = toRequestFloat(raw);
                if (parsed == null) {
                    return null;
                }
                if (parsed <= 0.0) {
                    return 0;
                }
                return Math.round(parsed).toNumber();
            }
            if (data instanceof String) {
                return parseViewersFromText(data as String);
            }
        } catch (ex) {
        }
        return null;
    }

    // Garmin often hands JSON as text: {"status":"ok","viewers":2} — toNumber("2}") is null.
    hidden function parseViewersFromText(text as String) as Number? {
        var key = "\"viewers\"";
        var idx = text.find(key);
        if (idx == null) {
            return null;
        }
        var rest = text.substring((idx as Number) + key.length(), text.length());
        if (rest == null) {
            return null;
        }
        var colon = rest.find(":");
        if (colon == null) {
            return null;
        }
        var numPart = rest.substring((colon as Number) + 1, rest.length());
        if (numPart == null) {
            return null;
        }
        var digits = "";
        var i = 0;
        while (i < numPart.length()) {
            var c = numPart.substring(i, i + 1);
            if (c == null) {
                break;
            }
            if (c.equals(" ") || c.equals("\t") || c.equals("\n") || c.equals("\r")) {
                if (digits.length() > 0) {
                    break;
                }
                i += 1;
            } else if ("0123456789".find(c) != null) {
                digits = digits + c;
                i += 1;
            } else {
                break;
            }
        }
        if (digits.length() == 0) {
            return null;
        }
        var parsedNum = digits.toNumber();
        if (parsedNum == null) {
            return null;
        }
        if (parsedNum < 0) {
            return 0;
        }
        return parsedNum;
    }

    hidden function readAltitude(info as Activity.Info) as Float? {
        var alt = readNumberField(info, :altitude);
        if (alt == null) {
            alt = readLiveNumberField(:altitude);
        }
        if (alt == null) {
            var gps = lastGps();
            if (gps != null) {
                alt = toRequestFloat(gps.altitude);
            }
        }
        return alt;
    }

    hidden function readPressureHpa(info as Activity.Info) as Float? {
        var pa = readNumberField(info, :ambientPressure);
        if (pa == null) {
            pa = readNumberField(info, :rawAmbientPressure);
        }
        if (pa == null) {
            pa = readNumberField(info, :meanSeaLevelPressure);
        }
        if (pa == null) {
            pa = readLiveNumberField(:ambientPressure);
        }
        if (pa == null) {
            pa = readLiveNumberField(:rawAmbientPressure);
        }
        if (pa == null) {
            pa = readLiveNumberField(:meanSeaLevelPressure);
        }
        return toHpa(pa);
    }

    hidden function readLiveNumberField(field as Symbol) as Float? {
        try {
            var live = Activity.getActivityInfo();
            if (live != null && live has field) {
                return toRequestFloat(live[field]);
            }
        } catch (ex) {
        }
        return null;
    }

    hidden function toHpa(pa as Float?) as Float? {
        if (pa == null) {
            return null;
        }
        var hpa = pa;
        if (pa > 2000.0) {
            hpa = pa / 100.0;
        }
        if (hpa < 300.0 || hpa > 1100.0) {
            return null;
        }
        return hpa;
    }

    hidden function readNumberField(info as Activity.Info, field as Symbol) as Float? {
        try {
            if (info has field) {
                return toRequestFloat(info[field]);
            }
        } catch (ex) {
        }
        return null;
    }

    hidden function isTimerOn(info as Activity.Info) as Boolean {
        var state = readTimerState(info);
        return state != null && state == Activity.TIMER_STATE_ON;
    }

    hidden function isTimerPaused(info as Activity.Info) as Boolean {
        var state = readTimerState(info);
        return state != null && state == Activity.TIMER_STATE_PAUSED;
    }

    hidden function canSendNow() as Boolean {
        if (!EsyaTrackerAuth.isOnlineMode() || !hasToken()) {
            return false;
        }
        return timerOn || (timerPaused && sendDuringPauseEnabled());
    }

    hidden function isOfflineMode() as Boolean {
        return !EsyaTrackerAuth.isOnlineMode();
    }

    hidden function sendDuringPauseEnabled() as Boolean {
        try {
            var value = Application.Properties.getValue("sendDuringPause");
            if (value instanceof Boolean) {
                return value as Boolean;
            }
            if (value instanceof Number) {
                return (value as Number) != 0;
            }
            if (value instanceof String) {
                var s = value as String;
                return s.equals("true") || s.equals("1");
            }
        } catch (ex) {
        }
        return true;
    }

    hidden function maybeQueuePauseSend(info as Activity.Info) as Void {
        if (busy) {
            return;
        }

        var now = Time.now().value();
        if (lastPauseSendAt != null && (now - lastPauseSendAt) < PAUSE_SEND_INTERVAL_SEC) {
            return;
        }

        var point = buildPoint(info);
        if (point == null) {
            return;
        }

        pending = point;
        lastPauseSendAt = now;
    }

    hidden function readTimerState(info as Activity.Info) as Number? {
        try {
            if (info has :timerState && info.timerState != null) {
                return info.timerState;
            }
        } catch (ex) {
        }

        try {
            var live = Activity.getActivityInfo();
            if (live != null && live has :timerState && live.timerState != null) {
                return live.timerState;
            }
        } catch (ex) {
        }

        return null;
    }

    hidden function trySend() as Void {
        if (busy || pending == null || !canSendNow()) {
            return;
        }

        var token = readToken();
        if (token.length() == 0) {
            return;
        }
        var body = pending as Dictionary;
        body.put("id", token);
        pending = null;
        busy = true;

        try {
            // Omit responseType so the device follows the server Content-Type.
            // Invalid tokens often return text/plain; forcing JSON caused -400/noise.
            Communications.makeWebRequest(
                "https://esya.ru/osmo",
                body,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token
                    }
                },
                method(:onReceive)
            );
        } catch (ex) {
            busy = false;
            lastCode = CODE_SEND_CRASH;
            txFail += 1;
        }
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        try {
            busy = false;
            lastCode = responseCode;

            if (responseCode >= 200 && responseCode < 300) {
                forbidden403Count = 0;
                txOk += 1;
                lastOkAt = Time.now().value();
                updateViewers(data);
                maybeBeepOnSend();
            } else {
                txFail += 1;
                if (responseCode == 401 || responseCode == 403) {
                    forbidden403Count += 1;
                    if (forbidden403Count > FORBIDDEN_CLEAR_COUNT) {
                        revokeBearerToken();
                    }
                }
            }

            writeFit();
            WatchUi.requestUpdate();

            if (canSendNow() && pending != null) {
                trySend();
            }
        } catch (ex) {
            busy = false;
            lastCode = CODE_SEND_CRASH;
            txFail += 1;
        }
    }

    hidden function maybeBeepOnSend() as Void {
        if (txOk == 1) {
            playSendTone();
            playFirstSendVibe();
            return;
        }
        if ((txOk % BEEP_EVERY_POINTS) == 0) {
            playSendTone();
        }
    }

    hidden function playSendTone() as Void {
        try {
            if (Attention has :playTone) {
                Attention.playTone(Attention.TONE_KEY);
            }
        } catch (ex) {
        }
    }

    hidden function playFirstSendVibe() as Void {
        try {
            if (!(Attention has :vibrate)) {
                return;
            }
            var pattern = [
                new Attention.VibeProfile(100, 250),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(100, 350),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(100, 250)
            ] as Array<Attention.VibeProfile>;
            Attention.vibrate(pattern);
        } catch (ex) {
        }
    }

    hidden function isBlankToken(token as String) as Boolean {
        return token.length() == 0
            || token.equals("unset")
            || token.equals(STALE_TOKEN)
            || token.equals(FALLBACK_TOKEN);
    }

    hidden function readToken() as String {
        var token = EsyaTrackerAuth.readToken();
        if (isBlankToken(token)) {
            return "";
        }
        return token;
    }

    hidden function hasToken() as Boolean {
        return readToken().length() > 0;
    }

    hidden function revokeBearerToken() as Void {
        forbidden403Count = 0;
        pending = null;
        lastCode = 0;
        if (EsyaTrackerAuth.isOnlineMode()) {
            EsyaTrackerAuth.markReregisterNeeded();
            EsyaTrackerAuth.registerGuest();
        } else {
            EsyaTrackerAuth.clearSession();
        }
        WatchUi.requestUpdate();
    }

    hidden function toRequestFloat(value as Object?) as Float? {
        if (value == null) {
            return null;
        }
        if (value instanceof Float) {
            return value as Float;
        }
        if (value instanceof Number) {
            return (value as Number).toFloat();
        }
        if (value instanceof Double) {
            return (value as Double).toFloat();
        }
        return null;
    }

    hidden function isPausedDisplay() as Boolean {
        return !timerOn && (timerPaused || txOk > 0);
    }

    hidden function statusValue(compact as Boolean) as String {
        if (fitTried && !fitReady && !fitSkippedReadd) {
            return statusText(Rez.Strings.NoFit);
        }
        if (isOfflineMode()) {
            if (timerOn || timerPaused) {
                return statusText(Rez.Strings.OfflineMode);
            }
            return statusText(Rez.Strings.OfflineIdle);
        }
        if (needsOnlineFitRestart()) {
            // Pause keeps "пауза" as the main line; restart hint is drawn under it.
            if (isPausedDisplay()) {
                return statusText(Rez.Strings.Paused);
            }
            return statusText(
                compact ? Rez.Strings.RestartActivityCompact : Rez.Strings.RestartActivity
            );
        }
        if (!hasToken()) {
            if (timerOn || timerPaused) {
                return statusText(Rez.Strings.OnlineConnecting);
            }
            return statusText(Rez.Strings.OnlineIdle);
        }
        if (isPausedDisplay()) {
            return statusText(Rez.Strings.Paused);
        }
        if (!timerOn) {
            return statusText(Rez.Strings.Start);
        }
        if (lastCode != 0 && (lastCode < 200 || lastCode >= 300)) {
            return statusLabel(lastCode);
        }
        if (txOk > 0) {
            return txOk.toString();
        }
        if (pending == null && txFail == 0) {
            return hasDistance
                ? statusText(Rez.Strings.NoLocation)
                : statusText(Rez.Strings.WaitGps);
        }
        if (busy) {
            return "...";
        }
        return txOk.toString();
    }

    hidden function txOkColor(theme as Number) as Number {
        if (txOk < COLOR_EVERY_POINTS) {
            return theme == Graphics.COLOR_BLACK ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        }
        var colors = [
            Graphics.COLOR_RED,
            Graphics.COLOR_ORANGE,
            Graphics.COLOR_YELLOW,
            Graphics.COLOR_GREEN,
            Graphics.COLOR_BLUE,
            Graphics.COLOR_PURPLE,
            Graphics.COLOR_PINK
        ] as Array<Number>;
        // Integer band: one color per COLOR_EVERY_POINTS sends (3600, 7200, 10800…).
        var band = Math.floor(txOk.toFloat() / COLOR_EVERY_POINTS.toFloat()).toNumber();
        var idx = (band - 1) % colors.size();
        if (idx < 0) {
            idx = 0;
        }
        return colors[idx];
    }

    hidden function statusText(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

    hidden function statusLabel(code as Number) as String {
        if (code == 401) {
            return statusText(Rez.Strings.NoToken);
        }
        if (code == 403) {
            return statusText(Rez.Strings.Forbidden);
        }
        if (code >= 500 && code < 600) {
            return statusText(Rez.Strings.ServerError);
        }
        if (code >= 400 && code < 500) {
            return statusText(Rez.Strings.ServerError);
        }
        if (
            code == Communications.BLE_CONNECTION_UNAVAILABLE
            || code == Communications.BLE_ERROR
        ) {
            return statusText(Rez.Strings.NoPhone);
        }
        if (
            code == Communications.NETWORK_REQUEST_TIMED_OUT
            || code == Communications.BLE_HOST_TIMEOUT
            || code == Communications.BLE_SERVER_TIMEOUT
            || code == Communications.SECURE_CONNECTION_REQUIRED
        ) {
            return statusText(Rez.Strings.NoInternet);
        }
        if (
            code == Communications.BLE_NO_DATA
            || code == Communications.BLE_QUEUE_FULL
            || code == Communications.BLE_REQUEST_CANCELLED
            || code == Communications.BLE_REQUEST_TOO_LARGE
            || code == Communications.BLE_UNKNOWN_SEND_ERROR
            || code == Communications.REQUEST_CANCELLED
            || code == Communications.REQUEST_CONNECTION_DROPPED
        ) {
            return statusText(Rez.Strings.NoLink);
        }
        if (code == Communications.UNKNOWN_ERROR) {
            return statusText(Rez.Strings.UnknownError);
        }
        if (
            code == Communications.INVALID_HTTP_HEADER_FIELDS_IN_REQUEST
            || code == Communications.INVALID_HTTP_BODY_IN_REQUEST
            || code == Communications.INVALID_HTTP_METHOD_IN_REQUEST
            || code == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE
            || code == Communications.INVALID_HTTP_HEADER_FIELDS_IN_NETWORK_RESPONSE
            || code == Communications.NETWORK_RESPONSE_TOO_LARGE
            || code == Communications.NETWORK_RESPONSE_OUT_OF_MEMORY
            || code == Communications.STORAGE_FULL
            || code == Communications.UNSUPPORTED_CONTENT_TYPE_IN_RESPONSE
            || code == CODE_SEND_CRASH
            || code == CODE_COMPUTE_CRASH
        ) {
            return statusText(Rez.Strings.SendError);
        }
        return code.toString();
    }

    hidden function looksLikeNumber(value as String) as Boolean {
        var parsed = value.toNumber();
        return parsed != null && parsed.toString().equals(value);
    }

    hidden function sensorFontFor(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        round as Boolean,
        spacious as Boolean,
        pad as Number
    ) as Graphics.FontDefinition {
        var fonts = [
            Graphics.FONT_TINY,
            Graphics.FONT_XTINY
        ] as Array<Graphics.FontDefinition>;
        if (round) {
            if (height >= 180) {
                fonts = [
                    Graphics.FONT_SMALL,
                    Graphics.FONT_TINY,
                    Graphics.FONT_XTINY
                ] as Array<Graphics.FontDefinition>;
            }
        } else if (spacious) {
            fonts = [
                Graphics.FONT_LARGE,
                Graphics.FONT_MEDIUM,
                Graphics.FONT_SMALL,
                Graphics.FONT_TINY
            ] as Array<Graphics.FontDefinition>;
        } else {
            fonts = [
                Graphics.FONT_SMALL,
                Graphics.FONT_TINY,
                Graphics.FONT_XTINY
            ] as Array<Graphics.FontDefinition>;
        }
        var i = 0;
        while (i < fonts.size()) {
            var font = fonts[i];
            var fh = dc.getFontHeight(font);
            var ok = true;
            if (round) {
                var topLines = [tempText, sensorTop2] as Array<String>;
                var botLines = [speedText, windText, sensorBot2] as Array<String>;
                var topW = maxTextWidth(dc, font, topLines);
                var botW = maxTextWidth(dc, font, botLines);
                var topMax = lineMaxWidth(width, height, pad + fh / 2, pad, true);
                var botMax = lineMaxWidth(width, height, height - pad - fh / 2, pad, true);
                var lineCount = countSensorTopLines(false) + countSensorBotLines(false, false);
                if (lineCount < 2) {
                    lineCount = 2;
                }
                ok = topW <= topMax
                    && botW <= botMax
                    && (lineCount * fh) + (2 * pad) < height;
            } else {
                var gap = spacious ? 28 : 20;
                var topNeed = dc.getTextWidthInPixels(tempText, font) + dc.getTextWidthInPixels(presText, font) + gap;
                var speedWind = speedText;
                if (windText.length() > 0) {
                    speedWind = speedText + " (" + windText + ")";
                }
                var bottomNeed = dc.getTextWidthInPixels(speedWind, font) + dc.getTextWidthInPixels(viewersText, font) + gap;
                var need = topNeed > bottomNeed ? topNeed : bottomNeed;
                ok = need <= (width - (2 * pad)) && (2 * fh) + (2 * pad) < (height / 2);
            }
            if (ok) {
                return font;
            }
            i += 1;
        }
        return Graphics.FONT_XTINY;
    }

    hidden function statusFont(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        value as String,
        spacious as Boolean,
        round as Boolean,
        maxW as Number
    ) as Graphics.FontDefinition {
        if (!timerOn || (fitTried && !fitReady && !fitSkippedReadd) || !looksLikeNumber(value)) {
            return pickFittingFont(dc, value, maxW, [
                Graphics.FONT_MEDIUM,
                Graphics.FONT_SMALL,
                Graphics.FONT_TINY,
                Graphics.FONT_XTINY
            ] as Array<Graphics.FontDefinition>);
        }

        var fonts = [
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_LARGE,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
            Graphics.FONT_TINY
        ] as Array<Graphics.FontDefinition>;
        if (spacious) {
            // Prefer the largest number faces on full-screen Edge / big fields.
            fonts = [
                Graphics.FONT_NUMBER_HOT,
                Graphics.FONT_NUMBER_MEDIUM,
                Graphics.FONT_NUMBER_MILD,
                Graphics.FONT_LARGE,
                Graphics.FONT_MEDIUM,
                Graphics.FONT_SMALL
            ] as Array<Graphics.FontDefinition>;
        } else if (round || height < 120 || value.length() >= 4) {
            fonts = [
                Graphics.FONT_NUMBER_MILD,
                Graphics.FONT_MEDIUM,
                Graphics.FONT_SMALL,
                Graphics.FONT_TINY,
                Graphics.FONT_XTINY
            ] as Array<Graphics.FontDefinition>;
        }

        return pickFittingFont(dc, value, maxW, fonts);
    }

    hidden function pickFittingFont(
        dc as Graphics.Dc,
        value as String,
        maxW as Number,
        fonts as Array<Graphics.FontDefinition>
    ) as Graphics.FontDefinition {
        var i = 0;
        while (i < fonts.size()) {
            var font = fonts[i];
            if (dc.getTextWidthInPixels(value, font) <= maxW) {
                return font;
            }
            i += 1;
        }
        return Graphics.FONT_XTINY;
    }

    hidden function statusTone() as Number {
        if (!timerOn || txOk == 0 || lastOkAt == null) {
            return TONE_DEFAULT;
        }

        var age = Time.now().value() - lastOkAt;
        if (isCriticalCode(lastCode) || age >= STALE_FAIL_SEC) {
            return TONE_ERROR;
        }
        if (isSoftFail(lastCode) || age >= STALE_WARN_SEC) {
            return TONE_WAIT;
        }
        return TONE_OK;
    }

    hidden function isCriticalCode(code as Number) as Boolean {
        return code == 401
            || code == 403
            || code == Communications.BLE_CONNECTION_UNAVAILABLE
            || code == Communications.BLE_ERROR
            || code == CODE_SEND_CRASH
            || code == CODE_COMPUTE_CRASH;
    }

    hidden function isSoftFail(code as Number) as Boolean {
        return code != 0 && (code < 200 || code >= 300) && !isCriticalCode(code);
    }

    hidden function statusBackground(theme as Number) as Number {
        var dark = theme == Graphics.COLOR_BLACK;
        var tone = statusTone();
        if (tone == TONE_OK) {
            return dark ? 0x082010 : 0xE7F4EA;
        }
        if (tone == TONE_WAIT) {
            return dark ? 0x241C08 : 0xFFF4D6;
        }
        if (tone == TONE_ERROR) {
            return dark ? 0x280C0C : 0xF8E4E4;
        }
        return theme;
    }

    hidden function resetGpsBadTimer() as Void {
        gpsBadAccumSec = 0;
        gpsSevereAccumSec = 0;
        gpsBadTickAt = null;
    }

    // quality ≤3 while recording/paused; null counts as absent (severe).
    hidden function tickGpsBadTimer() as Void {
        if (!timerOn && !timerPaused) {
            resetGpsBadTimer();
            return;
        }
        var now = Time.now().value();
        if (gpsBadTickAt == null) {
            gpsBadTickAt = now;
            return;
        }
        var dt = now - (gpsBadTickAt as Number);
        gpsBadTickAt = now;
        if (dt < 0) {
            dt = 0;
        }
        // compute can stall; avoid huge jumps after sleep/background.
        if (dt > 5) {
            dt = 5;
        }

        var q = cacheGpsQuality;
        var bad = q == null || q <= 3;
        var severe = q == null || q <= 2;
        if (!bad) {
            gpsBadAccumSec = 0;
            gpsSevereAccumSec = 0;
            return;
        }
        gpsBadAccumSec += dt;
        if (severe) {
            gpsSevereAccumSec += dt;
        } else {
            gpsSevereAccumSec = 0;
        }
    }

    hidden function clamp01(t as Float) as Float {
        if (t <= 0.0) {
            return 0.0;
        }
        if (t >= 1.0) {
            return 1.0;
        }
        return t;
    }

    hidden function lerpByte(a as Number, b as Number, t as Float) as Number {
        return Math.round(a.toFloat() + ((b - a).toFloat() * t)).toNumber();
    }

    hidden function lerpRgb(fromColor as Number, toColor as Number, t as Float) as Number {
        var u = clamp01(t);
        var fr = (fromColor / 65536) % 256;
        var fg = (fromColor / 256) % 256;
        var fb = fromColor % 256;
        var tr = (toColor / 65536) % 256;
        var tg = (toColor / 256) % 256;
        var tb = toColor % 256;
        if (fr < 0) {
            fr += 256;
        }
        if (fg < 0) {
            fg += 256;
        }
        if (fb < 0) {
            fb += 256;
        }
        if (tr < 0) {
            tr += 256;
        }
        if (tg < 0) {
            tg += 256;
        }
        if (tb < 0) {
            tb += 256;
        }
        var r = lerpByte(fr, tr, u);
        var g = lerpByte(fg, tg, u);
        var b = lerpByte(fb, tb, u);
        return (r * 65536) + (g * 256) + b;
    }

    // GPS ≤3: after 1 min yellow→orange (5 min), then orange→bright red (25 min).
    // GPS ≤2 / absent: skip yellow — orange→bright red over 25 min from the moment it starts.
    hidden function fieldBackground(theme as Number) as Number {
        var base = statusBackground(theme);
        if (!timerOn && !timerPaused) {
            return base;
        }
        var q = cacheGpsQuality;
        if (q != null && q >= 4) {
            return base;
        }

        var dark = theme == Graphics.COLOR_BLACK;
        var yellow = dark ? 0x2A2208 : 0xFFE08A;
        var orange = dark ? 0x3A1808 : 0xF08840;
        var brightRed = dark ? 0xC00000 : 0xFF1010;
        var severe = q == null || q <= 2;

        if (severe) {
            return lerpRgb(orange, brightRed, gpsSevereAccumSec.toFloat() / 1500.0);
        }
        // quality == 3
        if (gpsBadAccumSec <= 60) {
            return base;
        }
        if (gpsBadAccumSec <= 360) {
            return lerpRgb(yellow, orange, (gpsBadAccumSec - 60).toFloat() / 300.0);
        }
        return lerpRgb(orange, brightRed, (gpsBadAccumSec - 360).toFloat() / 1500.0);
    }

    hidden function fieldForeground(theme as Number) as Number {
        return theme == Graphics.COLOR_BLACK ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    hidden function sensorColor(bg as Number) as Number {
        if (bg == Graphics.COLOR_BLACK) {
            return 0xFFD166;
        }
        return 0x9A3412;
    }
}


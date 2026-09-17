import Toybox.Activity;
import Toybox.Application;
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

    const TX_OK_RECORD_ID = 0;
    const TX_FAIL_RECORD_ID = 1;
    const TX_OK_SESSION_ID = 2;
    const TX_FAIL_SESSION_ID = 3;
    const PRESSURE_FIELD_ID = 4;
    const BATTERY_FIELD_ID = 5;
    const GPS_FIELD_ID = 6;
    const FALLBACK_TOKEN = "";
    const STALE_TOKEN = "";
    const CODE_SEND_CRASH = -9001;
    const CODE_COMPUTE_CRASH = -9002;

    hidden var txOk as Number = 0;
    hidden var txFail as Number = 0;
    hidden var lastCode as Number = 0;
    hidden var busy as Boolean = false;
    hidden var pending as Dictionary?;
    hidden var hasDistance as Boolean = false;
    hidden var timerOn as Boolean = false;
    hidden var timerPaused as Boolean = false;
    hidden var lastElapsedDistance as Float?;
    hidden var lastElapsedAt as Number?;
    hidden var derivedSpeed as Float?;

    hidden var txOkRecord as FitContributor.Field?;
    hidden var txFailRecord as FitContributor.Field?;
    hidden var txOkSession as FitContributor.Field?;
    hidden var txFailSession as FitContributor.Field?;
    hidden var pressureField as FitContributor.Field?;
    hidden var batteryField as FitContributor.Field?;
    hidden var gpsField as FitContributor.Field?;
    hidden var fitReady as Boolean = false;
    hidden var fitTried as Boolean = false;
    hidden var tempText as String = "--";
    hidden var presText as String = "--";

    function initialize() {
        DataField.initialize();
        migrateToken();
    }

    function onTimerStart() as Void {
        ensureFitFields();
    }

    function compute(info as Activity.Info) as Void {
        try {
            ensureFitFields();
            timerOn = isTimerOn(info);
            timerPaused = isTimerPaused(info);
            hasDistance = info has :elapsedDistance && info.elapsedDistance != null && info.elapsedDistance > 0;
            updateSensorState(info);

            if (!timerOn) {
                pending = null;
                lastElapsedDistance = null;
                lastElapsedAt = null;
                derivedSpeed = null;
                writeFit();
                return;
            }

            sampleElapsedSpeed(info);

            var point = buildPoint(info);
            if (point != null) {
                pending = point;
            }

            writeFit();

            if (!busy) {
                trySend();
            }
        } catch (ex) {
            lastCode = CODE_COMPUTE_CRASH;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        try {
            var bg = getBackgroundColor();
            var fg = bg == Graphics.COLOR_BLACK ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            dc.setColor(fg, bg);
            dc.clear();

            var width = dc.getWidth();
            var height = dc.getHeight();
            var value = statusValue();
            var font = statusFont(dc, width, height, value);

            if (timerOn) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(width / 2, 2, Graphics.FONT_XTINY, "TX", Graphics.TEXT_JUSTIFY_CENTER);
            }

            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, font, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            var sensorFont = Graphics.FONT_XTINY;
            var sensorY = height - dc.getFontHeight(sensorFont);
            if (sensorY < height / 2 + 4) {
                sensorY = height / 2 + 4;
            }
            dc.setColor(sensorColor(bg), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                width / 2,
                sensorY,
                sensorFont,
                tempText + "  " + presText,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        } catch (ex) {
        }
    }

    hidden function ensureFitFields() as Void {
        if (fitReady) {
            return;
        }

        fitTried = true;
        txOkRecord = createField(
            "esya_tx_ok",
            TX_OK_RECORD_ID,
            FitContributor.DATA_TYPE_FLOAT,
            {
                :mesgType => FitContributor.MESG_TYPE_RECORD,
                :units => "n"
            }
        );
        txFailRecord = createField(
            "esya_tx_fail",
            TX_FAIL_RECORD_ID,
            FitContributor.DATA_TYPE_FLOAT,
            {
                :mesgType => FitContributor.MESG_TYPE_RECORD,
                :units => "n"
            }
        );
        txOkSession = createField(
            "esya_tx_ok_total",
            TX_OK_SESSION_ID,
            FitContributor.DATA_TYPE_FLOAT,
            {
                :mesgType => FitContributor.MESG_TYPE_SESSION,
                :units => "n"
            }
        );
        txFailSession = createField(
            "esya_tx_fail_total",
            TX_FAIL_SESSION_ID,
            FitContributor.DATA_TYPE_FLOAT,
            {
                :mesgType => FitContributor.MESG_TYPE_SESSION,
                :units => "n"
            }
        );
        setFit(txOkRecord, 0);
        setFit(txFailRecord, 0);
        setFit(txOkSession, 0);
        setFit(txFailSession, 0);
        try {
            pressureField = createField(
                "esya_ambient_pressure",
                PRESSURE_FIELD_ID,
                FitContributor.DATA_TYPE_FLOAT,
                {
                    :mesgType => FitContributor.MESG_TYPE_RECORD,
                    :units => "hPa"
                }
            );
            batteryField = createField(
                "esya_device_battery",
                BATTERY_FIELD_ID,
                FitContributor.DATA_TYPE_FLOAT,
                {
                    :mesgType => FitContributor.MESG_TYPE_RECORD,
                    :units => "%"
                }
            );
            gpsField = createField(
                "esya_gps_quality",
                GPS_FIELD_ID,
                FitContributor.DATA_TYPE_FLOAT,
                {
                    :mesgType => FitContributor.MESG_TYPE_RECORD,
                    :units => "0-4"
                }
            );
            setFitFloat(pressureField, 0.0);
            setFitFloat(batteryField, 0.0);
            setFitFloat(gpsField, 0.0);
        } catch (ex) {
        }
        fitReady = txOkRecord != null && txFailRecord != null && txOkSession != null && txFailSession != null;
    }

    hidden function writeFit() as Void {
        setFit(txOkRecord, txOk);
        setFit(txFailRecord, txFail);
        setFit(txOkSession, txOk);
        setFit(txFailSession, txFail);
    }

    hidden function setFit(field as FitContributor.Field?, value as Number) as Void {
        setFitFloat(field, value.toFloat());
    }

    hidden function setFitFloat(field as FitContributor.Field?, value as Float) as Void {
        if (field != null) {
            field.setData(value);
        }
    }

    hidden function updateSensorState(info as Activity.Info) as Void {
        var temp = readTemperature(info);
        if (temp != null) {
            tempText = temp.format("%.1f") + "C";
        } else {
            tempText = "--C";
        }

        var pres = readPressureHpa(info);
        if (pres != null) {
            presText = pres.format("%.0f") + "hPa";
            setFitFloat(pressureField, pres);
        } else {
            presText = "--hPa";
        }

        try {
            var stats = System.getSystemStats();
            if (stats != null) {
                setFitFloat(batteryField, stats.battery);
            }
        } catch (ex) {
        }

        var gps = readGpsQuality(info);
        if (gps != null) {
            setFitFloat(gpsField, gps.toFloat());
        }
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

        var temp = readTemperature(info);
        if (temp != null) {
            body.put("temp", temp.format("%.1f"));
        }

        var pres = readPressureHpa(info);
        if (pres != null) {
            body.put("pres", pres.format("%.1f"));
        }

        var acc = readAccuracyMeters(info);
        if (acc != null) {
            body.put("acc", acc.toString());
        }

        var alt = readNumberField(info, :altitude);
        if (alt == null && lastGps() != null) {
            alt = toRequestFloat(lastGps().altitude);
        }
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
        var activitySpeed = readNumberField(info, :currentSpeed);
        var liveSpeed = null as Float?;
        try {
            var live = Activity.getActivityInfo();
            if (live != null) {
                liveSpeed = toRequestFloat(live.currentSpeed);
            }
        } catch (ex) {
        }

        var gpsSpeed = null as Float?;
        var gps = lastGps();
        if (gps != null) {
            gpsSpeed = toRequestFloat(gps.speed);
        }

        var best = maxSpeed(maxSpeed(activitySpeed, liveSpeed), gpsSpeed);
        if (isMovingSpeed(best)) {
            return best;
        }
        if (isMovingSpeed(derivedSpeed)) {
            return derivedSpeed;
        }
        if (best != null) {
            return best;
        }
        return derivedSpeed;
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

        derivedSpeed = dd / dt.toFloat();
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
            return toRequestFloat(Application.Storage.getValue("esya_temp_c"));
        } catch (ex) {
        }
        return null;
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
        if (!timerOn || busy || pending == null) {
            return;
        }

        var token = readToken();
        var body = pending as Dictionary;
        body.put("id", token);
        pending = null;
        busy = true;

        try {
            Communications.makeWebRequest(
                "https://esya.ru/osmo",
                body,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
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
        busy = false;
        lastCode = responseCode;

        if (responseCode >= 200 && responseCode < 300) {
            txOk += 1;
        } else {
            txFail += 1;
        }

        writeFit();

        if (timerOn && pending != null) {
            trySend();
        }
    }

    hidden function migrateToken() as Void {
        try {
            var value = Application.Properties.getValue("bearerToken");
            var stored = "";
            if (value instanceof String) {
                stored = value as String;
            }
            if (stored.length() == 0 || stored.equals(STALE_TOKEN)) {
                Application.Properties.setValue("bearerToken", FALLBACK_TOKEN);
            }
        } catch (ex) {
        }
    }

    hidden function readToken() as String {
        try {
            var value = Application.Properties.getValue("bearerToken");
            if (value instanceof String) {
                var token = value as String;
                if (token.length() > 0 && !token.equals(STALE_TOKEN)) {
                    return token;
                }
            }
        } catch (ex) {
        }
        return FALLBACK_TOKEN;
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

    hidden function statusValue() as String {
        if (fitTried && !fitReady) {
            return "nofit";
        }
        if (!timerOn) {
            return timerPaused ? "Pause" : "Start";
        }
        if (lastCode != 0 && (lastCode < 200 || lastCode >= 300)) {
            return statusLabel(lastCode);
        }
        if (txOk > 0) {
            return txOk.toString();
        }
        if (pending == null && txFail == 0) {
            return hasDistance ? "nloc" : "gps";
        }
        if (busy) {
            return "...";
        }
        return txOk.toString();
    }

    hidden function statusLabel(code as Number) as String {
        if (code == 401) {
            return "токен";
        }
        if (code == 403) {
            return "запрет";
        }
        if (code == 404) {
            return "нет URL";
        }
        if (code >= 500 && code < 600) {
            return "ews";
        }
        if (code >= 400 && code < 500) {
            return "HTTP";
        }
        if (code == Communications.UNKNOWN_ERROR) {
            return "неизв.";
        }
        if (code == Communications.BLE_ERROR) {
            return "BLE";
        }
        if (code == Communications.BLE_HOST_TIMEOUT) {
            return "хост";
        }
        if (code == Communications.BLE_SERVER_TIMEOUT) {
            return "сервер";
        }
        if (code == Communications.BLE_NO_DATA) {
            return "пусто";
        }
        if (code == Communications.BLE_REQUEST_CANCELLED) {
            return "отмена";
        }
        if (code == Communications.BLE_QUEUE_FULL) {
            return "очередь";
        }
        if (code == Communications.BLE_REQUEST_TOO_LARGE) {
            return "велик";
        }
        if (code == Communications.BLE_UNKNOWN_SEND_ERROR) {
            return "отправка";
        }
        if (code == Communications.BLE_CONNECTION_UNAVAILABLE) {
            return "нет BLE";
        }
        if (code == Communications.INVALID_HTTP_HEADER_FIELDS_IN_REQUEST) {
            return "заголовки";
        }
        if (code == Communications.INVALID_HTTP_BODY_IN_REQUEST) {
            return "тело";
        }
        if (code == Communications.INVALID_HTTP_METHOD_IN_REQUEST) {
            return "метод";
        }
        if (code == Communications.NETWORK_REQUEST_TIMED_OUT) {
            return "нет сети";
        }
        if (code == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) {
            return "не JSON";
        }
        if (code == Communications.INVALID_HTTP_HEADER_FIELDS_IN_NETWORK_RESPONSE) {
            return "ответ hdr";
        }
        if (code == Communications.NETWORK_RESPONSE_TOO_LARGE) {
            return "велик";
        }
        if (code == Communications.NETWORK_RESPONSE_OUT_OF_MEMORY) {
            return "память";
        }
        if (code == Communications.STORAGE_FULL) {
            return "диск";
        }
        if (code == Communications.SECURE_CONNECTION_REQUIRED) {
            return "HTTPS";
        }
        if (code == Communications.UNSUPPORTED_CONTENT_TYPE_IN_RESPONSE) {
            return "тип";
        }
        if (code == Communications.REQUEST_CANCELLED) {
            return "отмена";
        }
        if (code == Communications.REQUEST_CONNECTION_DROPPED) {
            return "обрыв";
        }
        if (code == CODE_SEND_CRASH) {
            return "сбой TX";
        }
        if (code == CODE_COMPUTE_CRASH) {
            return "сбой";
        }
        return code.toString();
    }

    hidden function looksLikeNumber(value as String) as Boolean {
        var parsed = value.toNumber();
        return parsed != null && parsed.toString().equals(value);
    }

    hidden function statusFont(dc as Graphics.Dc, width as Number, height as Number, value as String) as Graphics.FontDefinition {
        if (!timerOn || (fitTried && !fitReady) || !looksLikeNumber(value)) {
            return height < 70 ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM;
        }

        var maxW = width - 4;
        var fonts = [
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_LARGE,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL
        ] as Array<Graphics.FontDefinition>;
        if (height < 70 || value.length() >= 4) {
            fonts = [
                Graphics.FONT_NUMBER_MILD,
                Graphics.FONT_NUMBER_HOT,
                Graphics.FONT_MEDIUM,
                Graphics.FONT_SMALL,
                Graphics.FONT_TINY
            ] as Array<Graphics.FontDefinition>;
        }

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

    hidden function sensorColor(bg as Number) as Number {
        if (bg == Graphics.COLOR_BLACK) {
            return 0xFFB347;
        }
        return 0xE67E22;
    }
}

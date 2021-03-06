using Toybox.Activity;
using Toybox.Graphics as Gfx;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi as Ui;
using Toybox.AntPlus;
using Toybox.UserProfile;

class PascisFirstDataFieldView extends Ui.DataField {

	const NUM_SAMPLES_TO_DISPLAY_AVG = 2;
	const LAP_OVERLAY_TIMEOUT = 3;
    
    //system vars
    hidden var mIs5s;
    
    //user profile vars
    hidden var mHrZones;
    hidden var mWeight;
    
    //calculation vars
    hidden var mMomentsPause;
    hidden var mMomentsLap;
    hidden var mPowerAvgMap;
    hidden var mLapPowerSum;
    hidden var mLapPowerSamples;
    hidden var mTotalPowerSum;
    hidden var mTotalPowerSamples;
    
    //value vars
    hidden var mHr;
    hidden var mCad;
    hidden var m3sAvgPower;
    hidden var m3sAvgPowerWkg;
    hidden var mLapAvgPower;
    hidden var mLapAvgPowerWkg;
    hidden var mTotalAvgPower;
    hidden var mTotalAvgPowerWkg;
    hidden var mLapTime;
    hidden var mTotalTime;

    function initialize() {
        DataField.initialize();
        
        if (System.getDeviceSettings().screenWidth == 240) {
        	mIs5s = false;
        	System.println("Device is a fenix5 or fenix5x");
        } else {
        	mIs5s = true;
        	System.println("Device is a fenix5s");
        }
        
        mHrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_BIKING);
        if (mHrZones == null) {
        	mHrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        }   
        mWeight = UserProfile.getProfile().weight;
        if (mWeight == null) {
        	mWeight = 0;
        }
        
		mMomentsPause = [];
        mMomentsLap = [];
        mPowerAvgMap = {};
        mLapPowerSum = 0;
        mLapPowerSamples = 0;
        mTotalPowerSum = 0;
        mTotalPowerSamples = 0;
        
        mHr = 0;
        mCad = 0;
        m3sAvgPower = 0;
        m3sAvgPowerWkg = 0d;
        mLapAvgPower = 0;
        mLapAvgPowerWkg = 0d;
        mTotalAvgPower = 0;
        mTotalAvgPowerWkg = 0d;
        mLapTime = new Time.Duration(0);
        mTotalTime = new Time.Duration(0);
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info) {
    	var timestamp = Time.now().value();
    	var newPowerAvgMap = {};
    	    	
    	//hr and cad
		mHr = info has :currentHeartRate && info.currentHeartRate != null ? info.currentHeartRate : 0;
    	mCad = info has :currentCadence && info.currentCadence != null ? info.currentCadence : 0;
    	    	
        //add current power
        if (info has :currentPower && info.currentPower != null) {
    		newPowerAvgMap.put(timestamp, info.currentPower);
    		
    		//lap and total power
    		if (isTimerRunning()) {
    			mLapPowerSum += info.currentPower;
    			mLapPowerSamples++;
    			mLapAvgPower = Math.round(mLapPowerSum.toDouble() / mLapPowerSamples);
    			mLapAvgPowerWkg = powerToWkg(mLapAvgPower);

				mTotalPowerSum += info.currentPower;
				mTotalPowerSamples++;
				mTotalAvgPower = Math.round(mTotalPowerSum.toDouble() / mTotalPowerSamples);
    			mTotalAvgPowerWkg = powerToWkg(mTotalAvgPower);
    		}
        }
        
    	//update 3s power avg map
    	if (mPowerAvgMap.hasKey(timestamp - 1)) {
    		newPowerAvgMap.put(timestamp - 1, mPowerAvgMap.get(timestamp - 1));
    	}
    	if (mPowerAvgMap.hasKey(timestamp - 2)) {
    		newPowerAvgMap.put(timestamp - 2, mPowerAvgMap.get(timestamp - 2));
    	}
    	mPowerAvgMap = newPowerAvgMap; 	
    	
    	//calculate 3s avg power and 3s power wkg
    	if (mPowerAvgMap.size() > 0) {    	
	    	var sum = 0d;
	    	var values = mPowerAvgMap.values();
	    	for (var i=0; i<values.size(); i++) {
	    		sum += values[i];
	    	}
	    	m3sAvgPower = Math.round(sum / values.size());
    	} else {
    		m3sAvgPower = 0;
    	}
    	m3sAvgPowerWkg = powerToWkg(m3sAvgPower);
    	
    	//timers
		mTotalTime = new Time.Duration(Math.round(info.timerTime / 1000));
		if (mMomentsLap.size() > 0) {
			var lastLapMoment = mMomentsLap[mMomentsLap.size()-1];
			mLapTime = Time.now().subtract(lastLapMoment).subtract(getPausedDuration(lastLapMoment, Time.now()));
		} else {
			mLapTime = new Time.Duration(0);
		}
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
        var obscurityFlags = DataField.getObscurityFlags();        
        return true;
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
        View.onUpdate(dc);
    
    	//common layout vars
        var bgColor = getBackgroundColor();
        var w = dc.getWidth();
        var h = dc.getHeight();
        
        var firstLineY = h / 3 * 0.9;
        var secondLineY = h / 3 * 2 + 5;
        var thirdLineY = secondLineY + (mIs5s ? 32 : 35);
        var hrGraphHeight = 8;
        var fourthLineY = thirdLineY + hrGraphHeight + 1;
        
        var tbDataLeftX = w/2 - (mIs5s ? 8 : 8);
        var tbDataRightX = w/2 + (mIs5s ? 8 : 8);
        
        var topLabelY = (mIs5s ? 10 : 10);
        var topDataY = firstLineY - (mIs5s ? 29 : 33);
        
        var tableLabelY = firstLineY;
        var tableCenterY = h/2 + (mIs5s ? 3 : 3);
        var tableWkgY = tableCenterY + (mIs5s ? 14 : 14);
        
        var tableColumnLeftX = w/4 - w*0.075;
        var tableColumnCenterX = w/2;
        var tableColumnRightX = w/4*3 + w*0.075;
        
        var timerY = secondLineY;
        
        //background
        dc.setColor(bgColor, bgColor);
        dc.fillRectangle(0, 0, w, h);
        
        //prevent other layout than single field
        if (!isSingleFieldLayout()) {
   			dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        	dc.drawText(w/2, h/4-12, Gfx.FONT_SYSTEM_XTINY, "ONLY", Gfx.TEXT_JUSTIFY_CENTER);
        	dc.drawText(w/2, h/2-12, Gfx.FONT_SYSTEM_XTINY, "SINGLE-FIELD", Gfx.TEXT_JUSTIFY_CENTER);
        	dc.drawText(w/2, h/4*3-12, Gfx.FONT_SYSTEM_XTINY, "LAYOUT", Gfx.TEXT_JUSTIFY_CENTER); 
        	return;
        }
        
        //lines
        dc.setPenWidth(1);
   		dc.setColor(bgColor == Gfx.COLOR_WHITE ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(w/2, 0, w/2, firstLineY);
        dc.drawLine(0, firstLineY, w, firstLineY);
        dc.drawLine(0, secondLineY, w, secondLineY);
        dc.drawLine(w/3, firstLineY, w/3, secondLineY);
        dc.drawLine(w/3*2, firstLineY, w/3*2, secondLineY);
        dc.drawLine(w/2, secondLineY, w/2, thirdLineY);
        dc.drawLine(0, thirdLineY, w, thirdLineY);
        dc.drawLine(0, fourthLineY, w, fourthLineY);
        
        //lower part hr
        var hrRange = mHrZones[5] - mHrZones[0];        
        var hrX1 = getHrX(w, mHrZones[1]);
        var hrX2 = getHrX(w, mHrZones[2]);
        var hrX3 = getHrX(w, mHrZones[3]);
        var hrX4 = getHrX(w, mHrZones[4]);
        var hrXCurrent = getHrX(w, mHr);      
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(0, thirdLineY+1, hrX1, hrGraphHeight);
        dc.setColor(Gfx.COLOR_BLUE, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(hrX1, thirdLineY+1, hrX2-hrX1, hrGraphHeight);
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(hrX2, thirdLineY+1, hrX3-hrX2, hrGraphHeight);
        dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(hrX3, thirdLineY+1, hrX4-hrX3, hrGraphHeight);
        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(hrX4, thirdLineY+1, w-hrX4, hrGraphHeight);
        
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(hrXCurrent-1, thirdLineY+2, 3, hrGraphHeight-2);
        
        //lower part tri 17
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(0, fourthLineY+1, w, h-fourthLineY);
        dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w/2, fourthLineY+(h-fourthLineY)/2-(mIs5s ? 12 : 14), Gfx.FONT_SYSTEM_TINY, "=TRI17=", Gfx.TEXT_JUSTIFY_CENTER);        
        
        //labels
        dc.setColor(bgColor == Gfx.COLOR_WHITE ? Gfx.COLOR_LT_GRAY : Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(tbDataLeftX, topLabelY, Gfx.FONT_SYSTEM_TINY, Ui.loadResource(Rez.Strings.labelHr), Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(tbDataRightX, topLabelY, Gfx.FONT_SYSTEM_TINY, Ui.loadResource(Rez.Strings.labelCad), Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(tableColumnLeftX, tableLabelY, Gfx.FONT_SYSTEM_TINY, Ui.loadResource(Rez.Strings.label3s), Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(tableColumnCenterX, tableLabelY, Gfx.FONT_SYSTEM_TINY, Ui.loadResource(Rez.Strings.labelLap), Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(tableColumnRightX, tableLabelY, Gfx.FONT_SYSTEM_TINY, Ui.loadResource(Rez.Strings.labelTotal), Gfx.TEXT_JUSTIFY_CENTER);
        
        //hr and cadence value
        dc.setColor(bgColor == Gfx.COLOR_WHITE ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(tbDataLeftX, topDataY, Gfx.FONT_NUMBER_MILD, mHr.format("%d"), Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(tbDataRightX, topDataY, Gfx.FONT_NUMBER_MILD, mCad.format("%d"), Gfx.TEXT_JUSTIFY_LEFT);
        
        //power values
        dc.setColor(bgColor == Gfx.COLOR_WHITE ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(tableColumnLeftX, tableCenterY - 6, m3sAvgPower > 1000 ? Gfx.FONT_NUMBER_MILD : Gfx.FONT_NUMBER_MEDIUM, m3sAvgPower.format("%d"), Gfx.TEXT_JUSTIFY_CENTER|Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(tableColumnCenterX, tableCenterY - 6, mLapAvgPower > 1000 ? Gfx.FONT_NUMBER_MILD : Gfx.FONT_NUMBER_MEDIUM, mLapAvgPower.format("%d"), Gfx.TEXT_JUSTIFY_CENTER|Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(tableColumnRightX, tableCenterY - 6, mTotalAvgPower > 1000 ? Gfx.FONT_NUMBER_MILD : Gfx.FONT_NUMBER_MEDIUM, mTotalAvgPower.format("%d"), Gfx.TEXT_JUSTIFY_CENTER|Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(bgColor == Gfx.COLOR_WHITE ? Gfx.COLOR_DK_GRAY : Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(tableColumnLeftX, tableWkgY, Gfx.FONT_SYSTEM_TINY, mWeight == 0 ? "Weight?" : m3sAvgPowerWkg.format(m3sAvgPowerWkg > 10 ? "%.1f" : "%.2f"), Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(tableColumnCenterX, tableWkgY, Gfx.FONT_SYSTEM_TINY, mWeight == 0 ? "Weight?" : mLapAvgPowerWkg.format(mLapAvgPowerWkg > 10 ? "%.1f" : "%.2f"), Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(tableColumnRightX, tableWkgY, Gfx.FONT_SYSTEM_TINY, mWeight == 0 ? "Weight?" : mTotalAvgPowerWkg.format(mTotalAvgPowerWkg > 10 ? "%.1f" : "%.2f"), Gfx.TEXT_JUSTIFY_CENTER);
        
        //timers
        dc.setColor(bgColor == Gfx.COLOR_WHITE ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        if (mLapTime.value() > 3600) {
        	dc.drawText(tbDataLeftX, timerY + (mIs5s ? 3 : 3), Gfx.FONT_SYSTEM_SMALL, formatDuration(mLapTime, true), Gfx.TEXT_JUSTIFY_RIGHT);
    	} else {
    		dc.drawText(tbDataLeftX, timerY, Gfx.FONT_SYSTEM_MEDIUM, formatDuration(mLapTime, false), Gfx.TEXT_JUSTIFY_RIGHT);
    	}
    	if (mTotalTime.value() > 3600) {
        	dc.drawText(tbDataRightX, timerY + (mIs5s ? 3 : 3), Gfx.FONT_SYSTEM_SMALL, formatDuration(mTotalTime, true), Gfx.TEXT_JUSTIFY_LEFT);
    	} else {
    		dc.drawText(tbDataRightX, timerY, Gfx.FONT_SYSTEM_MEDIUM, formatDuration(mTotalTime, false), Gfx.TEXT_JUSTIFY_LEFT);
    	}
        
        //lap overlay
        if (mMomentsLap.size() > 1 && Time.now().subtract(mMomentsLap[mMomentsLap.size()-1]).value() < LAP_OVERLAY_TIMEOUT) {
        	dc.setColor(bgColor == Gfx.COLOR_WHITE ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        	dc.fillRectangle(w/3+1, firstLineY+1, w/3-1, secondLineY-firstLineY);
        	dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        	dc.drawText(w/2, tableCenterY - 5, Gfx.FONT_SYSTEM_LARGE, "LAP", Gfx.TEXT_JUSTIFY_CENTER|Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }
    
    function onTimerStart() {
    	System.println("onTimerStart");
    	if (mMomentsPause.size() > 0) {
    		mMomentsPause[mMomentsPause.size()-1].add(Time.now());
		} else {		
    		mMomentsLap.add(Time.now());
		}
    }
    
    function onTimerStop() {
    	System.println("onTimerStop");
    	mMomentsPause.add([Time.now()]);
    }
    
    function onTimerPause() {
    	System.println("onTimerStop");
    	mMomentsPause.add([Time.now()]);
    }
    
    function onTimerResume() {
    	System.println("onTimerResume");
    	mMomentsPause[mMomentsPause.size()-1].add(Time.now());
    }
    
    function onTimerLap() {
    	System.println("onTimerLap");
    	mMomentsLap.add(Time.now());
    	
    	mLapPowerSamples = 0;
    	mLapPowerSum = 0;
    	mLapAvgPower = 0;
    	mLapAvgPowerWkg = 0d;
    	
    	Ui.requestUpdate();
    }
    
    function getPausedDuration(momentFrom, momentTo) {
    	var pausedDuration = new Time.Duration(0);
    	
    	//default values
    	if (momentFrom == null) {
    		momentFrom = Activity.getActivityInfo().startTime;
    	}
    	if (momentTo == null) {
    		momentTo = Time.now();
    	}
    	
    	//iterate over pauses
    	for (var i=0; i<mMomentsPause.size(); i++) {
    		var curPause = mMomentsPause[i]; 
    		var curPauseFrom = curPause[0];
    		var curPauseTo = curPause.size() == 1 ? Time.now() : curPause[1];
    		
    		if (curPauseFrom.greaterThan(momentTo) || curPauseTo.lessThan(momentFrom)) {
    			continue;
    		}
    		
    		var start = momentFrom.lessThan(curPauseFrom) ? curPauseFrom : momentFrom;
    		var end = momentTo.greaterThan(curPauseTo) ? curPauseTo : momentTo;
    		var diff = end.subtract(start);
    		
    		pausedDuration = new Time.Duration(pausedDuration.value() + diff.value());
    	}
    	
    	return pausedDuration;
    }
    
    function isTimerRunning() {
    	return Activity.getActivityInfo().timerState == Activity.TIMER_STATE_ON;
    }
    
    function powerToWkg(power) {
    	return power == 0 ? 0 : power / mWeight * 1000;
    }
    
    function outputPauses() {
    	var ret = "";
    	for (var i=0; i<mMomentsPause.size(); i++) {
    		var curPause = mMomentsPause[i];
    		ret = ret + formatMoment(curPause[0]);
    		if (curPause.size() > 1) {
    			ret = ret + "-" + formatMoment(curPause[1]);
    		}
    		if (i+1 < mMomentsPause.size()) {
    			ret = ret + ", ";
    		}
    	}
    	System.println("Pauses: " + ret);    	
    }
    
    function formatDuration(duration, showHour) {
    	var seconds = duration.value();    
    	var h = Math.floor(seconds / 3600);
    	var m = Math.floor((seconds % 3600) / 60);
    	var s = Math.round(seconds % 60);
    	
    	if (showHour) {
    		return h.format("%02d") + ":" + m.format("%02d") + ":" + s.format("%02d");
		} else {
			return m.format("%02d") + ":" + s.format("%02d");
		}
    }
    
    function formatMoment(moment) {
    	var date = Time.Gregorian.info(moment, Time.FORMAT_MEDIUM);
    	return date.hour + ":" + date.min + ":" + date.sec;
    }

    function isSingleFieldLayout() {
        return (DataField.getObscurityFlags() == OBSCURE_TOP | OBSCURE_LEFT | OBSCURE_BOTTOM | OBSCURE_RIGHT);
    }
    
    function getHrX(width, hr) {
    	if (hr <= mHrZones[0]) {
    		return 0;
		} else if (hr >= mHrZones[5]) {
			return width;
		} else {
			return ((hr - mHrZones[0]) / (mHrZones[5] - mHrZones[0]).toFloat() * width).toNumber();
		}
    }

}

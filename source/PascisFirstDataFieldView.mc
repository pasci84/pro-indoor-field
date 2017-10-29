using Toybox.Activity;
using Toybox.Graphics as Gfx;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi as Ui;

class PascisFirstDataFieldView extends Ui.DataField {

	const NUM_SAMPLES_TO_DISPLAY_AVG = 2;
	const SPACER = 30;
    
    //calculation vars
    hidden var mWeight;
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
        
        mWeight = UserProfile.getProfile().weight;
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
        
		System.println(mWeight.format("%d") + " g");
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info) {
    	var timestamp = Time.now().value();
    	var newPowerAvgMap = {};
    	    	
    	//hr and cad
		mHr = info has :currentHeartRate ? info.currentHeartRate : 0;
    	mCad = info has :currentCadence ? info.currentCadence : 0;
    	    	
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

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
        var bgColor = getBackgroundColor();
        View.findDrawableById("Background").setColor(bgColor);
        
		//actual data
		updateField(View.findDrawableById("valueHr"), mHr > 0 ? mHr.format("%d") : "-", bgColor);
		//updateField(View.findDrawableById("valueCad"), mCad.format("%d"), bgColor);
		
		var displayLapData = mLapPowerSamples >= NUM_SAMPLES_TO_DISPLAY_AVG;
		var displayTotalData = mTotalPowerSamples >= NUM_SAMPLES_TO_DISPLAY_AVG;
        updateField(View.findDrawableById("value3sPower"), m3sAvgPower.format("%d"), bgColor);
        updateField(View.findDrawableById("value3sWkg"), m3sAvgPowerWkg.format("%.2f"), null);
        updateField(View.findDrawableById("valueLapPower"), displayLapData ? mLapAvgPower.format("%d") : "-", bgColor);
        updateField(View.findDrawableById("valueLapWkg"), displayLapData ? mLapAvgPowerWkg.format("%.2f") : "-", null);
        updateField(View.findDrawableById("valueTotalPower"), displayTotalData ? mTotalAvgPower.format("%d") : "-", bgColor);
        updateField(View.findDrawableById("valueTotalWkg"), displayTotalData ? mTotalAvgPowerWkg.format("%.2f") : "-", null);
        
        updateField(View.findDrawableById("valueLapTime"), formatDuration(mLapTime), null);
        updateField(View.findDrawableById("valueTotalTime"), formatDuration(mTotalTime), null);

		//draw contents of layouts.xml now
        View.onUpdate(dc);       
        
        //lines
        var firstThirdY = (dc.getHeight() / 3) * 0.9;
        var secondThirdY = (dc.getHeight() / 3) * 2.2;
        dc.setPenWidth(1);
   		dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(0, firstThirdY, dc.getWidth(), firstThirdY);
        dc.drawLine(0, secondThirdY, dc.getWidth(), secondThirdY);
        dc.drawLine(dc.getWidth() / 2, secondThirdY, dc.getWidth() / 2, dc.getHeight());
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
        var obscurityFlags = DataField.getObscurityFlags();
        View.setLayout(Rez.Layouts.MainLayout(dc));
        
        //layout vars
        var tableOffsetY = 0;
        var labelOffsetY = -32;
        var powerOffsetY = 0;
        var wkgOffsetY = 32;
        var columnOffsetX = (dc.getWidth() / 4) * 1.3;
        
        //top row
        var labelHr = View.findDrawableById("labelHr");
        labelHr.setText(Rez.Strings.labelHr);
        labelHr.locY = 1;
        var valueHr = View.findDrawableById("valueHr");
        valueHr.locY = 26;
        
        //label row
        var label3s = View.findDrawableById("label3s");
        label3s.setText(Rez.Strings.label3s);
        label3s.locX = label3s.locX - columnOffsetX;
        label3s.locY = label3s.locY + labelOffsetY + tableOffsetY;
        var labelLap = View.findDrawableById("labelLap");
        labelLap.setText(Rez.Strings.labelLap);
        labelLap.locY = labelLap.locY + labelOffsetY + tableOffsetY;
        var labelTotal = View.findDrawableById("labelTotal");
        labelTotal.setText(Rez.Strings.labelTotal);
        labelTotal.locX = labelTotal.locX + columnOffsetX;
        labelTotal.locY = labelTotal.locY + labelOffsetY + tableOffsetY;
        
        //power row
        var value3sPower = View.findDrawableById("value3sPower");
        value3sPower.locX = value3sPower.locX - columnOffsetX;
        value3sPower.locY = value3sPower.locY + powerOffsetY + tableOffsetY;
        var valueLapPower = View.findDrawableById("valueLapPower");
        valueLapPower.locY = valueLapPower.locY + powerOffsetY + tableOffsetY;
        var valueTotalPower = View.findDrawableById("valueTotalPower");
        valueTotalPower.locX = valueTotalPower.locX + columnOffsetX;
        valueTotalPower.locY = valueTotalPower.locY + powerOffsetY + tableOffsetY;
        
        //wkg row
        var value3sWkg = View.findDrawableById("value3sWkg");
        value3sWkg.locX = value3sWkg.locX - columnOffsetX;
        value3sWkg.locY = value3sWkg.locY + wkgOffsetY + tableOffsetY;
        var valueLapWkg = View.findDrawableById("valueLapWkg");
        valueLapWkg.locY = valueLapWkg.locY + wkgOffsetY + tableOffsetY;
        var valueTotalWkg = View.findDrawableById("valueTotalWkg");
        valueTotalWkg.locX = valueTotalWkg.locX + columnOffsetX;
        valueTotalWkg.locY = valueTotalWkg.locY + wkgOffsetY + tableOffsetY;
        
        //timer row
        var valueLapTime = View.findDrawableById("valueLapTime");
        valueLapTime.locX = valueLapTime.locX - dc.getWidth() / 5;
        valueLapTime.locY = valueLapTime.locY + 62;
        var valueTotalTime = View.findDrawableById("valueTotalTime");
        valueTotalTime.locX = valueTotalTime.locX + dc.getWidth() / 5;
        valueTotalTime.locY = valueTotalTime.locY + 62;
        
        return true;
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
    }
    
    function getPausedDuration(momentFrom, momentTo)
    {
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
    
    function isTimerRunning()
    {
    	return Activity.getActivityInfo().timerState == Activity.TIMER_STATE_ON;
    }
    
    function updateField(field, text, bgColor) {
	    if (bgColor != null) {
    		field.setColor(bgColor == Gfx.COLOR_BLACK ? Gfx.COLOR_WHITE : Gfx.COLOR_BLACK);
		}
    	field.setText(text);
    }
    
    function powerToWkg(power)
    {
    	return power == 0 ? 0 : power / mWeight * 1000;
    }
    
    function outputPauses()
    {
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
    
    function formatDuration(duration)
    {
    	var seconds = duration.value();    
    	var h = Math.floor(seconds / 3600);
    	var m = Math.floor((seconds % 3600) / 60);
    	var s = Math.round(seconds % 60);    	
    	return h.format("%02d") + ":" + m.format("%02d") + ":" + s.format("%02d");
    }
    
    function formatMoment(moment)
    {
    	var date = Time.Gregorian.info(moment, Time.FORMAT_MEDIUM);
    	return date.hour + ":" + date.min + ":" + date.sec;
    }

    function isSingleFieldLayout() {
        return (DataField.getObscurityFlags() == OBSCURE_TOP | OBSCURE_LEFT | OBSCURE_BOTTOM | OBSCURE_RIGHT);
    }

}

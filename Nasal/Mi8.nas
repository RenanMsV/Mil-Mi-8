############################################################
##  Adapted from R22.nas for R44 by Clement DE L'HAMAIDE  ##
##                  Date : 05/05/2011                     ##
##          Trying to use it again in the Mi8             ##
############################################################

# Few notes about this
# How this works? Yasim doesnt have an default engine system, so thats why we need to create our own.
# How this helicopter engine system works? We have 2 systems, the engine system (/engines/engine/rpm), which is there just to create an illusion of an engine running with values, sounds and so... and the rotor system, which seems to be the one who drives the helicopter (/rotor/main/rpm), if the rotor rpm increases the helicopter power increases, if it gets too low the helicopter will fall like a rock. Also rotor diameter seems to increase its power too.

var RPM_arm=props.globals.getNode("/instrumentation/alerts/rpm",1);
var last_time = 0;
var start_timer=0;
var GPS = 0.002222;  ### avg cruise = 8 gph
var Fuel_Density=6.0;
var Fuel1_Level= props.globals.getNode("/consumables/fuel/tank/level-gal_us",1);
var Fuel1_LBS= props.globals.getNode("/consumables/fuel/tank/level-lbs",1);
var TotalFuelG=props.globals.getNode("/consumables/fuel/total-fuel-gals",1);
var TotalFuelP=props.globals.getNode("/consumables/fuel/total-fuel-lbs",1);
var NoFuel=props.globals.getNode("/engines/engine/out-of-fuel",1);

var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10);
FHmeter.stop();

# doors
var cargo_door = aircraft.door.new("controls/switches/fuselage/cargo-door/", 7);
props.globals.getNode("controls/switches/fuselage/left-door-x/position-norm", 1).setDoubleValue(0);
props.globals.getNode("controls/switches/fuselage/left-door-y/position-norm", 1).setDoubleValue(0);

setlistener("/sim/signals/fdm-initialized", func {
    Fuel_Density=props.globals.getNode("/consumables/fuel/tank/density-ppg").getValue();
    setprop("/instrumentation/clock/flight-meter-hour",0);
    RPM_arm.setBoolValue(0);
    print("Systems ... Check");
    settimer(update_systems,2);
    setprop("sim/model/sound/volume", 0.5);
    setprop("/instrumentation/doors/Rcrew/position-norm",1);
    
    # COMM1 (according to its documentation)
aircraft.data.add(
    "instrumentation/comm[0]/power-btn",
    "instrumentation/comm[0]/volume",
    "instrumentation/comm[0]/frequencies/selected-mhz",
    "instrumentation/comm[0]/frequencies/standby-mhz",
    "instrumentation/comm[0]/frequencies/dial-khz",
    "instrumentation/comm[0]/frequencies/dial-mhz",
    "instrumentation/comm[0]/test-btn",
    "instrumentation/nav[0]/audio-btn",
    "instrumentation/nav[0]/power-btn",
    "instrumentation/nav[0]/volume",
    "instrumentation/nav[0]/frequencies/selected-mhz",
    "instrumentation/nav[0]/frequencies/standby-mhz",
    "instrumentation/nav[0]/frequencies/dial-khz",
    "instrumentation/nav[0]/frequencies/dial-mhz",
    "instrumentation/nav[0]/radials/selected-deg",
);
setprop("/Mi8/engines/engine[0]/mp-pressure",1);
setprop("/sim/model/Mi8/gps-visible",1);
 


# mhab merged from woolthread.nas
# Simple vibrating yawstring

var yawstring = func {

  var airspeed = getprop("/velocities/airspeed-kt");
  # mhab fix
  if ( airspeed == nil ) airspeed=0;
  var rpm = getprop("/rotors/main/rpm");
  var severity = 0;

  if ( (airspeed < 137) and (rpm >170)) {
    severity = ( math.sin (math.pi*airspeed/137) * (rand()*12) ) ;
  }

  var position = getprop("/orientation/side-slip-deg") + severity ;
  setprop("/instrumentation/yawstring",position);
  settimer(yawstring,0);

}

# Start the yawstring ASAP
yawstring();


});

setlistener("/sim/signals/reinit", func {
    RPM_arm.setBoolValue(0);
    setprop("/controls/engines/engine/throttle",1);
});


setlistener("/controls/lighting/instruments-norm", func {
    var light = getprop("/controls/lighting/instruments-norm");
    setprop("controls/lighting/radio-norm",light);
});

setlistener("/sim/current-view/view-number", func(vw) {
    var nm = vw.getValue();
    setprop("sim/model/sound/volume", 1.0);
    if(nm == 0 or nm == 7)setprop("sim/model/sound/volume", 0.5);
},1,0);

setlistener("/gear/gear[1]/wow", func(gr) {
    if(gr.getBoolValue()){
    FHmeter.stop();
    }else{FHmeter.start();}
},0,0);

setlistener("/engines/engine/out-of-fuel", func(fl) {
    var nofuel = fl.getBoolValue();
    if(nofuel)kill_engine();
},0,0);

setlistener("/controls/electric/key", func(key){
    var key = key.getValue();
    if(key == 0)kill_engine();
},0,0);

##############################################
######### AUTOSTART / AUTOSHUTDOWN ###########
##############################################

setlistener("/sim/model/start-idling", func(idle){
    if (idle.getBoolValue()) Startup(); else Shutdown();
},0,0);

var Startup = func {
  setprop("/controls/electric/battery-switch",1);
  setprop("/controls/electric/engine/generator",1);
  setprop("/controls/electric/key",4);
  setprop("/controls/engines/engine[0]/clutch",1);
  props.globals.getNode("/controls/engines/engine[0]/starter").setBoolValue(1);
  setprop("engines/engine[0]/running", 1);
  gui.popupTip("Engines starting...", 4);
}

setlistener("/controls/engines/engine/starter", func(idle){
    var run= idle.getBoolValue();
    if (!run) return;
    setprop("/engines/engine/clutch-engaged", 1);
},0,0);

var Shutdown = func {
  setprop("/controls/electric/battery-switch",0);
  setprop("/controls/electric/engine/generator",0);
  setprop("/controls/electric/key",0);
  setprop("/controls/engines/engine[0]/clutch",0);
  props.globals.getNode("/controls/engines/engine[0]/starter").setBoolValue(0);
  gui.popupTip("Engines shutdown, you can brake the rotor by holding 'r'", 4);
}

###############################################
###############################################
###############################################

var flight_meter = func{
  var fmeter = getprop("/instrumentation/clock/flight-meter-sec");
  var fminute = fmeter * 0.016666;
  var fhour = fminute * 0.016666;
  setprop("/instrumentation/clock/flight-meter-hour",fhour);
}

var kill_engine=func{
        setprop("/controls/engines/engine/magnetos",0);
        setprop("/engines/engine/clutch-engaged",0);
        setprop("/engines/engine/running",0);
        start_timer=0;
}

var update_fuel = func{
    var amnt = arg[0] * GPS;
    amnt = amnt * 0.5;
    var lvl = Fuel1_Level.getValue();
    lvl = lvl-amnt;
    if(lvl < 0.0)lvl = 0.0;
    Fuel1_Level.setDoubleValue(lvl);
    Fuel1_LBS.setDoubleValue(lvl * Fuel_Density);
    TotalFuelG.setDoubleValue(lvl);
    TotalFuelP.setDoubleValue(lvl * Fuel_Density);
    if(lvl < 0.2){
        if(!NoFuel.getBoolValue()){
            NoFuel.setBoolValue(1);
        }
    }
}

var update_systems = func {
	var time = getprop("/sim/time/elapsed-sec");
	var dt = time - last_time;
	last_time = time;
	var throttle = getprop("/controls/rotor/engine-throttle");
	if(getprop("engines/engine/running"))update_fuel(dt);
	flight_meter();
	if(!RPM_arm.getBoolValue()){
	if(getprop("/rotors/main/rpm") > 525)RPM_arm.setBoolValue(1);
	}
	

	if(getprop("/systems/electrical/outputs/starter") > 11){
	    if(getprop("/controls/electric/key") > 2){
	      setprop("/engines/engine/cranking",1);
	    }
	    if(getprop("/controls/engines/engine/clutch")){
	      setprop("/engines/engine/clutch-engaged",1);
	    } else {
	      setprop("/engines/engine/clutch-engaged",0);
	    }
	}else{
	    setprop("/engines/engine/cranking",0);
	}

	if(getprop("/engines/engine/cranking") != 0){
	    if(!getprop("/engines/engine/running")){
	    start_timer +=1;
	    }else{start_timer = 0;}
	}

	if(start_timer > 40){
	    setprop("/engines/engine/running",1);
	    start_timer = 0;
	    }

	if(getprop("/engines/engine/running")){
	
	#when engine on moves fuel pressure and temperature gaguges NOTE: not realistic!! fix later
	interpolate("oilpressure",24,0.6);
	interpolate("oiltemp",24,20);
	
	var engineTrottle = getprop("/controls/engines/engine/throttle"); #mp gauge based on throttle
    
     interpolate("/Mi8/engines/engine[0]/mp-pressure", (engineTrottle*0.44) + 0.45, 0.9);
    
    
	

        if(getprop("/engines/engine/amp-v") > 0){
            if(getprop("/engines/engine/clutch-engaged")){
            interpolate("/rotors/main/rpm", 2700 * throttle, 7); # .9
            interpolate("/rotors/tail/rpm", 2700 * throttle, 7); # .9
            }else{
            interpolate("/rotors/main/rpm", 0, 0.2);
            interpolate("/rotors/tail/rpm", 0, 0.2);
            }
            interpolate("/engines/engine/rpm", 2700 * throttle, 7); # 0.8
        } else {
            if(!getprop("/controls/engines/engine/generator") and getprop("/engines/engine/amp-v") < 2){
            setprop("/engines/engine/clutch-engaged",0);
            setprop("/engines/engine/running",0);
            }
        }
	}else{
	interpolate("oilpressure",0,0.6);
	interpolate("oiltemp",0,20);
	
	  interpolate("/engines/engine/rpm", 0, 7); # 0.8
	  interpolate("/rotors/main/rpm", 0, 7); # .4
	  interpolate("/rotors/tail/rpm", 0, 7); # .4
      setprop("/Mi8/engines/engine[0]/mp-pressure",1);
	}
	
	if(getprop("/consumables/fuel/total-fuel-lbs") == 0) {
          setprop("/engines/engine/running",0);
	}
	settimer(update_systems,0);
}

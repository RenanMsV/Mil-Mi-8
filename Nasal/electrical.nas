####    Single Starter/Generator electrical system    ####
####    Syd Adams    ####
#### Based on Curtis Olson's nasal electrical code ####

var last_time = 0.0;
var OutPuts = props.globals.getNode("/systems/electrical/outputs",1);
var Volts = props.globals.getNode("/systems/electrical/volts",1);
var Amps = props.globals.getNode("/systems/electrical/amps",1);
var BATT = props.globals.getNode("/controls/electric/battery-switch",1);
var ALT = props.globals.getNode("/controls/electric/engine/generator",1);
var DIMMER = props.globals.getNode("/controls/lighting/instruments-norm",1);
var NORM = 0.0357;
var Battery={};
var Alternator={};


#var battery = Battery.new(volts,amps,amp_hours,charge_percent,charge_amps);

Battery = {
    new : func {
        m = { parents : [Battery] };
        m.ideal_volts = arg[0];
        m.ideal_amps = arg[1];
        m.amp_hours = arg[2];
        m.charge_percent = arg[3];
        m.charge_amps = arg[4];
    return m;
    },

    apply_load : func {
        var amphrs_used = arg[0] * arg[1] / 3600.0;
        var percent_used = amphrs_used / me.amp_hours;
        me.charge_percent -= percent_used;
        if ( me.charge_percent < 0.0 ) {
            me.charge_percent = 0.0;
        } elsif ( me.charge_percent > 1.0 ) {
            me.charge_percent = 1.0;
        }
        return me.amp_hours * me.charge_percent;
    },

    get_output_volts : func {
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        return me.ideal_volts * factor;
    },

    get_output_amps : func {
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        return me.ideal_amps * factor;
    }
};


# var alternator = Alternator.new("rpm-source",rpm_threshold,volts,amps);

Alternator = {
    new : func {
        m = { parents : [Alternator] };
        m.rpm_source =  props.globals.getNode(arg[0],1);
        m.rpm_threshold = arg[1];
        m.ideal_volts = arg[2];
        m.ideal_amps = arg[3];
        return m;
    },

    apply_load : func( amps, dt) {
        var factor = me.rpm_source.getValue() / me.rpm_threshold;
        if ( factor > 1.0 ){
            factor = 1.0;
        }
        var available_amps = me.ideal_amps * factor;
        return available_amps - amps;
    },

    get_output_volts : func {
        var factor = me.rpm_source.getValue() / me.rpm_threshold;
        if ( factor > 1.0 ) {
            factor = 1.0;
            }
        return me.ideal_volts * factor;
    },

    get_output_amps : func {
        var factor = me.rpm_source.getValue() / me.rpm_threshold;
        if ( factor > 1.0 ) {
            factor = 1.0;
        }
        return me.ideal_amps * factor;
    }
};

var battery = Battery.new(12,30,12,1.0,7.0);
var alternator = Alternator.new("/rotors/main/rpm",250.0,12.0,30.0);

#####################################
setlistener("/sim/signals/fdm-initialized", func {
    foreach(var a; props.globals.getNode("/systems/electrical/outputs").getChildren()){
       a.setValue(0);
    }
    props.globals.getNode("/controls/anti-ice/prop-heat",1).setBoolValue(0);
    props.globals.getNode("/controls/anti-ice/pitot-heat",1).setBoolValue(0);
    props.globals.getNode("/controls/lighting/landing-lights[0]",1).setBoolValue(0);
    props.globals.getNode("/controls/lighting/landing-lights[1]",1).setBoolValue(0);
    props.globals.getNode("/controls/lighting/beacon",1).setBoolValue(0);
    props.globals.getNode("/controls/lighting/nav-lights",1).setBoolValue(0);
    props.globals.getNode("/controls/lighting/cabin-lights",1).setBoolValue(0);
    props.globals.getNode("/controls/lighting/wing-lights",1).setBoolValue(0);
    props.globals.getNode("/controls/lighting/strobe",1).setBoolValue(0);
    props.globals.getNode("/controls/lighting/instrument-lights",1).setBoolValue(1);
    props.globals.getNode("/controls/lighting/instruments-norm",1).setBoolValue(1);
    props.globals.getNode("/controls/lighting/taxi-light",1).setBoolValue(0);
    props.globals.getNode("/controls/cabin/fan",1).setBoolValue(0);
    props.globals.getNode("/controls/cabin/heat",1).setBoolValue(0);
    props.globals.getNode("/controls/electric/external-power",1).setBoolValue(0);
    props.globals.getNode("/controls/electric/battery-switch",1).setBoolValue(0);
    props.globals.getNode("/controls/electric/key",1).setValue(0);
    props.globals.getNode("/controls/electric/engine/generator",1).setBoolValue(0);
    props.globals.getNode("/controls/engines/engine/magnetos",1).setBoolValue(0);
    props.globals.getNode("/controls/engines/engine/throttle",1).setValue("1");
    props.globals.getNode("/engines/engine/amp-v",1).setDoubleValue(0);
    props.globals.getNode("/controls/engines/engine/clutch",1).setBoolValue(0);
    props.globals.getNode("/controls/engines/engine/clutchguard",1).setBoolValue(0);
    props.globals.getNode("/controls/engines/engine/master-alt",1).setBoolValue(0);
    props.globals.getNode("/controls/engines/engine/master-bat",1).setBoolValue(0);
    props.globals.getNode("/controls/engines/engine/fuel-pump",1).setBoolValue(1);
    settimer(update_electrical,1);
    print("Electrical System ... OK");
});

var bus_volts = 0.0;
var update_virtual_bus = func(dt) {
    var PWR = props.globals.getNode("systems/electrical/serviceable",1).getBoolValue();
    var engine_state = props.globals.getNode("/engines/engine/running",1).getBoolValue();
    var AltVolts = alternator.get_output_volts();
    var BatVolts = battery.get_output_volts();
    var load = 0.0;

    if (ALT.getBoolValue() and (AltVolts > (bus_volts-2))){       # Si le moteur tourne, et que le switch Alt est à ON et que la tension de l'alternateur est supérieur à celle du bus
        props.globals.getNode("/engines/engine/amp-v",1).setValue(AltVolts);   # L'alternateur fournit la tension au moteur
    } elsif (BATT.getBoolValue()){                                             # Sinon si le switch de la batterie est à ON
        props.globals.getNode("/engines/engine/amp-v",1).setValue(BatVolts);   # C'est la batterie qui fournie la tension au moteur
    } else {
        props.globals.getNode("/engines/engine/amp-v",1).setValue(0.0);
    }

    var bus_amps = 0.0;
    var power_source = nil;

    if (BATT.getBoolValue()){
        if(PWR){bus_volts = BatVolts;}
        power_source = "battery";
    } else {
        bus_volts = 0.0;
    }
    if (ALT.getBoolValue() and (AltVolts > (bus_volts-2))){
        if(PWR){bus_volts = AltVolts;}
        power_source = "alternator";
    }

    load += electrical_bus(bus_volts);
    load += avionics_bus(bus_volts);

    if (bus_volts > 1.0){
        if (power_source == "battery") {       # si la source est la batterie
            bus_amps = load;                   # l'intensité utilisé par le bus est la charge de tout
        } else {                               # sinon
            bus_amps = battery.charge_amps;    # Sinon l'amperage du bus = 7A fourni par l'alternateur (mais limité à 7 par la batterie)
        }
    }

    if (power_source == "battery"){                      # si la source est la batterie
        battery.apply_load(load, dt);                    # on decharge la batterie
    } elsif (bus_volts > BatVolts){                      # sinon si la tension du bus est plus grande que la tension de la batterie
        battery.apply_load(-battery.charge_amps, dt);    # on charge la batterie en lui envoyant 7A
    }

    Amps.setValue(bus_amps);
    Volts.setValue(bus_volts);
    return load;
}

var electrical_bus = func(){
    var load = 0.0;
    var bus_volts = arg[0];
    var starter_volts = 0.0;

    if(props.globals.getNode("/controls/lighting/landing-lights").getBoolValue()){
        OutPuts.getNode("landing-lights",1).setValue(bus_volts);
        load += 1.2;
    } else {
        OutPuts.getNode("landing-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/nav-lights").getBoolValue()){
        OutPuts.getNode("nav-lights",1).setValue(bus_volts);
        load += 0.2;
    } else {
        OutPuts.getNode("nav-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/taxi-light").getBoolValue()){
        OutPuts.getNode("taxi-light",1).setValue(bus_volts);
        load += 1.2;
    } else {
        OutPuts.getNode("taxi-light",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/beacon").getBoolValue()){
        OutPuts.getNode("beacon",1).setValue(bus_volts);
        load += 1.2;
    } else {
        OutPuts.getNode("beacon",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/cabin-lights").getBoolValue()){
        OutPuts.getNode("cabin-lights",1).setValue(bus_volts);
        load += 0.6;
    } else {
        OutPuts.getNode("cabin-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/engines/engine[0]/fuel-pump").getBoolValue()){
        OutPuts.getNode("fuel-pump",1).setValue(bus_volts);
        load += 1.2;
    } else {
        OutPuts.getNode("fuel-pump",1).setValue(0.0);
    }
    

    if (props.globals.getNode("/controls/engines/engine[0]/starter").getBoolValue()){
        starter_volts = bus_volts;
        load += 8.0;
#	print("Start engine");
    }
    OutPuts.getNode("starter",1).setValue(starter_volts);

    return load;
}

var avionics_bus = func() {
    var load = 0.0;
    var bus_volts = arg[0];

    if (props.globals.getNode("/controls/lighting/instrument-lights").getBoolValue()){
        OutPuts.getNode("instrument-lights",1).setValue((bus_volts) * DIMMER.getValue());
        load += 0.25 * DIMMER.getValue();
    } else {
        OutPuts.getNode("instrument-lights",1).setValue(0.0);
    }
    if (!getprop('/controls/electric/battery-switch') and !getprop('/controls/electric/engine[0]/generator')) {
        setprop("/controls/lighting/instrument-lights",0);
    }else{
        setprop("/controls/lighting/instrument-lights",1);
    }
    
#    OutPuts.getNode("transponder",1).setValue(bus_volts);
#    OutPuts.getNode("nav[0]",1).setValue(bus_volts);
#    OutPuts.getNode("nav[1]",1).setValue(bus_volts);
#    OutPuts.getNode("comm[0]",1).setValue(bus_volts);
#    OutPuts.getNode("comm[1]",1).setValue(bus_volts);

  setprop("/systems/electrical/outputs/nav[1]", bus_volts);
  setprop("/systems/electrical/outputs/comm[1]", bus_volts);
 
  if(bus_volts > 0) {  #if there is power then turn on the radios
     setprop("/sim/model/c172p/lighting/comm1-power",  DIMMER.getValue());
  } else {
     setprop("/sim/model/c172p/lighting/comm1-power", 0);
  }
 


    return load;
}

var update_electrical = func {
    var time = getprop("/sim/time/elapsed-sec");
    var dt = time - last_time;
    var last_time = time;
    update_virtual_bus(dt);
    settimer(update_electrical, 0);
}

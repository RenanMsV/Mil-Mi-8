# creating beacon and strobe
var beacon_switch = props.globals.getNode("controls/switches/beacon", 2);
var beacon = aircraft.light.new( "/sim/model/lights/beacon", [0, 3], "/controls/lighting/beacon" );
var strobe_switch = props.globals.getNode("controls/switches/strobe", 2);
var strobe = aircraft.light.new( "/sim/model/lights/strobe", [0, 3], "/controls/lighting/strobe" );

# ALS light manager - requires user to have ALS and shaders enabled
# provides relative vectors from eye-point to aircraft lights
# in east/north/up coordinates the renderer uses

var light_manager = {

    lat_to_m: 110952.0,
    lon_to_m: 0.0,

    light1_xpos: 0.0,
    light1_ypos: 0.0,
    light1_zpos: 0.0,
    light1_r: 0.0,
    light1_g: 0.0,
    light1_b: 0.0,
    light1_size: 0.0,
    light1_stretch: 0.0,

    light2_xpos: 0.0,
    light2_ypos: 0.0,
    light2_zpos: 0.0,
    light2_r: 0.0,
    light2_g: 0.0,
    light2_b: 0.0,
    light2_size: 0.0,
    light2_stretch: 0.0,

    light3_xpos: 0.0,
    light3_ypos: 0.0,
    light3_zpos: 0.0,
    light3_r: 0.0,
    light3_g: 0.0,
    light3_b: 0.0,
    light3_size: 0.0,

    light4_xpos: 0.0,
    light4_ypos: 0.0,
    light4_zpos: 0.0,
    light4_r: 0.0,
    light4_g: 0.0,
    light4_b: 0.0,
    light4_size: 0.0,

    init: func {
        # define your lights here

        # light 1 ######## landing
        # offsets to aircraft center
        me.light1_xpos = 4.0;
        me.light1_ypos = -1.0;
        me.light1_zpos =  0.0;

        # color values
        me.light1_r = 0.5;
        me.light1_g = 0.5;
        me.light1_b = 0.5;

        # spot size
        me.light1_size = 5.0;
        me.light1_stretch = 1;

        # light 2 ######## beacon
        # offsets to aircraft center
        me.light2_xpos = -2.0;
        me.light2_ypos = 0.0;
        me.light2_zpos =  0.0;

        # color values
        me.light2_r = 0.1;
        me.light2_g = 0.0;
        me.light2_b = 0.0;

        # spot size
         me.light2_size = 10.0;
         me.light2_stretch = 1.5;

        # light 3 ######## nav right green
        # offsets to aircraft center
        me.light3_xpos = 7;
        me.light3_ypos = -2.0;
        me.light3_zpos = 0.0;

        # color values
        me.light3_r = 0.0;
        me.light3_g = .5;
        me.light3_b = 0.0;

        # spot size
        me.light3_size = 5.0;

        # light 4 ######## nav left red
        # offsets to aircraft center
        me.light4_xpos = 7;
        me.light4_ypos = 2.0;
        me.light4_zpos = 0.0;

        # color values
        me.light4_r = .7;
        me.light4_g = 0.0;
        me.light4_b = 0.0;

        # spot size
        me.light4_size = 5.0;

        # light 5 ######## strobe
        # offsets to aircraft center
        me.light5_xpos = 0.0;
        me.light5_ypos = 0.0;
        me.light5_zpos = 0.0;

        # color values
        me.light5_r = .2;
        me.light5_g = .2;
        me.light5_b = .2;

        # spot size
        me.light5_size = 10.0;

        # als landing light setup

        als_light_offset_1 = -6.0;
        als_light_offset_2 = 6.0;
        als_light_offset_3 = 0.0;

        setprop("/sim/rendering/als-secondary-lights/landing-light1-offset-deg", als_light_offset_1);
        setprop("/sim/rendering/als-secondary-lights/landing-light2-offset-deg", als_light_offset_2);
        setprop("/sim/rendering/als-secondary-lights/landing-light3-offset-deg", als_light_offset_3);
        
        me.light_manager_timer = maketimer(0.0, func{me.update()});
        
        me.start();
    },

    start: func {
        setprop("/sim/rendering/als-secondary-lights/num-lightspots", 5);

        setprop("/sim/rendering/als-secondary-lights/lightspot/size", me.light1_size);
        setprop("/sim/rendering/als-secondary-lights/lightspot/size[1]", me.light2_size);
        setprop("/sim/rendering/als-secondary-lights/lightspot/size[2]", me.light3_size);
        setprop("/sim/rendering/als-secondary-lights/lightspot/size[3]", me.light4_size);
        setprop("/sim/rendering/als-secondary-lights/lightspot/size[4]", me.light5_size);

        setprop("/sim/rendering/als-secondary-lights/lightspot/stretch", me.light1_stretch);
        setprop("/sim/rendering/als-secondary-lights/lightspot/stretch[1]", me.light2_stretch);

        me.light_manager_timer.start();
    },

    stop: func {
        me.light_manager_timer.stop();
    },

    update: func {

        if (!getprop("/sim/rendering/shaders/skydome")) return; # return if ALS not enabled
        var apos = geo.aircraft_position();
        var vpos = geo.viewer_position();

        me.lon_to_m = math.cos(apos.lat()*math.pi/180.0) * me.lat_to_m;

        var heading = getprop("/orientation/heading-deg") * math.pi/180.0;

        var lat = apos.lat();
        var lon = apos.lon();
        var alt = apos.alt();

        var sh = math.sin(heading);
        var ch = math.cos(heading);

        # light 1 position
        var alt_agl = getprop("/position/altitude-agl-ft");

        var proj_x = alt_agl;
        var proj_z = alt_agl/10.0;

        apos.set_lat(lat + ((me.light1_xpos + proj_x) * ch + me.light1_ypos * sh) / me.lat_to_m);
        apos.set_lon(lon + ((me.light1_xpos + proj_x)* sh - me.light1_ypos * ch) / me.lon_to_m);

        var delta_x = (apos.lat() - vpos.lat()) * me.lat_to_m;
        var delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
        var delta_z = apos.alt()- proj_z - vpos.alt();

        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-x-m", delta_x);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-y-m", delta_y);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-z-m", delta_z);
        setprop("/sim/rendering/als-secondary-lights/lightspot/dir", heading);

        # light 2 position
        var alt_agl = getprop("/position/altitude-agl-ft");

        var proj_x = alt_agl;
        var proj_z = alt_agl/10.0;

        apos.set_lat(lat + ((me.light2_xpos + proj_x) * ch + me.light2_ypos * sh) / me.lat_to_m);
        apos.set_lon(lon + ((me.light2_xpos + proj_x)* sh - me.light2_ypos * ch) / me.lon_to_m);

        var delta_x = (apos.lat() - vpos.lat()) * me.lat_to_m;
        var delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
        var delta_z = apos.alt()- proj_z - vpos.alt();

        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[1]", delta_x);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[1]", delta_y);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[1]", delta_z);
        setprop("/sim/rendering/als-secondary-lights/lightspot/dir", heading);

        # light 3 position
        apos.set_lat(lat + (me.light3_xpos * ch + me.light3_ypos * sh) / me.lat_to_m);
        apos.set_lon(lon + (me.light3_xpos * sh - me.light3_ypos * ch) / me.lon_to_m);

        delta_x = (apos.lat() - vpos.lat()) * me.lat_to_m;
        delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
        delta_z = apos.alt() - vpos.alt();

        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[2]", delta_x);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[2]", delta_y);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[2]", delta_z);

        # light 4 position
        apos.set_lat(lat + (me.light4_xpos * ch + me.light4_ypos * sh) / me.lat_to_m);
        apos.set_lon(lon + (me.light4_xpos * sh - me.light4_ypos * ch) / me.lon_to_m);

        delta_x = (apos.lat() - vpos.lat()) * me.lat_to_m;
        delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
        delta_z = apos.alt() - vpos.alt();

        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[3]", delta_x);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[3]", delta_y);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[3]", delta_z);

        # light 5 position
        apos.set_lat(lat + (me.light5_xpos * ch + me.light5_ypos * sh) / me.lat_to_m);
        apos.set_lon(lon + (me.light5_xpos * sh - me.light5_ypos * ch) / me.lon_to_m);

        delta_x = (apos.lat() - vpos.lat()) * me.lat_to_m;
        delta_y = -(apos.lon() - vpos.lon()) * me.lon_to_m;
        delta_z = apos.alt() - vpos.alt();

        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-x-m[4]", delta_x);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-y-m[4]", delta_y);
        setprop("/sim/rendering/als-secondary-lights/lightspot/eyerel-z-m[4]", delta_z);

    },   

    switch_position: func(light, lightr, lightg, lightb) {
        setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-r["~light~"]", lightr);
        setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-g["~light~"]", lightg);
        setprop("/sim/rendering/als-secondary-lights/lightspot/lightspot-b["~light~"]", lightb);
    },

    enable_or_disable: func (enable, light_num) {
        if (enable) {
            if (light_num == 0)
                me.switch_position(light_num, me.light1_r, me.light1_g, me.light1_b);
            if (light_num == 1)
                me.switch_position(light_num, me.light2_r, me.light2_g, me.light2_b);
            if (light_num == 2)
                me.switch_position(light_num, me.light3_r, me.light3_g, me.light3_b);
            if (light_num == 3)
                me.switch_position(light_num, me.light4_r, me.light4_g, me.light4_b);
            if (light_num == 4)
                me.switch_position(light_num, me.light5_r, me.light5_g, me.light5_b);
        } else {
            me.switch_position(light_num, 0.0, 0.0, 0.0);
        }
    },

};

setlistener("/sim/signals/fdm-initialized", func {

    light_manager.init();

    # landing
    setlistener("/sim/rendering/als-secondary-lights/use-landing-light-ext", func (node) {
        light_manager.enable_or_disable(node.getValue(), 0);
    }, 1, 0);

    # beacon
    setlistener("/sim/rendering/als-secondary-lights/use-taxi-light-ext", func (node) {
        light_manager.enable_or_disable(node.getValue(), 1);
    }, 1, 0);

    setlistener("/sim/model/lights/beacon/state", func (node) {
        setprop("/sim/rendering/als-secondary-lights/use-taxi-light-ext", node.getValue());
    }, 1, 0);

    # nav
    setlistener("/controls/lighting/nav-lights", func (node) {
        light_manager.enable_or_disable(node.getValue(), 2);
        light_manager.enable_or_disable(node.getValue(), 3);
    }, 1, 0);

    # strobe
    setlistener("/sim/rendering/als-secondary-lights/use-strobe-light-ext", func (node) {
        light_manager.enable_or_disable(node.getValue(), 4);
    }, 1, 0);

    setlistener("/sim/model/lights/strobe/state", func (node) {
        setprop("/sim/rendering/als-secondary-lights/use-strobe-light-ext", node.getValue());
    }, 1, 0);

    # no landing lights at external view 
    setlistener("/sim/current-view/internal", func (node) {
        if (!getprop("/controls/lighting/landing-lights") and !getprop("/controls/lighting/taxi-light")) return;
            setprop("/sim/rendering/als-secondary-lights/use-alt-landing-light", node.getValue());
            setprop("/sim/rendering/als-secondary-lights/use-landing-light", node.getValue());
    }, 1, 0);
});
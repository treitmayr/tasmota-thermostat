import persist
import string
import math

# lv_thermostat_card class

class lv_thermostat_card : lv.obj
    static var _setpoint_resolution = 10
    static var _arc_angle = 270
    static var _timer_id = "ltc_tmr"
    static var _persist_delay = 5 * 60 * 1000    # 5 minutes
    var arc
    var diff_arc
    var _setpoint_knob
    var _temp_knob
    var _setpoint_label
    var _temp_label
    var _setpoint_unit

    var _min
    var _max
    var _setpoint
    var _measured_temp
    var _humidity
    var _val_rule
    var _hum_rule
    var _hot_color
    var _cold_color

    def init(parent)
        super(self).init(parent)

        self._min = 0
        self._max = 0
        self._hot_color = lv.color(lv.COLOR_ORANGE)
        self._cold_color = lv.color(lv.COLOR_BLUE)

        # create main arc
        var arc = lv.arc(self)
        arc.set_bg_angles(0, self._arc_angle)
        arc.set_change_rate(30)         # °/s
        arc.add_flag(lv.OBJ_FLAG_ADV_HITTEST)
        arc.add_event_cb( / -> self._arc_changed(), lv.EVENT_VALUE_CHANGED, 0)
        self.arc = arc

        # create difference arc
        arc = lv.arc(self.arc)
        arc.set_bg_angles(0, 1)    # will be adjusted by measurement changes
        arc.set_range(0, 1)
        arc.set_value(1)
        arc.clear_flag(lv.OBJ_FLAG_CLICKABLE)
        # no background arc needed
        arc.remove_style(nil, lv.PART_MAIN)
        self.diff_arc = arc

        for a: [self.arc, self.diff_arc]
            a.set_rotation(self._arc_angle / 2)
            a.set_align(lv.ALIGN_CENTER)
            a.remove_style(nil, lv.PART_KNOB)
            for p: [lv.PART_MAIN, lv.PART_INDICATOR]
                a.set_style_border_width(0, p)
                a.set_style_pad_all(0, p)
            end
        end

        var knob
        knob = lv.obj(self.diff_arc)
        knob.set_style_bg_opa(lv.OPA_COVER, lv.PART_MAIN)
        var bg = self.get_style_bg_color_filtered(lv.PART_MAIN)    # filtered??
        knob.set_style_bg_color(bg, lv.PART_MAIN)
        self._setpoint_knob = knob

        knob = lv.obj(self.diff_arc)
        self._temp_knob = knob

        for k: [self._setpoint_knob, self._temp_knob]
            k.set_style_pad_all(0, 0)
            k.set_style_margin_all(0, 0)
            k.add_flag(lv.OBJ_FLAG_EVENT_BUBBLE)
            k.clear_flag(lv.OBJ_FLAG_CLICKABLE)
        end

        var label = lv.label(self.arc)
        label.set_style_pad_all(0, 0)
        label.set_style_margin_all(0, 0)
        #label.set_align(lv.ALIGN_CENTER)
        var font = lv.load_font("A:big_num.font")
        var height = lv.font_get_line_height(font)
        label.align(lv.ALIGN_CENTER, 0, int(-height/2.2))
        label.set_style_text_font(font, lv.PART_MAIN)
        label.set_text("")
        self._setpoint_label = label

        label = lv.label(self.arc)
        label.set_style_pad_all(0, 0)
        label.set_style_margin_all(0, 0)
        label.align_to(self._setpoint_label, lv.ALIGN_OUT_RIGHT_TOP, 0, 0)
        label.set_style_text_font(lv.montserrat_font(14), lv.PART_MAIN)
        label.set_text("°C")
        self._setpoint_unit = label

        label = lv.label(self.arc)
        label.set_style_pad_all(0, 0)
        label.set_style_margin_all(0, 0)
        font = lv.load_font("A:medium.font")
        height = lv.font_get_line_height(font)
        #label.set_style_pad_top(height / 2, 0)
        label.set_style_text_font(font, lv.PART_MAIN)
        label.align(lv.ALIGN_CENTER, 0, int(height * 1.5))
        label.set_text("")
        self._temp_label = label

        self.add_event_cb( / -> self._size_changed(), lv.EVENT_SIZE_CHANGED, 0)
        self.add_event_cb( / -> self._size_changed(), lv.EVENT_STYLE_CHANGED, 0)

        self._read_persistent_storage()

        # delayed initialization
        tasmota.set_timer(5000, / -> self.post_config(), "thermini")
    end

    def post_config()
        tasmota.remove_timer("thermini")
        self._set_setpoint()
    end

    def set_min(t)
        self._min = t
        if self._setpoint == nil
            self._setpoint = self._min
        end
        var keep = self.arc.get_max_value()
        self.arc.set_range(int(t * self._setpoint_resolution), keep)
        self.arc.set_value(int(self._setpoint * self._setpoint_resolution))
        self._update_diff_arc()
    end

    def set_max(t)
        self._max = t
        var keep = self.arc.get_min_value()
        self.arc.set_range(keep, int(t * self._setpoint_resolution))
        self._update_diff_arc()
    end

    def get_min()
        return self._min
    end

    def get_max()
        return self._max
    end

    def set_arc_width(t)
        t = int(t)
        self.arc.set_style_arc_width(t, lv.PART_MAIN | lv.STATE_DEFAULT)
        self.diff_arc.set_style_arc_width(t, lv.PART_MAIN | lv.STATE_DEFAULT)
        self.arc.set_style_arc_width(t, lv.PART_INDICATOR | lv.STATE_DEFAULT)
        self.diff_arc.set_style_arc_width(t, lv.PART_INDICATOR | lv.STATE_DEFAULT)

        var knob_size = t
        self._setpoint_knob.set_size(knob_size, knob_size)
        self._setpoint_knob.set_style_radius(knob_size / 2, lv.PART_MAIN)
        self._setpoint_knob.set_style_border_width(knob_size / 6, lv.PART_MAIN)

        knob_size = t * 3 / 10       # 30 %
        self._temp_knob.set_size(knob_size, knob_size)
        self._temp_knob.set_style_radius(knob_size / 2, lv.PART_MAIN)
        self._temp_knob.set_style_border_width(knob_size / 2, lv.PART_MAIN)
    end

    def set_setpoint(t)
        self._setpoint = real(t)
        self._set_setpoint()
        self._write_persistent_storage()
    end

    def _set_setpoint()
        self.arc.set_value(int(self._setpoint * self._setpoint_resolution))
        self.arc.align_obj_to_angle(self._setpoint_knob, 0)
        self._update_diff_arc()
        self._update__setpoint_label()
        self._update__temp_label()
        self._update__setpoint_label()
        self.setpoint_cb(self._setpoint)
    end

    def get_setpoint(t)
        return self._setpoint
    end

    def setpoint_cb(t)
    end

    def set_measured(t)
        self._measured_temp = real(t)
        self._update_diff_arc()
        self._update__temp_label()
        self.measured_temp_cb(self._measured_temp)
    end

    def get_measured_temp(t)
        return self._measured_temp
    end

    def measured_temp_cb(t)
    end

    def set_humidity(t)
        self._humidity = int(t)
        self._update_diff_arc()
        self._update__temp_label()
    end

    def get_humidity(t)
        return self._humidity
    end

    def set_measured_rule(t)
        # remove previous rule if any
        self.remove_measured_rule()

        self._val_rule = str(t)
        tasmota.add_rule(self._val_rule, / val -> self.set_measured(val), self)
    end

    def remove_measured_rule()
        if self._val_rule != nil
            tasmota.remove_rule(self._val_rule, self)
            self._val_rule = nil
        end
    end

    def set_humidity_rule(t)
        # remove previous rule if any
        self.remove_humidity_rule()

        self._hum_rule = str(t)
        tasmota.add_rule(self._hum_rule, / val -> self.set_humidity(val), self)
    end

    def remove_humidity_rule()
        if self._hum_rule != nil
            tasmota.remove_rule(self._hum_rule, self)
            self._hum_rule = nil
        end
    end

    def set_hot_color(s)
        print(f"{s} {type(s)}")
        self._hot_color = self._parse_color(s)
    end

    def set_cold_color(s)
        self._cold_color = self._parse_color(s)
    end

    # partly taken from from lv_haspmota.be
    static def _parse_color(s)
        s = str(s)
        if s[0] == '#'
            s = f"0x{s[1..]}"
            var l = size(s)
            if l == 4
                return lv.color_hex3(int(s))
            elif l == 7
                return lv.color_hex(int(s))
            end
        else
          import introspect
          var col_name = "COLOR_" + string.toupper(s)
          var col_try = introspect.get(lv, col_name)
          if col_try != nil
            return lv.color(col_try)
          end
        end
        # fail safe with black color
        return lv.color(0x000000)
    end

    def _update_diff_arc()
        if self._max <= self._min || self._setpoint == nil || self._measured_temp == nil
            # not fully initialized yet
            return
        end
        var diff = real(self._max - self._min)
        var mes_angle = self._arc_angle * (self._measured_temp - self._min) / diff
        var set_angle = self._arc_angle * (self._setpoint - self._min) / diff
        # clamp at top/bottom
        mes_angle = tasmota.int(mes_angle, 0, self._arc_angle)
        set_angle = tasmota.int(set_angle, 0, self._arc_angle)

        def _update_it(ang1, ang2, mode, col)
            self.diff_arc.set_bg_angles(ang1, ang2)
            if self.diff_arc.get_mode() != mode
                self.diff_arc.set_mode(mode)
            end
            var col32 = lv.color_to_u32(col)
            if lv.color_to_u32(self.diff_arc.get_style_arc_color(lv.PART_INDICATOR)) != col32
                var light = lv.color_lighten(col, 160)
                self.diff_arc.set_style_arc_color(col, lv.PART_INDICATOR)
                self.arc.set_style_arc_color(light, lv.PART_INDICATOR)
                self._setpoint_knob.set_local_style_prop(lv.STYLE_BORDER_COLOR, col32, lv.PART_MAIN)
                self._temp_knob.set_local_style_prop(lv.STYLE_BORDER_COLOR, lv.color_to_u32(light), lv.PART_MAIN)
            end
        end

        if mes_angle > set_angle
            _update_it(set_angle, mes_angle, lv.ARC_MODE_NORMAL, self._cold_color)
        else
            _update_it(mes_angle, set_angle, lv.ARC_MODE_REVERSE, self._hot_color)
        end
        self.diff_arc.align_obj_to_angle(self._temp_knob, 0)
    end

    def _arc_changed(obj, evt)
        self._setpoint = real(self.arc.get_value()) / self._setpoint_resolution
        self.arc.align_obj_to_angle(self._setpoint_knob, 0)
        self._update_diff_arc()
        self._update__setpoint_label()
        self._update__temp_label()
        self._write_persistent_storage()
        self.setpoint_cb(self._setpoint)
    end

    def _size_changed(obj, evt)
        var pad_hor = self.get_style_pad_left(lv.PART_MAIN | lv.STATE_DEFAULT)
                    + self.get_style_pad_right(lv.PART_MAIN | lv.STATE_DEFAULT)
                    + self.get_style_border_width(lv.PART_MAIN | lv.STATE_DEFAULT) * 2
        var pad_ver = self.get_style_pad_top(lv.PART_MAIN | lv.STATE_DEFAULT)
                    + self.get_style_pad_bottom(lv.PART_MAIN | lv.STATE_DEFAULT)
                    + self.get_style_border_width(lv.PART_MAIN | lv.STATE_DEFAULT) * 2

        # set size of main arcs
        var s = math.min(self.get_width() - pad_hor, self.get_height() - pad_ver)
        self.arc.set_size(s, s)
        self.diff_arc.set_size(s, s)

        # update inner color according to main background color
        var bg = self.get_style_bg_color_filtered(lv.PART_MAIN)    # filtered??
        self._setpoint_knob.set_style_bg_color(bg, lv.PART_MAIN)
        self.arc.align_obj_to_angle(self._setpoint_knob, 0)
    end

    def _update__setpoint_label()
        self._setpoint_label.set_text(string.replace(f"{self._setpoint:%.1f}", ".", ","))
        self._setpoint_unit.align_to(self._setpoint_label, lv.ALIGN_OUT_RIGHT_TOP, 0, 0)
    end

    def _update__temp_label()
        var s
        s = f"\uf076 {self._measured_temp:%.1f}°C"
        if self._humidity != nil
            s += f"   \ue798 {self._humidity}%"
        end
        self._temp_label.set_text(string.replace(s, ".", ","))
    end

    def _write_persistent_storage()
        tasmota.remove_timer(self._timer_id)
        persist.setpoint = self._setpoint
        tasmota.set_timer(self._persist_delay, / -> persist.save(), self._timer_id)
        #tasmota.set_timer(self._persist_delay, / -> print(f"Update persistent storage: {self._setpoint}"), self._timer_id)
    end

    def _read_persistent_storage()
        if persist.has("setpoint")
            try
                self._setpoint = real(persist.setpoint)
            except ..
                tasmota.log(f"Invalid setpoint '{persist.setpoint}' in persistent memory")
            end
        end
    end

end

return lv_thermostat_card

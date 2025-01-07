import haspmota
import math

# lv_thermostat_card class

class lv_thermostat_card : lv.obj
    static var setpoint_resolution = 10
    static var arc_angle = 270
    var arc
    var diff_arc
    var setpoint_knob
    var measurement_knob

    var min
    var max
    var setpoint
    var measurement
    var _val_rule

    def init(parent)
        super(self).init(parent)

        var arc

        self.min = 0
        self.max = 0

        # create main arc
        arc = lv.arc(self)
        arc.set_rotation(self.arc_angle / 2)
        arc.set_bg_angles(0, self.arc_angle)
        arc.set_change_rate(30)         # °/s
        arc.add_flag(lv.OBJ_FLAG_ADV_HITTEST)
        arc.add_event_cb( / -> self._arc_changed(), lv.EVENT_VALUE_CHANGED, 0)
        self.arc = arc

        # create difference arc
        self.diff_arc = lv.arc(self.arc)
        self.diff_arc.set_rotation(self.arc_angle / 2)
        self.diff_arc.set_bg_angles(0, 1)    # will be adjusted by measurement changes
        self.diff_arc.set_range(0, 1)
        self.diff_arc.set_value(1)
        self.diff_arc.clear_flag(lv.OBJ_FLAG_CLICKABLE)
        self.diff_arc.set_style_arc_color(lv.color(lv.COLOR_GREEN), lv.PART_INDICATOR)
        # no background arc needed
        self.diff_arc.remove_style(nil, lv.PART_MAIN)

        for a: [self.arc, self.diff_arc]
            a.set_align(lv.ALIGN_CENTER)
            a.remove_style(nil, lv.PART_KNOB)
            for p: [lv.PART_MAIN, lv.PART_INDICATOR]
                a.set_style_border_width(0, p)
                a.set_style_pad_all(0, p)
            end
        end

        var knob
        knob = lv.obj(self.diff_arc)
        knob.set_local_style_prop(lv.STYLE_BORDER_COLOR, lv.COLOR_RED, lv.PART_MAIN)
        knob.set_style_bg_opa(lv.OPA_COVER, lv.PART_MAIN)
        var bg = self.get_style_bg_color_filtered(lv.PART_MAIN)    # filtered??
        knob.set_style_bg_color(bg, lv.PART_MAIN)
        self.setpoint_knob = knob

        knob = lv.obj(self.diff_arc)
        knob.set_local_style_prop(lv.STYLE_BORDER_COLOR, 0x404040, lv.PART_MAIN)
        self.measurement_knob = knob

        for k: [self.setpoint_knob, self.measurement_knob]
            k.set_style_pad_all(0, 0)
            k.set_style_margin_all(0, 0)
            k.add_flag(lv.OBJ_FLAG_EVENT_BUBBLE)
            k.clear_flag(lv.OBJ_FLAG_CLICKABLE)
        end

        self.add_event_cb( / -> self._size_changed(), lv.EVENT_SIZE_CHANGED, 0)
        self.add_event_cb( / -> self._size_changed(), lv.EVENT_STYLE_CHANGED, 0)

        #tasmota.add_driver(self)
    end

    def post_config()
        # set again value, because the first time the range might not have been valid
        self.set_setpoint(self.setpoint)
        self.set_measurement(self.measurement)
    end

    def set_min(t)
        self.min = t
        var keep = self.arc.get_max_value()
        self.arc.set_range(int(t * self.setpoint_resolution), keep)
        if self.setpoint != nil
            self.arc.set_value(int(self.setpoint * self.setpoint_resolution))
        end
        self.setpoint = real(self.arc.get_value()) / self.setpoint_resolution
        self.update_diff_arc()
    end

    def set_max(t)
        self.max = t
        var keep = self.arc.get_min_value()
        self.arc.set_range(keep, int(t * self.setpoint_resolution))
        if self.setpoint != nil
            self.arc.set_value(int(self.setpoint * self.setpoint_resolution))
        end
        self.setpoint = real(self.arc.get_value()) / self.setpoint_resolution
        self.update_diff_arc()
    end

    def get_min()
        return self.min
    end

    def get_max()
        return self.max
    end

    def set_arc_width(t)
        t = int(t)
        self.arc.set_style_arc_width(t, lv.PART_MAIN | lv.STATE_DEFAULT)
        self.diff_arc.set_style_arc_width(t, lv.PART_MAIN | lv.STATE_DEFAULT)
        self.arc.set_style_arc_width(t, lv.PART_INDICATOR | lv.STATE_DEFAULT)
        self.diff_arc.set_style_arc_width(t, lv.PART_INDICATOR | lv.STATE_DEFAULT)

        var knob_size = t
        self.setpoint_knob.set_size(knob_size, knob_size)
        self.setpoint_knob.set_style_radius(knob_size / 2, lv.PART_MAIN)
        self.setpoint_knob.set_style_border_width(knob_size / 6, lv.PART_MAIN)

        knob_size = t * 3 / 10       # 30 %
        self.measurement_knob.set_size(knob_size, knob_size)
        self.measurement_knob.set_style_radius(knob_size / 2, lv.PART_MAIN)
        self.measurement_knob.set_style_border_width(knob_size / 2, lv.PART_MAIN)
    end

    def set_setpoint(t)
        self.setpoint = t
        self.arc.set_value(int(t * self.setpoint_resolution))
        self.arc.align_obj_to_angle(self.setpoint_knob, 0)
        self.update_diff_arc()
    end

    def set_measurement(t)
        print(f"set_measurement {t}")
        self.measurement = t
        self.update_diff_arc()
    end

    def set_measurement_rule(t)
        # remove previous rule if any
        self.remove_measurement_rule()

        self._val_rule = str(t)
        tasmota.add_rule(self._val_rule, / val -> self.set_measurement(val), self)
    end

    def remove_measurement_rule()
        if self._val_rule != nil
            tasmota.remove_rule(self._val_rule, self)
            self._val_rule = nil
        end
    end

    def update_diff_arc()
        if self.max <= self.min || self.setpoint == nil || self.measurement == nil
            # not fully initialized yet
            return
        end
        var diff = real(self.max - self.min)
        var mes_angle = self.arc_angle * (self.measurement - self.min) / diff
        var set_angle = self.arc_angle * (self.setpoint - self.min) / diff
        # clamp at top/bottom
        mes_angle = tasmota.int(mes_angle, 0, self.arc_angle)
        set_angle = tasmota.int(set_angle, 0, self.arc_angle)
        if mes_angle > set_angle
            self.diff_arc.set_mode(lv.ARC_MODE_NORMAL)
            self.diff_arc.set_bg_angles(set_angle, mes_angle)
        else
            self.diff_arc.set_mode(lv.ARC_MODE_REVERSE)
            self.diff_arc.set_bg_angles(mes_angle, set_angle)
        end
        self.diff_arc.align_obj_to_angle(self.measurement_knob, 0)
    end

    def _arc_changed(obj, evt)
        self.setpoint = real(self.arc.get_value()) / self.setpoint_resolution
        self.arc.align_obj_to_angle(self.setpoint_knob, 0)
        self.update_diff_arc()
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
        self.setpoint_knob.set_style_bg_color(bg, lv.PART_MAIN)
    end


  # def every_second()
  #   var dirty = false
  # 	for n:0..20
  # 	  var line = self.log_reader.get_log(self.log_level)
  # 	  if line == nil break end  # no more logs
  # 	  self.lines.remove(0)            # remove first line
  # 	  self.lines.push(line)
  # 	  dirty = true
  # 	end
  # 	if dirty self.update() end
  # end

  # def update()
  #   var msg = self.lines.concat("\n")
  #   self.label.set_text(msg)
  # end
end

return lv_thermostat_card

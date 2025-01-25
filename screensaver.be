class screensaver

	static var _event_template = '{"Screensaver":{"value":%d}}'

    var _dly
    var _dim_on
    var _dim_off
    var _overlay

    def init()
        # initialize
        self._dly = 0      # start disabled
        self._dim_on = 100
        self._dim_off = 0
        self._pressed()
        self._released()
    end

    def set_delay(val)
        tasmota.remove_timer("scrnsvr")
        self._dly = tasmota.int(val, 0, 3600) * 1000
        self._expired()
        return self
    end

    def set_dim_on(val)
        self._dim_on = tasmota.int(val, 0, 100)
        return self
    end

    def set_dim_off(val)
        self._dim_off = tasmota.int(val, 0, 100)
        return self
    end

    def turn_off()
        tasmota.remove_timer("scrnsvr")
        self._create_overlay()
        self._displ_off()
    end

    def _pressed()
        self._displ_on()
    end

    def _released()
        self._delete_overlay()
        self._expired()
    end

    def _expired()
        if self._dly > 0
            var inact = lv.layer_sys().get_display().get_inactive_time()
            if inact >= self._dly
                self._create_overlay()
                self._displ_off()
            else
                tasmota.set_timer(self._dly + 500 - inact, /-> self._expired(), "scrnsvr")
            end
        end
    end

    def _create_overlay()
        if self._overlay == nil
            var m = lv.obj(lv.layer_sys())
            m.remove_style_all()
            m.set_style_bg_opa(lv.OPA_TRANSP, lv.PART_MAIN)    # do not actually repaint
            m.set_size(lv.pct(100), lv.pct(100))       # full-sized
            m.add_event_cb(/-> self._pressed(), lv.EVENT_PRESSED, 0)
            m.add_event_cb(/-> self._released(), lv.EVENT_RELEASED, 0)
            self._overlay = m
        end
    end

    def _delete_overlay()
        if self._overlay != nil
            self._overlay.del()
            self._overlay = nil
        end
    end

    def _displ_off()
        import display
        display.dimmer(self._dim_off)
        tasmota.publish_rule(format(self._event_template, 0))
    end

    def _displ_on()
        import display
        display.dimmer(self._dim_on)
        tasmota.publish_rule(format(self._event_template, 1))
    end

end

return screensaver

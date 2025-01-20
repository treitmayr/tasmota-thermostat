class screensaver
    var _dly
    var _dim_on
    var _dim_off
    var _modal
    var _disp

    def init(delay, dim_on, dim_off)
        self._dly = delay * 1000
        self._dim_on = dim_on != nil ? dim_on : 100
        self._dim_off = dim_off != nil ? dim_off : 0

        var m = lv.obj(lv.layer_top())
        m.remove_style_all()
        m.remove_flag(lv.OBJ_FLAG_IGNORE_LAYOUT)     # see lv_msgbox implementation
        m.set_style_bg_opa(lv.OPA_TRANSP, lv.PART_MAIN)    # do not actually repaint
        m.set_size(lv.pct(100), lv.pct(100))
        m.add_event_cb( / -> self._pressed(), lv.EVENT_PRESSED, 0)
        m.add_event_cb( / -> self._released(), lv.EVENT_RELEASED, 0)
        self._modal = m

        self._disp = lv.layer_top().get_display()

        # initialize
        self._pressed()
        self._released()
    end

    def turn_off()
        tasmota.remove_timer("scrnsvr")
        self._modal.add_flag(lv.OBJ_FLAG_CLICKABLE)
        import display
        display.dimmer(self._dim_off)
    end

    def _pressed()
        import display
        display.dimmer(self._dim_on)
    end

    def _released()
        self._modal.clear_flag(lv.OBJ_FLAG_CLICKABLE)
        self._expired()
    end

    def _tmr_off()
        tasmota.remove_timer("scrnsvr")
    end

    def _expired()
        var inact = self._disp.get_inactive_time()
        if inact >= self._dly
            self._modal.add_flag(lv.OBJ_FLAG_CLICKABLE)
            import display
            display.dimmer(self._dim_off)
        else
            tasmota.set_timer(self._dly + 500 - inact, / -> self._expired(), "scrnsvr")
        end
    end

end

return screensaver

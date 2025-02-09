import lv

class screensaver : lv.obj

	static var _event_template = '{"Screensaver":{"value":%d}}'

    var _dly
    var _dim_on
    var _dim_off
    var _overlay
    var _berry_on
    var _berry_off

    def init(parent)
        super(self).init(parent)

        # initialize
        self._dly = 0      # start disabled
        self._dim_on = 100
        self._dim_off = 0

        # if included via pages.jsonl, make this object invisible
        self.remove_style_all()
        self.add_flag(lv.OBJ_FLAG_HIDDEN)

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

    def set_berry_on(val)
        self._berry_on = self._berry_compile(val)
    end

    def set_berry_off(val)
        self._berry_off = self._berry_compile(val)
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
            tasmota.gc()
        end
    end

    def _displ_off()
        print("_displ_off")
        if self._berry_off
            self._berry_run(self._berry_off)
        else
            import display
            display.dimmer(self._dim_off)
        end
        tasmota.publish_rule(format(self._event_template, 0))
    end

    def _displ_on()
        print("_displ_on")
        if self._berry_on
            self._berry_run(self._berry_on)
        else
            import display
            display.dimmer(self._dim_on)
        end
        tasmota.publish_rule(format(self._event_template, 1))
    end

    def _berry_compile(code)
        var func_compiled
        var berry_code = str(code)
        if berry_code != "nil"
            try
                func_compiled = compile(berry_code)
            except .. as e,m
                print(f"SSR: Unable to compile berry code \"{berry_code}\" - '{e}' - {m}")
            end
        end
        return func_compiled
    end

    def _berry_run(func)
        if func != nil
            try
                # run the compiled code
                var f_ret = func()
                if type(f_ret) == 'function'
                    f_ret()
                end
            except .. as e,m
                print(f"SSR: Unable to run berry code \"{func}\" - '{e}' - {m}")
            end
        end
    end

end

return screensaver
